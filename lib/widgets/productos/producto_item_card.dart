import 'package:flutter/material.dart';
import '../../models/producto.dart';
import '../../theme/app_theme.dart';
import '../../utils/format_utils.dart';
import '../lazy_product_image_widget.dart';

class ProductoItemCard extends StatelessWidget {
  static const String _backendBaseUrl =
      "https://vercy-motos-app-048m.onrender.com";

  final Producto producto;
  final Future<void> Function(Producto) onEdit;
  final void Function(Producto) onDelete;

  const ProductoItemCard({
    super.key,
    required this.producto,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Buscar la categoría por ID (solo usando producto.categoria)
    String categoriaNombre = 'Adicional';
    if (producto.categoria != null && producto.categoria!.nombre.isNotEmpty) {
      categoriaNombre = producto.categoria!.nombre;
    } else {
      categoriaNombre = 'Adicional';
    }

    return Card(
      color: Theme.of(context).colorScheme.surface,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: LazyProductImageWidget(
            key: ValueKey('lazy-img-${producto.id}'),
            producto: producto,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            backendBaseUrl: _backendBaseUrl,
          ),
        ),
        title: Text(
          producto.nombre,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Row(
              children: [
                Text(
                  formatCurrency(producto.precio),
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Costo: ${formatCurrency(producto.costo)}',
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.category, color: Colors.orange, size: 16),
                SizedBox(width: 4),
                Text(
                  categoriaNombre,
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            if (producto.descripcion != null &&
                producto.descripcion!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  producto.descripcion!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.onSurface),
              onPressed: () => onEdit(producto),
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () => onDelete(producto),
            ),
          ],
        ),
      ),
    );
  }
}
