import 'package:flutter/material.dart';
import '../models/producto.dart';
import '../models/factura_compra.dart';
import '../theme/app_theme.dart';
import '../utils/currency_utils.dart';

// Widget de diálogo para agregar items desde productos
class DialogoAgregarItemCompra extends StatefulWidget {
  final List<Producto> productos;
  final Function(ItemFacturaCompra) onItemAgregado;

  const DialogoAgregarItemCompra({
    super.key,
    required this.productos,
    required this.onItemAgregado,
  });

  @override
  DialogoAgregarItemCompraState createState() => DialogoAgregarItemCompraState();
}

class DialogoAgregarItemCompraState extends State<DialogoAgregarItemCompra> {
  Producto? _productoSeleccionado;
  final _cantidadController = TextEditingController();
  final _precioController = TextEditingController();
  final _totalController = TextEditingController();
  final _porcentajeImpuestoController = TextEditingController(
    text: '19',
  ); // IVA 19% por defecto
  final _porcentajeDescuentoController = TextEditingController(text: '0');
  String _searchText = '';
  bool _usarTotal = true;

  @override
  void dispose() {
    _cantidadController.dispose();
    _precioController.dispose();
    _totalController.dispose();
    _porcentajeImpuestoController.dispose();
    _porcentajeDescuentoController.dispose();
    super.dispose();
  }

  List<Producto> get _productosFiltrados {
    if (_searchText.isEmpty) return widget.productos;
    return widget.productos.where((producto) {
      return producto.nombre.toLowerCase().contains(
            _searchText.toLowerCase(),
          ) ||
          (producto.categoria?.nombre.toLowerCase().contains(
                _searchText.toLowerCase(),
              ) ??
              false);
    }).toList();
  }

  double get _subtotal {
    final cantidad = double.tryParse(_cantidadController.text) ?? 0;

    if (_usarTotal) {
      return double.tryParse(_totalController.text) ?? 0;
    } else {
      final precio = double.tryParse(_precioController.text) ?? 0;
      return cantidad * precio;
    }
  }

  double get _porcentajeImpuesto =>
      double.tryParse(_porcentajeImpuestoController.text) ?? 0;
  double get _porcentajeDescuento =>
      double.tryParse(_porcentajeDescuentoController.text) ?? 0;

  double get _valorDescuento => _subtotal * (_porcentajeDescuento / 100);
  double get _baseGravable => _subtotal - _valorDescuento;
  double get _valorImpuesto => _baseGravable * (_porcentajeImpuesto / 100);
  double get _totalItem => _baseGravable + _valorImpuesto;

  double get _precioUnitarioCalculado {
    final cantidad = double.tryParse(_cantidadController.text) ?? 0;
    final total = double.tryParse(_totalController.text) ?? 0;

    if (_usarTotal && cantidad > 0) {
      return total / cantidad;
    } else {
      return double.tryParse(_precioController.text) ?? 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Título
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Agregar Item',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Búsqueda de productos
            TextField(
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Buscar productos...',
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() => _searchText = value);
              },
            ),
            SizedBox(height: 16),

