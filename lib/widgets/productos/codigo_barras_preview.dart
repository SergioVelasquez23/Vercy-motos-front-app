import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import '../../models/producto.dart';
import '../../utils/format_utils.dart';

/// Vista previa de la etiqueta de código de barras de un producto, usada en
/// el diálogo de impresión de productos_screen.dart
/// (_buildCodigoBarrasPreview). Copiado tal cual, sin cambios de lógica.
class CodigoBarrasPreview extends StatelessWidget {
  final Producto producto;
  final bool mostrarPrecio;
  final String unidadMedida;
  final String tipoFecha;
  final String tipoLista;
  final String tipoPrecio;

  const CodigoBarrasPreview({
    super.key,
    required this.producto,
    required this.mostrarPrecio,
    required this.unidadMedida,
    required this.tipoFecha,
    required this.tipoLista,
    required this.tipoPrecio,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Unidad de medida y tipo de fecha
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                unidadMedida,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                tipoFecha,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Nombre del producto
          Text(
            producto.nombre,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Tipo de lista y tipo de precio
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tipoLista,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 9),
              ),
              Text(
                tipoPrecio,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 9),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Precio (solo si está seleccionado)
          if (mostrarPrecio)
            Text(
              formatCurrency(producto.precio),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (mostrarPrecio) const SizedBox(height: 8),
          // Código de barras
          if (producto.codigoBarras != null && producto.codigoBarras!.isNotEmpty)
            BarcodeWidget(
              barcode: Barcode.code128(),
              data: producto.codigoBarras!,
              width: 180,
              height: 60,
              drawText: false,
            )
          else if (producto.codigo != null && producto.codigo!.isNotEmpty)
            BarcodeWidget(
              barcode: Barcode.code128(),
              data: producto.codigo!,
              width: 180,
              height: 60,
              drawText: false,
            )
          else
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Sin código de barras',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          const SizedBox(height: 4),
          // Número del código
          Text(
            producto.codigoBarras ?? producto.codigo ?? 'N/A',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 10),
          ),
        ],
      ),
    );
  }
}