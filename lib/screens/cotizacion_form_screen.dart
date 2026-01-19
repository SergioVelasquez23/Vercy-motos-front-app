import 'package:flutter/material.dart';
import '../models/cotizacion.dart';
import '../models/item_cotizacion.dart';
import '../models/cliente.dart';
import '../services/cotizacion_service.dart';
import '../services/cliente_service.dart';
import '../theme/app_theme.dart';

class CotizacionFormScreen extends StatefulWidget {
  final Cotizacion? cotizacion;

  const CotizacionFormScreen({Key? key, this.cotizacion}) : super(key: key);

  @override
  _CotizacionFormScreenState createState() => _CotizacionFormScreenState();
}

class _CotizacionFormScreenState extends State<CotizacionFormScreen> {
  final CotizacionService _cotizacionService = CotizacionService();
  final ClienteService _clienteService = ClienteService();
  final _formKey = GlobalKey<FormState>();

  // Controladores
  final _clienteController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _validezController = TextEditingController(text: '30');
  final _codigoProductoController = TextEditingController();
  final _nombreProductoController = TextEditingController();
  final _cantidadController = TextEditingController(text: '1');
  final _precioController = TextEditingController();
  final _porcentajeImpuestoController = TextEditingController(text: '0');
  final _porcentajeDescuentoController = TextEditingController(text: '0');

  DateTime _fecha = DateTime.now();
  DateTime _fechaVencimiento = DateTime.now().add(Duration(days: 30));
  String _tipoImpuesto = 'IVA';
  List<ItemCotizacion> _items = [];
  Cliente? _clienteSeleccionado;
  bool _isLoading = false;
  bool _esEdicion = false;

  // Retenciones
  double _retencion = 0;
  double _reteIVA = 0;
  double _reteICA = 0;

  @override
  void initState() {
    super.initState();
    _esEdicion = widget.cotizacion != null;

    if (_esEdicion) {
      _cargarDatosCotizacion();
    }
  }

  void _cargarDatosCotizacion() {
    final c = widget.cotizacion!;
    _clienteController.text = c.clienteId;
    _fecha = c.fecha;
    _fechaVencimiento =
        c.fechaVencimiento ?? DateTime.now().add(Duration(days: 30));
    _descripcionController.text = c.descripcion ?? '';
    _items = List.from(c.items);
    _retencion = c.retencion;
    _reteIVA = c.reteIVA;
    _reteICA = c.reteICA;
  }

