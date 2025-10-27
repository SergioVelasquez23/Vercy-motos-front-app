import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../models/mesa.dart';
import '../../models/pedido.dart';
import '../../models/item_pedido.dart';
import '../../models/pago_parcial.dart';
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
  // Mapa para controlar la cantidad parcial seleccionada por producto
  Map<ItemPedido, int> cantidadesParciales = {};

  // ✅ NUEVO: Variables para control de cantidades específicas
  late Map<String, bool> itemsSeleccionados;
  late Map<String, int> cantidadesSeleccionadas;
  late Map<String, TextEditingController> cantidadControllers;

  // Controladores
  late TextEditingController descuentoPorcentajeController;
  late TextEditingController descuentoValorController;
  late TextEditingController propinaController;
  late TextEditingController billetesController;
  late TextEditingController montoEfectivoController;
  late TextEditingController montoTarjetaController;
  late TextEditingController montoTransferenciaController;

  // ✅ NUEVO: Controladores para información del cliente
  late TextEditingController clienteNombreController;
  late TextEditingController clienteNitController;
  late TextEditingController clienteCorreoController;
  late TextEditingController clienteTelefonoController;
  late TextEditingController clienteDireccionController;

  // Variables de estado
  String medioPago = 'efectivo';
  bool incluyePropina = false;
  bool esCortesia = false;
  bool esConsumoInterno = false;
  bool pagoMultiple = false;
  bool incluirDatosCliente =
      false; // ✅ NUEVO: Para mostrar/ocultar sección cliente
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
    _initCantidades();
  }

  void _initControllers() {
    descuentoPorcentajeController = TextEditingController();
    descuentoValorController = TextEditingController();
    propinaController = TextEditingController();
    billetesController = TextEditingController();
    montoEfectivoController = TextEditingController();
    montoTarjetaController = TextEditingController();
    montoTransferenciaController = TextEditingController();

    // ✅ NUEVO: Inicializar controladores cliente
    clienteNombreController = TextEditingController();
    clienteNitController = TextEditingController(
      text: '222222222-2',
    ); // Valor por defecto
    clienteCorreoController = TextEditingController();
    clienteTelefonoController = TextEditingController();
    clienteDireccionController = TextEditingController();
  }

  // ✅ OPTIMIZADO: Inicializar control de cantidades de forma más eficiente
  void _initCantidades() {
    final itemCount = widget.pedido.items.length;

    // Pre-asignar capacidad para evitar redimensionamientos
    itemsSeleccionados = <String, bool>{};
    cantidadesSeleccionadas = <String, int>{};
    cantidadControllers = <String, TextEditingController>{};

    // Inicialización optimizada en un solo loop
    for (int i = 0; i < itemCount; i++) {
      final key = i.toString();
      final item = widget.pedido.items[i];

      itemsSeleccionados[key] = true;
      cantidadesSeleccionadas[key] = item.cantidad;
      cantidadControllers[key] = TextEditingController(
        text: item.cantidad.toString(),
      );
    }
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

    // ✅ NUEVO: Dispose controladores cliente
    clienteNombreController.dispose();
    clienteNitController.dispose();
    clienteCorreoController.dispose();
    clienteTelefonoController.dispose();
    clienteDireccionController.dispose();

    // ✅ NUEVO: Limpiar controllers de cantidades
    for (var controller in cantidadControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  // ✅ ACTUALIZADO: Calcular total con cantidades específicas
  double get totalSeleccionado {
    double total = 0.0;
    for (int i = 0; i < widget.pedido.items.length; i++) {
      if (itemsSeleccionados[i.toString()] == true) {
        final item = widget.pedido.items[i];
        final cantidadSeleccionada = cantidadesSeleccionadas[i.toString()] ?? 0;
        total += item.precioUnitario * cantidadSeleccionada;
      }
    }
    return total;
  }

  // ✅ NUEVO: Funciones auxiliares sincronizadas de PagoParcialDialog
  double get totalConDescuentos {
    double totalConDesc = totalSeleccionado;

    // Aplicar descuento por porcentaje primero
    if (descuentoPorcentajeController.text.isNotEmpty) {
      final porcentaje =
          double.tryParse(descuentoPorcentajeController.text) ?? 0.0;
      totalConDesc = totalConDesc * (1 - (porcentaje / 100));
    }

    // Luego restar descuento por valor
    if (descuentoValorController.text.isNotEmpty) {
      final descuento = double.tryParse(descuentoValorController.text) ?? 0.0;
      totalConDesc = totalConDesc - descuento;
    }

    // No puede ser negativo
    return totalConDesc < 0 ? 0.0 : totalConDesc;
  }

  double get totalConPropina {
    final propina = propinaController.text.isNotEmpty
        ? double.tryParse(propinaController.text) ?? 0.0
        : 0.0;
    return totalConDescuentos + propina;
  }

  double get totalPagosMultiples {
    final efectivo = montoEfectivoController.text.isNotEmpty
        ? double.tryParse(montoEfectivoController.text) ?? 0.0
        : 0.0;
    final tarjeta = montoTarjetaController.text.isNotEmpty
        ? double.tryParse(montoTarjetaController.text) ?? 0.0
        : 0.0;
    final transferencia = montoTransferenciaController.text.isNotEmpty
        ? double.tryParse(montoTransferenciaController.text) ?? 0.0
        : 0.0;
    return efectivo + tarjeta + transferencia;
  }

  double get cambio {
    if (medioPago == 'efectivo' && billetesController.text.isNotEmpty) {
      final billetes = double.tryParse(billetesController.text) ?? 0.0;
      return billetes - totalConPropina;
    }
    return 0.0;
  }

  List<ItemPedido> get itemsParaPagar {
    List<ItemPedido> items = [];
    for (int i = 0; i < widget.pedido.items.length; i++) {
      if (itemsSeleccionados[i.toString()] == true) {
        final item = widget.pedido.items[i];
        final cantidadSeleccionada = cantidadesSeleccionadas[i.toString()] ?? 0;

        // Crear una copia del item con la cantidad específica seleccionada
        final itemCopia = ItemPedido(
          id: item.id,
          productoId: item.productoId,
          productoNombre: item.productoNombre,
          precioUnitario: item.precioUnitario,
          cantidad: cantidadSeleccionada, // Usar cantidad específica
          ingredientesSeleccionados: item.ingredientesSeleccionados,
          notas: item.notas,
          agregadoPor: item.agregadoPor,
          fechaAgregado: item.fechaAgregado,
        );

        items.add(itemCopia);
      }
    }
    return items;
  }

  // Genera los pagos parciales según la selección actual
  List<PagoParcial> generarPagosParciales(String nombreUsuario) {
    final pagosParciales = <PagoParcial>[];
    final now = DateTime.now();

    if (pagoMultiple) {
      // Procesar pagos parciales con diferentes medios
      if (montoEfectivoController.text.isNotEmpty) {
        final montoEfectivo =
            double.tryParse(montoEfectivoController.text) ?? 0.0;
        if (montoEfectivo > 0) {
          pagosParciales.add(
            PagoParcial(
              monto: montoEfectivo,
              formaPago: 'efectivo',
              fecha: now,
              procesadoPor: nombreUsuario,
            ),
          );
        }
      }

      if (montoTarjetaController.text.isNotEmpty) {
        final montoTarjeta =
            double.tryParse(montoTarjetaController.text) ?? 0.0;
        if (montoTarjeta > 0) {
          pagosParciales.add(
            PagoParcial(
              monto: montoTarjeta,
              formaPago: 'tarjeta',
              fecha: now,
              procesadoPor: nombreUsuario,
            ),
          );
        }
      }

      if (montoTransferenciaController.text.isNotEmpty) {
        final montoTransferencia =
            double.tryParse(montoTransferenciaController.text) ?? 0.0;
        if (montoTransferencia > 0) {
          pagosParciales.add(
            PagoParcial(
              monto: montoTransferencia,
              formaPago: 'transferencia',
              fecha: now,
              procesadoPor: nombreUsuario,
            ),
          );
        }
      }
    } else {
      // Pago simple con un solo medio de pago
      pagosParciales.add(
        PagoParcial(
          monto: totalConPropina,
          formaPago: medioPago,
          fecha: now,
          procesadoPor: nombreUsuario,
        ),
      );
    }

    return pagosParciales;
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
              _buildInformacionCliente(),
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
    // ✅ SINCRONIZADO: Contar productos seleccionados usando índices
    int seleccionados = 0;
    for (int i = 0; i < widget.pedido.items.length; i++) {
      if (itemsSeleccionados[i.toString()] == true) {
        seleccionados++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SeccionTitulo(titulo: 'Productos del Pedido'),
            Row(
              children: [
                // Botón seleccionar todos
                TextButton.icon(
                  onPressed: _seleccionarTodos,
                  icon: Icon(
                    Icons.select_all,
                    size: 16,
                    color: AppTheme.primary,
                  ),
                  label: Text(
                    'Todos',
                    style: TextStyle(color: AppTheme.primary, fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                ),
                SizedBox(width: 8),
                // Botón deseleccionar todos
                TextButton.icon(
                  onPressed: _deseleccionarTodos,
                  icon: Icon(Icons.clear_all, size: 16, color: AppTheme.error),
                  label: Text(
                    'Ninguno',
                    style: TextStyle(color: AppTheme.error, fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                ),
                SizedBox(width: 12),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    '$seleccionados/${widget.pedido.items.length}',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 16),
        SeccionContainer(
          child: Column(
            children: List.generate(
              widget.pedido.items.length,
              (index) => _buildProductoItem(widget.pedido.items[index], index),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductoItem(ItemPedido item, int index) {
    // ✅ SINCRONIZADO: Usar sistema de índices
    final indexKey = index.toString();
    final isSelected = itemsSeleccionados[indexKey] == true;
    final cantidadMax = item.cantidad;
    final cantidadSeleccionada = cantidadesSeleccionadas[indexKey] ?? 0;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: isSelected,
            onChanged: (bool? value) {
              setState(() {
                itemsSeleccionados[indexKey] = value ?? false;
                if (value == true) {
                  // Al seleccionar, inicializar con cantidad máxima
                  cantidadesSeleccionadas[indexKey] = cantidadMax;
                  cantidadControllers[indexKey]?.text = cantidadMax.toString();
                } else {
                  // Al deseleccionar, limpiar cantidad
                  cantidadesSeleccionadas[indexKey] = 0;
                  cantidadControllers[indexKey]?.text = '0';
                }
              });
            },
            activeColor: AppTheme.primary,
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.productoNombre ?? 'Producto'}',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'Precio unitario: ${formatCurrency(item.precioUnitario)}',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                if (item.ingredientesSeleccionados.isNotEmpty) ...[
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
                // Debug: Verificar si agregadoPor tiene valor
                () {
                  print(
                    '🐛 Debug - Item: ${item.productoNombre}, agregadoPor: ${item.agregadoPor}',
                  );
                  return Container();
                }(),
                if (item.agregadoPor != null &&
                    item.agregadoPor!.isNotEmpty) ...[
                  SizedBox(height: 2),
                  Text(
                    '👤 Agregado por: ${item.agregadoPor}',
                    style: TextStyle(
                      color: AppTheme.textSecondary.withOpacity(0.8),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ] else if (widget.pedido.guardadoPor != null &&
                    widget.pedido.guardadoPor!.isNotEmpty) ...[
                  SizedBox(height: 2),
                  Text(
                    '👤 Pedido por: ${widget.pedido.guardadoPor}',
                    style: TextStyle(
                      color: AppTheme.textSecondary.withOpacity(0.8),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ] else if (widget.pedido.mesero.isNotEmpty) ...[
                  SizedBox(height: 2),
                  Text(
                    '👤 Mesero: ${widget.pedido.mesero}',
                    style: TextStyle(
                      color: AppTheme.textSecondary.withOpacity(0.8),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (item.notas != null && item.notas!.isNotEmpty) ...[
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
          ),

          // ✅ SINCRONIZADO: Campo de cantidad específica
          if (isSelected)
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  Text(
                    'Cantidad',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  Container(
                    width: 60,
                    child: TextField(
                      controller: cantidadControllers[indexKey],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppTheme.primary),
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                        hintText: '0',
                        hintStyle: TextStyle(color: AppTheme.textSecondary),
                      ),
                      onChanged: (value) {
                        final cantidad = int.tryParse(value) ?? 0;
                        if (cantidad >= 0 && cantidad <= cantidadMax) {
                          setState(() {
                            cantidadesSeleccionadas[indexKey] = cantidad;
                          });
                        }
                      },
                    ),
                  ),
                  Text(
                    'Max: $cantidadMax',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),

          // Total
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatCurrency(item.precioUnitario),
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (isSelected)
                Text(
                  'Total: ${formatCurrency(item.precioUnitario * cantidadSeleccionada)}',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
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
          child: Column(
            children: [
              // Subtotal del pedido completo
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Subtotal pedido completo:',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    formatCurrency(widget.pedido.total),
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (productosSeleccionados.isNotEmpty) ...[
                SizedBox(height: 12),
                Divider(color: AppTheme.textSecondary.withOpacity(0.3)),
                SizedBox(height: 12),
                // Subtotal de productos seleccionados
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Subtotal seleccionado:',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      formatCurrency(totalSeleccionado),
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
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
                    // Limpiar el otro campo solo si realmente se está escribiendo algo
                    if (value.isNotEmpty &&
                        descuentoValorController.text.isNotEmpty) {
                      descuentoValorController.clear();
                    }
                    // Forzar rebuild para que el total se recalcule inmediatamente
                    setState(() {});
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
                    // Limpiar el otro campo solo si realmente se está escribiendo algo
                    if (value.isNotEmpty &&
                        descuentoPorcentajeController.text.isNotEmpty) {
                      descuentoPorcentajeController.clear();
                    }
                    // Forzar rebuild para que el total se recalcule inmediatamente
                    setState(() {});
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
          child: Column(
            children: [
              Row(
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
                    formatCurrency(totalConPropina),
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // ✅ SINCRONIZADO: Usar conteo de índices
              Builder(
                builder: (context) {
                  int seleccionados = 0;
                  for (int i = 0; i < widget.pedido.items.length; i++) {
                    if (itemsSeleccionados[i.toString()] == true) {
                      seleccionados++;
                    }
                  }

                  if (seleccionados > 0 &&
                      seleccionados < widget.pedido.items.length) {
                    return Column(
                      children: [
                        SizedBox(height: 8),
                        Text(
                          'Pago parcial de $seleccionados de ${widget.pedido.items.length} productos',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    );
                  }
                  return SizedBox.shrink();
                },
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

  Widget _buildInformacionCliente() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SeccionTitulo(titulo: 'Información del Cliente'),
        SizedBox(height: 16),
        SeccionContainer(
          child: Column(
            children: [
              _buildSwitchOption(
                icon: Icons.person,
                title: 'Incluir datos del cliente en el documento',
                value: incluirDatosCliente,
                onChanged: (value) {
                  setState(() {
                    incluirDatosCliente = value;
                    if (!value) {
                      // Limpiar campos si se desactiva
                      clienteNombreController.clear();
                      clienteCorreoController.clear();
                      clienteTelefonoController.clear();
                      clienteDireccionController.clear();
                      clienteNitController.text =
                          '222222222-2'; // Valor por defecto
                    }
                  });
                },
              ),
              if (incluirDatosCliente) ...[
                SizedBox(height: 16),
                _buildCampoCliente(
                  controller: clienteNitController,
                  label: 'NIT/Cédula',
                  hint: '222222222-2',
                  icon: Icons.badge,
                ),
                SizedBox(height: 16),
                _buildCampoCliente(
                  controller: clienteNombreController,
                  label: 'Nombre Completo',
                  hint: 'Nombre del cliente',
                  icon: Icons.person,
                ),
                SizedBox(height: 16),
                _buildCampoCliente(
                  controller: clienteCorreoController,
                  label: 'Correo Electrónico',
                  hint: 'cliente@ejemplo.com',
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                ),
                SizedBox(height: 16),
                _buildCampoCliente(
                  controller: clienteTelefonoController,
                  label: 'Teléfono',
                  hint: '300 123 4567',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 16),
                _buildCampoCliente(
                  controller: clienteDireccionController,
                  label: 'Dirección',
                  hint: 'Dirección del cliente',
                  icon: Icons.location_on,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCampoCliente({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: AppTheme.textSecondary),
        hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.6)),
        prefixIcon: Icon(icon, color: AppTheme.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primary.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.primary, width: 2),
        ),
      ),
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
                  onChanged: (value) {
                    // Actualizar total cuando cambie la propina
                    setState(() {});
                  },
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
              if (billetesSeleccionados > totalConPropina) ...[
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
                        'Cambio: ${formatCurrency(billetesSeleccionados - totalConPropina)}',
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

  void _seleccionarTodos() {
    setState(() {
      // ✅ SINCRONIZADO: Seleccionar usando índices
      for (int i = 0; i < widget.pedido.items.length; i++) {
        final indexKey = i.toString();
        final item = widget.pedido.items[i];
        itemsSeleccionados[indexKey] = true;
        cantidadesSeleccionadas[indexKey] = item.cantidad;
        cantidadControllers[indexKey]?.text = item.cantidad.toString();
      }
    });
  }

  void _deseleccionarTodos() {
    setState(() {
      // ✅ SINCRONIZADO: Deseleccionar usando índices
      for (int i = 0; i < widget.pedido.items.length; i++) {
        final indexKey = i.toString();
        itemsSeleccionados[indexKey] = false;
        cantidadesSeleccionadas[indexKey] = 0;
        cantidadControllers[indexKey]?.text = '0';
      }
    });
  }

  void _procesarPago() {
    // ✅ SINCRONIZADO: Validar usando sistema de índices
    bool haySeleccionados = false;
    for (int i = 0; i < widget.pedido.items.length; i++) {
      if (itemsSeleccionados[i.toString()] == true) {
        haySeleccionados = true;
        break;
      }
    }

    if (!haySeleccionados) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Debes seleccionar al menos un producto para procesar el pago',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Validar los montos totales si es pago múltiple
    if (pagoMultiple) {
      final totalPagos = _calcularTotalPagosMultiples();
      final diferencia = totalPagos - totalConPropina;

      // Diferencia máxima permitida de 10 pesos
      if (diferencia.abs() > 10) {
        String mensaje;
        if (diferencia < 0) {
          mensaje =
              'El monto total es insuficiente. Faltan ${formatCurrency(diferencia.abs())}.';
        } else {
          mensaje =
              'El monto total excede lo requerido. Sobran ${formatCurrency(diferencia)}.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensaje, style: TextStyle(color: Colors.white)),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    // Calcular propina
    final propina = propinaController.text.isNotEmpty
        ? double.tryParse(propinaController.text) ?? 0.0
        : 0.0;

    // Generar los pagos parciales
    final pagosParciales = _generarPagosParciales();

    // ✅ SINCRONIZADO: Usar itemsParaPagar del getter
    final resultado = {
      'medioPago': medioPago,
      'incluyePropina': incluyePropina,
      'descuentoPorcentaje': descuentoPorcentajeController.text,
      'descuentoValor': descuentoValorController.text,
      'propina': propina,
      'esCortesia': esCortesia,
      'esConsumoInterno': esConsumoInterno,
      'billetesRecibidos': billetesSeleccionados,
      'pagoMultiple': pagoMultiple,
      'montoEfectivo': montoEfectivoController.text,
      'montoTarjeta': montoTarjetaController.text,
      'montoTransferencia': montoTransferenciaController.text,
      'productosSeleccionados': itemsParaPagar, // ✅ Usar getter sincronizado
      'totalCalculado': totalConPropina, // ✅ Usar getter sincronizado
      'subtotalSeleccionado': totalSeleccionado, // ✅ Usar getter sincronizado
      'pagosParciales': pagosParciales,
      'totalPagado': pagoMultiple
          ? _calcularTotalPagosMultiples()
          : totalConPropina,
      'fechaPago': DateTime.now(),
      // ✅ INFORMACIÓN DEL CLIENTE: Datos capturados para PDF
      'incluirDatosCliente': incluirDatosCliente,
      'clienteNombre': clienteNombreController.text.trim(),
      'clienteNit': clienteNitController.text.trim(),
      'clienteCorreo': clienteCorreoController.text.trim(),
      'clienteTelefono': clienteTelefonoController.text.trim(),
      'clienteDireccion': clienteDireccionController.text.trim(),
    };

    Navigator.pop(context, resultado);
  }

  // Calcular el total de los pagos múltiples
  double _calcularTotalPagosMultiples() {
    final montoEfectivo = montoEfectivoController.text.isNotEmpty
        ? double.tryParse(montoEfectivoController.text) ?? 0.0
        : 0.0;

    final montoTarjeta = montoTarjetaController.text.isNotEmpty
        ? double.tryParse(montoTarjetaController.text) ?? 0.0
        : 0.0;

    final montoTransferencia = montoTransferenciaController.text.isNotEmpty
        ? double.tryParse(montoTransferenciaController.text) ?? 0.0
        : 0.0;

    return montoEfectivo + montoTarjeta + montoTransferencia;
  }

  // Generar los pagos parciales según los montos ingresados
  List<PagoParcial> _generarPagosParciales() {
    final List<PagoParcial> pagosParciales = [];
    final now = DateTime.now();
    final String procesadoPor = 'Sistema'; // Idealmente obtenido del context

    if (pagoMultiple) {
      // Agregar pago en efectivo si hay monto
      if (montoEfectivoController.text.isNotEmpty) {
        final monto = double.tryParse(montoEfectivoController.text);
        if (monto != null && monto > 0) {
          pagosParciales.add(
            PagoParcial(
              monto: monto,
              formaPago: 'efectivo',
              fecha: now,
              procesadoPor: procesadoPor,
            ),
          );
        }
      }

      // Agregar pago con tarjeta si hay monto
      if (montoTarjetaController.text.isNotEmpty) {
        final monto = double.tryParse(montoTarjetaController.text);
        if (monto != null && monto > 0) {
          pagosParciales.add(
            PagoParcial(
              monto: monto,
              formaPago: 'tarjeta',
              fecha: now,
              procesadoPor: procesadoPor,
            ),
          );
        }
      }

      // Agregar pago con transferencia si hay monto
      if (montoTransferenciaController.text.isNotEmpty) {
        final monto = double.tryParse(montoTransferenciaController.text);
        if (monto != null && monto > 0) {
          pagosParciales.add(
            PagoParcial(
              monto: monto,
              formaPago: 'transferencia',
              fecha: now,
              procesadoPor: procesadoPor,
            ),
          );
        }
      }
    } else {
      // Agregar un solo pago con el medio seleccionado
      pagosParciales.add(
        PagoParcial(
          monto: totalConPropina,
          formaPago: medioPago,
          fecha: now,
          procesadoPor: procesadoPor,
        ),
      );
    }

    return pagosParciales;
  }
}
