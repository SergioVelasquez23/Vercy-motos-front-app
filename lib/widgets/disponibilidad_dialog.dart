import 'package:flutter/material.dart';
import '../models/disponibilidad_item.dart';

String _etiquetaEstado(DisponibilidadItem i) {
  switch (i.estado) {
    case 'OK':
      return 'Hay en bodega';
    case 'SOLO_ALMACEN':
      return 'Solo en almacén';
    case 'NO_ENCONTRADO':
      return 'Producto no encontrado';
    default:
      return 'Sin stock';
  }
}

Color _colorEstado(DisponibilidadItem i) {
  switch (i.estado) {
    case 'OK':
      return Colors.green;
    case 'SOLO_ALMACEN':
      return Colors.orange;
    default:
      return Colors.red;
  }
}

/// Lista de productos con su disponibilidad en bodega y almacén. Los que tienen
/// problema aparecen primero, para ver de un vistazo qué falta.
class DisponibilidadLista extends StatelessWidget {
  final List<DisponibilidadItem> items;
  const DisponibilidadLista({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final ordenados = [...items]..sort((a, b) => (a.esOk ? 1 : 0).compareTo(b.esOk ? 1 : 0));
    final problemas = items.where((i) => !i.esOk).length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          problemas == 0
              ? 'Todos los productos están disponibles en bodega.'
              : '$problemas producto(s) sin stock suficiente en bodega:',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: problemas == 0 ? Colors.green : Colors.red,
          ),
        ),
        const SizedBox(height: 8),
        for (final i in ordenados)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(i.esOk ? Icons.check_circle : Icons.warning_amber_rounded,
                    size: 18, color: _colorEstado(i)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i.nombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(
                        'Pide ${i.solicitado} · Bodega ${i.bodega} · Almacén ${i.almacen}',
                        style: TextStyle(fontSize: 11, color: onSurface.withOpacity(0.65)),
                      ),
                    ],
                  ),
                ),
                Text(
                  _etiquetaEstado(i),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _colorEstado(i)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

Future<void> mostrarDisponibilidad(BuildContext context, List<DisponibilidadItem> items) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Disponibilidad de inventario'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 460),
        child: SingleChildScrollView(child: DisponibilidadLista(items: items)),
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
      ],
    ),
  );
}
