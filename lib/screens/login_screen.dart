import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/auth_service.dart';
import '../providers/user_provider.dart';
import '../providers/datos_cache_provider.dart';
import '../theme/app_theme.dart';
import '../services/keep_alive_service.dart';
import 'package:universal_html/html.dart' as html;

// Extension para validación de email
extension EmailValidator on String {
  bool isValidEmail() {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(this);
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // Services and Controllers
  final AuthService authService = AuthService();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController codeController = TextEditingController();
  final TextEditingController registerNameController = TextEditingController();
  final TextEditingController registerEmailController = TextEditingController();
  final TextEditingController registerPasswordController =
      TextEditingController();

  // State variables
  bool showCodeField = false;
  String? errorMessage;
  bool rememberCredentials = false;
  bool _showPassword = false; // Toggle para mostrar/ocultar contraseña
  bool _isLoading = false; // Estado de carga del botón
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final _secureStorage = const FlutterSecureStorage();
  // Wake-up / retry timers
  Timer? _loginWatchdogTimer;
  bool _showWakeupOverlay = false;
  int _wakeupRemainingSeconds = 60;
  Timer? _wakeupTicker;
  Timer? _wakeupStepTimer;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    
    // Inicializar controladores de animación
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    // Iniciar animaciones
    _fadeController.forward();
    _slideController.forward();

    // Listeners para inputs
    emailController.addListener(() {
      setState(() {});
    });
    passwordController.addListener(() {
      setState(() {});
    });
  }

