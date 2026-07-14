import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'dialogs_helper.dart';

void showSuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: AppTheme.success,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
}

/// Muestra un error. Usa un diálogo compacto centrado (ver
/// [showErrorDialog]) en vez de un SnackBar: se nota más y el usuario
/// puede leer el mensaje completo con calma antes de cerrarlo.
void showErrorSnackBar(BuildContext context, String message) {
  showErrorDialog(context, message);
}

void showWarningSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: AppTheme.warning,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
}

void showInfoSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
}
