import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../models/mesa.dart';
import '../../models/pedido.dart';
import '../../models/item_pedido.dart';
import '../../widgets/common/common_widgets.dart';
import '../../utils/format_utils.dart';

class DialogoPago extends StatefulWidget {
  final Mesa mesa;
  final Pedido pedido;

  const DialogoPago({super.key, required this.mesa, required this.pedido});

  @override
  State<DialogoPago> createState() => _DialogoPagoState();
}

class _DialogoPagoState extends State<DialogoPago> {
  // Controladores
  late TextEditingController descuentoPorcentajeController;
  late TextEditingController descuentoValorController;
  late TextEditingController propinaController;
  late TextEditingController billetesController;
  late TextEditingController montoEfectivoController;
  late TextEditingController montoTarjetaController;
  late TextEditingController montoTransferenciaController;

  // Variables de estado
  String medioPago = 'efectivo';
  bool incluyePropina = false;
  bool esCortesia = false;
  bool esConsumoInterno = false;
  bool pagoMultiple = false;
  double billetesSeleccionados = 0.0;
  List<ItemPedido> productosSeleccionados = [];

  Map<int, int> contadorBilletes = {
    50000: 0,
    20000: 0,
    10000: 0,
    5000: 0,
    2000: 0,
    1000: 0,
  };

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    descuentoPorcentajeController = TextEditingController();
    descuentoValorController = TextEditingController();
    propinaController = TextEditingController();
    billetesController = TextEditingController();
    montoEfectivoController = TextEditingController();
    montoTarjetaController = TextEditingController();
    montoTransferenciaController = TextEditingController();
  }

  @override
  void dispose() {
    descuentoPorcentajeController.dispose();
    descuentoValorController.dispose();
    propinaController.dispose();
    billetesController.dispose();
    montoEfectivoController.dispose();
    montoTarjetaController.dispose();
    montoTransferenciaController.dispose();
    super.dispose();
  }

  double get _totalCalculado {
    double total = widget.pedido.total;
    double descuento = 0;

    if (descuentoPorcentajeController.text.isNotEmpty) {
      final porcentaje =
          double.tryParse(descuentoPorcentajeController.text) ?? 0;
      descuento = total * (porcentaje / 100);
    } else if (descuentoValorController.text.isNotEmpty) {
      descuento = double.tryParse(descuentoValorController.text) ?? 0;
    }

    double propina = 0;
    if (incluyePropina && propinaController.text.isNotEmpty) {
      propina = double.tryParse(propinaController.text) ?? 0;
    }

    return total - descuento + propina;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.backgroundDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: EdgeInsets.all(28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              SizedBox(height: 32),
              _buildProductosSection(),
              SizedBox(height: 32),
              _buildSubtotalSection(),
              SizedBox(height: 32),
              _buildDescuentosSection(),
              SizedBox(height: 32),
              _buildTotalSection(),
              SizedBox(height: 32),
              _buildOpcionesEspeciales(),
              SizedBox(height: 32),
              _buildInformacionPedido(),
              SizedBox(height: 32),
              _buildPropinaSection(),
              SizedBox(height: 32),
              _buildBilletesSection(),
              SizedBox(height: 32),
              _buildMetodoPagoSection(),
              SizedBox(height: 32),
              _buildPagoMultipleSection(),
              SizedBox(height: 32),
              _buildBotonesAccion(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Center(
      child: Column(
        children: [
          Icon(Icons.payment, color: AppTheme.primary, size: 32),
          SizedBox(height: 12),
          Text(
            'Procesar Pago',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SeccionTitulo(titulo: 'Productos del Pedido'),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
              ),
              child: Text(
                '${productosSeleccionados.length}/${widget.pedido.items.length}',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        SeccionContainer(
          child: Column(
            children: widget.pedido.items
                .map((item) => _buildProductoItem(item))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildProductoItem(ItemPedido item) {
    final isSelected = productosSeleccionados.contains(item);

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primary.withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          width: 1,
        ),
      ),
      padding: EdgeInsets.all(12),
      child: Row(
        children: [
          Checkbox(
            value: isSelected,
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  productosSeleccionados.add(item);
                } else {
                  productosSeleccionados.remove(item);
                }
              });
            },
            activeColor: AppTheme.primary,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productoNombre ?? 'Producto sin nombre',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Cantidad: ${item.cantidad}',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatCurrency(item.precio),
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                'Total: ${formatCurrency(item.precio * item.cantidad)}',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubtotalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SeccionTitulo(titulo: 'Subtotal'),
        SizedBox(height: 16),
        SeccionContainer(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal:',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                formatCurrency(widget.pedido.total),
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescuentosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SeccionTitulo(titulo: 'Descuento'),
        SizedBox(height: 16),
        SeccionContainer(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: descuentoPorcentajeController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Descuento (%)',
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                    prefixIcon: Icon(Icons.percent, color: AppTheme.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppTheme.primary.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.primary, width: 2),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      if (value.isNotEmpty) {
                        descuentoValorController.clear();
                      }
                    });
                  },
                ),
              ),
              SizedBox(width: 16),
              Text(
                'O',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: descuentoValorController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Valor fijo',
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                    prefixIcon: Icon(
                      Icons.attach_money,
                      color: AppTheme.primary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppTheme.primary.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.primary, width: 2),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      if (value.isNotEmpty) {
                        descuentoPorcentajeController.clear();
                      }
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTotalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SeccionTitulo(titulo: 'Total'),
        SizedBox(height: 16),
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primary.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL A PAGAR:',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                formatCurrency(_totalCalculado),
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOpcionesEspeciales() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SeccionTitulo(titulo: 'Opciones Especiales'),
        SizedBox(height: 16),
        SeccionContainer(
          child: Column(
            children: [
              _buildSwitchOption(
                icon: Icons.card_giftcard,
                title: 'Es cortesía (gratuito)',
                value: esCortesia,
                onChanged: (value) {
                  setState(() {
                    esCortesia = value;
                    if (value) esConsumoInterno = false;
                  });
                },
              ),
              SizedBox(height: 16),
              _buildSwitchOption(
                icon: Icons.home_work,
                title: 'Consumo interno',
                value: esConsumoInterno,
                onChanged: (value) {
                  setState(() {
                    esConsumoInterno = value;
                    if (value) esCortesia = false;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchOption({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: value ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? AppTheme.primary : AppTheme.cardBg.withOpacity(0.3),
          width: value ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: value ? AppTheme.primary : AppTheme.textSecondary,
            size: 24,
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: value,
            activeColor: AppTheme.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildInformacionPedido() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SeccionTitulo(titulo: 'Información del Pedido'),
        SizedBox(height: 16),
        SeccionContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoRow(
                icono: Icons.table_restaurant,
                etiqueta: 'Mesa',
                valor: widget.pedido.mesa,
              ),
              InfoRow(
                icono: Icons.person,
                etiqueta: 'Mesero',
                valor: widget.pedido.mesero,
              ),
              if (widget.pedido.cliente != null)
                InfoRow(
                  icono: Icons.person_outline,
                  etiqueta: 'Cliente',
                  valor: widget.pedido.cliente!,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPropinaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SeccionTitulo(titulo: 'Propina'),
        SizedBox(height: 16),
        SeccionContainer(
          child: Column(
            children: [
              _buildSwitchOption(
                icon: Icons.star,
                title: 'Incluir propina',
                value: incluyePropina,
                onChanged: (value) {
                  setState(() {
                    incluyePropina = value;
                    if (!value) propinaController.clear();
                  });
                },
              ),
              if (incluyePropina) ...[
                SizedBox(height: 16),
                TextField(
                  controller: propinaController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Valor de la propina',
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                    prefixIcon: Icon(
                      Icons.attach_money,
                      color: AppTheme.primary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppTheme.primary.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.primary, width: 2),
                    ),
                  ),
                  onChanged: (value) => setState(() {}),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBilletesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SeccionTitulo(titulo: 'Selector de Billetes'),
        SizedBox(height: 16),
        SeccionContainer(
          child: Column(
            children: [
              Row(
                children: [
                  _buildBilletButton(50000),
                  SizedBox(width: 8),
                  _buildBilletButton(20000),
                  SizedBox(width: 8),
                  _buildBilletButton(10000),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  _buildBilletButton(5000),
                  SizedBox(width: 8),
                  _buildBilletButton(2000),
                  SizedBox(width: 8),
                  _buildBilletButton(1000),
                ],
              ),
              SizedBox(height: 16),
              TextField(
                controller: billetesController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Total recibido',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                  prefixIcon: Icon(Icons.attach_money, color: AppTheme.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppTheme.primary.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.primary, width: 2),
                  ),
                ),
              ),
              if (billetesSeleccionados > _totalCalculado) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.success.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.change_circle, color: AppTheme.success),
                      SizedBox(width: 8),
                      Text(
                        'Cambio: ${formatCurrency(billetesSeleccionados - _totalCalculado)}',
                        style: TextStyle(
                          color: AppTheme.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBilletButton(int valor) {
    final count = contadorBilletes[valor] ?? 0;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            billetesSeleccionados += valor.toDouble();
            contadorBilletes[valor] = count + 1;
            billetesController.text = billetesSeleccionados.toStringAsFixed(0);
          });
        },
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primary, AppTheme.primary.withOpacity(0.8)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (count > 0) ...[
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 6),
              ],
              Icon(Icons.money, color: Colors.white, size: 20),
              SizedBox(height: 4),
              Text(
                '${formatCurrency(valor / 1000)}K',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetodoPagoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SeccionTitulo(titulo: 'Método de Pago'),
        SizedBox(height: 16),
        SeccionContainer(
          child: Column(
            children: [
              _buildMetodoPagoOption('efectivo', 'Efectivo', Icons.money),
              _buildMetodoPagoOption('tarjeta', 'Tarjeta', Icons.credit_card),
              _buildMetodoPagoOption(
                'transferencia',
                'Transferencia',
                Icons.account_balance,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetodoPagoOption(String value, String title, IconData icon) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: RadioListTile<String>(
        value: value,
        groupValue: medioPago,
        onChanged: (String? value) {
          setState(() {
            medioPago = value!;
          });
        },
        title: Row(
          children: [
            Icon(icon, color: AppTheme.primary),
            SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        activeColor: AppTheme.primary,
      ),
    );
  }

  Widget _buildPagoMultipleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SeccionTitulo(titulo: 'Pago Múltiple'),
        SizedBox(height: 16),
        SeccionContainer(
          child: Column(
            children: [
              _buildSwitchOption(
                icon: Icons.account_balance_wallet,
                title: 'Habilitar pago múltiple',
                value: pagoMultiple,
                onChanged: (value) {
                  setState(() {
                    pagoMultiple = value;
                    if (!value) {
                      montoEfectivoController.clear();
                      montoTarjetaController.clear();
                      montoTransferenciaController.clear();
                    }
                  });
                },
              ),
              if (pagoMultiple) ...[
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: montoEfectivoController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Efectivo',
                          prefixIcon: Icon(
                            Icons.money,
                            color: AppTheme.primary,
                          ),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: montoTarjetaController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Tarjeta',
                          prefixIcon: Icon(
                            Icons.credit_card,
                            color: AppTheme.primary,
                          ),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                TextField(
                  controller: montoTransferenciaController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Transferencia',
                    prefixIcon: Icon(
                      Icons.account_balance,
                      color: AppTheme.primary,
                    ),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBotonesAccion() {
    return Row(
      children: [
        ActionButton(
          text: 'Cancelar',
          icon: Icons.cancel,
          backgroundColor: AppTheme.error,
          onPressed: () => Navigator.pop(context),
        ),
        SizedBox(width: 16),
        ActionButton(
          text: 'Procesar Pago',
          icon: Icons.check,
          flex: 2,
          onPressed: _procesarPago,
        ),
      ],
    );
  }

  void _procesarPago() {
    // Crear el resultado con todos los datos del pago
    final resultado = {
      'medioPago': medioPago,
      'incluyePropina': incluyePropina,
      'descuentoPorcentaje': descuentoPorcentajeController.text,
      'descuentoValor': descuentoValorController.text,
      'propina': propinaController.text,
      'esCortesia': esCortesia,
      'esConsumoInterno': esConsumoInterno,
      'billetesRecibidos': billetesSeleccionados,
      'pagoMultiple': pagoMultiple,
      'montoEfectivo': montoEfectivoController.text,
      'montoTarjeta': montoTarjetaController.text,
      'montoTransferencia': montoTransferenciaController.text,
      'productosSeleccionados': productosSeleccionados.isEmpty
          ? []
          : productosSeleccionados,
    };

    Navigator.pop(context, resultado);
  }
}
