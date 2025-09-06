import 'package:flutter/material.dart';
import '../services/cuadre_caja_service.dart';
import '../models/cuadre_caja.dart';

/// Widget helper para validar que hay una caja abierta antes de crear pedidos
class CajaValidationWidget extends StatelessWidget {
  final Widget child;
  final String? customMessage;

  const CajaValidationWidget({
    super.key,
    required this.child,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CuadreCaja?>(
      future: CuadreCajaService().getCajaActiva(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.data == null) {
          return _buildNoCajaAlert(context);
        }

        return child;
      },
    );
  }

  Widget _buildNoCajaAlert(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 64,
            color: Colors.orange,
          ),
          const SizedBox(height: 16),
          Text(
            customMessage ?? 'No hay caja abierta',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Debe abrir una caja antes de registrar pedidos.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Navegar a la pantalla de abrir caja
              Navigator.pushNamed(context, '/abrir_caja');
            },
            icon: const Icon(Icons.lock_open),
            label: const Text('Abrir Caja'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Función helper para mostrar un diálogo de alerta cuando no hay caja abierta
class CajaValidationHelper {
  static Future<bool> validateCajaAbierta(BuildContext context, {
    String? customTitle,
    String? customMessage,
  }) async {
    try {
      final cajaActiva = await CuadreCajaService().getCajaActiva();
      
      if (cajaActiva == null) {
        _showNoCajaDialog(context, customTitle, customMessage);
        return false;
      }
      
      return true;
    } catch (e) {
      _showErrorDialog(context, e.toString());
      return false;
    }
  }

  static void _showNoCajaDialog(BuildContext context, String? customTitle, String? customMessage) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              Text(customTitle ?? 'Caja no abierta'),
            ],
          ),
          content: Text(
            customMessage ?? 'No se puede crear un pedido sin una caja abierta. Debe abrir una caja antes de registrar pedidos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/abrir_caja');
              },
              icon: const Icon(Icons.lock_open),
              label: const Text('Abrir Caja'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  static void _showErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 8),
              Text('Error'),
            ],
          ),
          content: Text('Error al validar caja: $error'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    );
  }
}
