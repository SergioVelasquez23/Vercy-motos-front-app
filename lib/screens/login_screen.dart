import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../providers/user_provider.dart';

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
    final Color primary = Color(0xFFFF6B00);
    final Color bgDark = Color(0xFF1E1E1E);
    final Color cardBg = Color(0xFF252525);
    final Color textDark = Color(0xFFE0E0E0);
    final Color textLight = Color(0xFFA0A0A0);

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
                constraints: BoxConstraints(maxWidth: 400),
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Título
                      Row(
                        children: [
                          Icon(Icons.person_add, color: primary, size: 24),
                          SizedBox(width: 12),
                          Text(
                            'Crear cuenta',
                            style: TextStyle(
                              color: textDark,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24),

                      // Campo Nombre
                      Container(
                        decoration: BoxDecoration(
                          color: bgDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: textLight.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: registerNameController,
                          style: TextStyle(color: textDark),
                          decoration: InputDecoration(
                            labelText: 'Nombre completo',
                            labelStyle: TextStyle(color: textLight),
                            prefixIcon: Icon(
                              Icons.person_outline,
                              color: primary,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Campo Email
                      Container(
                        decoration: BoxDecoration(
                          color: bgDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: textLight.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: registerEmailController,
                          style: TextStyle(color: textDark),
                          decoration: InputDecoration(
                            labelText: 'Correo electrónico',
                            labelStyle: TextStyle(color: textLight),
                            prefixIcon: Icon(
                              Icons.email_outlined,
                              color: primary,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Campo Contraseña
                      Container(
                        decoration: BoxDecoration(
                          color: bgDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: textLight.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: registerPasswordController,
                          obscureText: true,
                          style: TextStyle(color: textDark),
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            labelStyle: TextStyle(color: textLight),
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: primary,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),

                      if (registerError != null) ...[
                        SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            registerError!,
                            style: TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ),
                      ],

                      SizedBox(height: 24),

                      // Botones
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(
                                'Cancelar',
                                style: TextStyle(
                                  color: textLight,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Container(
                              height: 45,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  colors: [primary, Color(0xFFFF8533)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                              ),
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
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
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
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
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
    final Color primary = Color(0xFFFF6B00);
    final Color bgDark = Color(0xFF1E1E1E);
    final Color cardBg = Color(0xFF252525);
    final Color textDark = Color(0xFFE0E0E0);
    final Color textLight = Color(0xFFA0A0A0);

    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo elegante con sombra
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: primary.withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          'images/logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            // Intentar con el logo otra vez, o usar un ícono simple
                            return Container(
                              decoration: BoxDecoration(
                                color: primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Image.asset(
                                  'images/logo.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    // Fallback final si el logo no carga
                                    return Icon(
                                      Icons.restaurant,
                                      color: primary,
                                      size: 190,
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 40),

                  // Tarjeta principal de login
                  Container(
                    padding: EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          spreadRadius: 1,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Título elegante
                        Text(
                          'Bienvenido',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: textDark,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Ingresa a tu cuenta',
                          style: TextStyle(
                            fontSize: 16,
                            color: textLight,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 32),

                        // Campo de email
                        Container(
                          decoration: BoxDecoration(
                            color: bgDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: textLight.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: TextField(
                            controller: emailController,
                            style: TextStyle(color: textDark),
                            decoration: InputDecoration(
                              labelText: 'Correo electrónico',
                              labelStyle: TextStyle(color: textLight),
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                color: primary,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 16),

                        // Campo de contraseña
                        Container(
                          decoration: BoxDecoration(
                            color: bgDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: textLight.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: TextField(
                            controller: passwordController,
                            obscureText: true,
                            style: TextStyle(color: textDark),
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              labelStyle: TextStyle(color: textLight),
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: primary,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 24),

                        // Botón de login elegante
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              colors: [primary, Color(0xFFFF8533)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primary.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Iniciar Sesión',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 16),

                        // Enlace de registro
                        TextButton(
                          onPressed: _showRegisterDialog,
                          child: RichText(
                            text: TextSpan(
                              text: '¿No tienes cuenta? ',
                              style: TextStyle(color: textLight),
                              children: [
                                TextSpan(
                                  text: 'Regístrate',
                                  style: TextStyle(
                                    color: primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Campo de código de verificación (si es necesario)
                        if (showCodeField) ...[
                          SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              color: bgDark,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.amber.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: TextField(
                              controller: codeController,
                              style: TextStyle(color: textDark),
                              decoration: InputDecoration(
                                labelText: 'Código de verificación',
                                labelStyle: TextStyle(color: textLight),
                                prefixIcon: Icon(
                                  Icons.security,
                                  color: Colors.amber,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 45,
                            child: ElevatedButton(
                              onPressed: _validateCode,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Validar Código',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ],

                        // Mensaje de error elegante
                        if (errorMessage != null) ...[
                          SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    errorMessage!,
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 14,
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
