import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../models/inventario.dart';
import '../models/movimiento_inventario.dart';
import '../services/inventario_service.dart';
import '../config/constants.dart';
import '../providers/user_provider.dart';

class MovimientoInventarioDialog extends StatefulWidget {
  final List<Inventario> inventarioItems;
  final MovimientoInventario? movimientoExistente;

  const MovimientoInventarioDialog({
    super.key,
    required this.inventarioItems,
    this.movimientoExistente,
  });

  @override
  _MovimientoInventarioDialogState createState() =>
      _MovimientoInventarioDialogState();
}

class _MovimientoInventarioDialogState
    extends State<MovimientoInventarioDialog> {
  final _formKey = GlobalKey<FormState>();
  final InventarioService _inventarioService = InventarioService();

  // Producto seleccionado
  Inventario? _productoSeleccionado;

  // Controladores de texto
  final _cantidadController = TextEditingController();
  final _facturaController = TextEditingController();
  final _proveedorController = TextEditingController();
  final _observacionesController = TextEditingController();
  final _costoUnitarioController = TextEditingController();

  // Valores de formulario
  String _tipoMovimiento = 'Entrada - Compra';
  DateTime _fecha = DateTime.now();
  bool _isLoading = false;
  String _error = '';

  // Lista de tipos de movimiento definidos en constants.dart
  final List<String> _tiposMovimiento = kTiposMovimiento;

  @override
  void initState() {
    super.initState();

    // Si estamos editando un movimiento existente, cargamos sus datos
    if (widget.movimientoExistente != null) {
      _cargarDatosMovimiento();
    }
  }

  void _cargarDatosMovimiento() {
    final movimiento = widget.movimientoExistente!;

    // Buscar el producto en la lista de inventario
    _productoSeleccionado = widget.inventarioItems.firstWhere(
      (item) => item.id == movimiento.inventarioId,
      orElse: () => widget.inventarioItems.first,
    );

    // Cargar los valores en los controladores
    _cantidadController.text = movimiento.cantidadMovimiento.abs().toString();
    _facturaController.text = movimiento.facturaNo ?? '';
    _proveedorController.text = movimiento.proveedor ?? '';
    _observacionesController.text = movimiento.observaciones ?? '';
    _costoUnitarioController.text = (movimiento.costoUnitario ?? 0.0)
        .toString();

    // Establecer el tipo de movimiento y la fecha
    _tipoMovimiento = movimiento.tipoMovimiento;
    _fecha = movimiento.fecha;
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _facturaController.dispose();
    _proveedorController.dispose();
    _observacionesController.dispose();
    _costoUnitarioController.dispose();
    super.dispose();
  }

  // Manejar cambio de fecha
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null && picked != _fecha) {
      setState(() {
        _fecha = picked;
      });
    }
  }

  // Guardar el movimiento
  Future<void> _guardarMovimiento() async {
    if (!_formKey.currentState!.validate() || _productoSeleccionado == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final double cantidad = double.parse(_cantidadController.text);
      final double costoUnitario = _costoUnitarioController.text.isNotEmpty
          ? double.parse(_costoUnitarioController.text)
          : _productoSeleccionado!.precioCompra;

      // Determinar si es entrada o salida basado en el tipo de movimiento
      final bool esEntrada = _tipoMovimiento.toLowerCase().startsWith(
        'entrada',
      );
      final double cantidadAjustada = esEntrada ? cantidad : -cantidad;

      // Obtener el usuario actual
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final responsableActual = userProvider.userName ?? 'Sistema';

      // Crear objeto de movimiento
      final MovimientoInventario nuevoMovimiento = MovimientoInventario(
        inventarioId: _productoSeleccionado!.id,
        productoId:
            _productoSeleccionado!.codigo, // usando código como ID de producto
        productoNombre:
            _productoSeleccionado!.nombre, // usando nombre del inventario
        tipoMovimiento: _tipoMovimiento,
        motivo: _tipoMovimiento.split(' - ').last.toLowerCase(),
        cantidadAnterior: _productoSeleccionado!.stockActual,
        cantidadMovimiento: cantidadAjustada,
        cantidadNueva: _productoSeleccionado!.stockActual + cantidadAjustada,
        costoUnitario: costoUnitario,
        precioTotal: cantidad * costoUnitario,
        responsable: responsableActual,
        fecha: _fecha,
        facturaNo: _facturaController.text.isEmpty
            ? null
            : _facturaController.text,
        proveedor: _proveedorController.text.isEmpty
            ? null
            : _proveedorController.text,
        observaciones: _observacionesController.text.isEmpty
            ? null
            : _observacionesController.text,
      );

      // Guardar movimiento
      await _inventarioService.registrarMovimiento(nuevoMovimiento);

      // Cerrar diálogo
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = kErrorGuardado);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = Color(kPrimaryColor);
    final Color cardBg = Color(kCardBackgroundDark);
    final Color textLight = Color(kTextDark);

    return AlertDialog(
      backgroundColor: cardBg,
      title: Text('Movimiento Inventario', style: TextStyle(color: textLight)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fecha
              Row(
                children: [
                  Text('Fecha*', style: TextStyle(color: textLight)),
                  SizedBox(width: 8),
                  Expanded(
                    child: TextButton(
                      onPressed: () => _selectDate(context),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white10,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        alignment: Alignment.centerLeft,
                      ),
                      child: Text(
                        '${_fecha.day}/${_fecha.month}/${_fecha.year}',
                        style: TextStyle(color: primary),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.calendar_today, color: primary),
                    onPressed: () => _selectDate(context),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Tipo de movimiento
              Text('Tipo*', style: TextStyle(color: textLight)),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _tipoMovimiento,
                  items: _tiposMovimiento.map((tipo) {
                    return DropdownMenuItem(
                      value: tipo,
                      child: Text(tipo, style: TextStyle(color: textLight)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _tipoMovimiento = value!);
                  },
                  dropdownColor: cardBg,
                  style: TextStyle(color: textLight),
                  underline: Container(),
                ),
              ),
              SizedBox(height: 16),

              // Número de factura
              Text('Factura No.', style: TextStyle(color: textLight)),
              SizedBox(height: 8),
              TextFormField(
                controller: _facturaController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  counterText:
                      '${_facturaController.text.length}/$kMaximoCaracteres',
                ),
                maxLength: kMaximoCaracteres,
                style: TextStyle(color: textLight),
              ),
              SizedBox(height: 16),

              // Nota u observaciones
              Text('Nota', style: TextStyle(color: textLight)),
              SizedBox(height: 8),
              TextFormField(
                controller: _observacionesController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  counterText:
                      '${_observacionesController.text.length}/$kMaximoCaracteresDescripcion',
                ),
                style: TextStyle(color: textLight),
                maxLines: 2,
                maxLength: kMaximoCaracteresDescripcion,
              ),
              SizedBox(height: 16),

              // Proveedor
              Text('Proveedor', style: TextStyle(color: textLight)),
              SizedBox(height: 8),
              TextFormField(
                controller: _proveedorController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  counterText:
                      '${_proveedorController.text.length}/$kMaximoCaracteres',
                ),
                maxLength: kMaximoCaracteres,
                style: TextStyle(color: textLight),
              ),
              SizedBox(height: 16),

              // Producto
              Row(
                children: [
                  Text('Producto*', style: TextStyle(color: textLight)),
                  Spacer(),
                  if (widget.inventarioItems.isEmpty)
                    TextButton.icon(
                      icon: Icon(Icons.refresh, color: primary, size: 16),
                      label: Text(
                        'Recargar',
                        style: TextStyle(color: primary, fontSize: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Recargando datos...'),
                            backgroundColor: primary,
                          ),
                        );
                      },
                    ),
                ],
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<Inventario>(
                  isExpanded: true,
                  value: _productoSeleccionado,
                  hint: Text(
                    'Seleccione',
                    style: TextStyle(color: Colors.grey),
                  ),
                  items: widget.inventarioItems.isEmpty
                      ? []
                      : widget.inventarioItems.map((producto) {
                          return DropdownMenuItem(
                            value: producto,
                            child: Text(
                              '${producto.nombre} (Actual: ${producto.stockActual} ${producto.unidad})',
                              style: TextStyle(color: textLight),
                            ),
                          );
                        }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _productoSeleccionado = value;
                      // Actualizar costo unitario si está vacío
                      if (_costoUnitarioController.text.isEmpty &&
                          value != null) {
                        _costoUnitarioController.text = value.precioCompra
                            .toString();
                      }
                    });
                  },
                  dropdownColor: cardBg,
                  style: TextStyle(color: textLight),
                  underline: Container(),
                ),
              ),
              SizedBox(height: 16),

              // Cantidad y costo unitario
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cantidad*', style: TextStyle(color: textLight)),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _cantidadController,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*$'),
                            ),
                          ],
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white10,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          style: TextStyle(color: textLight),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Requerido';
                            }
                            if (double.tryParse(value) == null ||
                                double.parse(value) <= 0) {
                              return 'Inválido';
                            }
                            if (double.parse(value) >
                                kMaximoCantidadInventario) {
                              return 'Máximo $kMaximoCantidadInventario';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Costo Unitario',
                          style: TextStyle(color: textLight),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _costoUnitarioController,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*$'),
                            ),
                          ],
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white10,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          style: TextStyle(color: textLight),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Mostrar error si hay
              if (_error.isNotEmpty) ...[
                SizedBox(height: 16),
                Text(_error, style: TextStyle(color: Colors.red)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text('Cerrar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _guardarMovimiento,
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text('Guardar cambios'),
        ),
      ],
    );
  }
}
