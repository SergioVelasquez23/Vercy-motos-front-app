import 'package:flutter/material.dart';

class LoginForm extends StatelessWidget {
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final VoidCallback onLogin;

  LoginForm({
    required this.usernameController,
    required this.passwordController,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: usernameController,
          decoration: InputDecoration(labelText: 'Username'),
        ),
        TextField(
          controller: passwordController,
          decoration: InputDecoration(labelText: 'Password'),
          obscureText: true,
        ),
        ElevatedButton(onPressed: onLogin, child: Text('Login')),
      ],
    );
  }
}
