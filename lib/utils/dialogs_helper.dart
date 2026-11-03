import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

/// Diálogo de confirmación para eliminar algo (compra, factura, etc.) con un
/// campo de texto opcional para el motivo. Retorna el motivo escrito (puede
/// ser `''` si se dejó vacío) si el usuario confirma, o `null` si canceló.
/// Antes este mismo diálogo (mismo título/mensaje/estilo de campo, cambiando
/// solo "compra"/"factura") estaba duplicado tal cual en
/// `compras_list_screen.dart` y `facturas_compras_screen.dart`.
Future<String?> showMotivoEliminacionDialog(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String hintText = 'Motivo (opcional)',
  String confirmText = 'Eliminar',
}) {
  final motivoController = TextEditingController();
  final onSurface = Theme.of(context).colorScheme.onSurface;
  return showDialog<String?>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(titulo, style: TextStyle(color: onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mensaje, style: TextStyle(color: onSurface.withOpacity(0.7))),
            const SizedBox(height: 16),
            TextField(
              controller: motivoController,
              maxLines: 3,
              style: TextStyle(color: onSurface),
              decoration: InputDecoration(
                labelText: 'Razón de la eliminación (opcional)',
                labelStyle: TextStyle(color: onSurface.withOpacity(0.7)),
                hintText: hintText,
                hintStyle: TextStyle(color: onSurface.withOpacity(0.7).withOpacity(0.5)),
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: onSurface.withOpacity(0.7).withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: onSurface.withOpacity(0.7).withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text('Cancelar', style: TextStyle(color: onSurface.withOpacity(0.7))),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(motivoController.text.trim()),
            child: Text(confirmText, style: const TextStyle(color: Colors.red)),
          ),
        ],
      );
    },
  );
}

/// Pregunta de dónde tomar una imagen (cámara o galería). Retorna el
/// [ImageSource] elegido, o `null` si el usuario cerró el diálogo sin elegir.
/// Antes este mismo diálogo estaba duplicado en `categorias_screen.dart` y
/// `productos_screen.dart`.
Future<ImageSource?> showImageSourceDialog(BuildContext context) {
  final onSurface = Theme.of(context).colorScheme.onSurface;
  return showDialog<ImageSource>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: Text('Seleccionar imagen', style: TextStyle(color: onSurface)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.camera_alt, color: AppTheme.primary),
            title: Text('Tomar foto', style: TextStyle(color: onSurface)),
            onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
          ),
          ListTile(
            leading: Icon(Icons.photo_library, color: AppTheme.primary),
            title: Text('Galería', style: TextStyle(color: onSurface)),
            onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
}

/// Pregunta con qué caja se va a facturar un pedido de asesor: LOCAL o
/// ENVIOS. Retorna `'LOCAL'` / `'ENVIOS'`, o `null` si el usuario canceló.
Future<String?> showEleccionCajaDialog(BuildContext context) {
  final onSurface = Theme.of(context).colorScheme.onSurface;
  return showDialog<String>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Con qué caja se factura?',
                style: TextStyle(
                  color: onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Elige dónde va a quedar registrado el cobro de este pedido.',
                style: TextStyle(color: onSurface.withOpacity(0.6), fontSize: 13),
              ),
              const SizedBox(height: 18),
              _OpcionCaja(
                // Íconos NO "outlined": son los que ya se usan como literales
                // en el resto de la app (cerrar_caja_screen, cuadre_caja_screen,
                // etc.) para Local/Envíos. Al pasarlos por parámetro aquí, un
                // ícono que no aparezca también como literal en algún otro
                // lado se lo come el tree-shaking de íconos en el build de
                // producción y queda en blanco (le pasó a storefront_outlined).
                icon: Icons.storefront,
                label: 'Caja local',
                subtitle: 'Venta de mostrador',
                color: AppTheme.primary,
                onTap: () => Navigator.pop(ctx, 'LOCAL'),
              ),
              const SizedBox(height: 10),
              _OpcionCaja(
                icon: Icons.local_shipping,
                label: 'Caja de envíos',
                subtitle: 'Pedido para despachar',
                color: AppTheme.secondary,
                onTap: () => Navigator.pop(ctx, 'ENVIOS'),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancelar',
                      style: TextStyle(color: onSurface.withOpacity(0.6))),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _OpcionCaja extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _OpcionCaja({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: onSurface.withOpacity(0.55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color.withOpacity(0.7), size: 20),
            ],
          ),
        ),
      ),
    );
  }
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
