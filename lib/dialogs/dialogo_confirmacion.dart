import 'package:flutter/material.dart';
import '../utils/currency_utils.dart';

/// Clase de utilidad para mostrar diálogos de confirmación
///
/// Esta clase proporciona métodos para mostrar diferentes tipos de diálogos
/// de confirmación para operaciones críticas que afectan la caja.
class DialogoConfirmacion {
  /// Muestra un diálogo de confirmación estándar
  static Future<bool> mostrar(
    BuildContext context, {
    required String titulo,
    required String mensaje,
    String textoConfirmar = 'Confirmar',
    String textoCancelar = 'Cancelar',
    bool peligroso = false,
  }) async {
    final resultado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(titulo),
          content: Text(mensaje),
          actions: <Widget>[
            TextButton(
              child: Text(textoCancelar),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: peligroso
                  ? ButtonStyle(
                      backgroundColor: MaterialStateProperty.all(Colors.red),
                      foregroundColor: MaterialStateProperty.all(Colors.white),
                    )
                  : null,
              child: Text(textoConfirmar),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    return resultado ?? false;
  }

  /// Muestra un diálogo de confirmación para eliminar un registro
  /// con indicación del impacto en la caja
  static Future<bool> confirmarEliminacion(
    BuildContext context, {
    required String tipo,
    required String nombre,
    bool afectaCaja = false,
    double? montoReversion,
  }) async {
    String mensaje = '¿Está seguro que desea eliminar este $tipo: "$nombre"?';

    if (afectaCaja) {
      mensaje += '\n\n⚠️ IMPORTANTE: Esta acción revertirá ';
      if (montoReversion != null) {
        mensaje += '${CurrencyUtils.format(montoReversion)} ';
      }
      mensaje += 'automáticamente a la caja.';
    }

    return await mostrar(
      context,
      titulo: 'Confirmar eliminación',
      mensaje: mensaje,
      textoConfirmar: 'Eliminar',
      textoCancelar: 'Cancelar',
      peligroso: true,
    );
  }

  /// Muestra un diálogo de confirmación para una operación que afecta el efectivo
  static Future<bool> confirmarOperacionEfectivo(
    BuildContext context, {
    required String tipo,
    required String detalle,
    required double monto,
    required double efectivoDisponible,
  }) async {
    final efectivoRestante = efectivoDisponible - monto;
    final bool fondosInsuficientes = efectivoRestante < 0;

    String titulo = fondosInsuficientes
        ? 'Advertencia: Fondos insuficientes'
        : 'Confirmar $tipo';
    String mensaje =
        '$detalle\n\n' +
        '💰 Efectivo actual: ${CurrencyUtils.format(efectivoDisponible)}\n' +
        '💰 Monto a utilizar: ${CurrencyUtils.format(monto)}\n' +
        '💰 Efectivo restante: ${CurrencyUtils.format(efectivoRestante)}';

    if (fondosInsuficientes) {
      mensaje =
          '⚠️ ADVERTENCIA: No hay suficiente efectivo disponible en caja.\n\n' +
          mensaje +
          '\n\n¿Deseas continuar de todas formas? La caja quedará en negativo.';
    }

    return await mostrar(
      context,
      titulo: titulo,
      mensaje: mensaje,
      textoConfirmar: fondosInsuficientes
          ? 'Continuar de todas formas'
          : 'Confirmar',
      textoCancelar: 'Cancelar',
      peligroso: fondosInsuficientes,
    );
  }
}
