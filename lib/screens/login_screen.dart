import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  void _login() async {
    setState(() {
      errorMessage = null;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      final response = await authService.iniciarSesionWithResponse(
        context,
        emailController.text,
        passwordController.text,
      );

      if (response != null) {
        if (response['error'] != null) {
          setState(() {
            errorMessage = response['error'];
          });
        } else if (response['requiresCode'] == true) {
          setState(() {
            showCodeField = true;
          });
        } else if (response['token'] != null) {
          final token = response['token'];
          try {
            await userProvider.setToken(token);
            await Future.delayed(Duration(milliseconds: 100));
            if (userProvider.isMesero && !userProvider.isAdmin) {
              Navigator.pushReplacementNamed(context, '/mesas');
            } else {
              Navigator.pushReplacementNamed(context, '/dashboard');
            }
          } catch (e) {
            setState(() {
              errorMessage = 'Error interno. Inténtalo de nuevo.';
            });
          }
        }
      } else {
        setState(() {
          errorMessage = 'Error de conexión. Inténtalo de nuevo.';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error inesperado: $e';
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

        await Future.delayed(Duration(milliseconds: 100));

        if (userProvider.isMesero && !userProvider.isAdmin) {
          Navigator.pushReplacementNamed(context, '/mesas');
        } else {
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
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
      barrierColor: Colors.black.withOpacity(0.7),
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
    print('🔵 LoginScreen build: construyendo pantalla de login');
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top,
            ),
            child: Center(
              child: Container(
                padding: EdgeInsets.all(context.responsivePadding),
                constraints: BoxConstraints(
                  maxWidth: context.isMobile ? double.infinity : 400,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo elegante con sombra
                    Container(
                      padding: EdgeInsets.all(AppTheme.spacingLarge),
                      decoration: AppTheme.elevatedCardDecoration,
                      child: Container(
                        width: context.isMobile ? 120 : 140,
                        height: context.isMobile ? 120 : 140,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLarge,
                          ),
                          border: Border.all(
                            color: AppTheme.primary.withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLarge - 2,
                          ),
                          child: Image.asset(
                            'images/logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusLarge - 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.restaurant,
                                  color: AppTheme.primary,
                                  size: context.isMobile ? 60 : 70,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: AppTheme.spacingXLarge),

                    // Tarjeta principal de login
                    Container(
                      padding: EdgeInsets.all(
                        context.isMobile
                            ? AppTheme.spacingLarge
                            : AppTheme.spacingXLarge,
                      ),
                      decoration: AppTheme.elevatedCardDecoration,
                      child: Column(
                        children: [
                          // Título elegante
                          Text(
                            'Bienvenido',
                            style: AppTheme.headlineLarge.copyWith(
                              fontSize: context.isMobile ? 24 : 28,
                            ),
                          ),
                          SizedBox(height: AppTheme.spacingSmall),
                          Text(
                            'Ingresa a tu cuenta',
                            style: AppTheme.bodyLarge.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          SizedBox(height: AppTheme.spacingXLarge),

                          // Campo de email
                          TextFormField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: AppTheme.bodyMedium,
                            decoration: InputDecoration(
                              labelText: 'Correo electrónico',
                              labelStyle: AppTheme.labelMedium.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                color: AppTheme.primary,
                              ),
                              filled: true,
                              fillColor: AppTheme.surfaceDark,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMedium,
                                ),
                                borderSide: BorderSide(
                                  color: AppTheme.textMuted.withOpacity(0.3),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMedium,
                                ),
                                borderSide: BorderSide(
                                  color: AppTheme.textMuted.withOpacity(0.3),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMedium,
                                ),
                                borderSide: BorderSide(
                                  color: AppTheme.primary,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: AppTheme.spacingMedium),

                          // Campo de contraseña
                          TextFormField(
                            controller: passwordController,
                            obscureText: true,
                            style: AppTheme.bodyMedium,
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              labelStyle: AppTheme.labelMedium.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: AppTheme.primary,
                              ),
                              filled: true,
                              fillColor: AppTheme.surfaceDark,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMedium,
                                ),
                                borderSide: BorderSide(
                                  color: AppTheme.textMuted.withOpacity(0.3),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMedium,
                                ),
                                borderSide: BorderSide(
                                  color: AppTheme.textMuted.withOpacity(0.3),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMedium,
                                ),
                                borderSide: BorderSide(
                                  color: AppTheme.primary,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: AppTheme.spacingLarge),

                          // Botón de login elegante con mejor responsividad
                          Container(
                            width: double.infinity,
                            margin: EdgeInsets.symmetric(
                              horizontal: 4,
                            ), // Margen para evitar cortes
                            child: SizedBox(
                              height: context.isMobile
                                  ? 56
                                  : 60, // Altura más generosa
                              child: ElevatedButton(
                                onPressed: _login,
                                style: AppTheme.primaryButtonStyle.copyWith(
                                  elevation: MaterialStateProperty.all(4),
                                  shape: MaterialStateProperty.all(
                                    RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusMedium,
                                      ),
                                    ),
                                  ),
                                  padding: MaterialStateProperty.all(
                                    EdgeInsets.symmetric(
                                      horizontal: context.isMobile ? 24 : 28,
                                      vertical: context.isMobile ? 16 : 18,
                                    ),
                                  ),
                                ),
                                child: FittedBox(
                                  fit: BoxFit
                                      .scaleDown, // Escala el texto si es necesario
                                  child: Text(
                                    'Iniciar Sesión',
                                    style: AppTheme.labelLarge.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: context.isMobile ? 18 : 20,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: AppTheme.spacingMedium),

                          // Enlace de registro
                          TextButton(
                            onPressed: _showRegisterDialog,
                            style: AppTheme.secondaryButtonStyle,
                            child: RichText(
                              text: TextSpan(
                                text: '¿No tienes cuenta? ',
                                style: AppTheme.bodyMedium.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Regístrate',
                                    style: AppTheme.bodyMedium.copyWith(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Campo de código de verificación (si es necesario)
                          if (showCodeField) ...[
                            SizedBox(height: AppTheme.spacingLarge),
                            TextFormField(
                              controller: codeController,
                              keyboardType: TextInputType.number,
                              style: AppTheme.bodyMedium,
                              decoration: InputDecoration(
                                labelText: 'Código de verificación',
                                labelStyle: AppTheme.labelMedium.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                                prefixIcon: Icon(
                                  Icons.security,
                                  color: AppTheme.warning,
                                ),
                                filled: true,
                                fillColor: AppTheme.surfaceDark,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMedium,
                                  ),
                                  borderSide: BorderSide(
                                    color: AppTheme.warning.withOpacity(0.3),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMedium,
                                  ),
                                  borderSide: BorderSide(
                                    color: AppTheme.warning.withOpacity(0.3),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMedium,
                                  ),
                                  borderSide: BorderSide(
                                    color: AppTheme.warning,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: AppTheme.spacingMedium),
                            SizedBox(
                              width: double.infinity,
                              height: 45,
                              child: ElevatedButton(
                                onPressed: _validateCode,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.warning,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusMedium,
                                    ),
                                  ),
                                  elevation: 2,
                                ),
                                child: Text(
                                  'Validar Código',
                                  style: AppTheme.labelMedium.copyWith(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],

                          // Mensaje de error elegante
                          if (errorMessage != null) ...[
                            SizedBox(height: AppTheme.spacingLarge),
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
                                  SizedBox(width: AppTheme.spacingSmall),
                                  Expanded(
                                    child: Text(
                                      errorMessage!,
                                      style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.error,
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
