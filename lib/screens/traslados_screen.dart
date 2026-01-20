import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/traslado.dart';
import '../models/producto.dart';
import '../services/traslado_service.dart';
import '../services/producto_service.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';

class TrasladosScreen extends StatefulWidget {
  const TrasladosScreen({super.key});

  @override
  _TrasladosScreenState createState() => _TrasladosScreenState();
}

class _TrasladosScreenState extends State<TrasladosScreen> {
  final TrasladoService _trasladoService = TrasladoService();
  final ProductoService _productoService = ProductoService();
  final TextEditingController _searchController = TextEditingController();

  List<Traslado> _traslados = [];
  List<Traslado> _trasladosFiltrados = [];
  List<Producto> _productos = [];
  bool _isLoading = false;
  String _filtroEstado = 'TODOS';

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _searchController.addListener(_filtrarTraslados);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final traslados = await _trasladoService.listarTraslados(
        estado: _filtroEstado != 'TODOS' ? _filtroEstado : null,
      );
      final productos = await _productoService.getProductos();

      setState(() {
        _traslados = traslados;
        _trasladosFiltrados = traslados;
        _productos = productos;
      });
    } catch (e) {
      _mostrarError('Error al cargar datos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filtrarTraslados() {
    final busqueda = _searchController.text.toLowerCase();
    setState(() {
      _trasladosFiltrados = _traslados.where((traslado) {
        final cumpleBusqueda =
            busqueda.isEmpty ||
            (traslado.numero?.toLowerCase().contains(busqueda) ?? false) ||
            (traslado.solicitante?.toLowerCase().contains(busqueda) ?? false) ||
            (traslado.productoNombre?.toLowerCase().contains(busqueda) ??
                false) ||
            (traslado.origenBodegaNombre?.toLowerCase().contains(busqueda) ??
                false) ||
            (traslado.destinoBodegaNombre?.toLowerCase().contains(busqueda) ??
                false);

        final cumpleEstado =
            _filtroEstado == 'TODOS' || traslado.estado == _filtroEstado;

        return cumpleBusqueda && cumpleEstado;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final userName = userProvider.userName ?? 'Usuario';

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text('Traslados', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () =>
              Navigator.pushReplacementNamed(context, '/dashboard'),
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          _buildFiltros(),
          _buildBotones(userName),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  )
                : _trasladosFiltrados.isEmpty
                ? _buildEmptyState()
                : _buildTablaTraslados(),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Buscar por número, proveedor...',
              hintStyle: TextStyle(color: AppTheme.textSecondary),
              prefixIcon: Icon(Icons.search, color: AppTheme.primary),
              filled: true,
              fillColor: AppTheme.surfaceDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Text('Estado: ', style: TextStyle(color: AppTheme.textPrimary)),
              SizedBox(width: 8),
              ...[
                {'label': 'TODOS', 'value': 'TODOS'},
                {'label': 'PENDIENTE', 'value': 'PENDIENTE'},
                {'label': 'ACEPTADO', 'value': 'ACEPTADO'},
                {'label': 'RECHAZADO', 'value': 'RECHAZADO'},
              ].map((estado) {
                final isSelected = _filtroEstado == estado['value'];
                return Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(estado['label']!),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _filtroEstado = estado['value']!);
                      _cargarDatos();
                    },
                    backgroundColor: AppTheme.surfaceDark,
                    selectedColor: AppTheme.primary.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.textSecondary,
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBotones(String userName) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton.icon(
            onPressed: _cargarDatos,
            icon: Icon(Icons.refresh, color: Colors.white),
            label: Text('Actualizar', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
          SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => _mostrarDialogoCrearTraslado(userName),
            icon: Icon(Icons.add, color: Colors.white),
            label: Text(
              'Crear Traslados',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTablaTraslados() {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(AppTheme.surfaceDark),
            dataRowColor: MaterialStateProperty.all(AppTheme.cardBg),
            columns: [
              DataColumn(
                label: Text(
                  '#',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Fecha',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Solicita',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Origen',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Destino',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Cantidad',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Estado',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Acciones',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            rows: _trasladosFiltrados.map((traslado) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      traslado.numero ?? '-',
                      style: TextStyle(color: AppTheme.textPrimary),
                    ),
                  ),
                  DataCell(
                    Text(
                      traslado.fechaSolicitud != null
                          ? DateFormat(
                              'yyyy-MM-dd - HH:mm:ss',
                            ).format(traslado.fechaSolicitud!)
                          : '-',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                  DataCell(
                    Text(
                      traslado.solicitante ?? '-',
                      style: TextStyle(color: AppTheme.textPrimary),
                    ),
                  ),
                  DataCell(
                    Text(
                      traslado.origenBodegaNombre ?? '-',
                      style: TextStyle(color: AppTheme.textPrimary),
                    ),
                  ),
                  DataCell(
                    Text(
                      traslado.destinoBodegaNombre ?? '-',
                      style: TextStyle(color: AppTheme.textPrimary),
                    ),
                  ),
                  DataCell(
                    Text(
                      '${traslado.cantidad ?? 0}',
                      style: TextStyle(color: AppTheme.textPrimary),
                    ),
                  ),
                  DataCell(_buildEstadoBadge(traslado.estado ?? 'PENDIENTE')),
                  DataCell(_buildAcciones(traslado)),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildEstadoBadge(String estado) {
    Color color;
    switch (estado) {
      case 'ACEPTADO':
        color = Colors.green;
        break;
      case 'RECHAZADO':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        estado,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildAcciones(Traslado traslado) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.print, color: AppTheme.primary, size: 20),
          onPressed: () => _verDetalles(traslado),
          tooltip: 'Ver detalles',
        ),
        if (traslado.estado == 'PENDIENTE')
          IconButton(
            icon: Icon(Icons.info, color: AppTheme.primary, size: 20),
            onPressed: () => _mostrarDialogoProcesar(traslado),
            tooltip: 'Procesar',
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_shipping, size: 64, color: AppTheme.textSecondary),
          SizedBox(height: 16),
          Text(
            'No hay traslados',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            'Crea tu primer traslado de compras',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoCrearTraslado(String userName) {
    showDialog(
      context: context,
      builder: (context) => _DialogoCrearTraslado(
        productos: _productos,
        userName: userName,
        onTrasladoCreado: () {
          _cargarDatos();
        },
      ),
    );
  }

  void _mostrarDialogoProcesar(Traslado traslado) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final aprobador = userProvider.userName ?? 'Usuario';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text(
          'Procesar Traslado ${traslado.numero}',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Producto: ${traslado.productoNombre}',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            Text(
              'Cantidad: ${traslado.cantidad}',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            Text(
              'Origen: ${traslado.origenBodegaNombre}',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            Text(
              'Destino: ${traslado.destinoBodegaNombre}',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _procesarTraslado(traslado.id!, 'RECHAZAR', aprobador);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Rechazar', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _procesarTraslado(traslado.id!, 'ACEPTAR', aprobador);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('Aceptar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _procesarTraslado(
    String trasladoId,
    String accion,
    String aprobador,
  ) async {
    try {
      await _trasladoService.procesarTraslado(
        trasladoId: trasladoId,
        accion: accion,
        aprobador: aprobador,
      );
      _mostrarExito('Traslado ${accion.toLowerCase()} correctamente');
      _cargarDatos();
    } catch (e) {
      _mostrarError('Error al procesar traslado: $e');
    }
  }

  void _verDetalles(Traslado traslado) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text(
          'Detalles Traslado ${traslado.numero}',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetalleFila('Producto:', traslado.productoNombre ?? '-'),
              _buildDetalleFila(
                'Cantidad:',
                '${traslado.cantidad} ${traslado.unidad ?? ''}',
              ),
              _buildDetalleFila('Origen:', traslado.origenBodegaNombre ?? '-'),
              _buildDetalleFila(
                'Destino:',
                traslado.destinoBodegaNombre ?? '-',
              ),
              _buildDetalleFila('Solicitante:', traslado.solicitante ?? '-'),
              _buildDetalleFila('Estado:', traslado.estado ?? '-'),
              if (traslado.aprobador != null)
                _buildDetalleFila('Aprobador:', traslado.aprobador!),
              if (traslado.observaciones != null)
                _buildDetalleFila('Observaciones:', traslado.observaciones!),
              if (traslado.fechaSolicitud != null)
                _buildDetalleFila(
                  'Fecha Solicitud:',
                  DateFormat(
                    'yyyy-MM-dd HH:mm',
                  ).format(traslado.fechaSolicitud!),
                ),
              if (traslado.fechaAprobacion != null)
                _buildDetalleFila(
                  'Fecha Aprobación:',
                  DateFormat(
                    'yyyy-MM-dd HH:mm',
                  ).format(traslado.fechaAprobacion!),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalleFila(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(value, style: TextStyle(color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.green),
    );
  }
}

// Diálogo para crear traslado
class _DialogoCrearTraslado extends StatefulWidget {
  final List<Producto> productos;
  final String userName;
  final VoidCallback onTrasladoCreado;

  const _DialogoCrearTraslado({
    required this.productos,
    required this.userName,
    required this.onTrasladoCreado,
  });

  @override
  _DialogoCrearTrasladoState createState() => _DialogoCrearTrasladoState();
}

class _DialogoCrearTrasladoState extends State<_DialogoCrearTraslado> {
  final TrasladoService _trasladoService = TrasladoService();
  final _cantidadController = TextEditingController();
  final _observacionesController = TextEditingController();

  Producto? _productoSeleccionado;
  String? _origenSeleccionado;
  String? _destinoSeleccionado;
  bool _isLoading = false;

  final List<Map<String, String>> _bodegas = [
    {'id': 'BODEGA', 'nombre': 'BODEGA'},
    {'id': 'ALMACEN', 'nombre': 'ALMACEN'},
  ];

  @override
  void dispose() {
    _cantidadController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardBg,
      title: Text(
        'Crear Traslado',
        style: TextStyle(color: AppTheme.textPrimary),
      ),
      content: SingleChildScrollView(
        child: Container(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Producto>(
                value: _productoSeleccionado,
                decoration: InputDecoration(
                  labelText: 'Producto',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: AppTheme.surfaceDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                dropdownColor: AppTheme.surfaceDark,
                style: TextStyle(color: AppTheme.textPrimary),
                items: widget.productos.map((producto) {
                  return DropdownMenuItem(
                    value: producto,
                    child: Text(
                      '${producto.nombre} (Almacén: ${producto.almacen ?? 0}, Bodega: ${producto.bodega ?? 0})',
                    ),
                  );
                }).toList(),
                onChanged: (value) =>
                    setState(() => _productoSeleccionado = value),
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _origenSeleccionado,
                decoration: InputDecoration(
                  labelText: 'Bodega Origen',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: AppTheme.surfaceDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                dropdownColor: AppTheme.surfaceDark,
                style: TextStyle(color: AppTheme.textPrimary),
                items: _bodegas.map((bodega) {
                  return DropdownMenuItem(
                    value: bodega['id'],
                    child: Text(bodega['nombre']!),
                  );
                }).toList(),
                onChanged: (value) =>
                    setState(() => _origenSeleccionado = value),
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _destinoSeleccionado,
                decoration: InputDecoration(
                  labelText: 'Bodega Destino',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: AppTheme.surfaceDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                dropdownColor: AppTheme.surfaceDark,
                style: TextStyle(color: AppTheme.textPrimary),
                items: _bodegas.map((bodega) {
                  return DropdownMenuItem(
                    value: bodega['id'],
                    child: Text(bodega['nombre']!),
                  );
                }).toList(),
                onChanged: (value) =>
                    setState(() => _destinoSeleccionado = value),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _cantidadController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Cantidad',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: AppTheme.surfaceDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _observacionesController,
                maxLines: 3,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Observaciones (opcional)',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: AppTheme.surfaceDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancelar',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _crearTraslado,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
          child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text('Crear', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _crearTraslado() async {
    if (_productoSeleccionado == null ||
        _origenSeleccionado == null ||
        _destinoSeleccionado == null ||
        _cantidadController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor completa todos los campos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_origenSeleccionado == _destinoSeleccionado) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Las bodegas deben ser diferentes'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _trasladoService.crearTraslado(
        productoId: _productoSeleccionado!.id!,
        origenBodegaId: _origenSeleccionado!,
        destinoBodegaId: _destinoSeleccionado!,
        cantidad: double.parse(_cantidadController.text),
        solicitante: widget.userName,
        observaciones: _observacionesController.text.isEmpty
            ? null
            : _observacionesController.text,
      );

      Navigator.pop(context);
      widget.onTrasladoCreado();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Traslado creado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
