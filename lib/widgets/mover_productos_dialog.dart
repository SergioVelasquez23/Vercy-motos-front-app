import 'package:flutter/material.dart';
import '../models/item_pedido.dart';
import '../models/mesa.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';

class MoverProductosDialog extends StatefulWidget {
  final List<ItemPedido> items;
  final Mesa mesaOrigen;
  final List<Mesa> mesasDestino;
  final Function(List<ItemPedido> itemsMovidos, Mesa mesaDestino)
  onProductosMovidos;

  const MoverProductosDialog({
    super.key,
    required this.items,
    required this.mesaOrigen,
    required this.mesasDestino,
    required this.onProductosMovidos,
  });

  @override
  State<MoverProductosDialog> createState() => _MoverProductosDialogState();
}

class _MoverProductosDialogState extends State<MoverProductosDialog> {
  // Items seleccionados para mover (ninguno por defecto)
  late Map<String, bool> itemsSeleccionados;
  Mesa? mesaDestinoSeleccionada;

  @override
  void initState() {
    super.initState();
    // Inicializar todos los items como no seleccionados
    itemsSeleccionados = {};
    for (int i = 0; i < widget.items.length; i++) {
      itemsSeleccionados[i.toString()] = false;
    }
  }

  double get totalSeleccionado {
    double total = 0.0;
    for (int i = 0; i < widget.items.length; i++) {
      if (itemsSeleccionados[i.toString()] == true) {
        final item = widget.items[i];
        total += item.precio * item.cantidad;
      }
    }
    return total;
  }

  List<ItemPedido> get itemsAMover {
    List<ItemPedido> items = [];
    for (int i = 0; i < widget.items.length; i++) {
      if (itemsSeleccionados[i.toString()] == true) {
        items.add(widget.items[i]);
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.85,
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Center(
              child: Column(
                children: [
                  Icon(Icons.move_to_inbox, color: AppTheme.primary, size: 32),
                  SizedBox(height: 12),
                  Text(
                    'Mover Productos',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'De ${widget.mesaOrigen.nombre} a otra mesa',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Seleccionar mesa destino
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seleccionar Mesa Destino',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  DropdownButtonFormField<Mesa>(
                    value: mesaDestinoSeleccionada,
                    decoration: InputDecoration(
                      hintText: 'Selecciona una mesa',
                      hintStyle: TextStyle(color: AppTheme.textSecondary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.primary),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.textMuted),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: AppTheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    dropdownColor: AppTheme.cardBg,
                    style: TextStyle(color: AppTheme.textPrimary),
                    items: widget.mesasDestino.map((mesa) {
                      return DropdownMenuItem<Mesa>(
                        value: mesa,
                        child: Row(
                          children: [
                            Icon(
                              mesa.ocupada
                                  ? Icons.table_restaurant
                                  : Icons.table_bar,
                              color: mesa.ocupada
                                  ? AppTheme.error
                                  : AppTheme.success,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Text(
                              mesa.nombre,
                              style: TextStyle(color: AppTheme.textPrimary),
                            ),
                            if (mesa.ocupada)
                              Text(
                                ' (Ocupada)',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (mesa) {
                      setState(() {
                        mesaDestinoSeleccionada = mesa;
                      });
                    },
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Lista de productos para seleccionar
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header de productos
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value:
                                itemsSeleccionados.values.every((v) => v) &&
                                itemsSeleccionados.values.isNotEmpty,
                            tristate: true,
                            onChanged: (value) {
                              setState(() {
                                bool nuevoValor = value ?? false;
                                for (int i = 0; i < widget.items.length; i++) {
                                  itemsSeleccionados[i.toString()] = nuevoValor;
                                }
                              });
                            },
                            activeColor: AppTheme.primary,
                            checkColor: Colors.white,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Productos a Mover',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (itemsAMover.isNotEmpty)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${itemsAMover.length} seleccionados',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Lista de productos scrollable
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.all(8),
                        itemCount: widget.items.length,
                        itemBuilder: (context, index) {
                          final item = widget.items[index];
                          final isSelected =
                              itemsSeleccionados[index.toString()] ?? false;

                          return Container(
                            margin: EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primary.withOpacity(0.1)
                                  : AppTheme.cardBg.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primary
                                    : AppTheme.textMuted.withOpacity(0.3),
                              ),
                            ),
                            child: CheckboxListTile(
                              value: isSelected,
                              onChanged: (value) {
                                setState(() {
                                  itemsSeleccionados[index.toString()] =
                                      value ?? false;
                                });
                              },
                              activeColor: AppTheme.primary,
                              checkColor: Colors.white,
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${item.cantidad}x ${item.productoNombre ?? 'Producto'}',
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (item
                                      .ingredientesSeleccionados
                                      .isNotEmpty) ...[
                                    SizedBox(height: 2),
                                    Text(
                                      'Ingredientes: ${item.ingredientesSeleccionados.join(', ')}',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                  if (item.notas != null &&
                                      item.notas!.isNotEmpty) ...[
                                    SizedBox(height: 2),
                                    Text(
                                      item.notas!,
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: null,
                              secondary: Text(
                                formatCurrency(item.precio * item.cantidad),
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Resumen y total
            if (itemsAMover.isNotEmpty) ...[
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total de productos seleccionados:',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      formatCurrency(totalSeleccionado),
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
            ],

            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: AppTheme.textMuted),
                    ),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed:
                        itemsAMover.isEmpty || mesaDestinoSeleccionada == null
                        ? null
                        : () {
                            widget.onProductosMovidos(
                              itemsAMover,
                              mesaDestinoSeleccionada!,
                            );
                            Navigator.of(context).pop(true);
                          },
                    icon: Icon(Icons.move_to_inbox, size: 20),
                    label: Text(
                      'Mover Productos',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