            // Contenido principal scrollable
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Lista de productos
                    Text(
                      'Seleccionar Producto:',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      height: 200, // Altura fija para la lista
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[600]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        itemCount: _productosFiltrados.length,
                        itemBuilder: (context, index) {
                          final producto = _productosFiltrados[index];
                          final isSelected =
                              _productoSeleccionado?.id == producto.id;

                          return ListTile(
                            title: Text(
                              producto.nombre,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                            ),
                            subtitle: Text(
                              '${producto.categoria?.nombre ?? 'Sin categoría'} - Stock: ${producto.cantidad}',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                            ),
                            trailing: Text(
                              CurrencyUtils.format(producto.precio),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            selected: isSelected,
                            selectedTileColor: AppTheme.primary.withOpacity(
                              0.1,
                            ),
                            onTap: () {
                              setState(() {
                                _productoSeleccionado = producto;
                                _precioController.text = producto.precio
                                    .toString();
                              });
                            },
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 16),

                    // Detalles del item
                    if (_productoSeleccionado != null) ...[
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[600]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Título
                            Text(
                              'Detalles del Item',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 16),

                            // Switch para elegir el modo de entrada
                            Row(
                              children: [
                                Icon(
                                  _usarTotal
                                      ? Icons.calculate
                                      : Icons.attach_money,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                  size: 20,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Modo de entrada de precios',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        _usarTotal
                                            ? 'Total directo - el precio unitario se calculará automáticamente'
                                            : 'Precio unitario manual - ingresa el precio por unidad',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _usarTotal,
                                  onChanged: (value) {
                                    setState(() {
                                      _usarTotal = value;
                                      // Limpiar los campos al cambiar de modo
                                      if (_usarTotal) {
                                        _precioController.clear();
                                      } else {
                                        _totalController.clear();
                                      }
                                    });
                                  },
                                  activeColor: AppTheme.primary,
                                  activeTrackColor: AppTheme.primary
                                      .withOpacity(0.3),
                                ),
                              ],
                            ),
                            SizedBox(height: 20),

                            // Campos de entrada uniformes
                            // Cantidad (siempre visible)
                            TextField(
                              controller: _cantidadController,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Cantidad',
                                labelStyle: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                                suffixText: 'unidades',
                                suffixStyle: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.grey[600]!,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: AppTheme.primary,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            SizedBox(height: 16),

                            // Campo de precio/total condicional
                            if (!_usarTotal) ...[
                              TextField(
                                controller: _precioController,
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Precio Unitario',
                                  labelStyle: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                  prefixText: '\$',
                                  prefixStyle: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                  helperText: 'Precio por unidad',
                                  helperStyle: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.grey[600]!,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: AppTheme.primary,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ] else ...[
                              TextField(
                                controller: _totalController,
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Total del Item',
                                  labelStyle: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                  prefixText: '\$',
                                  prefixStyle: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                  helperText:
                                      'El precio unitario se calculará automáticamente',
                                  helperStyle: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.grey[600]!,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: AppTheme.primary,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                            SizedBox(height: 16),

                            // 💰 Campos DIAN: IVA y Descuento
                            Row(
                              children: [
                                // Campo IVA
                                Expanded(
                                  child: TextField(
                                    controller: _porcentajeImpuestoController,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: '% IVA',
                                      labelStyle: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                      ),
                                      suffixText: '%',
                                      suffixStyle: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                      ),
                                      helperText: '0%, 5%, 19%',
                                      helperStyle: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                        fontSize: 10,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.grey[600]!,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: AppTheme.primary,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                SizedBox(width: 12),
                                // Campo Descuento
                                Expanded(
                                  child: TextField(
                                    controller: _porcentajeDescuentoController,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: '% Descuento',
                                      labelStyle: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                      ),
                                      suffixText: '%',
                                      suffixStyle: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.grey[600]!,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: AppTheme.primary,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),

                            // Información del subtotal con desglose DIAN
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  // Mostrar precio unitario calculado si está en modo total
                                  if (_usarTotal && _subtotal > 0) ...[
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Precio Unitario Calculado:',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onSurface,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          CurrencyUtils.format(_precioUnitarioCalculado),
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onSurface,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                  ],
                                  // Subtotal base
                                  _buildDesgloseRow('Subtotal:', _subtotal),
                                  if (_valorDescuento > 0) ...[
                                    _buildDesgloseRow(
                                      'Descuento (${_porcentajeDescuento.toStringAsFixed(0)}%):',
                                      -_valorDescuento,
                                      isNegative: true,
                                    ),
                                    _buildDesgloseRow(
                                      'Base Gravable:',
                                      _baseGravable,
                                    ),
                                  ],
                                  if (_valorImpuesto > 0)
                                    _buildDesgloseRow(
                                      'IVA (${_porcentajeImpuesto.toStringAsFixed(0)}%):',
                                      _valorImpuesto,
                                    ),
                                  Divider(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7).withOpacity(
                                      0.3,
                                    ),
                                  ),
                                  // Total final
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'TOTAL ITEM:',
                                        style: TextStyle(
                                          color: AppTheme.primary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        CurrencyUtils.format(_totalItem),
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
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Botones siempre visibles en la parte inferior
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                  ),
                ),
                SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _puedeAgregar() ? _agregarItem : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Agregar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _puedeAgregar() {
    if (_productoSeleccionado == null) return false;

    final cantidadValida =
        _cantidadController.text.isNotEmpty &&
        (double.tryParse(_cantidadController.text) ?? 0) > 0;

    if (!cantidadValida) return false;

    if (_usarTotal) {
      return _totalController.text.isNotEmpty &&
          (double.tryParse(_totalController.text) ?? 0) > 0;
    } else {
      return _precioController.text.isNotEmpty &&
          (double.tryParse(_precioController.text) ?? 0) > 0;
    }
  }

  Widget _buildDesgloseRow(
    String label,
    double valor, {
    bool isNegative = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 13),
          ),
          Text(
            '${isNegative ? "-" : ""}${CurrencyUtils.format(valor.abs())}',
            style: TextStyle(
              color: isNegative ? Colors.red[300] : Theme.of(context).colorScheme.onSurface,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  void _agregarItem() {
    final cantidad = double.parse(_cantidadController.text);
    double precio;
    double subtotal;

    if (_usarTotal) {
      subtotal = double.parse(_totalController.text);
      precio = subtotal / cantidad;
    } else {
      precio = double.parse(_precioController.text);
      subtotal = cantidad * precio;
    }

    final item = ItemFacturaCompra(
      ingredienteId: _productoSeleccionado!.id ?? '',
      ingredienteNombre: _productoSeleccionado!.nombre,
      cantidad: cantidad,
      unidad: 'unidad',
      precioUnitario: precio,
      subtotal: subtotal,
      // Campos DIAN
      porcentajeImpuesto: _porcentajeImpuesto,
      valorImpuesto: _valorImpuesto,
      porcentajeDescuento: _porcentajeDescuento,
      valorDescuento: _valorDescuento,
    );

    widget.onItemAgregado(item);
    Navigator.pop(context);
  }
}