  // ----- Wake-up sequence -----
  void _startWakeUpSequence() {
    if (!mounted) return;
    if (_showWakeupOverlay) return;
      
    setState(() {
      _showWakeupOverlay = true;
      _wakeupRemainingSeconds = 60;
    });

    // Ticker cada segundo para la barra de progreso
    _wakeupTicker?.cancel();
    _wakeupTicker = Timer.periodic(Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _wakeupRemainingSeconds = (_wakeupRemainingSeconds - 1).clamp(0, 60);
      });
      if (_wakeupRemainingSeconds <= 0) {
        _reloadPage();
      }
    });

    // Paso de wake-up: cada 60s enviar un ping liviano al backend
    _wakeupStepTimer?.cancel();
    _wakeupStepTimer = Timer.periodic(Duration(seconds: 60), (_) async {
      await _performWakeupStep();
    });

    // Ejecutar inmediatamente un primer intento
    _performWakeupStep();
  }

  void _stopWakeUpSequence() {
    _wakeupTicker?.cancel();
    _wakeupStepTimer?.cancel();
    _loginWatchdogTimer?.cancel();
    if (mounted) {
      setState(() {
        _showWakeupOverlay = false;
      });
    }
  }

  void _reloadPage() {
    _wakeupTicker?.cancel();
    _wakeupStepTimer?.cancel();
    _loginWatchdogTimer?.cancel();
    html.window.location.reload();
  }

  Future<void> _performWakeupStep() async {
    // Ping liviano para despertar el backend sin saturarlo con recargas de datos
    try {
      await KeepAliveService().forcePing();
    } catch (_) {}
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final savedEmail = await _secureStorage.read(key: 'saved_email');
      final savedPassword = await _secureStorage.read(key: 'saved_password');
      final savedRemember = await _secureStorage.read(
        key: 'remember_credentials',
      );

      if (savedEmail != null && savedPassword != null) {
        setState(() {
          emailController.text = savedEmail;
          passwordController.text = savedPassword;
          rememberCredentials = savedRemember == 'true';
        });

        // Intentar auto-login si las credenciales están guardadas
        if (savedRemember == 'true') {
          _attemptAutoLogin();
        }
      }
    } catch (e) {
        
    }
  }

  Future<void> _attemptAutoLogin() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // Solo hacer auto-login si no hay token válido actualmente
      if (!userProvider.isAuthenticated) {
          

        // Iniciar watchdog: si el login tarda más de 15s, arrancar pantalla de wake-up
        _loginWatchdogTimer?.cancel();
        _loginWatchdogTimer = Timer(Duration(seconds: 15), () {
          if (mounted) _startWakeUpSequence();
        });

        final response = await authService.iniciarSesionWithResponse(
          context,
          emailController.text,
          passwordController.text,
        );

        // Login completado — cancelar watchdog/wakeup si estaba activo
        _loginWatchdogTimer?.cancel();
        if (_showWakeupOverlay) {
          _stopWakeUpSequence();
        }

        if (response != null && response['token'] != null) {
          final token = response['token'];
          await userProvider.setToken(token);

            

          // Pre-cargar productos en background
          final cacheProvider = Provider.of<DatosCacheProvider>(
            context,
            listen: false,
          );
          cacheProvider.warmupProductos();

          // Mantener el backend de Render despierto
          KeepAliveService().startKeepAlive();

          // Navegar automáticamente
          await Future.delayed(Duration(milliseconds: 100));
          context.go('/dashboard');
        } else if (response != null && response['requiresCode'] == true) {
          // Si requiere código 2FA, mostrar el campo
          setState(() {
            showCodeField = true;
          });
            
        } else {
            
        }
      }
    } catch (e) {
        
    }
  }

  Future<void> _saveCredentials() async {
    try {
      await _secureStorage.write(
        key: 'saved_email',
        value: emailController.text,
      );
      await _secureStorage.write(
        key: 'saved_password',
        value: passwordController.text,
      );
      await _secureStorage.write(key: 'remember_credentials', value: 'true');
        
    } catch (e) {
        
    }
  }

  Future<void> _clearSavedCredentials() async {
    try {
      await _secureStorage.delete(key: 'saved_email');
      await _secureStorage.delete(key: 'saved_password');
      await _secureStorage.delete(key: 'remember_credentials');
        
    } catch (e) {
        
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    codeController.dispose();
    registerNameController.dispose();
    registerEmailController.dispose();
    registerPasswordController.dispose();
    _loginWatchdogTimer?.cancel();
    _wakeupTicker?.cancel();
    _wakeupStepTimer?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _login() async {
    setState(() {
      errorMessage = null;
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // Iniciar watchdog: si el login tarda más de 15s, arrancar pantalla de wake-up
      _loginWatchdogTimer?.cancel();
      _loginWatchdogTimer = Timer(Duration(seconds: 15), () {
        if (mounted) _startWakeUpSequence();
      });

      final response = await authService.iniciarSesionWithResponse(
        context,
        emailController.text,
        passwordController.text,
      );

      // Login completado — cancelar watchdog/wakeup si estaba activo
      _loginWatchdogTimer?.cancel();
      if (_showWakeupOverlay) {
        _stopWakeUpSequence();
      }

      if (response != null) {
        if (response['error'] != null) {
          setState(() {
            errorMessage = response['error'];
            _isLoading = false;
          });
        } else if (response['requiresCode'] == true) {
          setState(() {
            showCodeField = true;
            _isLoading = false;
          });
        } else if (response['token'] != null) {
          final token = response['token'];
          try {
            await userProvider.setToken(token);

            // Guardar credenciales si el usuario lo solicita
            if (rememberCredentials) {
              await _saveCredentials();
            } else {
              await _clearSavedCredentials();
            }

            // Pre-cargar productos en background
            final cacheProvider = Provider.of<DatosCacheProvider>(
              context,
              listen: false,
            );
            cacheProvider.warmupProductos();

            // Mantener el backend de Render despierto
            KeepAliveService().startKeepAlive();

            await Future.delayed(Duration(milliseconds: 100));

            // Redirigir según el rol del usuario
            if (userProvider.isOnlyAsesor) {
              // Los asesores van directamente a su pantalla de pedidos
              context.go('/asesor-pedidos');
            } else {
              // Admins y otros roles van al dashboard
              context.go('/dashboard');
            }
          } catch (e) {
            setState(() {
              errorMessage = 'Error interno. Inténtalo de nuevo.';
              _isLoading = false;
            });
          }
        }
      } else {
        setState(() {
          errorMessage = 'Error de conexión. Inténtalo de nuevo.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error inesperado: $e';
        _isLoading = false;
      });
    }
  }

  void _validateCode() async {
    setState(() {
      errorMessage = null;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final response = await authService.validarCodigo(codeController.text);
      if (response != null && response['token'] != null) {
        await userProvider.setToken(response['token']);

        // Guardar credenciales si el usuario lo solicita
        if (rememberCredentials) {
          await _saveCredentials();
        } else {
          await _clearSavedCredentials();
        }

        // Pre-cargar productos en background
        final cacheProvider = Provider.of<DatosCacheProvider>(
          context,
          listen: false,
        );
        cacheProvider.warmupProductos();

        await Future.delayed(Duration(milliseconds: 100));
        context.go('/dashboard');
      } else {
        setState(() {
          errorMessage = 'Código incorrecto o expirado.';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: $e';
      });
    }
  }

  Future<void> _showRegisterDialog() async {
    String? registerError;
    bool isLoading = false;
    await showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: context.isMobile ? double.infinity : 400,
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                margin: EdgeInsets.all(context.responsivePadding),
                padding: EdgeInsets.all(AppTheme.spacingLarge),
                decoration: AppTheme.elevatedCardDecoration,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(AppTheme.spacingSmall),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusSmall,
                              ),
                            ),
                            child: Icon(
                              Icons.person_add,
                              color: AppTheme.primary,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: AppTheme.spacingMedium),
                          Text('Crear cuenta', style: AppTheme.headlineMedium),
                        ],
                      ),
                      SizedBox(height: AppTheme.spacingLarge),
                      if (registerError != null) ...[
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(AppTheme.spacingMedium),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMedium,
                            ),
                            border: Border.all(
                              color: AppTheme.error.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: AppTheme.error,
                                size: 20,
                              ),
                              SizedBox(width: AppTheme.spacingSmall),
                              Expanded(
                                child: Text(
                                  registerError!,
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: AppTheme.spacingMedium),
                      ],
                      TextFormField(
                        controller: registerNameController,
                        style: AppTheme.bodyMedium,
                        decoration: InputDecoration(
                          labelText: 'Nombre completo',
                          prefixIcon: Icon(
                            Icons.person_outline,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                      SizedBox(height: AppTheme.spacingMedium),
                      TextFormField(
                        controller: registerEmailController,
                        keyboardType: TextInputType.emailAddress,
                        style: AppTheme.bodyMedium,
                        decoration: InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                      SizedBox(height: AppTheme.spacingMedium),
                      TextFormField(
                        controller: registerPasswordController,
                        obscureText: true,
                        style: AppTheme.bodyMedium,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                      SizedBox(height: AppTheme.spacingLarge),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('Cancelar'),
                            ),
                          ),
                          SizedBox(width: AppTheme.spacingMedium),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isLoading
                                  ? null
                                  : () async {
                                      setState(() {
                                        isLoading = true;
                                        registerError = null;
                                      });

                                      try {
                                        final result = await authService
                                            .registerUser(
                                              registerNameController.text,
                                              registerEmailController.text,
                                              registerPasswordController.text,
                                            );

                                        if (result['success'] == true) {
                                          if (mounted) {
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Cuenta creada exitosamente',
                                                ),
                                                backgroundColor:
                                                    AppTheme.success,
                                              ),
                                            );
                                            registerNameController.clear();
                                            registerEmailController.clear();
                                            registerPasswordController.clear();
                                          }
                                        } else {
                                          setState(() {
                                            registerError =
                                                result['message'] ??
                                                'Error al crear la cuenta';
                                          });
                                        }
                                      } catch (e) {
                                        setState(() {
                                          registerError = 'Error: $e';
                                        });
                                      } finally {
                                        setState(() {
                                          isLoading = false;
                                        });
                                      }
                                    },
                              child: isLoading
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text('Crear cuenta'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool emailValid = emailController.text.isValidEmail();
    final isMobile = context.screenWidth < 900;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Layout principal: dos columnas (desktop) o mobile
          if (!isMobile)
            Row(
              children: [
                // COLUMNA IZQUIERDA: Fondo con imagen de motos (70%)
                Expanded(
                  flex: 7,
                  child: Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/images/fondologin.png'),
                        fit: BoxFit.cover,
                        onError: (exception, stackTrace) {},
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Overlay oscuro para mejorar legibilidad del texto
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.3),
                                Colors.black.withValues(alpha: 0.5),
                              ],
                            ),
                          ),
                        ),
                        // Contenido
                        Center(
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Vercy Motos',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: context.screenWidth > 1400 ? 56 : 48,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withValues(alpha: 0.6),
                                          offset: Offset(0, 3),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Gestión inteligente de tu negocio',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.95),
                                      fontSize: context.screenWidth > 1400 ? 20 : 18,
                                      fontWeight: FontWeight.w400,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withValues(alpha: 0.5),
                                          offset: Offset(0, 2),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // COLUMNA DERECHA: Formulario de login (30%)
                Expanded(flex: 3, child: _buildLoginForm(emailValid, context)),
              ],
            )
          else
            // En mobile: solo el formulario
            _buildLoginForm(emailValid, context),

          // Wake-up overlay
          if (_showWakeupOverlay)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.6),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppTheme.primary),
                      SizedBox(height: AppTheme.spacingLarge),
                      Text(
                        'Despertando backend...',
                        style: AppTheme.headlineSmall.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: AppTheme.spacingSmall),
                      Text(
                        '${(_wakeupRemainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_wakeupRemainingSeconds % 60).toString().padLeft(2, '0')}',
                        style: AppTheme.bodyLarge.copyWith(color: Colors.white),
                      ),
                      SizedBox(height: AppTheme.spacingMedium),
                      Text(
                        'Se intentará recargar Productos y Pedidos periódicamente.',
                        textAlign: TextAlign.center,
                        style: AppTheme.bodySmall.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      SizedBox(height: AppTheme.spacingLarge),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              _stopWakeUpSequence();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.error,
                            ),
                            child: Text('Cancelar'),
                          ),
                          SizedBox(width: AppTheme.spacingMedium),
                          ElevatedButton(
                            onPressed: () async {
                              await _performWakeupStep();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                            ),
                            child: Text('Intentar ahora'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(bool emailValid, BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Container(
                color: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: context.isMobile ? 24 : context.isTablet ? 32 : 48,
                  vertical: context.isMobile ? 32 : 32,
                ),
                child: Center(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: context.isMobile ? double.infinity : context.isTablet ? 450 : 400,
                        ),
                        padding: EdgeInsets.all(context.isMobile ? 20 : 32),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!, width: 1.5),
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                      // Logo (solo en mobile, cuando no hay imagen lateral)
                      if (context.isMobile) ...[
                        Center(
                          child: Image.asset(
                            'assets/images/vercylogo.png',
                            height: 64,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.two_wheeler,
                              size: 56,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                      ],
                      // Título
                      Text(
                        'Bienvenido',
                        style: TextStyle(
                          fontSize: context.isMobile ? 26 : context.isTablet ? 32 : 36,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Ingresa a tu cuenta',
                        style: TextStyle(
                          fontSize: context.isMobile ? 13 : 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      SizedBox(height: context.isMobile ? 20 : 40),

                      // Email input
                      _buildInputField(
                        controller: emailController,
                        label: 'Correo electrónico',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (_) => setState(() {}),
                        suffixIcon: emailController.text.isNotEmpty
                            ? Icon(
                                emailValid
                                    ? Icons.check_circle
                                    : Icons.error_outline,
                                color: emailValid
                                    ? AppTheme.success
                                    : AppTheme.error,
                              )
                            : null,
                      ),
                      SizedBox(height: context.isMobile ? 16 : 20),

                      // Password input
                      _buildInputField(
                        controller: passwordController,
                        label: 'Contraseña',
                        icon: Icons.lock_outline,
                        obscureText: !_showPassword,
                        onChanged: (_) => setState(() {}),
                        suffixIcon: passwordController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AppTheme.textMuted,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showPassword = !_showPassword;
                                  });
                                },
                              )
                            : null,
                      ),
                      SizedBox(height: context.isMobile ? 12 : 16),

                      // Remember checkbox
                      Row(
                        children: [
                          Checkbox(
                            value: rememberCredentials,
                            onChanged: (value) {
                              setState(() {
                                rememberCredentials = value ?? false;
                              });
                            },
                            activeColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            side: BorderSide(
                              color: Colors.grey[400]!,
                              width: 1.5,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Recordar mis credenciales',
                              style: TextStyle(
                                fontSize: context.isMobile ? 12 : 14,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: context.isMobile ? 24 : 32),

                      // Login button - prominente y rojo
                      SizedBox(
                        width: double.infinity,
                        height: context.isMobile ? 48 : 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondaryDark,
                            disabledBackgroundColor: AppTheme.secondaryDark.withOpacity(0.6),
                            foregroundColor: Colors.white,
                            elevation: _isLoading ? 2 : 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Iniciando sesión...',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: context.isMobile ? 14 : 16,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  'Iniciar Sesión',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: context.isMobile ? 14 : 16,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(height: context.isMobile ? 16 : 20),

                      // Divider con texto
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey[300])),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'o',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: context.isMobile ? 12 : 14,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey[300])),
                        ],
                      ),
                      SizedBox(height: context.isMobile ? 16 : 20),

                      // Sign up link
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '¿No tienes cuenta? ',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: context.isMobile ? 12 : 14,
                              ),
                            ),
                            GestureDetector(
                              onTap: _isLoading ? null : _showRegisterDialog,
                              child: Text(
                                'Regístrate',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Verificación 2FA
                      if (showCodeField) ...[
                        SizedBox(height: 32),
                        Text(
                          'Código de verificación',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 12),
                        _buildInputField(
                          controller: codeController,
                          label: 'Ingresa el código',
                          icon: Icons.security,
                          keyboardType: TextInputType.number,
                        ),
                        SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _validateCode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.warning,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Validar Código',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],

                      // Error message
                      if (errorMessage != null) ...[
                        SizedBox(height: 24),
                        AnimatedContainer(
                          duration: Duration(milliseconds: 300),
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.error.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: AppTheme.error,
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: TextStyle(
                                    color: AppTheme.error,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
          );
        },
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: AppTheme.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppTheme.primary, width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14,
          ),
        ),
      ),
    );
  }
}
