import 'package:flutter/material.dart';
import '../models/pedido.dart';
import '../models/item_pedido.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';

class PagoParcialDialog extends StatefulWidget {
  final Pedido pedido;
  final Function(
    List<ItemPedido> itemsSeleccionados,
    Map<String, dynamic> datosPago,
  )
  onPagoConfirmado;

  const PagoParcialDialog({
    super.key,
    required this.pedido,
    required this.onPagoConfirmado,
  });

  @override
  State<PagoParcialDialog> createState() => _PagoParcialDialogState();
}

class _PagoParcialDialogState extends State<PagoParcialDialog> {
  // Items seleccionados para pagar (todos por defecto)
  late Map<String, bool> itemsSeleccionados;

  // Datos del pago
  String formaPago = 'efectivo';
  double propina = 0.0;
  TextEditingController propinaController = TextEditingController();
  TextEditingController billetesController = TextEditingController();

  // Para el cálculo del cambio
  double billetesRecibidos = 0.0;

  @override
  void initState() {
    super.initState();
    // Inicializar todos los items como seleccionados
    itemsSeleccionados = {};
    for (int i = 0; i < widget.pedido.items.length; i++) {
      itemsSeleccionados[i.toString()] = true;
    }
  }

  double get totalSeleccionado {
    double total = 0.0;
    for (int i = 0; i < widget.pedido.items.length; i++) {
      if (itemsSeleccionados[i.toString()] == true) {
        final item = widget.pedido.items[i];
        total += item.precio * item.cantidad;
      }
    }
    return total;
  }

  double get totalConPropina => totalSeleccionado + propina;

  double get cambio {
    if (formaPago == 'efectivo' && billetesRecibidos > 0) {
      return billetesRecibidos - totalConPropina;
    }
    return 0.0;
  }

  List<ItemPedido> get itemsParaPagar {
    List<ItemPedido> items = [];
    for (int i = 0; i < widget.pedido.items.length; i++) {
      if (itemsSeleccionados[i.toString()] == true) {
        items.add(widget.pedido.items[i]);
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
        height: MediaQuery.of(context).size.height * 0.8,
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Center(
              child: Column(
                children: [
                  Icon(Icons.payment, color: AppTheme.primary, size: 32),
                  SizedBox(height: 12),
                  Text(
                    'Pago Parcial - Mesa ${widget.pedido.mesa}',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Selecciona los productos a pagar',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Lista de productos para seleccionar
            Expanded(
              flex: 3,
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
                            value: itemsSeleccionados.values.every((v) => v),
                            onChanged: (value) {
                              setState(() {
                                for (
                                  int i = 0;
                                  i < widget.pedido.items.length;
                                  i++
                                ) {
                                  itemsSeleccionados[i.toString()] =
                                      value ?? false;
                                }
                              });
                            },
                            activeColor: AppTheme.primary,
                          ),
                          Expanded(
                            child: Text(
                              'Productos (${widget.pedido.items.length})',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Text(
                            'Total',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Lista scrolleable de productos
                    Expanded(
                      child: ListView.builder(
                        itemCount: widget.pedido.items.length,
                        itemBuilder: (context, index) {
                          final item = widget.pedido.items[index];
                          final isSelected =
                              itemsSeleccionados[index.toString()] ?? false;
                          final subtotal = item.precio * item.cantidad;

                          return Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primary.withOpacity(0.05)
                                  : Colors.transparent,
                              border: Border(
                                bottom: BorderSide(
                                  color: AppTheme.primary.withOpacity(0.1),
                                  width: 1,
                                ),
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
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${item.cantidad}x ${item.productoNombre ?? 'Producto'}',
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  if (item.agregadoPor != null) ...[
                                    SizedBox(height: 2),
                                    Text(
                                      '👤 Agregado por: ${item.agregadoPor}',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary
                                            .withOpacity(0.8),
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                  if (item.notas != null &&
                                      item.notas!.isNotEmpty) ...[
                                    SizedBox(height: 4),
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
                              secondary: Text(
                                formatCurrency(subtotal),
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Resumen del pago
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Subtotal:',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        formatCurrency(totalSeleccionado),
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (propina > 0) ...[
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Propina:',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          formatCurrency(propina),
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                  Divider(color: AppTheme.primary.withOpacity(0.3)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total a Pagar:',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        formatCurrency(totalConPropina),
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // Opciones de pago
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Forma de Pago:',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),

                    // Selector de forma de pago
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildFormaPagoChip('efectivo', 'Efectivo'),
                        _buildFormaPagoChip('tarjeta', 'Tarjeta'),
                        _buildFormaPagoChip('transferencia', 'Transferencia'),
                      ],
                    ),

                    SizedBox(height: 16),

                    // Campo de propina
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: propinaController,
                            decoration: InputDecoration(
                              labelText: 'Propina',
                              hintText: '0',
                              prefixText: '\$ ',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: AppTheme.primary),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              setState(() {
                                propina = double.tryParse(value) ?? 0.0;
                              });
                            },
                          ),
                        ),
                      ],
                    ),

                    // Solo mostrar campo de billetes si es efectivo
                    if (formaPago == 'efectivo') ...[
                      SizedBox(height: 16),
                      TextField(
                        controller: billetesController,
                        decoration: InputDecoration(
                          labelText: 'Dinero recibido',
                          hintText: '0',
                          prefixText: '\$ ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppTheme.primary),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          setState(() {
                            billetesRecibidos = double.tryParse(value) ?? 0.0;
                          });
                        },
                      ),

                      if (billetesRecibidos > 0 && cambio != 0) ...[
                        SizedBox(height: 12),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cambio >= 0
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: cambio >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                cambio >= 0 ? 'Cambio:' : 'Falta:',
                                style: TextStyle(
                                  color: cambio >= 0
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                formatCurrency(cambio.abs()),
                                style: TextStyle(
                                  color: cambio >= 0
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: AppTheme.primary),
                      ),
                    ),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: itemsParaPagar.isEmpty ? null : _confirmarPago,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Procesar Pago',
                      style: TextStyle(
                        color: Colors.white,
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
    );
  }

  Widget _buildFormaPagoChip(String value, String label) {
    final isSelected = formaPago == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            formaPago = value;
          });
        }
      },
      selectedColor: AppTheme.primary.withOpacity(0.2),
      checkmarkColor: AppTheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  void _confirmarPago() {
    if (itemsParaPagar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selecciona al menos un producto para pagar'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (formaPago == 'efectivo' && billetesRecibidos < totalConPropina) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('El dinero recibido es insuficiente'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final datosPago = {
      'formaPago': formaPago,
      'propina': propina,
      'billetesRecibidos': billetesRecibidos,
      'cambio': cambio,
      'total': totalConPropina,
    };

    widget.onPagoConfirmado(itemsParaPagar, datosPago);
    Navigator.of(context).pop();
  }
}
