import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService authService = AuthService();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController codeController = TextEditingController();
  bool showCodeField = false;
  String? errorMessage;

  void _login() async {
    try {
      final response = await authService.iniciarSesionWithResponse(
        context,
        emailController.text,
        passwordController.text,
      );
      if (response != null && response['twoFactorCode'] != null) {
        setState(() {
          showCodeField = true;
        });
      } else if (response != null && response['token'] != null) {
        // Login completo, navegar al dashboard
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    }
  }

  void _validateCode() async {
    setState(() {
      errorMessage = null;
    });
    try {
      final response = await authService.validarCodigo(codeController.text);
      if (response != null && response['token'] != null) {
        // Guardar el token si es necesario
        await authService.storage.write(
          key: 'jwt_token',
          value: response['token'],
        );
        // Navegar al dashboard
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        setState(() {
          errorMessage = 'Código incorrecto o expirado.';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
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
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'Correo electrónico'),
            ),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: 'Contraseña'),
              obscureText: true,
            ),
            if (showCodeField) ...[
              SizedBox(height: 20),
              TextField(
                controller: codeController,
                decoration: InputDecoration(
                  labelText: 'Código de verificación',
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _validateCode,
                child: Text('Validar Código'),
              ),
            ] else ...[
              SizedBox(height: 20),
              ElevatedButton(onPressed: _login, child: Text('Iniciar Sesión')),
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
