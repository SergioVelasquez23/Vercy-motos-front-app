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
  // Controladores para registro
  final TextEditingController registerNameController = TextEditingController();
  final TextEditingController registerEmailController = TextEditingController();
  final TextEditingController registerPasswordController =
      TextEditingController();

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
                      // Título
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(AppTheme.spacingSmall),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            ),
                            child: Icon(Icons.person_add, color: AppTheme.primary, size: 24),
                          ),
                          SizedBox(width: AppTheme.spacingMedium),
                          Text(
                            'Crear cuenta',
                            style: AppTheme.headlineMedium,
                          ),
                        ],
                      ),
                      SizedBox(height: AppTheme.spacingLarge),

                      // Campo Nombre
                      TextFormField(
                        controller: registerNameController,
                        style: AppTheme.bodyMedium,
                        decoration: InputDecoration(
                          labelText: 'Nombre completo',
                          labelStyle: AppTheme.labelMedium.copyWith(color: AppTheme.textSecondary),
                          prefixIcon: Icon(
                            Icons.person_outline,
                            color: AppTheme.primary,
                          ),
                          filled: true,
                          fillColor: AppTheme.surfaceDark,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            borderSide: BorderSide(color: AppTheme.textMuted.withOpacity(0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            borderSide: BorderSide(color: AppTheme.textMuted.withOpacity(0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            borderSide: BorderSide(color: AppTheme.primary, width: 2),
                          ),
                        ),
                      ),
                      SizedBox(height: AppTheme.spacingMedium),

                      // Campo Email
                      TextFormField(
                        controller: registerEmailController,
                        keyboardType: TextInputType.emailAddress,
                        style: AppTheme.bodyMedium,
                        decoration: InputDecoration(
                          labelText: 'Correo electrónico',
                          labelStyle: AppTheme.labelMedium.copyWith(color: AppTheme.textSecondary),
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: AppTheme.primary,
                          ),
                          filled: true,
                          fillColor: AppTheme.surfaceDark,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            borderSide: BorderSide(color: AppTheme.textMuted.withOpacity(0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            borderSide: BorderSide(color: AppTheme.textMuted.withOpacity(0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            borderSide: BorderSide(color: AppTheme.primary, width: 2),
                          ),
                        ),
                      ),
                      SizedBox(height: AppTheme.spacingMedium),

                      // Campo Contraseña
                      TextFormField(
                        controller: registerPasswordController,
                        obscureText: true,
                        style: AppTheme.bodyMedium,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          labelStyle: AppTheme.labelMedium.copyWith(color: AppTheme.textSecondary),
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: AppTheme.primary,
                          ),
                          filled: true,
                          fillColor: AppTheme.surfaceDark,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            borderSide: BorderSide(color: AppTheme.textMuted.withOpacity(0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            borderSide: BorderSide(color: AppTheme.textMuted.withOpacity(0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            borderSide: BorderSide(color: AppTheme.primary, width: 2),
                          ),
                        ),
                      ),

                      if (registerError != null) ...[
                        SizedBox(height: AppTheme.spacingMedium),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(AppTheme.spacingMedium),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            border: Border.all(
                              color: AppTheme.error.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: AppTheme.error, size: 20),
                              SizedBox(width: AppTheme.spacingSmall),
                              Expanded(
                                child: Text(
                                  registerError!,
                                  style: AppTheme.bodySmall.copyWith(color: AppTheme.error),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      SizedBox(height: AppTheme.spacingLarge),

                      // Botones
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: AppTheme.secondaryButtonStyle,
                              child: Text(
                                'Cancelar',
                                style: AppTheme.labelLarge.copyWith(color: AppTheme.textSecondary),
                              ),
                            ),
                          ),
                          SizedBox(width: AppTheme.spacingMedium),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: isLoading
                                  ? null
                                  : () async {
                                      setState(() => isLoading = true);
                                      final result = await authService
                                          .registerUser(
                                            registerNameController.text,
                                            registerEmailController.text,
                                            registerPasswordController.text,
                                          );
                                      setState(() => isLoading = false);
                                      if (result == true) {
                                        Navigator.pop(context);
                                        setState(() {
                                          errorMessage =
                                              'Usuario registrado correctamente. Ahora puedes iniciar sesión.';
                                        });
                                      } else {
                                        setState(() {
                                          registerError = result is String
                                              ? result
                                              : 'Error al registrar usuario.';
                                        });
                                      }
                                    },
                              style: AppTheme.primaryButtonStyle,
                              child: isLoading
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Registrarse',
                                      style: AppTheme.labelLarge.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
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

  final AuthService authService = AuthService();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController codeController = TextEditingController();

  bool showCodeField = false;
  String? errorMessage;

  void _login() async {
    setState(() {
      errorMessage = null;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      print('🔐 Intentando iniciar sesión...');
      final response = await authService.iniciarSesionWithResponse(
        context,
        emailController.text,
        passwordController.text,
      );
      print('Respuesta del backend: $response');

      if (response != null) {
        if (response['error'] != null) {
          // Mostrar error específico devuelto por el servicio
          setState(() {
            errorMessage = response['error'];
          });
        } else if (response['requiresCode'] == true) {
          // Mostrar campo de código si es necesario
          setState(() {
            showCodeField = true;
          });
        } else if (response['token'] != null) {
          print('✅ Login exitoso, token recibido');
          final token = response['token'];

          // Saltarse la verificación del token y proceder directamente
          print(
            '⚡ Procesando login directamente, omitiendo verificación de token',
          );

          try {
            // Obtener información del usuario del response
            final usuario = response['user'];
            print('👤 Información del usuario: $usuario');

            // Update user provider with token
            await userProvider.setToken(token);
            print('✅ Token guardado en UserProvider');

            // Esperar un poco para que se procesen los roles del JWT
            await Future.delayed(Duration(milliseconds: 100));

            // Verificar roles nuevamente después del delay
            print('👤 Verificación final de roles:');
            print('👤 isMesero: ${userProvider.isMesero}');
            print('👤 isAdmin: ${userProvider.isAdmin}');
            print('👤 roles: ${userProvider.roles}');

            // Redirigir según el rol del usuario
            if (userProvider.isMesero && !userProvider.isAdmin) {
              print('👤 ✅ Usuario es mesero, redirigiendo a mesas');
              Navigator.pushReplacementNamed(context, '/mesas');
            } else {
              print('👤 ✅ Usuario es admin, redirigiendo a dashboard');
              Navigator.pushReplacementNamed(context, '/dashboard');
            }
          } catch (e) {
            print('❌ Error procesando login: $e');
            setState(() {
              errorMessage = 'Error procesando autenticación: $e';
            });
          }
        } else {
          setState(() {
            errorMessage = 'Usuario o contraseña incorrectos.';
          });
        }
      } else {
        setState(() {
          errorMessage = 'No se pudo procesar la respuesta del servidor.';
        });
      }
    } catch (e) {
      print('❌ Excepción durante el login: $e');
      setState(() {
        errorMessage = 'Error de conexión: $e';
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
        // Update the UserProvider with token instead of just saving it
        await userProvider.setToken(response['token']);

        // Esperar un poco para que se procesen los roles del JWT
        await Future.delayed(Duration(milliseconds: 100));

        // Verificar roles nuevamente después del delay
        print('👤 Verificación final de roles en validación código:');
        print('👤 isMesero: ${userProvider.isMesero}');
        print('👤 isAdmin: ${userProvider.isAdmin}');
        print('👤 roles: ${userProvider.roles}');

        // Redirigir según el rol del usuario
        if (userProvider.isMesero && !userProvider.isAdmin) {
          print('👤 ✅ Usuario es mesero, redirigiendo a mesas');
          Navigator.pushReplacementNamed(context, '/mesas');
        } else {
          print('👤 ✅ Usuario es admin, redirigiendo a dashboard');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(context.responsivePadding),
            child: Container(
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
                        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                        border: Border.all(
                          color: AppTheme.primary.withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLarge - 2),
                        child: Image.asset(
                          'images/logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusLarge - 2),
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
                    padding: EdgeInsets.all(context.isMobile ? AppTheme.spacingLarge : AppTheme.spacingXLarge),
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
                            labelStyle: AppTheme.labelMedium.copyWith(color: AppTheme.textSecondary),
                            prefixIcon: Icon(
                              Icons.email_outlined,
                              color: AppTheme.primary,
                            ),
                            filled: true,
                            fillColor: AppTheme.surfaceDark,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              borderSide: BorderSide(color: AppTheme.textMuted.withOpacity(0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              borderSide: BorderSide(color: AppTheme.textMuted.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              borderSide: BorderSide(color: AppTheme.primary, width: 2),
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
                            labelStyle: AppTheme.labelMedium.copyWith(color: AppTheme.textSecondary),
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: AppTheme.primary,
                            ),
                            filled: true,
                            fillColor: AppTheme.surfaceDark,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              borderSide: BorderSide(color: AppTheme.textMuted.withOpacity(0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              borderSide: BorderSide(color: AppTheme.textMuted.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                              borderSide: BorderSide(color: AppTheme.primary, width: 2),
                            ),
                          ),
                        ),

                        SizedBox(height: AppTheme.spacingLarge),

                        // Botón de login elegante
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _login,
                            style: AppTheme.primaryButtonStyle.copyWith(
                              elevation: MaterialStateProperty.all(4),
                            ),
                            child: Text(
                              'Iniciar Sesión',
                              style: AppTheme.labelLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
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
                              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
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
                              labelStyle: AppTheme.labelMedium.copyWith(color: AppTheme.textSecondary),
                              prefixIcon: Icon(
                                Icons.security,
                                color: AppTheme.warning,
                              ),
                              filled: true,
                              fillColor: AppTheme.surfaceDark,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                borderSide: BorderSide(color: AppTheme.warning.withOpacity(0.3)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                borderSide: BorderSide(color: AppTheme.warning.withOpacity(0.3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                borderSide: BorderSide(color: AppTheme.warning, width: 2),
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
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
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
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
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
    );
  }
}