  @override
  void dispose() {
    _clienteController.dispose();
    _descripcionController.dispose();
    _validezController.dispose();
    _codigoProductoController.dispose();
    _nombreProductoController.dispose();
    _cantidadController.dispose();
    _precioController.dispose();
    _porcentajeImpuestoController.dispose();
    _porcentajeDescuentoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar Cotización' : 'Nueva Cotización'),
        backgroundColor: AppTheme.primary,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEncabezado(),
                    SizedBox(height: 24),
                    _buildDatosProducto(),
                    SizedBox(height: 24),
                    _buildItemsList(),
                    SizedBox(height: 24),
                    _buildRetenciones(),
                    SizedBox(height: 24),
                    _buildTotales(),
                  ],
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildEncabezado() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Información General',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fecha',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final fecha = await showDatePicker(
                          context: context,
                          initialDate: _fecha,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (fecha != null) setState(() => _fecha = fecha);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          '${_fecha.year}-${_fecha.month.toString().padLeft(2, '0')}-${_fecha.day.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Validez (días)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: _validezController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        suffixText: 'días',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final dias = int.tryParse(value) ?? 30;
                        setState(() {
                          _fechaVencimiento = _fecha.add(Duration(days: dias));
                        });
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vence',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final fecha = await showDatePicker(
                          context: context,
                          initialDate: _fechaVencimiento,
                          firstDate: _fecha,
                          lastDate: DateTime(2030),
                        );
                        if (fecha != null)
                          setState(() => _fechaVencimiento = fecha);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          suffixIcon: Icon(Icons.event),
                        ),
                        child: Text(
                          '${_fechaVencimiento.year}-${_fechaVencimiento.month.toString().padLeft(2, '0')}-${_fechaVencimiento.day.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cliente *',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: _clienteController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        hintText: 'Buscar o seleccionar cliente',
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Padding(
                padding: EdgeInsets.only(top: 24),
                child: IconButton(
                  onPressed: _buscarCliente,
                  icon: Icon(Icons.search),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  tooltip: 'Buscar cliente',
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Observaciones',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _descripcionController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  hintText: 'Notas adicionales...',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDatosProducto() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Agregar Producto',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _codigoProductoController,
                  decoration: InputDecoration(
                    labelText: 'Código',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _nombreProductoController,
                  decoration: InputDecoration(
                    labelText: 'Nombre producto *',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _cantidadController,
                  decoration: InputDecoration(
                    labelText: 'Cantidad',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _precioController,
                  decoration: InputDecoration(
                    labelText: 'Precio',
                    prefixText: '\$',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _tipoImpuesto,
                  decoration: InputDecoration(
                    labelText: 'Tipo Impuesto',
                    border: OutlineInputBorder(),
                  ),
                  items: ['IVA', 'INC', 'Exento']
                      .map(
                        (tipo) =>
                            DropdownMenuItem(value: tipo, child: Text(tipo)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _tipoImpuesto = value!),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _porcentajeImpuestoController,
                  decoration: InputDecoration(
                    labelText: '% Impuesto',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _porcentajeDescuentoController,
                  decoration: InputDecoration(
                    labelText: '% Descuento',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _agregarItem,
                icon: Icon(Icons.add),
                label: Text('Agregar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    if (_items.isEmpty) {
      return Container(
        padding: EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.shopping_cart_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              SizedBox(height: 16),
              Text(
                'No hay productos agregados',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Producto',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Cantidad',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Precio',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Total',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(width: 50),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            separatorBuilder: (context, index) => Divider(height: 1),
            itemBuilder: (context, index) {
              final item = _items[index];
              return ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                title: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(item.productoNombre ?? 'Producto'),
                    ),
                    Expanded(flex: 1, child: Text('${item.cantidad}')),
                    Expanded(
                      flex: 1,
                      child: Text(
                        '\$${item.precioUnitario.toStringAsFixed(0)}',
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        '\$${item.valorTotal.toStringAsFixed(0)}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _eliminarItem(index),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRetenciones() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Retenciones',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: '% Retención',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) =>
                      setState(() => _retencion = double.tryParse(value) ?? 0),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: '% Rete IVA',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) =>
                      setState(() => _reteIVA = double.tryParse(value) ?? 0),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: '% Rete ICA',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) =>
                      setState(() => _reteICA = double.tryParse(value) ?? 0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotales() {
    final subtotal = _items.fold(0.0, (sum, item) => sum + item.subtotal);
    final totalImpuestos = _items.fold(
      0.0,
      (sum, item) => sum + item.valorImpuesto,
    );
    final totalDescuentos = _items.fold(
      0.0,
      (sum, item) => sum + item.valorDescuento,
    );

    final valorRetencion = subtotal * (_retencion / 100);
    final valorReteIVA = totalImpuestos * (_reteIVA / 100);
    final valorReteICA = subtotal * (_reteICA / 100);
    final totalRetenciones = valorRetencion + valorReteIVA + valorReteICA;

    final total =
        subtotal + totalImpuestos - totalDescuentos - totalRetenciones;

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          _buildTotalRow('Subtotal', subtotal),
          _buildTotalRow('Impuestos', totalImpuestos),
          _buildTotalRow('Descuentos', -totalDescuentos),
          _buildTotalRow('Retenciones', -totalRetenciones),
          Divider(thickness: 2),
          _buildTotalRow('TOTAL', total, isTotal: true),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double valor, {bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 20 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '\$${valor.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: isTotal ? 20 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? AppTheme.primary : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _guardarCotizacion,
              child: _isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _esEdicion ? 'Actualizar Cotización' : 'Crear Cotización',
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _agregarItem() {
    if (_nombreProductoController.text.isEmpty ||
        _precioController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Complete los datos del producto')),
      );
      return;
    }

    final item = ItemCotizacion(
      productoId: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      codigoProducto: _codigoProductoController.text,
      productoNombre: _nombreProductoController.text,
      cantidad: int.tryParse(_cantidadController.text) ?? 1,
      precioUnitario: double.tryParse(_precioController.text) ?? 0,
      tipoImpuesto: _tipoImpuesto,
      porcentajeImpuesto:
          double.tryParse(_porcentajeImpuestoController.text) ?? 0,
      porcentajeDescuento:
          double.tryParse(_porcentajeDescuentoController.text) ?? 0,
    );

    setState(() {
      _items.add(item);
      _limpiarFormularioProducto();
    });
  }

  void _eliminarItem(int index) {
    setState(() => _items.removeAt(index));
  }

  void _limpiarFormularioProducto() {
    _codigoProductoController.clear();
    _nombreProductoController.clear();
    _cantidadController.text = '1';
    _precioController.clear();
    _porcentajeImpuestoController.text = '0';
    _porcentajeDescuentoController.text = '0';
  }

  void _buscarCliente() async {
    // TODO: Implementar búsqueda de clientes
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Función en desarrollo')));
  }

  Future<void> _guardarCotizacion() async {
    if (_clienteController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Seleccione un cliente')));
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Agregue al menos un producto')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final cotizacion = Cotizacion(
        id: widget.cotizacion?.id,
        clienteId: _clienteController.text,
        fecha: _fecha,
        fechaVencimiento: _fechaVencimiento,
        items: _items,
        estado: widget.cotizacion?.estado ?? 'activa',
        descripcion: _descripcionController.text.isEmpty
            ? null
            : _descripcionController.text,
        retencion: _retencion,
        reteIVA: _reteIVA,
        reteICA: _reteICA,
      );

      cotizacion.calcularTotales();

      if (_esEdicion) {
        await _cotizacionService.actualizarCotizacion(
          widget.cotizacion!.id!,
          cotizacion,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cotización actualizada'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        await _cotizacionService.crearCotizacion(cotizacion);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cotización creada'),
            backgroundColor: Colors.green,
          ),
        );
      }

      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
