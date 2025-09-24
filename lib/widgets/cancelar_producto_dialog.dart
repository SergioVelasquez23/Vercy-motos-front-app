import 'package:flutter/material.dart';
import '../models/item_pedido.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';

class CancelarProductoDialog extends StatefulWidget {
  final List<ItemPedido> items;
  final String mesaId;
  final String mesaNombre;
  final String usuarioId;
  final String usuarioNombre;
  final Function(List<ItemPedido> itemsCancelados, String motivo)?
  onProductosCancelados;

  const CancelarProductoDialog({
    Key? key,
    required this.items,
    required this.mesaId,
    required this.mesaNombre,
    required this.usuarioId,
    required this.usuarioNombre,
    this.onProductosCancelados,
  }) : super(key: key);

  @override
  State<CancelarProductoDialog> createState() => _CancelarProductoDialogState();
}

class _CancelarProductoDialogState extends State<CancelarProductoDialog> {
  late Map<String, bool> itemsSeleccionados;
  String motivoCancelacion = 'Error en pedido';
  TextEditingController observacionesController = TextEditingController();

  // Motivos predefinidos
  final List<String> motivosDisponibles = [
    'Error en pedido',
    'Cliente cambió de opinión',
    'Producto no disponible',
    'Problema en cocina',
    'Demora excesiva',
    'Otro',
  ];

  @override
  void initState() {
    super.initState();
    // Inicializar ningún item seleccionado por defecto
    itemsSeleccionados = {};
    for (int i = 0; i < widget.items.length; i++) {
      itemsSeleccionados[i.toString()] = false;
    }
  }

  List<ItemPedido> get itemsSeleccionadosList {
    List<ItemPedido> items = [];
    for (int i = 0; i < widget.items.length; i++) {
      if (itemsSeleccionados[i.toString()] == true) {
        items.add(widget.items[i]);
      }
    }
    return items;
  }

  double get totalACancelar {
    double total = 0.0;
    for (int i = 0; i < widget.items.length; i++) {
      if (itemsSeleccionados[i.toString()] == true) {
        final item = widget.items[i];
        total += item.precioUnitario * item.cantidad;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.cardBg,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.cancel_outlined, color: Colors.red, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cancelar Productos',
                        style: AppTheme.headlineMedium.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Mesa: ${widget.mesaNombre}',
                        style: AppTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: AppTheme.textDark),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Lista de productos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seleccionar productos a cancelar:',
                    style: AppTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Lista de productos con checkboxes
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppTheme.textLight.withValues(alpha: 0.3),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        itemCount: widget.items.length,
                        itemBuilder: (context, index) {
                          final item = widget.items[index];
                          final isSelected =
                              itemsSeleccionados[index.toString()] ?? false;

                          return Container(
                            decoration: BoxDecoration(
                              border: index > 0
                                  ? Border(
                                      top: BorderSide(
                                        color: AppTheme.textLight.withValues(
                                          alpha: 0.2,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            child: CheckboxListTile(
                              value: isSelected,
                              onChanged: (bool? value) {
                                setState(() {
                                  itemsSeleccionados[index.toString()] =
                                      value ?? false;
                                });
                              },
                              activeColor: Colors.red,
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${item.cantidad}x ${item.productoNombre ?? 'Producto sin nombre'}',
                                          style: AppTheme.bodyMedium.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (item.notas != null &&
                                            item.notas!.isNotEmpty)
                                          Text(
                                            item.notas!,
                                            style: AppTheme.bodySmall,
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    formatCurrency(
                                      item.precioUnitario * item.cantidad,
                                    ),
                                    style: AppTheme.bodyMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Motivo de cancelación
            Text(
              'Motivo de cancelación:',
              style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppTheme.textLight.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: motivoCancelacion,
                isExpanded: true,
                underline: const SizedBox(),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                items: motivosDisponibles.map((motivo) {
                  return DropdownMenuItem<String>(
                    value: motivo,
                    child: Text(motivo, style: AppTheme.bodyMedium),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    motivoCancelacion = newValue!;
                  });
                },
              ),
            ),

            const SizedBox(height: 16),

            // Observaciones
            Text(
              'Observaciones (opcional):',
              style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 8),

            TextField(
              controller: observacionesController,
              style: AppTheme.bodyMedium,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Agregar comentarios adicionales...',
                hintStyle: AppTheme.bodySmall,
                border: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: AppTheme.textLight.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Total y botones
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.backgroundDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total a cancelar:',
                        style: AppTheme.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        formatCurrency(totalACancelar),
                        style: AppTheme.headlineSmall.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: AppTheme.secondaryButtonStyle,
                          child: Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: itemsSeleccionadosList.isEmpty
                              ? null
                              : () {
                                  widget.onProductosCancelados?.call(
                                    itemsSeleccionadosList,
                                    motivoCancelacion,
                                  );
                                  Navigator.of(context).pop();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            'Confirmar Cancelación',
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    observacionesController.dispose();
    super.dispose();
  }
}
