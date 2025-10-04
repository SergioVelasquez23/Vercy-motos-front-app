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

  // ✅ NUEVO: Variables para descuentos
  double descuentoPorcentaje = 0.0;
  double descuentoValor = 0.0;
  TextEditingController descuentoPorcentajeController = TextEditingController();
  TextEditingController descuentoValorController = TextEditingController();

  // ✅ NUEVO: Variables para pagos múltiples
  bool pagoMultiple = false;
  double montoEfectivo = 0.0;
  double montoTarjeta = 0.0;
  double montoTransferencia = 0.0;
  TextEditingController montoEfectivoController = TextEditingController();
  TextEditingController montoTarjetaController = TextEditingController();
  TextEditingController montoTransferenciaController = TextEditingController();

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

  double get totalConDescuentos {
    double totalConDesc = totalSeleccionado;

    // Aplicar descuento por porcentaje primero
    if (descuentoPorcentaje > 0) {
      totalConDesc = totalConDesc * (1 - (descuentoPorcentaje / 100));
    }

    // Luego restar descuento por valor
    if (descuentoValor > 0) {
      totalConDesc = totalConDesc - descuentoValor;
    }

    // No puede ser negativo
    return totalConDesc < 0 ? 0 : totalConDesc;
  }

  double get totalConPropina => totalConDescuentos + propina;

  double get totalPagosMultiples =>
      montoEfectivo + montoTarjeta + montoTransferencia;

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
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.85,
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
                  // ✅ NUEVO: Mostrar descuentos si existen
                  if (descuentoPorcentaje > 0 || descuentoValor > 0) ...[
                    SizedBox(height: 8),
                    if (descuentoPorcentaje > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Descuento (${descuentoPorcentaje.toStringAsFixed(1)}%):',
                            style: TextStyle(color: Colors.green, fontSize: 14),
                          ),
                          Text(
                            '- ${formatCurrency(totalSeleccionado * (descuentoPorcentaje / 100))}',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    if (descuentoValor > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Descuento fijo:',
                            style: TextStyle(color: Colors.green, fontSize: 14),
                          ),
                          Text(
                            '- ${formatCurrency(descuentoValor)}',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                  ],
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
                    Row(
                      children: [
                        Wrap(
                          spacing: 8,
                          children: [
                            _buildFormaPagoChip('efectivo', 'Efectivo'),
                            _buildFormaPagoChip('tarjeta', 'Tarjeta'),
                            _buildFormaPagoChip(
                              'transferencia',
                              'Transferencia',
                            ),
                          ],
                        ),
                        SizedBox(width: 16),
                        // ✅ NUEVO: Switch para pago múltiple
                        Row(
                          children: [
                            Text(
                              'Pago mixto:',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(width: 8),
                            Switch(
                              value: pagoMultiple,
                              onChanged: (value) {
                                setState(() {
                                  pagoMultiple = value;
                                  // Limpiar campos si se desactiva
                                  if (!value) {
                                    montoEfectivo = 0.0;
                                    montoTarjeta = 0.0;
                                    montoTransferencia = 0.0;
                                    montoEfectivoController.clear();
                                    montoTarjetaController.clear();
                                    montoTransferenciaController.clear();
                                  }
                                });
                              },
                              activeColor: AppTheme.primary,
                            ),
                          ],
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    // ✅ NUEVO: Sección de descuentos
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Descuentos:',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: descuentoPorcentajeController,
                                  decoration: InputDecoration(
                                    labelText: 'Descuento %',
                                    hintText: '0',
                                    suffixText: '%',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) {
                                    setState(() {
                                      descuentoPorcentaje =
                                          double.tryParse(value) ?? 0.0;
                                      // Limpiar descuento por valor si se usa porcentaje
                                      if (descuentoPorcentaje > 0) {
                                        descuentoValor = 0.0;
                                        descuentoValorController.clear();
                                      }
                                    });
                                  },
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: TextField(
                                  controller: descuentoValorController,
                                  decoration: InputDecoration(
                                    labelText: 'Descuento fijo',
                                    hintText: '0',
                                    prefixText: '\$ ',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) {
                                    setState(() {
                                      descuentoValor =
                                          double.tryParse(value) ?? 0.0;
                                      // Limpiar descuento por porcentaje si se usa valor
                                      if (descuentoValor > 0) {
                                        descuentoPorcentaje = 0.0;
                                        descuentoPorcentajeController.clear();
                                      }
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16),

                    // ✅ NUEVO: Sección de pagos múltiples
                    if (pagoMultiple) ...[
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.primary.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Distribución del Pago:',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Total: ${formatCurrency(totalConPropina)}',
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: montoEfectivoController,
                                    decoration: InputDecoration(
                                      labelText: 'Efectivo',
                                      hintText: '0',
                                      prefixText: '\$ ',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      setState(() {
                                        montoEfectivo =
                                            double.tryParse(value) ?? 0.0;
                                      });
                                    },
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: montoTarjetaController,
                                    decoration: InputDecoration(
                                      labelText: 'Tarjeta',
                                      hintText: '0',
                                      prefixText: '\$ ',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      setState(() {
                                        montoTarjeta =
                                            double.tryParse(value) ?? 0.0;
                                      });
                                    },
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: montoTransferenciaController,
                                    decoration: InputDecoration(
                                      labelText: 'Transferencia',
                                      hintText: '0',
                                      prefixText: '\$ ',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      setState(() {
                                        montoTransferencia =
                                            double.tryParse(value) ?? 0.0;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            // Mostrar diferencia
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    (totalPagosMultiples - totalConPropina)
                                            .abs() <
                                        0.01
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      (totalPagosMultiples - totalConPropina)
                                              .abs() <
                                          0.01
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total pagado:',
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        formatCurrency(totalPagosMultiples),
                                        style: TextStyle(
                                          color: AppTheme.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if ((totalPagosMultiples -
                                                  totalConPropina)
                                              .abs() >=
                                          0.01)
                                        Text(
                                          totalPagosMultiples > totalConPropina
                                              ? 'Exceso: ${formatCurrency(totalPagosMultiples - totalConPropina)}'
                                              : 'Falta: ${formatCurrency(totalConPropina - totalPagosMultiples)}',
                                          style: TextStyle(
                                            color:
                                                totalPagosMultiples >
                                                    totalConPropina
                                                ? Colors.blue
                                                : Colors.orange,
                                            fontSize: 12,
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
                      SizedBox(height: 16),
                    ],

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

                    // Solo mostrar campo de billetes si es efectivo Y no es pago múltiple
                    if (formaPago == 'efectivo' && !pagoMultiple) ...[
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

    // ✅ NUEVO: Validaciones para pago múltiple
    if (pagoMultiple) {
      if ((totalPagosMultiples - totalConPropina).abs() >= 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Los montos no coinciden con el total a pagar'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    } else {
      // Validación original para pago único
      if (formaPago == 'efectivo' && billetesRecibidos < totalConPropina) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('El dinero recibido es insuficiente'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // ✅ NUEVO: Datos de pago actualizados
    final datosPago = {
      'formaPago': pagoMultiple ? 'multiple' : formaPago,
      'propina': propina,
      'billetesRecibidos': billetesRecibidos,
      'cambio': cambio,
      'total': totalConPropina,
      'subtotal': totalSeleccionado,
      'totalConDescuentos': totalConDescuentos,
      // Descuentos
      'descuentoPorcentaje': descuentoPorcentaje,
      'descuentoValor': descuentoValor,
      // Pago múltiple
      'pagoMultiple': pagoMultiple,
      'montoEfectivo': montoEfectivo,
      'montoTarjeta': montoTarjeta,
      'montoTransferencia': montoTransferencia,
      'totalPagosMultiples': totalPagosMultiples,
    };

    widget.onPagoConfirmado(itemsParaPagar, datosPago);
    Navigator.of(context).pop();
  }
}
