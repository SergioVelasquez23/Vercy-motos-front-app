import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Muestra un diálogo de confirmación estándar.
/// Retorna `true` si el usuario confirmó, `false` si canceló.
Future<bool> showConfirmDialog(
  BuildContext context, {
  String title = 'Confirmar',
  required String content,
  String confirmText = 'Confirmar',
  String cancelText = 'Cancelar',
  Color? confirmColor,
  bool isDangerous = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(title,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
      content: Text(content,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelText,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor ??
                (isDangerous ? AppTheme.error : AppTheme.primary),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Muestra un diálogo de información simple (solo botón "Aceptar").
Future<void> showInfoDialog(
  BuildContext context, {
  required String title,
  required String content,
  String buttonText = 'Aceptar',
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(title,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
      content: Text(content,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
          ),
          child: Text(buttonText),
        ),
      ],
    ),
  );
}
