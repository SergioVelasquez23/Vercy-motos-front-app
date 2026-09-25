import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Ancho responsivo para el contenido de un diálogo que normalmente usa un
/// `SizedBox(width: preferido)` fijo: en pantallas anchas usa [preferido],
/// pero nunca más del 90% del ancho de pantalla — evita que ese ancho fijo
/// se salga del diálogo en un celular (donde 90% ya puede ser mucho menos
/// que [preferido]).
double dialogWidth(BuildContext context, double preferido) {
  final disponible = MediaQuery.of(context).size.width * 0.9;
  return preferido < disponible ? preferido : disponible;
}

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

/// Muestra un error en un widget compacto centrado en la pantalla,
/// en vez del SnackBar tradicional (más difícil de notar y de leer
/// completo). Se cierra tocando fuera o con el botón "Cerrar".
Future<void> showErrorDialog(
  BuildContext context,
  String message, {
  String title = 'Error',
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.error_outline, color: AppTheme.error, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.75),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Pregunta si una factura es "LOCAL" o "ENVIOS" antes de facturar un
/// pedido (ver PedidoAsesorService.facturarPedido en el backend, que ahora
/// exige este dato). Retorna 'LOCAL', 'ENVIOS', o `null` si el usuario
/// cerró el diálogo sin elegir (en ese caso no se debe continuar).
Future<String?> showTipoCajaDialog(BuildContext context) async {
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        '¿Cómo se factura este pedido?',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
      ),
      content: Text(
        'Indica si es una factura local o de envíos antes de continuar.',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, null),
          child: Text('Cancelar',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
        ),
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(ctx, 'LOCAL'),
          icon: Icon(Icons.storefront, size: 18),
          label: const Text('Factura local'),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(ctx, 'ENVIOS'),
          icon: Icon(Icons.local_shipping, size: 18, color: Colors.white),
          label: const Text('Facturación de envíos'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    ),
  );
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
