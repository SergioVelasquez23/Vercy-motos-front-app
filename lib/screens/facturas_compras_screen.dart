import 'package:flutter/material.dart';
import '../models/factura_compra.dart';
import '../models/proveedor.dart';
import '../models/producto.dart';
import '../services/factura_compra_service.dart';
import '../services/proveedor_service.dart';
import '../services/producto_service.dart';
import '../theme/app_theme.dart';

class FacturasComprasScreen extends StatefulWidget {
  const FacturasComprasScreen({super.key});

  @override
  _FacturasComprasScreenState createState() => _FacturasComprasScreenState();
}

class _FacturasComprasScreenState extends State<FacturasComprasScreen> {
  final FacturaCompraService _facturaCompraService = FacturaCompraService();
  final TextEditingController _searchController = TextEditingController();

  List<FacturaCompra> _facturas = [];
  List<FacturaCompra> _facturasFiltradas = [];
  bool _isLoading = false;
  String _filtroEstado = 'TODOS';
  String? _filtroProveedor;
  String _filtroPagoCaja = 'TODOS'; // TODOS, PAGADAS_CAJA, NO_PAGADAS_CAJA

  // Variable para controlar el timeout del botón guardar factura
  bool _guardandoFactura = false;

  @override
  void initState() {
    super.initState();
    _cargarFacturas();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Método auxiliar para determinar si una factura debe considerarse como pagada
  bool _estaFacturaPagada(FacturaCompra factura) {
    return factura.estado.toUpperCase() == 'PAGADA' || factura.pagadoDesdeCaja;
  }

  // Método para obtener el estado real a mostrar para una factura
  String _obtenerEstadoVisual(FacturaCompra factura) {
    if (_estaFacturaPagada(factura)) {
      return 'PAGADA';
    }
    return factura.estado.toUpperCase();
  }

  Future<void> _cargarFacturas() async {
    setState(() => _isLoading = true);
    try {
      final facturas = await _facturaCompraService.getFacturasCompras();

      // Verificar las fechas de creación de las facturas
      for (var i = 0; i < facturas.length && i < 5; i++) {
        var factura = facturas[i];
      }

      setState(() {
        _facturas = facturas;
        _aplicarFiltros();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar facturas: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _aplicarFiltros() {
    setState(() {
      _facturasFiltradas = _facturas.where((factura) {
        final cumpleBusqueda =
            _searchController.text.isEmpty ||
            factura.numeroFactura.toLowerCase().contains(
              _searchController.text.toLowerCase(),
            ) ||
            factura.proveedorNombre.toLowerCase().contains(
              _searchController.text.toLowerCase(),
            ) ||
            (factura.proveedorNit?.toLowerCase().contains(
                  _searchController.text.toLowerCase(),
                ) ??
                false);

        // Mejorar la lógica de filtrado por estado usando el método auxiliar
        bool cumpleEstado;
        if (_filtroEstado == 'TODOS') {
          cumpleEstado = true;
        } else if (_filtroEstado == 'PAGADA') {
          // Una factura se considera pagada si su estado es PAGADA o si pagadoDesdeCaja es true
          cumpleEstado = _estaFacturaPagada(factura);
        } else {
          // Para otros estados como PENDIENTE o CANCELADA, usar la comparación directa
          // Si la factura está pagada desde caja, no debe aparecer como pendiente
          if (_filtroEstado == 'PENDIENTE') {
            cumpleEstado =
                factura.estado == _filtroEstado && !_estaFacturaPagada(factura);
          } else {
            cumpleEstado = factura.estado == _filtroEstado;
          }
        }

        final cumpleProveedor =
            _filtroProveedor == null ||
            factura.proveedorNit == _filtroProveedor;

        final cumplePagoCaja =
            _filtroPagoCaja == 'TODOS' ||
            (_filtroPagoCaja == 'PAGADAS_CAJA' && factura.pagadoDesdeCaja) ||
            (_filtroPagoCaja == 'NO_PAGADAS_CAJA' && !factura.pagadoDesdeCaja);

        return cumpleBusqueda &&
            cumpleEstado &&
            cumpleProveedor &&
            cumplePagoCaja;
      }).toList();

      // Imprimir fechas antes de ordenar
      for (var i = 0; i < _facturasFiltradas.length && i < 5; i++) {
        final factura = _facturasFiltradas[i];
      }

      // Ordenar por fecha de creación primero, luego por fecha de factura si hay empate
      _facturasFiltradas.sort((a, b) {
        // Primero intentar ordenar por fechaCreacion
        final dateCompare = b.fechaCreacion.compareTo(a.fechaCreacion);

        // Si las fechas son iguales (posible para facturas creadas en el mismo momento)
        // usar la fecha de factura como criterio secundario
        if (dateCompare == 0) {
          return b.fechaFactura.compareTo(a.fechaFactura);
        }

        return dateCompare;
      });

      // Imprimir logs para debug después de ordenar
      for (var i = 0; i < _facturasFiltradas.length && i < 5; i++) {
        final factura = _facturasFiltradas[i];
        final fechaStr =
            "${factura.fechaCreacion.day}/${factura.fechaCreacion.month}/${factura.fechaCreacion.year} ${factura.fechaCreacion.hour}:${factura.fechaCreacion.minute}";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text('Facturas de Compras', style: AppTheme.headlineMedium),
        backgroundColor: AppTheme.backgroundDark,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacementNamed(context, '/dashboard'),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppTheme.textPrimary),
            onPressed: _cargarFacturas,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFiltros(),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  )
                : _facturasFiltradas.isEmpty
                ? _buildEmptyState()
                : _buildListaFacturas(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        onPressed: () => _navegarACrearFactura(),
        child: Icon(Icons.add, color: Colors.white),
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
              prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: AppTheme.textSecondary),
                      onPressed: () {
                        _searchController.clear();
                        _aplicarFiltros();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.textSecondary.withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.textSecondary.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.primary),
              ),
            ),
            onChanged: (value) => _aplicarFiltros(),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Text('Estado: ', style: TextStyle(color: AppTheme.textPrimary)),
              SizedBox(width: 8),
              Expanded(
                child: Scrollbar(
                  scrollbarOrientation: ScrollbarOrientation.bottom,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['TODOS', 'PENDIENTE', 'PAGADA', 'CANCELADA']
                          .map(
                            (estado) => Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(estado),
                                selected: _filtroEstado == estado,
                                onSelected: (selected) {
                                  setState(() {
                                    _filtroEstado = estado;
                                    _aplicarFiltros();
                                  });
                                },
                                selectedColor: AppTheme.primary.withOpacity(0.2),
                                checkmarkColor: AppTheme.primary,
                                labelStyle: TextStyle(
                                  color: _filtroEstado == estado
                                      ? AppTheme.primary
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Text('Pago: ', style: TextStyle(color: AppTheme.textPrimary)),
              SizedBox(width: 8),
              Expanded(
                child: Scrollbar(
                  scrollbarOrientation: ScrollbarOrientation.bottom,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children:
                          [
                                {'value': 'TODOS', 'label': 'Todos'},
                                {
                                  'value': 'PAGADAS_CAJA',
                                  'label': 'Desde caja',
                                },
                                {
                                  'value': 'NO_PAGADAS_CAJA',
                                  'label': 'Fuera de caja',
                                },
                              ]
                              .map(
                                (filtro) => Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(filtro['label']!),
                                    selected:
                                        _filtroPagoCaja == filtro['value'],
                                    onSelected: (selected) {
                                      setState(() {
                                        _filtroPagoCaja = filtro['value']!;
                                        _aplicarFiltros();
                                      });
                                    },
                                    selectedColor: Colors.blue.withOpacity(0.2),
                                    checkmarkColor: Colors.blue,
                                    labelStyle: TextStyle(
                                      color: _filtroPagoCaja == filtro['value']
                                          ? Colors.blue
                                          : AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: AppTheme.textSecondary),
          SizedBox(height: 16),
          Text(
            'No hay facturas de compras',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Crea tu primera factura de compras',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _navegarACrearFactura(),
            icon: Icon(Icons.add),
            label: Text('Crear Factura'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaFacturas() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _facturasFiltradas.length,
      itemBuilder: (context, index) {
        final factura = _facturasFiltradas[index];
        return Card(
          color: AppTheme.cardBg,
          margin: EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              InkWell(
                onTap: () => _mostrarDetalleFactura(factura),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icono a la izquierda
                      CircleAvatar(
                        backgroundColor: AppTheme.primary,
                        child: Icon(Icons.receipt, color: Colors.white),
                      ),
                      SizedBox(width: 12),

                      // Columna con información principal
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              factura.numeroFactura,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              factura.proveedorNombre,
                              style: TextStyle(color: AppTheme.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'NIT: ${factura.proveedorNit ?? 'No especificado'}',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                            // Mostrar fecha de creación en lugar de fecha de factura para facilitar la verificación del orden
                            Text(
                              'Creado: ${_formatearFechaConHora(factura.fechaCreacion)} - Factura: ${_formatearFecha(factura.fechaFactura)}',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(width: 12),

                      // Columna de estado y precio
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Si la factura está pagada desde caja, mostrar el indicador
                              if (_estaFacturaPagada(factura))
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  margin: EdgeInsets.only(right: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green),
                                  ),
                                  child: Icon(
                                    Icons.account_balance_wallet,
                                    size: 12,
                                    color: Colors.green,
                                  ),
                                ),
                              // Si está pagado desde caja, mostrar como PAGADA independientemente del estado
                              _buildEstadoChip(
                                factura.pagadoDesdeCaja
                                    ? 'PAGADA'
                                    : factura.estado,
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            '\$${factura.total.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Botones de edición y eliminación
              Container(height: 1, color: Colors.grey.shade800),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Botón Eliminar
                  Expanded(
                    child: InkWell(
                      onTap: () => _confirmarEliminarFactura(factura),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete, size: 16, color: Colors.red),
                            SizedBox(width: 6),
                            Text(
                              'Eliminar',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEstadoChip(String estado) {
    Color color;
    switch (estado.toUpperCase()) {
      case 'PENDIENTE':
        color = Colors.orange;
        break;
      case 'PAGADA':
        color = Colors.green;
        break;
      case 'CANCELADA':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        estado,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _navegarACrearFactura() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CrearFacturaCompraScreen()),
    ).then((_) => _cargarFacturas());
  }

  void _mostrarDetalleFactura(FacturaCompra factura) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetalleFacturaCompraScreen(factura: factura),
      ),
    ).then((_) => _cargarFacturas());
  }

  // Método para editar una factura
  void _editarFactura(FacturaCompra factura) {
    // Edición no implementada aún
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('La edición de facturas no está disponible aún')),
    );
    /* 
    Para implementar cuando se agregue el parámetro facturaParaEditar en CrearFacturaCompraScreen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CrearFacturaCompraScreen(),
      ),
    ).then((_) => _cargarFacturas());
    */
  }

  // Método para confirmar la eliminación de una factura
  Future<void> _confirmarEliminarFactura(FacturaCompra factura) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text('Eliminar Factura', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          '¿Estás seguro de que deseas eliminar la factura ${factura.numeroFactura}?\n\n'
          'Esta acción no se puede deshacer y afectará al inventario.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final resultado = await _facturaCompraService.eliminarFacturaCompra(
          factura.id!,
        );

        if (resultado['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Factura eliminada correctamente'),
              backgroundColor: Colors.green,
            ),
          );
          await _cargarFacturas();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error: ${resultado['message'] ?? "No se pudo eliminar la factura"}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar factura: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  // Nuevo método para formatear fecha con hora
  String _formatearFechaConHora(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }
}

class CrearFacturaCompraScreen extends StatefulWidget {
  const CrearFacturaCompraScreen({Key? key}) : super(key: key);

  @override
  _CrearFacturaCompraScreenState createState() =>
      _CrearFacturaCompraScreenState();
}

class _CrearFacturaCompraScreenState extends State<CrearFacturaCompraScreen> {
  final _formKey = GlobalKey<FormState>();
  final FacturaCompraService _facturaCompraService = FacturaCompraService();
  final ProveedorService _proveedorService = ProveedorService();
  final ProductoService _productoService = ProductoService();

  final _proveedorNitController = TextEditingController();
  final _proveedorNombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  
  // 💰 Controladores DIAN para retenciones
  final _porcentajeRetencionController = TextEditingController(text: '0');
  final _porcentajeReteIvaController = TextEditingController(text: '0');
  final _porcentajeReteIcaController = TextEditingController(text: '0');
  
  // Descuento general
  final _descuentoGeneralValorController = TextEditingController(text: '0');
  String _tipoDescuentoGeneral = 'Porcentaje'; // 'Porcentaje' o 'Valor'

  DateTime _fechaFactura = DateTime.now();
  DateTime _fechaVencimiento = DateTime.now().add(Duration(days: 30));
  final List<ItemFacturaCompra> _items = [];
  List<Proveedor> _proveedores = [];
  List<Producto> _productos = [];
  Proveedor? _proveedorSeleccionado;
  bool _isLoading = false;
  bool _pagadoDesdeCaja = false;

  // Variable para controlar el timeout del botón guardar factura
  bool _guardandoFactura = false;
  String? _numeroFactura;


  @override
  void initState() {
    super.initState();
    _generarNumeroFactura();
    _cargarProductos();
    _cargarProveedores();
  }

  @override
  void dispose() {
    _proveedorNitController.dispose();
    _proveedorNombreController.dispose();
    _descripcionController.dispose();
    _porcentajeRetencionController.dispose();
    _porcentajeReteIvaController.dispose();
    _porcentajeReteIcaController.dispose();
    _descuentoGeneralValorController.dispose();
    super.dispose();
  }

  Future<void> _runDebugTests() async {
    try {
      print('🔧 Ejecutando pruebas de debug desde UI...');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ejecutando pruebas de debug...'),
          backgroundColor: Colors.orange,
        ),
      );

      final debugResult = await _facturaCompraService.debugBackendConnection();

      print('📊 Resultado de pruebas de debug: $debugResult');

      // Crear un mensaje resumido para mostrar al usuario
      final tests = debugResult['tests'] as Map<String, dynamic>;
      final successCount = tests.values
          .where(
            (test) =>
                test is Map && test['success'] == true ||
                test['reachable'] == true,
          )
          .length;

      final message =
          'Pruebas completadas: $successCount/${tests.length} exitosas. Ver consola para detalles.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: successCount == tests.length
              ? Colors.green
              : Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      print('💥 Error en pruebas de debug: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error en pruebas de debug: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _generarNumeroFactura() async {
    try {
      print('🎯 Iniciando generación de número de factura desde UI...');
      setState(() {
        _numeroFactura = 'Generando...';
      });

      final numero = await _facturaCompraService.generarNumeroFactura();
      print('🎯 Número de factura recibido en UI: $numero');

      setState(() {
        _numeroFactura = numero;
      });

      print('✅ Estado actualizado con número: $_numeroFactura');
    } catch (e) {
      print('💥 Error en _generarNumeroFactura (UI): $e');
      setState(() {
        _numeroFactura = 'Error al generar';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar número de factura: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _cargarProductos() async {
    try {
      final productos = await _productoService.getProductos();
      setState(() {
        _productos = productos;
      });
    } catch (e) {
      print('Error al cargar productos: $e');
    }
  }

  Future<void> _cargarProveedores() async {
    try {
      final proveedores = await _proveedorService.getProveedores();
      setState(() {
        _proveedores = proveedores;
      });
    } catch (e) {
      print('Error al cargar proveedores: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Crear compra',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.backgroundDark,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
        actions: [
          // Botón Compras en borrador
          TextButton(
            onPressed: () {
              // TODO: Navegar a compras en borrador
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Compras en borrador - Próximamente')),
              );
            },
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              'Compras en borrador',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoBasica(),
                    SizedBox(height: 24),
                    _buildFechas(),
                    SizedBox(height: 24),
                    _buildItems(),
                    SizedBox(height: 24),
                    _buildDescripcionYRetenciones(),
                    SizedBox(height: 24),
                    _buildResumen(),
                    SizedBox(height: 24),
                    _buildBotones(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoBasica() {
    return Card(
      color: AppTheme.cardBg,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Información Básica',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            TextFormField(
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Número de Factura',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.textSecondary.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.primary),
                ),
              ),
              initialValue: _numeroFactura ?? 'Generando...',
              enabled: false,
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<Proveedor>(
              initialValue: _proveedorSeleccionado,
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Proveedor',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
                hintText: 'Seleccionar proveedor',
                hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.7)),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.textSecondary.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.primary),
                ),
              ),
              dropdownColor: AppTheme.cardBg,
              items: [
                DropdownMenuItem<Proveedor>(
                  value: null,
                  child: Text(
                    'Proveedor general',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
                ..._proveedores.map((proveedor) {
                  return DropdownMenuItem<Proveedor>(
                    value: proveedor,
                    child: Text(
                      proveedor.nombre,
                      style: TextStyle(color: AppTheme.textPrimary),
                    ),
                  );
                }),
              ],
              onChanged: (Proveedor? valor) {
                setState(() {
                  _proveedorSeleccionado = valor;
                  if (valor != null) {
                    _proveedorNitController.text = valor.documento ?? '';
                    _proveedorNombreController.text = valor.nombre;
                  } else {
                    _proveedorNitController.clear();
                    _proveedorNombreController.clear();
                  }
                });
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _proveedorNitController,
              style: TextStyle(color: AppTheme.textPrimary),
              enabled: _proveedorSeleccionado == null,
              decoration: InputDecoration(
                labelText: 'NIT del Proveedor (Opcional)',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
                hintText: _proveedorSeleccionado != null
                    ? 'Autocompletado desde proveedor seleccionado'
                    : 'Solo para proveedores personalizados',
                hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.7)),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.textSecondary.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.primary),
                ),
                disabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.textSecondary.withOpacity(0.1)),
                ),
              ),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _proveedorNombreController,
              style: TextStyle(color: AppTheme.textPrimary),
              enabled: _proveedorSeleccionado == null,
              decoration: InputDecoration(
                labelText: 'Nombre del Proveedor (Opcional)',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
                hintText: _proveedorSeleccionado != null
                    ? 'Autocompletado desde proveedor seleccionado'
                    : 'Solo para proveedores personalizados',
                hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.7)),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.textSecondary.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.primary),
                ),
                disabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.textSecondary.withOpacity(0.1)),
                ),
              ),
            ),
            SizedBox(height: 16),
            SwitchListTile(
              title: Text(
                'Pagado desde caja',
                style: TextStyle(color: AppTheme.textPrimary),
              ),
              subtitle: Text(
                'Marcar si esta compra afecta el flujo de caja del día',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              value: _pagadoDesdeCaja,
              onChanged: (value) {
                setState(() {
                  _pagadoDesdeCaja = value;
                });
              },
              activeThumbColor: AppTheme.primary,
              activeTrackColor: AppTheme.primary.withOpacity(0.3),
            ),
            SizedBox(height: 16),
            Divider(color: AppTheme.textSecondary.withOpacity(0.3)),
            SizedBox(height: 16),
            // 💰 Sección de Retenciones DIAN
            Text(
              'Retenciones (Opcional)',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Configure los porcentajes de retención si aplican',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _porcentajeRetencionController,
                    style: TextStyle(color: AppTheme.textPrimary),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '% Rete Fuente',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      suffixText: '%',
                      suffixStyle: TextStyle(color: AppTheme.textSecondary),
                      helperText: '0.1% - 11%',
                      helperStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _porcentajeReteIvaController,
                    style: TextStyle(color: AppTheme.textPrimary),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '% Rete IVA',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      suffixText: '%',
                      suffixStyle: TextStyle(color: AppTheme.textSecondary),
                      helperText: '15% estándar',
                      helperStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _porcentajeReteIcaController,
                    style: TextStyle(color: AppTheme.textPrimary),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '% Rete ICA',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      suffixText: '%',
                      suffixStyle: TextStyle(color: AppTheme.textSecondary),
                      helperText: 'Varía por municipio',
                      helperStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFechas() {
    return Card(
      color: AppTheme.cardBg,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fechas',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: Text(
                      'Fecha de Factura',
                      style: TextStyle(color: AppTheme.textPrimary),
                    ),
                    subtitle: Text(
                      _formatearFecha(_fechaFactura),
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    leading: Icon(Icons.calendar_today, color: AppTheme.primary),
                    onTap: () => _seleccionarFecha(context, true),
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: Text(
                      'Fecha de Vencimiento',
                      style: TextStyle(color: AppTheme.textPrimary),
                    ),
                    subtitle: Text(
                      _formatearFecha(_fechaVencimiento),
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    leading: Icon(Icons.event, color: AppTheme.primary),
                    onTap: () => _seleccionarFecha(context, false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItems() {
    return Card(
      color: AppTheme.cardBg,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Items de la Factura',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _agregarItem,
                  icon: Icon(Icons.add),
                  label: Text('Agregar Item'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (_items.isEmpty)
              Container(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2, size: 48, color: AppTheme.textSecondary),
                      SizedBox(height: 8),
                      Text(
                        'No hay items agregados',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Card(
                  color: AppTheme.backgroundDark,
                  margin: EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      item.ingredienteNombre,
                      style: TextStyle(color: AppTheme.textPrimary),
                    ),
                    subtitle: Text(
                      '${item.cantidad} ${item.unidad} x \$${item.precioUnitario.toStringAsFixed(0)}',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '\$${item.subtotal.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _eliminarItem(index),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildResumen() {
    // Calcular totales DIAN
    final subtotalItems = _items.fold<double>(0, (sum, item) => sum + item.subtotal);
    final totalDescuentosItems = _items.fold<double>(0, (sum, item) => sum + item.valorDescuento);
    
    // Calcular descuento general
    final descuentoGeneralValor =
        double.tryParse(_descuentoGeneralValorController.text) ?? 0;
    double descuentoGeneralAplicado = 0;
    if (_tipoDescuentoGeneral == 'Porcentaje') {
      descuentoGeneralAplicado = subtotalItems * (descuentoGeneralValor / 100);
    } else {
      descuentoGeneralAplicado = descuentoGeneralValor;
    }

    final baseGravable =
        subtotalItems - totalDescuentosItems - descuentoGeneralAplicado;
    final totalImpuestosItems = _items.fold<double>(0, (sum, item) => sum + item.valorImpuesto);
    
    // Retenciones
    final porcRetencion = double.tryParse(_porcentajeRetencionController.text) ?? 0;
    final porcReteIva = double.tryParse(_porcentajeReteIvaController.text) ?? 0;
    final porcReteIca = double.tryParse(_porcentajeReteIcaController.text) ?? 0;
    
    final valorRetencion = baseGravable * (porcRetencion / 100);
    final valorReteIva = totalImpuestosItems * (porcReteIva / 100);
    final valorReteIca = baseGravable * (porcReteIca / 100);
    final totalRetenciones = valorRetencion + valorReteIva + valorReteIca;
    
    // Total final
    final totalFinal = baseGravable + totalImpuestosItems - totalRetenciones;

    return Card(
      color: AppTheme.cardBg,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Resumen',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            // Desglose de totales
            _buildResumenRow('Subtotal:', subtotalItems),
            if (totalDescuentosItems > 0)
              _buildResumenRow(
                'Dcto Producto:',
                -totalDescuentosItems,
                isNegative: true,
              ),

            // Descuento General
            SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Dcto General',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 100,
                        child: DropdownButtonFormField<String>(
                          value: _tipoDescuentoGeneral,
                          dropdownColor: AppTheme.cardBg,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'Porcentaje',
                              child: Text('%'),
                            ),
                            DropdownMenuItem(value: 'Valor', child: Text('\$')),
                          ],
                          onChanged: (value) {
                            setState(
                              () =>
                                  _tipoDescuentoGeneral = value ?? 'Porcentaje',
                            );
                          },
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _descuentoGeneralValorController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(),
                            hintText: _tipoDescuentoGeneral == 'Porcentaje'
                                ? '%'
                                : '\$',
                            hintStyle: TextStyle(color: AppTheme.textSecondary),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  '-\$${descuentoGeneralAplicado.toStringAsFixed(0)}',
                  style: TextStyle(color: Colors.red[300], fontSize: 14),
                ),
              ],
            ),
            SizedBox(height: 8),
            
            if (totalImpuestosItems > 0)
              _buildResumenRow('Impuesto:', totalImpuestosItems),
            // Retenciones
            if (totalRetenciones > 0) ...[
              if (valorRetencion > 0)
                _buildResumenRow(
                  'Retención:',
                  -valorRetencion,
                  isNegative: true,
                ),
              if (valorReteIva > 0)
                _buildResumenRow('Reteiva:', -valorReteIva, isNegative: true),
              if (valorReteIca > 0)
                _buildResumenRow('Reteica:', -valorReteIca, isNegative: true),
            ],
            Divider(color: AppTheme.primary.withOpacity(0.5)),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '\$${totalFinal.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumenRow(String label, double valor, {bool isNegative = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          Text(
            '${isNegative ? "-" : ""}\$${valor.abs().toStringAsFixed(0)}',
            style: TextStyle(
              color: isNegative ? Colors.red[300] : AppTheme.textPrimary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescripcionYRetenciones() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Columna izquierda - Descripción
        Expanded(
          flex: 2,
          child: Card(
            color: AppTheme.cardBg,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Descripción',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _descripcionController,
                    maxLines: 5,
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Ingrese una descripción de la compra...',
                      hintStyle: TextStyle(color: AppTheme.textSecondary),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: AppTheme.textSecondary.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: 16),

        // Columna derecha - Retenciones
        Expanded(
          child: Card(
            color: AppTheme.cardBg,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Retenciones',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),

                  // Retención
                  TextFormField(
                    controller: _porcentajeRetencionController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Retencion %',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: AppTheme.textSecondary.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.primary),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  SizedBox(height: 12),

                  // Reteiva
                  TextFormField(
                    controller: _porcentajeReteIvaController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Reteiva %',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: AppTheme.textSecondary.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.primary),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  SizedBox(height: 12),

                  // Reteica
                  TextFormField(
                    controller: _porcentajeReteIcaController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Reteica %',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: AppTheme.textSecondary.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.primary),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBotones() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Botón Crear Borrador
        OutlinedButton(
          onPressed: _guardandoFactura
              ? null
              : () {
                  // TODO: Implementar guardar como borrador
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Guardar como borrador - Próximamente'),
                    ),
                  );
                },
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppTheme.primary),
            padding: EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'Crear Borrador',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(width: 24),

        // Botón Comprar
        ElevatedButton(
          onPressed: _guardandoFactura ? null : _guardarFactura,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            padding: EdgeInsets.symmetric(horizontal: 64, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _guardandoFactura
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  'Comprar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _seleccionarFecha(
    BuildContext context,
    bool esFechaFactura,
  ) async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: esFechaFactura ? _fechaFactura : _fechaVencimiento,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (fecha != null) {
      setState(() {
        if (esFechaFactura) {
          _fechaFactura = fecha;
        } else {
          _fechaVencimiento = fecha;
        }
      });
    }
  }

  void _agregarItem() {
    if (_productos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hay productos disponibles'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _DialogoAgregarItem(
        productos: _productos,
        onItemAgregado: (item) {
          setState(() {
            _items.add(item);
          });
        },
      ),
    );
  }

  void _eliminarItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _guardarFactura() async {
    if (!_formKey.currentState!.validate()) {
      print('❌ Formulario no válido');
      return;
    }

    if (_items.isEmpty) {
      print('❌ No hay items en la factura');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Debe agregar al menos un item'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 🚀 TIMEOUT: Verificar si ya está guardando
    if (_guardandoFactura) return;

    print('🎯 Iniciando proceso de guardado de factura...');
    print('🆔 Número de factura actual: $_numeroFactura');
    print('📋 Cantidad de items: ${_items.length}');

    setState(() {
      _isLoading = true;
      _guardandoFactura = true;
    });

    try {
      // Calcular el total acumulando los subtotales de cada ítem
      final total = _items.fold<double>(0, (sum, item) => sum + item.subtotal);
      print('💰 Total calculado: $total');

      // Verificar que el número de factura no esté vacío o sea "Generando..."
      if (_numeroFactura == null ||
          _numeroFactura!.isEmpty ||
          _numeroFactura == 'Generando...' ||
          _numeroFactura == 'Error al generar') {
        print('⚠️ Número de factura no válido: $_numeroFactura');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: Número de factura no válido. Reintentando generación...',
            ),
            backgroundColor: Colors.orange,
          ),
        );

        // Intentar regenerar el número
        await _generarNumeroFactura();

        if (_numeroFactura == null ||
            _numeroFactura!.isEmpty ||
            _numeroFactura == 'Generando...' ||
            _numeroFactura == 'Error al generar') {
          throw Exception('No se pudo generar un número de factura válido');
        }
      }

      // Verificar que todos los ítems tengan subtotales válidos
      bool itemsValidos = _items.every((item) => item.subtotal > 0);
      if (!itemsValidos) {
        print('⚠️ Hay ítems con subtotales inválidos');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: Algunos ítems tienen valores inválidos'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      print('✅ Total validado: $total');
      print('📋 Items de la factura antes de crear:');
      for (var i = 0; i < _items.length; i++) {
        final item = _items[i];
        print(
          '📝 Item $i: ${item.ingredienteNombre} - ${item.cantidad} ${item.unidad} x ${item.precioUnitario} = ${item.subtotal}',
        );
      }

      // Asegurarnos que los items tengan valores correctos
      final List<ItemFacturaCompra> itemsVerificados = _items.map((item) {
        // Validar y corregir cualquier subtotal si fuera necesario
        double subtotalCalculado = item.cantidad * item.precioUnitario;
        if (subtotalCalculado != item.subtotal) {
          print(
            '⚠️ Subtotal incorrecto en ${item.ingredienteNombre}: reportado ${item.subtotal}, calculado $subtotalCalculado',
          );
          // Crear una nueva instancia con el subtotal correcto
          return ItemFacturaCompra(
            ingredienteId: item.ingredienteId,
            ingredienteNombre: item.ingredienteNombre,
            cantidad: item.cantidad,
            unidad: item.unidad,
            precioUnitario: item.precioUnitario,
            subtotal: subtotalCalculado,
            porcentajeImpuesto: item.porcentajeImpuesto,
            valorImpuesto: item.valorImpuesto,
            porcentajeDescuento: item.porcentajeDescuento,
            valorDescuento: item.valorDescuento,
          );
        }
        return item;
      }).toList();

      // Calcular totales DIAN
      final subtotalItems = itemsVerificados.fold<double>(0, (sum, item) => sum + item.subtotal);
      final totalDescuentosItems = itemsVerificados.fold<double>(0, (sum, item) => sum + item.valorDescuento);
      final baseGravable = subtotalItems - totalDescuentosItems;
      final totalImpuestosItems = itemsVerificados.fold<double>(0, (sum, item) => sum + item.valorImpuesto);
      
      // Retenciones
      final porcRetencion = double.tryParse(_porcentajeRetencionController.text) ?? 0;
      final porcReteIva = double.tryParse(_porcentajeReteIvaController.text) ?? 0;
      final porcReteIca = double.tryParse(_porcentajeReteIcaController.text) ?? 0;
      
      final valorRetencion = baseGravable * (porcRetencion / 100);
      final valorReteIva = totalImpuestosItems * (porcReteIva / 100);
      final valorReteIca = baseGravable * (porcReteIca / 100);
      final totalRetenciones = valorRetencion + valorReteIva + valorReteIca;
      
      // Total final DIAN
      final totalFinal = baseGravable + totalImpuestosItems - totalRetenciones;

      final factura = FacturaCompra(
        numeroFactura: _numeroFactura ?? '',
        proveedorNit: _proveedorNitController.text.trim().isEmpty
            ? null
            : _proveedorNitController.text.trim(),
        proveedorNombre: _proveedorNombreController.text.trim().isEmpty
            ? null
            : _proveedorNombreController.text.trim(),
        fechaFactura: _fechaFactura,
        fechaVencimiento: _fechaVencimiento,
        total: totalFinal,
        estado: 'PENDIENTE',
        pagadoDesdeCaja: _pagadoDesdeCaja,
        items: itemsVerificados,
        fechaCreacion: DateTime.now(),
        fechaActualizacion: DateTime.now(),
        // Campos DIAN
        subtotal: subtotalItems,
        totalDescuentos: totalDescuentosItems,
        baseGravable: baseGravable,
        totalImpuestos: totalImpuestosItems,
        totalRetenciones: totalRetenciones,
        porcentajeRetencion: porcRetencion,
        valorRetencion: valorRetencion,
        porcentajeReteIva: porcReteIva,
        valorReteIva: valorReteIva,
        porcentajeReteIca: porcReteIca,
        valorReteIca: valorReteIca,
      );

      print('🏪 Enviando factura al servicio...');
      final facturaCreada = await _facturaCompraService.crearFacturaCompra(
        factura,
      );
      print('✅ Factura creada exitosamente: ${facturaCreada.id}');

      // Verificar si la factura creada tiene el total correcto
      if (facturaCreada.total <= 0 && total > 0) {
        print('⚠️ La factura se creó con total 0 pero debería ser $total');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Advertencia: La factura se creó pero el total puede estar incorrecto. Se intentará corregir.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );

        // Intentar actualizar la factura con el total correcto
        try {
          // Aquí podrías llamar a un método para actualizar la factura si existe
          print(
            '🔄 Se debería implementar un método para actualizar el total de la factura',
          );
        } catch (e) {
          print('❌ Error al intentar actualizar el total: $e');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Factura creada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }

      Navigator.pop(context);
    } catch (e) {
      print('💥 Error en _guardarFactura (UI): $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al crear factura: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _guardandoFactura = false;
      });
    }
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }
}

class DetalleFacturaCompraScreen extends StatelessWidget {
  final FacturaCompra factura;

  const DetalleFacturaCompraScreen({super.key, required this.factura});

  // Método auxiliar para determinar si una factura debe considerarse como pagada
  bool _estaFacturaPagada(FacturaCompra factura) {
    return factura.estado.toUpperCase() == 'PAGADA' || factura.pagadoDesdeCaja;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Detalle de Factura',
          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.backgroundDark,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoGeneral(),
            SizedBox(height: 16),
            _buildItems(),
            SizedBox(height: 16),
            _buildResumen(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoGeneral() {
    return Card(
      color: AppTheme.cardBg,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Información General',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            _buildInfoRow('Número de Factura:', factura.numeroFactura),
            _buildInfoRow('Proveedor:', factura.proveedorNombre),
            if (factura.proveedorNit != null)
              _buildInfoRow('NIT:', factura.proveedorNit!),
            _buildInfoRow(
              'Fecha de Factura:',
              _formatearFecha(factura.fechaFactura),
            ),
            _buildInfoRow(
              'Fecha de Creación:',
              _formatearFechaConHora(factura.fechaCreacion),
            ),
            _buildInfoRow(
              'Fecha de Vencimiento:',
              _formatearFecha(factura.fechaVencimiento),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Estado:', style: TextStyle(color: AppTheme.textSecondary)),
                // Si está pagado desde caja, mostrar PAGADA independientemente del estado en la base de datos
                // Usar el método auxiliar para determinar el estado visual
                _buildEstadoChip(
                  _estaFacturaPagada(factura) ? 'PAGADA' : factura.estado,
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Pagado desde caja:', style: TextStyle(color: AppTheme.textSecondary)),
                Row(
                  children: [
                    Icon(
                      factura.pagadoDesdeCaja
                          ? Icons.check_circle
                          : Icons.cancel,
                      color: factura.pagadoDesdeCaja
                          ? Colors.green
                          : Colors.grey,
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      factura.pagadoDesdeCaja ? 'Sí' : 'No',
                      style: TextStyle(
                        color: factura.pagadoDesdeCaja
                            ? Colors.green
                            : AppTheme.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItems() {
    return Card(
      color: AppTheme.cardBg,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Items de la Factura',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            ...factura.items.map(
              (item) => Card(
                color: AppTheme.backgroundDark,
                margin: EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    item.ingredienteNombre,
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                  subtitle: Text(
                    '${item.cantidad} ${item.unidad} x \$${item.precioUnitario.toStringAsFixed(0)}',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  trailing: Text(
                    '\$${item.subtotal.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumen() {
    return Card(
      color: AppTheme.cardBg,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total:',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '\$${factura.total.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Nota: El IVA ya está incluido en los precios',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppTheme.textSecondary)),
          Text(value, style: TextStyle(color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildEstadoChip(String estado) {
    Color color;
    switch (estado.toUpperCase()) {
      case 'PENDIENTE':
        color = Colors.orange;
        break;
      case 'PAGADA':
        color = Colors.green;
        break;
      case 'CANCELADA':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        estado,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  // Añadir método para formatear fecha con hora
  String _formatearFechaConHora(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }
}

// Widget de diálogo para agregar items desde productos
class _DialogoAgregarItem extends StatefulWidget {
  final List<Producto> productos;
  final Function(ItemFacturaCompra) onItemAgregado;

  const _DialogoAgregarItem({
    super.key,
    required this.productos,
    required this.onItemAgregado,
  });

  @override
  _DialogoAgregarItemState createState() => _DialogoAgregarItemState();
}

class _DialogoAgregarItemState extends State<_DialogoAgregarItem> {
  Producto? _productoSeleccionado;
  final _cantidadController = TextEditingController();
  final _precioController = TextEditingController();
  final _totalController = TextEditingController();
  final _porcentajeImpuestoController = TextEditingController(text: '19'); // IVA 19% por defecto
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

  double get _porcentajeImpuesto => double.tryParse(_porcentajeImpuestoController.text) ?? 0;
  double get _porcentajeDescuento => double.tryParse(_porcentajeDescuentoController.text) ?? 0;
  
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
      backgroundColor: AppTheme.cardBg,
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
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: AppTheme.textSecondary),
                ),
              ],
            ),
            SizedBox(height: 20),

            // Búsqueda de productos
            TextField(
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Buscar productos...',
                hintStyle: TextStyle(color: AppTheme.textSecondary),
                prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
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
                        color: AppTheme.textPrimary,
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
                              style: TextStyle(color: AppTheme.textPrimary),
                            ),
                            subtitle: Text(
                              '${producto.categoria?.nombre ?? 'Sin categoría'} - Stock: ${producto.cantidad}',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                            trailing: Text(
                              '\$${producto.precio.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            selected: isSelected,
                            selectedTileColor: AppTheme.primary.withOpacity(0.1),
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
                          color: AppTheme.cardBg,
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
                                color: AppTheme.textPrimary,
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
                                  color: AppTheme.textSecondary,
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
                                          color: AppTheme.textPrimary,
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
                                          color: AppTheme.textSecondary,
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
                                  activeTrackColor: AppTheme.primary.withOpacity(
                                    0.3,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 20),

                            // Campos de entrada uniformes
                            // Cantidad (siempre visible)
                            TextField(
                              controller: _cantidadController,
                              style: TextStyle(color: AppTheme.textPrimary),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Cantidad',
                                labelStyle: TextStyle(color: AppTheme.textSecondary),
                                suffixText: 'unidades',
                                suffixStyle: TextStyle(color: AppTheme.textSecondary),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: Colors.grey[600]!,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: AppTheme.primary),
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
                                style: TextStyle(color: AppTheme.textPrimary),
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Precio Unitario',
                                  labelStyle: TextStyle(
                                    color: AppTheme.textSecondary,
                                  ),
                                  prefixText: '\$',
                                  prefixStyle: TextStyle(
                                    color: AppTheme.textSecondary,
                                  ),
                                  helperText: 'Precio por unidad',
                                  helperStyle: TextStyle(
                                    color: AppTheme.textSecondary,
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
                                style: TextStyle(color: AppTheme.textPrimary),
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Total del Item',
                                  labelStyle: TextStyle(
                                    color: AppTheme.textSecondary,
                                  ),
                                  prefixText: '\$',
                                  prefixStyle: TextStyle(
                                    color: AppTheme.textSecondary,
                                  ),
                                  helperText:
                                      'El precio unitario se calculará automáticamente',
                                  helperStyle: TextStyle(
                                    color: AppTheme.textSecondary,
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
                                    style: TextStyle(color: AppTheme.textPrimary),
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: '% IVA',
                                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                                      suffixText: '%',
                                      suffixStyle: TextStyle(color: AppTheme.textSecondary),
                                      helperText: '0%, 5%, 19%',
                                      helperStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(color: Colors.grey[600]!),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(color: AppTheme.primary),
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
                                    style: TextStyle(color: AppTheme.textPrimary),
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: '% Descuento',
                                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                                      suffixText: '%',
                                      suffixStyle: TextStyle(color: AppTheme.textSecondary),
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(color: Colors.grey[600]!),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(color: AppTheme.primary),
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
                                            color: AppTheme.textPrimary,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          '\$${_precioUnitarioCalculado.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: AppTheme.textPrimary,
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
                                    _buildDesgloseRow('Descuento (${_porcentajeDescuento.toStringAsFixed(0)}%):', -_valorDescuento, isNegative: true),
                                    _buildDesgloseRow('Base Gravable:', _baseGravable),
                                  ],
                                  if (_valorImpuesto > 0)
                                    _buildDesgloseRow('IVA (${_porcentajeImpuesto.toStringAsFixed(0)}%):', _valorImpuesto),
                                  Divider(color: AppTheme.textSecondary.withOpacity(0.3)),
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
                                        '\$${_totalItem.toStringAsFixed(0)}',
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
                    style: TextStyle(color: AppTheme.textSecondary),
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

  Widget _buildDesgloseRow(String label, double valor, {bool isNegative = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          Text(
            '${isNegative ? "-" : ""}\$${valor.abs().toStringAsFixed(0)}',
            style: TextStyle(
              color: isNegative ? Colors.red[300] : AppTheme.textPrimary,
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