import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../providers/user_provider.dart';

class LoginScreen extends StatefulWidget {
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
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Crear cuenta'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: registerNameController,
                      decoration: InputDecoration(labelText: 'Nombre'),
                    ),
                    TextField(
                      controller: registerEmailController,
                      decoration: InputDecoration(
                        labelText: 'Correo electrónico',
                      ),
                    ),
                    TextField(
                      controller: registerPasswordController,
                      decoration: InputDecoration(labelText: 'Contraseña'),
                      obscureText: true,
                    ),
                    if (registerError != null) ...[
                      SizedBox(height: 10),
                      Text(registerError!, style: TextStyle(color: Colors.red)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          setState(() => isLoading = true);
                          final result = await authService.registerUser(
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
                    backgroundColor: Colors.deepOrangeAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text('Registrarse'),
                ),
              ],
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

            // Redirigir al dashboard
            Navigator.pushReplacementNamed(context, '/dashboard');
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
        Navigator.pushReplacementNamed(context, '/dashboard');
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
      appBar: AppBar(title: Text('Inicio de Sesión')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icono de fogata y título
            Column(
              children: [
                Icon(
                  Icons.local_fire_department,
                  color: Colors.deepOrangeAccent,
                  size: 64,
                ),
                SizedBox(height: 8),
                Text(
                  'Serch Restapp',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrangeAccent,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 24),
              ],
            ),
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'Correo electrónico'),
            ),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: 'Contraseña'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrangeAccent,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text('Iniciar Sesión'),
            ),
            TextButton(
              onPressed: _showRegisterDialog,
              child: Text('¿No tienes cuenta? Registrarse'),
            ),

            if (showCodeField) ...[
              SizedBox(height: 20),
              TextField(
                controller: codeController,
                decoration: InputDecoration(
                  labelText: 'Código de verificación',
                ),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: _validateCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrangeAccent,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  textStyle: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text('Validar Código'),
              ),
            ],

            if (errorMessage != null) ...[
              SizedBox(height: 20),
              Text(errorMessage!, style: TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}
