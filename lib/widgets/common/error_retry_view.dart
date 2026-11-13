import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Estado de error estándar para pantallas que cargan datos: icono, título,
/// mensaje y un botón **Reintentar**.
///
/// Reemplaza los `_buildErrorWidget()` que estaban copiados en cada pantalla
/// (cartera, alertas, cuentas por pagar/cobrar, gastos programados). Para el
/// mensaje usa `errorMessage(e)` de `utils/api_error.dart`, no `e.toString()`.
class ErrorRetryView extends StatelessWidget {
  /// Título corto, p. ej. "Error al cargar cuentas".
  final String title;

  /// Detalle del error. Si es null se muestra "Error desconocido".
  final String? message;

  /// Se llama al pulsar Reintentar (normalmente, la función que carga los datos).
  final VoidCallback onRetry;

  const ErrorRetryView({
    super.key,
    required this.title,
    required this.onRetry,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppTheme.error),
            const SizedBox(height: 16),
            Text(title, style: textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                message ?? 'Error desconocido',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
