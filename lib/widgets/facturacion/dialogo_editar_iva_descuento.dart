import 'package:flutter/material.dart';
import '../../models/item_pedido.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_utils.dart';

/// Resultado de [mostrarDialogoEditarIvaDescuento]: si el usuario confirmó,
/// trae un % de IVA y un % de descuento por cada item (mismo orden que la
/// lista de `items` que se le pasó al diálogo).
class ResultadoEdicionIvaDescuento {
  final bool confirmado;
  final List<double> ivaValues;
  final List<double> dctoValues;

  const ResultadoEdicionIvaDescuento({
    required this.confirmado,
    required this.ivaValues,
    required this.dctoValues,
  });
}

/// Diálogo para editar el % de IVA y el % de descuento de una lista de
/// items antes de cargarlos al formulario de facturación.
///
/// Antes vivía duplicado casi al carácter entre
/// `_mostrarDialogoEditarItemsPedidoAsesor` y
/// `_mostrarDialogoEditarItemsBorrador` en facturacion_screen.dart — la
/// única diferencia real entre los dos usos es el título/subtítulo y la
/// etiqueta de la columna de precio (con IVA incluido vs. ya neto); qué
/// hacer con los valores editados (extraer precio base o no) sigue siendo
/// decisión de quien llama, no de este diálogo.
Future<ResultadoEdicionIvaDescuento> mostrarDialogoEditarIvaDescuento({
  required BuildContext context,
  required String titulo,
  required List<ItemPedido> items,
  String subtitulo = 'Edita IVA y descuento antes de cargar',
  String columnaPrecioLabel = 'Precio c/IVA',
  IconData icono = Icons.receipt_long,
}) async {
  final ivaCtrs = items
      .map((i) => TextEditingController(text: i.porcentajeImpuesto.toStringAsFixed(0)))
      .toList();
  final dctoCtrs = items
      .map((i) => TextEditingController(text: i.porcentajeDescuento.toStringAsFixed(0)))
      .toList();

  final confirmar = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final theme = Theme.of(context);
      final textStyle = TextStyle(fontSize: 12, color: theme.colorScheme.onSurface);
      final headerStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface);
      final inputDec = InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        border: const OutlineInputBorder(),
        suffixText: '%',
        suffixStyle: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
      );

      return AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Row(
          children: [
            Icon(icono, color: AppTheme.primary, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(titulo, style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface)),
                  Text(subtitulo, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 740,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cabecera de columnas
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(flex: 4, child: Text('Producto', style: headerStyle)),
                    SizedBox(width: 44, child: Text('Cant.', style: headerStyle, textAlign: TextAlign.center)),
                    SizedBox(width: 78, child: Text(columnaPrecioLabel, style: headerStyle, textAlign: TextAlign.right)),
                    const SizedBox(width: 8),
                    SizedBox(width: 64, child: Text('IVA %', style: headerStyle, textAlign: TextAlign.center)),
                    const SizedBox(width: 8),
                    SizedBox(width: 64, child: Text('Dcto %', style: headerStyle, textAlign: TextAlign.center)),
                  ],
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: 4),
              // Lista de items con scroll
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (_, idx) {
                    final item = items[idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Text(
                              item.productoNombre ?? '-',
                              style: textStyle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(
                            width: 44,
                            child: Text('${item.cantidad}', style: textStyle, textAlign: TextAlign.center),
                          ),
                          SizedBox(
                            width: 78,
                            child: Text(
                              CurrencyUtils.format(item.precioUnitario),
                              style: textStyle.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.55)),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 64,
                            child: TextField(
                              controller: ivaCtrs[idx],
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                              decoration: inputDec,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 64,
                            child: TextField(
                              controller: dctoCtrs[idx],
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                              decoration: inputDec,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Sin cambios'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Aplicar y cargar'),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
          ),
        ],
      );
    },
  );

  final ivaValues = ivaCtrs.map((c) => double.tryParse(c.text) ?? 0.0).toList();
  final dctoValues = dctoCtrs.map((c) => double.tryParse(c.text) ?? 0.0).toList();
  // Diferir el dispose a después del frame actual: el diálogo todavía está
  // en su animación de salida cuando el Future de showDialog se resuelve, y
  // si se disponen los controllers de inmediato, ese último frame de
  // transición intenta reconstruir un TextField que ya apunta a un
  // controller muerto ("used after being disposed"). Bug preexistente,
  // detectado recién ahora que este diálogo tiene un test real.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    for (final c in ivaCtrs) {
      c.dispose();
    }
    for (final c in dctoCtrs) {
      c.dispose();
    }
  });

  return ResultadoEdicionIvaDescuento(
    confirmado: confirmar == true,
    ivaValues: ivaValues,
    dctoValues: dctoValues,
  );
}
