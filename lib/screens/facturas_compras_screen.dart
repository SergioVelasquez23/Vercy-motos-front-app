import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/factura_compra.dart';
import '../models/proveedor.dart';
import '../models/producto.dart';
import '../models/movimiento_inventario.dart';
import '../services/factura_compra_service.dart';
import '../services/proveedor_service.dart';
import '../services/producto_service.dart';
import '../services/inventario_service.dart';
import '../providers/datos_cache_provider.dart';
import '../theme/app_theme.dart';
import '../utils/busqueda_productos_utils.dart';

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
          onPressed: () =>
              Navigator.pushReplacementNamed(context, '/dashboard'),
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
                borderSide: BorderSide(
                  color: AppTheme.textSecondary.withOpacity(0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: AppTheme.textSecondary.withOpacity(0.3),
                ),
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
                                selectedColor: AppTheme.primary.withOpacity(
                                  0.2,
                                ),
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
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            // Mostrar fecha de creación en lugar de fecha de factura para facilitar la verificación del orden
                            Text(
                              'Creado: ${_formatearFechaConHora(factura.fechaCreacion)} - Factura: ${_formatearFecha(factura.fechaFactura)}',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
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
    final motivoController = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: Text(
            'Eliminar Factura',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Estás seguro de que deseas eliminar la factura ${factura.numeroFactura}?\n\n'
                'Se revertirá el inventario asociado a esta compra.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              SizedBox(height: 16),
              TextField(
                controller: motivoController,
                maxLines: 3,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Razón de la eliminación (opcional)',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                  hintText: 'Ej: Factura duplicada, error de digitación...',
                  hintStyle: TextStyle(
                    color: AppTheme.textSecondary.withOpacity(0.5),
                  ),
                  filled: true,
                  fillColor: AppTheme.backgroundDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: AppTheme.textSecondary.withOpacity(0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: AppTheme.textSecondary.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(
                'Cancelar',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(motivoController.text.trim());
              },
              child: Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        // Revertir inventario ANTES de eliminar la factura
        await _facturaCompraService.revertirInventarioCompra(factura);

        final resultado = await _facturaCompraService.eliminarFacturaCompra(
          factura.id!,
          motivoEliminacion: result.isNotEmpty ? result : null,
        );

        if (resultado['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Factura eliminada correctamente. Stock revertido.',
              ),
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

  // Nuevo método para formatear fecha con hora (formato 12h con AM/PM)
  String _formatearFechaConHora(DateTime fecha) {
    final hour24 = fecha.hour;
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final period = hour24 >= 12 ? 'PM' : 'AM';
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')} ${hour12.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')} $period';
  }
}

class CrearFacturaCompraScreen extends StatefulWidget {
  final FacturaCompra? facturaParaEditar;

  const CrearFacturaCompraScreen({Key? key, this.facturaParaEditar})
    : super(key: key);

  @override
  _CrearFacturaCompraScreenState createState() =>
      _CrearFacturaCompraScreenState();
}

class _CrearFacturaCompraScreenState extends State<CrearFacturaCompraScreen> {
  final _formKey = GlobalKey<FormState>();
  final FacturaCompraService _facturaCompraService = FacturaCompraService();
  final ProveedorService _proveedorService = ProveedorService();
  final ProductoService _productoService = ProductoService();
  final InventarioService _inventarioService = InventarioService();

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

  // Controladores para agregar producto
  final _codigoProductoController = TextEditingController();
  final _nombreProductoController = TextEditingController();
  final _cantidadProductoController = TextEditingController();
  final _valorUnitarioController = TextEditingController();
  final _porcentajeImpuestoController = TextEditingController(text: '19');
  final _porcentajeDescuentoController = TextEditingController(text: '0');
  // 📦 Controladores para PARTE Y PARTE
  final _cantidadAlmacenController = TextEditingController();
  final _cantidadBodegaController = TextEditingController();
  
  // Campo para guardar desde donde salió la compra (transferencia, sistecredito, etc)
  final _origenCompraController = TextEditingController();
  
  String _tipoImpuesto = 'IVA';
  String _tipoDescuento = '%';
  Producto? _productoSeleccionado;
  String _destinoSeleccionado = 'ALMACÉN'; // 📦 BODEGA, ALMACÉN o PARTE Y PARTE

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
  bool _modoEdicion = false;

  // Estados de carga para productos y proveedores
  bool _cargandoProductos = true;
  bool _cargandoProveedores = true;

  @override
  void initState() {
    super.initState();
    _modoEdicion = widget.facturaParaEditar != null;
    if (_modoEdicion) {
      _cargarDatosFacturaParaEditar();
    } else {
      _generarNumeroFactura();
    }
    _cargarProductos();
    _cargarProveedores();
  }

  void _cargarDatosFacturaParaEditar() {
    final factura = widget.facturaParaEditar!;
    _numeroFactura = factura.numeroFactura;
    _proveedorNombreController.text = factura.proveedorNombre;
    _proveedorNitController.text = factura.proveedorNit ?? '';
    _fechaFactura = factura.fechaFactura;
    _fechaVencimiento =
        factura.fechaVencimiento ?? DateTime.now().add(Duration(days: 30));
    _pagadoDesdeCaja = factura.pagadoDesdeCaja;
    
    // Cargar descripción y origen
    if (factura.descripcion != null) {
      if (factura.descripcion!.startsWith('Origen:')) {
        // Extraer el origen de la descripción
        _origenCompraController.text = factura.descripcion!.replaceFirst(
          'Origen: ',
          '',
        );
      } else {
        _descripcionController.text = factura.descripcion!;
      }
    }

    // Cargar items
    _items.clear();
    _items.addAll(factura.items);

    setState(() {});
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
    _codigoProductoController.dispose();
    _nombreProductoController.dispose();
    _cantidadProductoController.dispose();
    _valorUnitarioController.dispose();
    _porcentajeImpuestoController.dispose();
    _porcentajeDescuentoController.dispose();
    _origenCompraController.dispose();
    _cantidadAlmacenController.dispose();
    _cantidadBodegaController.dispose();
    super.dispose();
  }

  Future<void> _runDebugTests() async {
    try {
        

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ejecutando pruebas de debug...'),
          backgroundColor: Colors.orange,
        ),
      );

      final debugResult = await _facturaCompraService.debugBackendConnection();

        

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
        
      setState(() {
        _numeroFactura = 'Generando...';
      });

      final numero = await _facturaCompraService.generarNumeroFactura();
        

      setState(() {
        _numeroFactura = numero;
      });

        
    } catch (e) {
        
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
      // Obtener productos desde el provider de cache primero
      final cacheProvider = Provider.of<DatosCacheProvider>(
        context,
        listen: false,
      );

      if (cacheProvider.productos != null &&
          cacheProvider.productos!.isNotEmpty) {
        // ✅ El cache está disponible - asignar sin setState innecesarios
        _productos = cacheProvider.productos!;
        if (mounted) {
          setState(
            () => _cargandoProductos = false,
          ); // Solo actualizar estado de carga
        }
      } else {
        // Si no hay productos en cache, cargarlos del servicio
        if (mounted) setState(() => _cargandoProductos = true);
        final productos = await _productoService.getProductos();
        if (mounted) {
          setState(() {
            _productos = productos;
            _cargandoProductos = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargandoProductos = false);
      }
    }
  }

  Future<void> _cargarProveedores() async {
    try {
      setState(() => _cargandoProveedores = true);
      final proveedores = await _proveedorService.getProveedores();
      if (mounted) {
        setState(() {
          _proveedores = proveedores;
          _cargandoProveedores = false;
        });
      }
    } catch (e) {
        
      if (mounted) {
        setState(() => _cargandoProveedores = false);
      }
    }
  }

  Future<void> _mostrarDialogoCrearProducto() async {
    final nombreController = TextEditingController();
    final codigoController = TextEditingController();
    final precioController = TextEditingController();
    final costoController = TextEditingController();
    final cantidadController = TextEditingController(text: '0');
    final descripcionController = TextEditingController();
    final codigoBarrasController = TextEditingController();
    final categoriaController = TextEditingController();
    final marcaController = TextEditingController();
    final ubicacionController = TextEditingController();
    final impuestosController = TextEditingController(text: '19');
    bool guardando = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: Row(
            children: [
              Icon(Icons.add_shopping_cart, color: AppTheme.primary),
              SizedBox(width: 8),
              Text(
                'Crear Nuevo Producto',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 18),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Container(
              width: 450,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nombre
                  TextField(
                    controller: nombreController,
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Nombre del producto *',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.surfaceDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  // Código y Código de barras
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: codigoController,
                          style: TextStyle(color: AppTheme.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Código (opcional)',
                            labelStyle: TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                            filled: true,
                            fillColor: AppTheme.surfaceDark,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: codigoBarrasController,
                          style: TextStyle(color: AppTheme.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Código barras',
                            labelStyle: TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                            filled: true,
                            fillColor: AppTheme.surfaceDark,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  // Costo y Precio
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: costoController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: AppTheme.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Costo *',
                            labelStyle: TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                            prefixText: '\$ ',
                            filled: true,
                            fillColor: AppTheme.surfaceDark,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: precioController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: AppTheme.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Precio venta *',
                            labelStyle: TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                            prefixText: '\$ ',
                            filled: true,
                            fillColor: AppTheme.surfaceDark,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  // Cantidad inicial
                  TextField(
                    controller: cantidadController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Cantidad inicial',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.surfaceDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  // Cantidad y % Impuesto
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: cantidadController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: AppTheme.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Cantidad',
                            labelStyle: TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                            filled: true,
                            fillColor: AppTheme.surfaceDark,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: impuestosController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: AppTheme.textPrimary),
                          decoration: InputDecoration(
                            labelText: '% Impuesto',
                            labelStyle: TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                            filled: true,
                            fillColor: AppTheme.surfaceDark,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  // Categoría, Marca, Ubicación
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: categoriaController,
                          style: TextStyle(color: AppTheme.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Categoría',
                            labelStyle: TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                            filled: true,
                            fillColor: AppTheme.surfaceDark,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: marcaController,
                          style: TextStyle(color: AppTheme.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Marca',
                            labelStyle: TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                            filled: true,
                            fillColor: AppTheme.surfaceDark,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  // Ubicación
                  TextField(
                    controller: ubicacionController,
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Ubicación/Localización',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.surfaceDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  // Descripción
                  TextField(
                    controller: descripcionController,
                    maxLines: 2,
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Descripción (opcional)',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.surfaceDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: guardando ? null : () => Navigator.pop(dialogContext),
              child: Text(
                'Cancelar',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: guardando
                  ? null
                  : () async {
                      if (nombreController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('El nombre es obligatorio')),
                        );
                        return;
                      }
                      if (costoController.text.isEmpty ||
                          precioController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('El costo y precio son obligatorios'),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => guardando = true);

                      try {
                        final precio = double.parse(precioController.text);
                        final costo = double.parse(costoController.text);
                        final utilidad = precio - costo;
                        final cantidad =
                            int.tryParse(cantidadController.text) ?? 0;
                        final impuestos =
                            double.tryParse(impuestosController.text) ?? 19;

                        final nuevoProducto = Producto(
                          id: '',
                          nombre: nombreController.text.trim(),
                          codigo: codigoController.text.isNotEmpty
                              ? codigoController.text.trim()
                              : null,
                          codigoBarras: codigoBarrasController.text.isNotEmpty
                              ? codigoBarrasController.text.trim()
                              : null,
                          precio: precio,
                          costo: costo,
                          utilidad: utilidad,
                          cantidad: cantidad,
                          descripcion: descripcionController.text.isNotEmpty
                              ? descripcionController.text.trim()
                              : null,
                          categoria: null, // Sin categoría por ahora
                          marca: marcaController.text.isNotEmpty
                              ? marcaController.text.trim()
                              : null,
                          localizacion: ubicacionController.text.isNotEmpty
                              ? ubicacionController.text.trim()
                              : null,
                          porcentajeImpuesto: impuestos,
                          estado: 'Activo',
                        );

                        final productoCreado = await _productoService
                            .addProducto(nuevoProducto);

                        // � AGREGAR DIRECTAMENTE a la lista EXISTENTE (sin refetch!)
                        if (mounted) {
                          final cacheProvider = Provider.of<DatosCacheProvider>(
                            context,
                            listen: false,
                          );

                          // 1️⃣ Agregar a lista local - CREAR NUEVA LISTA
                          setState(() {
                            // Crear una nueva lista con el producto al inicio
                            _productos = [productoCreado, ..._productos];
                            _productoSeleccionado = productoCreado;
                            _codigoProductoController.text =
                                productoCreado.codigo ?? productoCreado.id;
                            _nombreProductoController.text =
                                productoCreado.nombre;
                            _valorUnitarioController.text = productoCreado.costo
                                .toString();
                          });

                          // 2️⃣ Actualizar TAMBIÉN el Provider para next time
                          cacheProvider.agregarProductoAlCache(productoCreado);
                        }

                        Navigator.pop(dialogContext);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '✅ Producto creado: ${productoCreado.nombre}',
                            ),
                            backgroundColor: AppTheme.success,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => guardando = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error al crear producto: $e'),
                            backgroundColor: AppTheme.error,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
              ),
              child: guardando
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text(
          _modoEdicion ? 'Editar compra' : 'Crear compra',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.backgroundDark,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacementNamed(context, '/compras'),
        ),
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWideScreen = constraints.maxWidth > 900;

                  if (isWideScreen) {
                    // Layout de dos columnas para pantallas grandes
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Columna izquierda - Formulario
                        Expanded(
                          flex: 3,
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFechasYProveedor(),
                                SizedBox(height: 24),
                                _buildDatosProducto(),
                                SizedBox(height: 24),
                                _buildDescripcionYRetencionesCompacto(),
                                SizedBox(height: 24),
                                _buildBotones(),
                              ],
                            ),
                          ),
                        ),
                        // Columna derecha - Resumen
                        Container(
                          width: 350,
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(24),
                            child: _buildResumenLateral(),
                          ),
                        ),
                      ],
                    );
                  } else {
                    // Layout de una columna para móviles
                    return SingleChildScrollView(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFechasYProveedor(),
                          SizedBox(height: 20),
                          _buildDatosProducto(),
                          SizedBox(height: 20),
                          _buildDescripcionYRetencionesCompacto(),
                          SizedBox(height: 20),
                          _buildResumenLateral(),
                          SizedBox(height: 20),
                          _buildBotones(),
                        ],
                      ),
                    );
                  }
                },
              ),
            ),
    );
  }

  // Nuevo: Fechas y Proveedor en formato compacto como en la imagen
  Widget _buildFechasYProveedor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fila 1: Fecha y Vencimiento
        Row(
          children: [
            // Fecha
            Expanded(
              child: Row(
                children: [
                  Text(
                    'Fecha',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _seleccionarFecha(context, true),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppTheme.textSecondary.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatearFechaISO(_fechaFactura),
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                            Icon(
                              Icons.calendar_today,
                              color: AppTheme.textSecondary,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 32),
            // Vencimiento
            Expanded(
              child: Row(
                children: [
                  Text(
                    'Vencimiento',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _seleccionarFecha(context, false),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppTheme.textSecondary.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatearFechaISO(_fechaVencimiento),
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                            Icon(
                              Icons.calendar_today,
                              color: AppTheme.textSecondary,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        // Fila 2: Proveedor y Factura
        Row(
          children: [
            // Proveedor
            Expanded(
              child: Row(
                children: [
                  Text(
                    'Proveedor',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppTheme.textSecondary.withOpacity(0.3),
                        ),
                      ),
                      child: DropdownButtonFormField<Proveedor>(
                        value: _proveedorSeleccionado,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: InputBorder.none,
                          hintText: 'Seleccionar proveedor',
                          hintStyle: TextStyle(color: AppTheme.textSecondary),
                        ),
                        dropdownColor: AppTheme.cardBg,
                        isExpanded: true,
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
                              _proveedorNitController.text =
                                  valor.documento ?? '';
                              _proveedorNombreController.text = valor.nombre;
                            } else {
                              _proveedorNitController.clear();
                              _proveedorNombreController.clear();
                            }
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 32),
            // Factura (número)
            Expanded(
              child: Row(
                children: [
                  Text(
                    'Factura',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppTheme.textSecondary.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        _numeroFactura ?? 'Generando...',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        // Toggle de Pago desde Caja (VISIBLE Y PROMINENTE)
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _pagadoDesdeCaja
                ? Colors.green.withOpacity(0.15)
                : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _pagadoDesdeCaja
                  ? Colors.green.withOpacity(0.5)
                  : Colors.orange.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _pagadoDesdeCaja ? Icons.check_circle : Icons.warning_amber,
                color: _pagadoDesdeCaja ? Colors.green : Colors.orange,
                size: 28,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pagado desde Caja',
                      style: TextStyle(
                        color: _pagadoDesdeCaja ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _pagadoDesdeCaja
                          ? 'Esta compra se descontara del efectivo de la caja'
                          : 'Esta compra NO afectara el flujo de caja del dia',
                      style: TextStyle(
                        color: _pagadoDesdeCaja
                            ? Colors.green.shade300
                            : Colors.orange.shade300,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _pagadoDesdeCaja,
                onChanged: (value) {
                  setState(() {
                    _pagadoDesdeCaja = value;
                  });
                },
                activeColor: Colors.green,
                activeTrackColor: Colors.green.withOpacity(0.3),
                inactiveThumbColor: Colors.orange,
                inactiveTrackColor: Colors.orange.withOpacity(0.3),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        // Campo de Origen de Compra (solo se muestra cuando NO paga desde caja)
        if (!_pagadoDesdeCaja)
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Origen de la Compra',
                  style: TextStyle(
                    color: Colors.blue.shade300,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _origenCompraController,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    hintText:
                        'Ej: Transferencia, Sistecredito, Efectivo en mano, etc.',
                    hintStyle: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Nuevo: Sección Datos Producto como en la imagen
  Widget _buildDatosProducto() {
    // Calcular valor total del producto actual
    final cantidad = double.tryParse(_cantidadProductoController.text) ?? 0;
    final valorUnitario = double.tryParse(_valorUnitarioController.text) ?? 0;
    final valorTotal = cantidad * valorUnitario;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Datos Producto',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        // Fila 1: Código de Barras
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Text(
                'Código de Barras',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              ),
              SizedBox(width: 16),
              Expanded(
                child: TextField(
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    hintText: 'Escanear o ingresar código',
                    hintStyle: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (value) {
                    // Buscar producto por código de barras
                    final producto = _productos
                        .where((p) => p.id == value)
                        .firstOrNull;
                    if (producto != null) {
                      setState(() {
                        _productoSeleccionado = producto;
                        _codigoProductoController.text = producto.id;
                        _nombreProductoController.text = producto.nombre;
                        _valorUnitarioController.text = producto.precio
                            .toString();
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        // Fila 2: Código, Nombre, Cantidad, Valor unitario
        Row(
          children: [
            _buildFieldLabel('Código', flex: 1),
            _buildFieldLabel('Nombre producto', flex: 3),
            _buildFieldLabel('Cantidad', flex: 1),
            _buildFieldLabel('Valor unitario', flex: 1),
          ],
        ),
        SizedBox(height: 4),
        // Fila 3: Campos de entrada con Autocomplete para producto
        Row(
          children: [
            // Código - Autocomplete para buscar por código
            Expanded(
              flex: 1,
              child: _cargandoProductos
                  ? Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primary,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Cargando...',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Autocomplete<Producto>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return const Iterable<Producto>.empty();
                        }
                        // Buscar por código - sin requisito de mínimo 2 caracteres
                        final texto = textEditingValue.text.toLowerCase();
                        return _productos
                            .where((p) {
                              final cod = (p.codigo ?? '').toLowerCase();
                              return cod.contains(texto) || cod.startsWith(texto);
                            })
                            .take(15);
                      },
                      displayStringForOption: (Producto producto) =>
                          (producto.codigo?.isNotEmpty ?? false) 
                              ? producto.codigo!
                              : producto.id,
                      onSelected: (Producto producto) {
                        setState(() {
                          _productoSeleccionado = producto;
                          _codigoProductoController.text = (producto.codigo?.isNotEmpty ?? false)
                              ? producto.codigo!
                              : producto.id;
                          _nombreProductoController.text = producto.nombre;
                          _valorUnitarioController.text = producto.costo
                              .toString();
                        });
                      },
                      fieldViewBuilder:
                          (
                            BuildContext context,
                            TextEditingController textEditingController,
                            FocusNode focusNode,
                            VoidCallback onFieldSubmitted,
                          ) {
                            // Sincronizar con el controlador principal
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              textEditingController.text = _codigoProductoController.text;
                            });
                            return TextField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                                hintText: 'Código...',
                                hintStyle: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                ),
                                filled: true,
                                fillColor: AppTheme.surfaceDark,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            );
                          },
                      optionsViewBuilder:
                          (
                            BuildContext context,
                            AutocompleteOnSelected<Producto> onSelected,
                            Iterable<Producto> options,
                          ) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4.0,
                                color: AppTheme.surfaceDark,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxHeight: 250,
                                    maxWidth: 150,
                                  ),
                                  child: ListView.builder(
                                    padding: EdgeInsets.all(8.0),
                                    itemCount: options.length,
                                    shrinkWrap: true,
                                    itemBuilder: (BuildContext context, int index) {
                                      final Producto option = options.elementAt(index);
                                      return InkWell(
                                        onTap: () => onSelected(option),
                                        child: Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text(
                                            (option.codigo?.isNotEmpty ?? false)
                                                ? option.codigo!
                                                : option.id,
                                            style: TextStyle(
                                              color: AppTheme.textPrimary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                    ),
            ),
            SizedBox(width: 8),
            // Nombre Producto - Autocomplete con indicador de carga
            Expanded(
              flex: 2,
              child: _cargandoProductos
                  ? Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primary,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Cargando productos...',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Autocomplete<Producto>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        // No mostrar nada si está vacío (igual que facturación)
                        if (textEditingValue.text.isEmpty) {
                          return const Iterable<Producto>.empty();
                        }
                        // Requerir al menos 2 caracteres para buscar (más rápido)
                        if (textEditingValue.text.length < 2) {
                          return const Iterable<Producto>.empty();
                        }
                        // Buscar en productos
                        return filtrarYOrdenarProductos(
                          _productos,
                          textEditingValue.text,
                          limite: 15,
                        );
                      },
                      displayStringForOption: (Producto producto) =>
                          producto.nombre,
                      onSelected: (Producto producto) {
                        setState(() {
                          _productoSeleccionado = producto;
                          _codigoProductoController.text = (producto.codigo?.isNotEmpty ?? false)
                              ? producto.codigo!
                              : producto.id;
                          _nombreProductoController.text = producto.nombre;
                          _valorUnitarioController.text = producto.costo
                              .toString();
                        });
                      },
                      fieldViewBuilder:
                          (
                            BuildContext context,
                            TextEditingController textEditingController,
                            FocusNode focusNode,
                            VoidCallback onFieldSubmitted,
                          ) {
                            return TextField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                                hintText: _productos.isEmpty
                                    ? 'No hay productos disponibles'
                                    : 'Escribe al menos 2 letras...',
                                hintStyle: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                ),
                                filled: true,
                                fillColor: AppTheme.surfaceDark,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: BorderSide.none,
                                ),
                                suffixIcon: Icon(
                                  Icons.arrow_drop_down,
                                  color: AppTheme.textSecondary,
                                  size: 20,
                                ),
                              ),
                            );
                          },
                      optionsViewBuilder:
                          (
                            BuildContext context,
                            AutocompleteOnSelected<Producto> onSelected,
                            Iterable<Producto> options,
                          ) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4.0,
                                color: AppTheme.surfaceDark,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxHeight: 300,
                                    maxWidth: 400,
                                  ),
                                  child: ListView.builder(
                                    padding: EdgeInsets.all(8.0),
                                    itemCount: options.length,
                                    shrinkWrap: true,
                                    itemBuilder: (BuildContext context, int index) {
                                      final Producto option = options.elementAt(
                                        index,
                                      );
                                      return InkWell(
                                        onTap: () => onSelected(option),
                                        child: Container(
                                          padding: EdgeInsets.all(12.0),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: AppTheme.textSecondary
                                                    .withOpacity(0.2),
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                option.nombre,
                                                style: TextStyle(
                                                  color: AppTheme.textPrimary,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Text(
                                                    'Código: ${option.id}',
                                                    style: TextStyle(
                                                      color: AppTheme
                                                          .textSecondary,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  Spacer(),
                                                  Text(
                                                    '\$${option.precio.toStringAsFixed(0)}',
                                                    style: TextStyle(
                                                      color: AppTheme.primary,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                    ),
            ),
            SizedBox(width: 4),
            // Botón para crear nuevo producto
            Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppTheme.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.add, color: AppTheme.primary, size: 20),
                onPressed: _mostrarDialogoCrearProducto,
                tooltip: 'Crear nuevo producto',
              ),
            ),
            SizedBox(width: 8),
            // Cantidad
            Expanded(
              flex: 1,
              child: TextField(
                controller: _cantidadProductoController,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  hintText: '0',
                  hintStyle: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            SizedBox(width: 8),
            // Valor unitario
            Expanded(
              flex: 1,
              child: TextField(
                controller: _valorUnitarioController,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  hintText: '\$0',
                  hintStyle: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        // Fila 4: Valor total, Tipo Imp, % Imp, Tipo %, % Descuento
        Row(
          children: [
            _buildFieldLabel('Valor total', flex: 1),
            _buildFieldLabel('', flex: 1), // Dropdown tipo impuesto
            _buildFieldLabel('% Imp.', flex: 1),
            _buildFieldLabel('', flex: 1), // Dropdown tipo descuento
            _buildFieldLabel('% Descuento', flex: 1),
            SizedBox(width: 60), // Espacio para botones
          ],
        ),
        SizedBox(height: 4),
        Row(
          children: [
            // Valor total calculado
            Expanded(
              flex: 1,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '\$${valorTotal.toStringAsFixed(0)}',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonFormField<String>(
                  value: _tipoImpuesto,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: InputBorder.none,
                  ),
                  dropdownColor: AppTheme.cardBg,
                  items: ['--', 'IVA', 'INC']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _tipoImpuesto = v ?? '--'),
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: TextField(
                controller: _porcentajeImpuestoController,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  hintText: '0',
                  hintStyle: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonFormField<String>(
                  value: _tipoDescuento,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: InputBorder.none,
                  ),
                  dropdownColor: AppTheme.cardBg,
                  items: ['%', '\$']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _tipoDescuento = v ?? '%'),
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: TextField(
                controller: _porcentajeDescuentoController,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  hintText: '0',
                  hintStyle: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            // 📦 MOSTRAR STOCK DISPONIBLE
            if (_productoSeleccionado != null)
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppTheme.primary.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Stock: ALM ${_productoSeleccionado!.almacen ?? 0}',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'BOD ${_productoSeleccionado!.bodega ?? 0}',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(width: 8),
            // 📦 Selector de DESTINO en compras
            Expanded(
              flex: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DropdownButtonFormField<String>(
                  value: _destinoSeleccionado,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: InputBorder.none,
                    hintText: 'Destino',
                  ),
                  dropdownColor: AppTheme.cardBg,
                  items: ['BODEGA', 'ALMACÉN', 'PARTE Y PARTE']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _destinoSeleccionado = v ?? 'ALMACÉN'),
                ),
              ),
            ),
            SizedBox(width: 8),
            // Botones + y -
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.add, color: Colors.white, size: 16),
                    padding: EdgeInsets.zero,
                    onPressed: _agregarItemDesdeFormulario,
                  ),
                ),
                SizedBox(width: 4),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.remove, color: Colors.white, size: 16),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      if (_items.isNotEmpty) {
                        _eliminarItem(_items.length - 1);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
        // 📦 Campos adicionales para PARTE Y PARTE
        if (_destinoSeleccionado == 'PARTE Y PARTE') ...[
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: TextFormField(
                    controller: _cantidadAlmacenController,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      border: InputBorder.none,
                      hintText: 'Cant. Almacén',
                      hintStyle: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                      prefixIcon: Icon(
                        Icons.store,
                        color: Colors.blue,
                        size: 16,
                      ),
                    ),
                    onChanged: (value) {
                      // Auto-calcular cantidad bodega
                      final total =
                          double.tryParse(_cantidadProductoController.text) ??
                          0;
                      final almacen = double.tryParse(value) ?? 0;
                      if (almacen <= total) {
                        _cantidadBodegaController.text = (total - almacen)
                            .toString();
                      }
                    },
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: TextFormField(
                    controller: _cantidadBodegaController,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      border: InputBorder.none,
                      hintText: 'Cant. Bodega',
                      hintStyle: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                      prefixIcon: Icon(
                        Icons.warehouse,
                        color: Colors.orange,
                        size: 16,
                      ),
                    ),
                    onChanged: (value) {
                      // Auto-calcular cantidad almacén
                      final total =
                          double.tryParse(_cantidadProductoController.text) ??
                          0;
                      final bodega = double.tryParse(value) ?? 0;
                      if (bodega <= total) {
                        _cantidadAlmacenController.text = (total - bodega)
                            .toString();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
        SizedBox(height: 16),
        // Lista de items agregados
        if (_items.isNotEmpty) ...[
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: AppTheme.textSecondary.withOpacity(0.3),
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                // Header de la tabla
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Producto',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Cant.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'P. Unit',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Subtotal',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: 40),
                    ],
                  ),
                ),
                // Items
                ..._items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: AppTheme.textSecondary.withOpacity(0.2),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            item.ingredienteNombre,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${item.cantidad} ${item.unidad}',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '\$${item.precioUnitario.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '\$${item.subtotal.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // 📦 Mostrar destino
                        Tooltip(
                          message: item.destino == 'PARTE Y PARTE'
                              ? 'Almacén: ${item.cantidadAlmacen.toStringAsFixed(0)}\nBodega: ${item.cantidadBodega.toStringAsFixed(0)}'
                              : item.destino,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: item.destino == 'BODEGA'
                                  ? Colors.blue.withOpacity(0.2)
                                  : item.destino == 'ALMACÉN'
                                  ? Colors.orange.withOpacity(0.2)
                                  : Colors.purple.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.destino.length > 8
                                      ? 'P. P.'
                                      : item.destino,
                                  style: TextStyle(
                                    color: item.destino == 'BODEGA'
                                        ? Colors.blue
                                        : item.destino == 'ALMACÉN'
                                        ? Colors.orange
                                        : Colors.purple,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (item.destino == 'PARTE Y PARTE')
                                  Text(
                                    'A:${item.cantidadAlmacen.toStringAsFixed(0)} B:${item.cantidadBodega.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      color: Colors.purple,
                                      fontSize: 9,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: AppTheme.error,
                              size: 18,
                            ),
                            padding: EdgeInsets.zero,
                            onPressed: () => _eliminarItem(index),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFieldLabel(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
    );
  }

  Widget _buildTextField({int flex = 1, String? hint, bool enabled = true}) {
    return Expanded(
      flex: flex,
      child: TextField(
        enabled: enabled,
        style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          hintText: hint,
          hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          filled: true,
          fillColor: enabled
              ? AppTheme.surfaceDark
              : AppTheme.surfaceDark.withOpacity(0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // Descripción y Retenciones lado a lado como en la imagen
  Widget _buildDescripcionYRetencionesCompacto() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Descripción
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Descripción',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _descripcionController,
                maxLines: 4,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Descripción de la compra...',
                  hintStyle: TextStyle(color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: AppTheme.surfaceDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 24),
        // Retenciones
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRetencionField('Retención', _porcentajeRetencionController),
              SizedBox(height: 8),
              _buildRetencionField('Reteiva', _porcentajeReteIvaController),
              SizedBox(height: 8),
              _buildRetencionField('Reteica', _porcentajeReteIcaController),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRetencionField(String label, TextEditingController controller) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              suffixText: '%',
              suffixStyle: TextStyle(color: AppTheme.textSecondary),
              filled: true,
              fillColor: AppTheme.surfaceDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }

  // Resumen lateral como en la imagen
  Widget _buildResumenLateral() {
    // Calcular totales
    final subtotalItems = _items.fold<double>(
      0,
      (sum, item) => sum + item.subtotal,
    );
    final totalDescuentosItems = _items.fold<double>(
      0,
      (sum, item) => sum + item.valorDescuento,
    );

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
    final totalImpuestosItems = _items.fold<double>(
      0,
      (sum, item) => sum + item.valorImpuesto,
    );

    final porcRetencion =
        double.tryParse(_porcentajeRetencionController.text) ?? 0;
    final porcReteIva = double.tryParse(_porcentajeReteIvaController.text) ?? 0;
    final porcReteIca = double.tryParse(_porcentajeReteIcaController.text) ?? 0;

    final valorRetencion = baseGravable * (porcRetencion / 100);
    final valorReteIva = totalImpuestosItems * (porcReteIva / 100);
    final valorReteIca = baseGravable * (porcReteIca / 100);

    final totalFinal =
        baseGravable +
        totalImpuestosItems -
        valorRetencion -
        valorReteIva -
        valorReteIca;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildResumenRowCompacto('Subtotal', subtotalItems),
        _buildResumenRowCompacto(
          'Dcto Producto',
          totalDescuentosItems,
          isNegative: true,
        ),
        // Dcto General con dropdown
        Row(
          children: [
            Expanded(
              child: Text(
                'Dcto General',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
            ),
            Container(
              width: 70,
              height: 32,
              child: DropdownButtonFormField<String>(
                value: _tipoDescuentoGeneral == 'Porcentaje'
                    ? 'Valor'
                    : 'Valor',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide.none,
                  ),
                ),
                dropdownColor: AppTheme.cardBg,
                items: [
                  DropdownMenuItem(value: 'Valor', child: Text('Valor')),
                  DropdownMenuItem(value: '%', child: Text('%')),
                ],
                onChanged: (v) {
                  setState(
                    () => _tipoDescuentoGeneral = v == '%'
                        ? 'Porcentaje'
                        : 'Valor',
                  );
                },
              ),
            ),
            SizedBox(width: 8),
            Container(
              width: 80,
              height: 32,
              child: TextField(
                controller: _descuentoGeneralValorController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  prefixText: '\$',
                  prefixStyle: TextStyle(color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: AppTheme.surfaceDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        _buildResumenRowCompacto('Impuesto', totalImpuestosItems),
        _buildResumenRowCompacto('Retención', valorRetencion, isNegative: true),
        _buildResumenRowCompacto('Reteiva', valorReteIva, isNegative: true),
        _buildResumenRowCompacto('Reteica', valorReteIca, isNegative: true),
        SizedBox(height: 8),
        Divider(color: AppTheme.primary.withOpacity(0.3)),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'TOTAL',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '\$${totalFinal.toStringAsFixed(0)}',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResumenRowCompacto(
    String label,
    double valor, {
    bool isNegative = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          Container(
            width: 120,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${isNegative && valor > 0 ? "-" : ""}\$${valor.abs().toStringAsFixed(0)}',
              style: TextStyle(
                color: isNegative && valor > 0
                    ? Colors.red[300]
                    : AppTheme.textPrimary,
                fontSize: 13,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _formatearFechaISO(DateTime fecha) {
    return '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
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
            // 💰 Switch de Pago desde Caja (más visible)
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _pagadoDesdeCaja
                    ? Colors.green.withOpacity(0.15)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _pagadoDesdeCaja
                      ? Colors.green.withOpacity(0.5)
                      : Colors.orange.withOpacity(0.3),
                ),
              ),
              child: SwitchListTile(
                title: Text(
                  '💰 Pagado desde Caja',
                  style: TextStyle(
                    color: _pagadoDesdeCaja ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  _pagadoDesdeCaja
                      ? '✅ Esta compra se descontará del efectivo de la caja'
                      : '⚠️ Esta compra NO afectará el flujo de caja del día',
                  style: TextStyle(
                    color: _pagadoDesdeCaja
                        ? Colors.green.shade300
                        : Colors.orange.shade300,
                    fontSize: 12,
                  ),
                ),
                value: _pagadoDesdeCaja,
                onChanged: (value) {
                  setState(() {
                    _pagadoDesdeCaja = value;
                  });
                },
                activeColor: Colors.green,
                activeTrackColor: Colors.green.withOpacity(0.3),
                inactiveThumbColor: Colors.orange,
                inactiveTrackColor: Colors.orange.withOpacity(0.3),
                contentPadding: EdgeInsets.zero,
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
                  borderSide: BorderSide(
                    color: AppTheme.textSecondary.withOpacity(0.3),
                  ),
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
                hintStyle: TextStyle(
                  color: AppTheme.textSecondary.withOpacity(0.7),
                ),
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
                hintStyle: TextStyle(
                  color: AppTheme.textSecondary.withOpacity(0.7),
                ),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: AppTheme.textSecondary.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.primary),
                ),
                disabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: AppTheme.textSecondary.withOpacity(0.1),
                  ),
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
                hintStyle: TextStyle(
                  color: AppTheme.textSecondary.withOpacity(0.7),
                ),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: AppTheme.textSecondary.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.primary),
                ),
                disabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: AppTheme.textSecondary.withOpacity(0.1),
                  ),
                ),
              ),
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
                      helperStyle: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                      ),
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
                      helperStyle: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                      ),
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
                      helperStyle: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                      ),
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
                    leading: Icon(
                      Icons.calendar_today,
                      color: AppTheme.primary,
                    ),
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
                      Icon(
                        Icons.inventory_2,
                        size: 48,
                        color: AppTheme.textSecondary,
                      ),
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
    final subtotalItems = _items.fold<double>(
      0,
      (sum, item) => sum + item.subtotal,
    );
    final totalDescuentosItems = _items.fold<double>(
      0,
      (sum, item) => sum + item.valorDescuento,
    );

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
    final totalImpuestosItems = _items.fold<double>(
      0,
      (sum, item) => sum + item.valorImpuesto,
    );

    // Retenciones
    final porcRetencion =
        double.tryParse(_porcentajeRetencionController.text) ?? 0;
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

  Widget _buildResumenRow(
    String label,
    double valor, {
    bool isNegative = false,
  }) {
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

  // Método para agregar item desde el formulario inline
  void _agregarItemDesdeFormulario() {
    if (_productoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Seleccione un producto'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final cantidad = double.tryParse(_cantidadProductoController.text) ?? 0;
    if (cantidad <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('La cantidad debe ser mayor a 0'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 📦 Validar PARTE Y PARTE
    double cantidadAlmacen = 0;
    double cantidadBodega = 0;
    if (_destinoSeleccionado == 'PARTE Y PARTE') {
      cantidadAlmacen = double.tryParse(_cantidadAlmacenController.text) ?? 0;
      cantidadBodega = double.tryParse(_cantidadBodegaController.text) ?? 0;

      if (cantidadAlmacen <= 0 && cantidadBodega <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ingrese las cantidades para Almacén y Bodega'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final sumaCantidades = cantidadAlmacen + cantidadBodega;
      if ((sumaCantidades - cantidad).abs() > 0.01) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'La suma de Almacén ($cantidadAlmacen) + Bodega ($cantidadBodega) debe ser igual a la cantidad total ($cantidad)',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
    } else if (_destinoSeleccionado == 'BODEGA') {
      cantidadBodega = cantidad;
    } else {
      // ALMACÉN
      cantidadAlmacen = cantidad;
    }

    final precioUnitario = double.tryParse(_valorUnitarioController.text) ?? 0;
    if (precioUnitario <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('El valor unitario debe ser mayor a 0'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final porcentajeImpuesto =
        double.tryParse(_porcentajeImpuestoController.text) ?? 0;
    final porcentajeDescuento =
        double.tryParse(_porcentajeDescuentoController.text) ?? 0;

    final subtotal = cantidad * precioUnitario;
    final descuento = _tipoDescuento == '%'
        ? subtotal * (porcentajeDescuento / 100)
        : porcentajeDescuento;
    final baseGravable = subtotal - descuento;
    final impuesto = _tipoImpuesto != '--'
        ? baseGravable * (porcentajeImpuesto / 100)
        : 0.0;
    final total = baseGravable + impuesto;

    final item = ItemFacturaCompra(
      ingredienteId: _productoSeleccionado!.id ?? '',
      ingredienteNombre: _productoSeleccionado!.nombre,
      cantidad: cantidad,
      unidad: 'UND',
      precioUnitario: precioUnitario,
      subtotal: baseGravable,
      valorImpuesto: impuesto,
      valorDescuento: descuento,
      porcentajeImpuesto: porcentajeImpuesto,
      porcentajeDescuento: porcentajeDescuento,
      destino: _destinoSeleccionado, // 📦 Agregar destino
      cantidadAlmacen: cantidadAlmacen, // 📦 Cantidad para almacén
      cantidadBodega: cantidadBodega, // 📦 Cantidad para bodega
    );

    setState(() {
      _items.add(item);
      // Limpiar los campos
      _productoSeleccionado = null;
      _codigoProductoController.clear();
      _nombreProductoController.clear();
      _cantidadProductoController.clear();
      _valorUnitarioController.clear();
      _porcentajeImpuestoController.text = '19';
      _porcentajeDescuentoController.text = '0';
      _tipoImpuesto = 'IVA';
      _tipoDescuento = '%';
      _destinoSeleccionado = 'ALMACÉN'; // 📦 Resetear destino
      _cantidadAlmacenController.clear(); // 📦 Limpiar cantidad almacén
      _cantidadBodegaController.clear(); // 📦 Limpiar cantidad bodega
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Producto agregado'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
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
        
      return;
    }

    if (_items.isEmpty) {
        
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

      
      
      

    setState(() {
      _isLoading = true;
      _guardandoFactura = true;
    });

    try {
      // Calcular el total acumulando los subtotales de cada ítem
      final total = _items.fold<double>(0, (sum, item) => sum + item.subtotal);
        

      // Verificar que el número de factura no esté vacío o sea "Generando..."
      if (_numeroFactura == null ||
          _numeroFactura!.isEmpty ||
          _numeroFactura == 'Generando...' ||
          _numeroFactura == 'Error al generar') {
          
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
          
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: Algunos ítems tienen valores inválidos'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

        
        
      for (var i = 0; i < _items.length; i++) {
        final item = _items[i];
                 }

      // Asegurarnos que los items tengan valores correctos
      final List<ItemFacturaCompra> itemsVerificados = _items.map((item) {
        // Validar y corregir cualquier subtotal si fuera necesario
        double subtotalCalculado = item.cantidad * item.precioUnitario;
          
          
          
          
          

        if (subtotalCalculado != item.subtotal) {
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
            destino: item.destino, // 📦 Preservar destino
            cantidadAlmacen: item.cantidadAlmacen, // 📦 Preservar cantidad almacén
            cantidadBodega: item.cantidadBodega, // 📦 Preservar cantidad bodega
          );
        }
        return item;
      }).toList();

      // Calcular totales DIAN
      final subtotalItems = itemsVerificados.fold<double>(
        0,
        (sum, item) => sum + item.subtotal,
      );
      final totalDescuentosItems = itemsVerificados.fold<double>(
        0,
        (sum, item) => sum + item.valorDescuento,
      );
      final baseGravable = subtotalItems - totalDescuentosItems;
      final totalImpuestosItems = itemsVerificados.fold<double>(
        0,
        (sum, item) => sum + item.valorImpuesto,
      );

        
        
        
        
        

      // Retenciones
      final porcRetencion =
          double.tryParse(_porcentajeRetencionController.text) ?? 0;
      final porcReteIva =
          double.tryParse(_porcentajeReteIvaController.text) ?? 0;
      final porcReteIca =
          double.tryParse(_porcentajeReteIcaController.text) ?? 0;

      final valorRetencion = baseGravable * (porcRetencion / 100);
      final valorReteIva = totalImpuestosItems * (porcReteIva / 100);
      final valorReteIca = baseGravable * (porcReteIca / 100);
      final totalRetenciones = valorRetencion + valorReteIva + valorReteIca;

      // Total final DIAN
      double totalFinal = baseGravable + totalImpuestosItems - totalRetenciones;

        
        
        
        
        

      // Si el total es 0 pero hay items con subtotales, usar la suma directa de subtotales
      if (totalFinal <= 0 && itemsVerificados.isNotEmpty) {
        final sumaDirectaSubtotales = itemsVerificados.fold<double>(
          0,
          (sum, item) => sum + item.subtotal,
        );
        if (sumaDirectaSubtotales > 0) {
          totalFinal = sumaDirectaSubtotales;
        }
      }

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
        estado: _pagadoDesdeCaja ? 'PENDIENTE' : 'PROCESADA',
        pagadoDesdeCaja: _pagadoDesdeCaja,
        items: itemsVerificados,
        // Guardar el origen de la compra si no paga desde caja
        descripcion: !_pagadoDesdeCaja
            ? 'Origen: ${_origenCompraController.text.isNotEmpty ? _origenCompraController.text : 'No especificado'}'
            : _descripcionController.text.isNotEmpty
            ? _descripcionController.text
            : null,
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

        
      final facturaCreada = await _facturaCompraService.crearFacturaCompra(
        factura,
      );
        

      // ✅ NO actualizar stock desde el frontend - el backend ya actualiza el stock
      // automáticamente al crear la factura. Hacerlo aquí también causaba duplicación (+2 en vez de +1).
      // Los items enviados ya incluyen 'destino', 'cantidadAlmacen' y 'cantidadBodega'
      // para que el backend sepa dónde poner el stock.

      // � Refrescar cache de productos para actualizar UI automáticamente
      try {
        final cacheProvider = Provider.of<DatosCacheProvider>(
          context,
          listen: false,
        );
        await cacheProvider.forceRefreshProductos();
        print('✅ Cache de productos actualizado después de la compra');
      } catch (e) {
        print('⚠️ Error refrescando cache (no crítico): $e');
      }

      // �💰 Actualizar el costo del producto con el último precio de compra
      await _actualizarCostoProductos(facturaCreada);

      // Verificar si la factura creada tiene el total correcto
      if (facturaCreada.total <= 0 && total > 0) {
          
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
        } catch (e) {
            
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Factura creada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Pequeño delay para asegurar que el backend procesó la factura
      await Future.delayed(Duration(milliseconds: 500));

      // Navegar a la lista de compras
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/compras');
      }
    } catch (e) {
        
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear factura: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _guardandoFactura = false;
        });
      }
    }
  }

  // 📦 Registrar movimientos de inventario cuando se crea una factura de compra
  Future<void> _registrarMovimientosInventarioCompra(
    FacturaCompra factura, {
    List<ItemFacturaCompra>? itemsOriginales,
  }) async {
    try {
      // ✅ Usar items originales (con destino correcto del usuario) si están disponibles
      // El backend NO persiste el campo 'destino', así que la respuesta siempre tiene
      // destino='ALMACÉN' por defecto, ignorando lo que el usuario seleccionó.
      final itemsParaProcesar = itemsOriginales ?? factura.items;
      for (var item in itemsParaProcesar) {
        try {
          // 🔍 Obtener el producto completo para actualizar stock
          final productoCompleto = await _productoService.getProducto(
            item.ingredienteId,
          );

          if (productoCompleto == null) {
            print('⚠️ Producto no encontrado: ${item.ingredienteId}');
            continue; // Saltar si no encuentra el producto
          }

          // 🔍 LOG: Ver producto obtenido del backend
          print('📥 Producto obtenido: ${productoCompleto.nombre}');
          print('   - ID: ${productoCompleto.id}');
          print('   - Almacén actual: ${productoCompleto.almacen}');
          print('   - Bodega actual: ${productoCompleto.bodega}');
          print('   - Destino item: ${item.destino}');
          print('   - cantidadAlmacen item: ${item.cantidadAlmacen}');
          print('   - cantidadBodega item: ${item.cantidadBodega}');

          // 📍 Determinar el destino de la compra
          final destino = item.destino;

          // 📊 Obtener stock anterior y calcular nuevo stock
          double stockAnterior = 0;
          double nuevoStock = 0;
          
          // ✅ Obtener valores actuales de AMBAS ubicaciones (convertir null a 0)
          double almacenActual = (productoCompleto.almacen ?? 0).toDouble();
          double bodegaActual = (productoCompleto.bodega ?? 0).toDouble();

          if (destino.toUpperCase() == 'BODEGA') {
            // Sumar a BODEGA
            stockAnterior = bodegaActual;
            nuevoStock = stockAnterior + item.cantidad;
            bodegaActual = nuevoStock; // Actualizar bodega solamente
          } else if (destino.toUpperCase() == 'PARTE Y PARTE') {
            // 📦 Usar cantidades específicas para ALMACÉN y BODEGA
            final cantidadParaAlmacen = item.cantidadAlmacen > 0 
                ? item.cantidadAlmacen 
                : item.cantidad / 2; // Fallback a mitad si no hay valor
            final cantidadParaBodega = item.cantidadBodega > 0 
                ? item.cantidadBodega 
                : item.cantidad / 2; // Fallback a mitad si no hay valor
            
            final almacenAnterior = almacenActual;
            final bodegaAnterior = bodegaActual;
            
            // Actualizar ambos con las cantidades especificadas
            almacenActual = almacenAnterior + cantidadParaAlmacen;
            bodegaActual = bodegaAnterior + cantidadParaBodega;
            
            print('📦 PARTE Y PARTE: ${item.ingredienteNombre} - Almacén: +$cantidadParaAlmacen, Bodega: +$cantidadParaBodega');

            // Crear movimiento con información de PARTE Y PARTE
            final movimiento = MovimientoInventario(
              inventarioId: item.ingredienteId,
              productoId: item.ingredienteId,
              productoNombre: item.ingredienteNombre,
              tipoMovimiento: 'Entrada',
              motivo: 'Compra - Factura ${factura.numeroFactura} (PARTE Y PARTE)',
              cantidadAnterior: almacenAnterior + bodegaAnterior,
              cantidadMovimiento: item.cantidad,
              cantidadNueva: almacenActual + bodegaActual,
              responsable: 'Sistema',
              referencia: 'FC-${factura.numeroFactura}',
              observaciones: 'Compra a ${factura.proveedorNombre} - Almacén: +${cantidadParaAlmacen.toStringAsFixed(0)}, Bodega: +${cantidadParaBodega.toStringAsFixed(0)}',
              costoUnitario: item.precioUnitario,
              precioTotal: item.subtotal,
              fecha: DateTime.now(),
              facturaNo: factura.numeroFactura,
              proveedor: factura.proveedorNombre,
            );

            // 📝 Registrar movimiento - el backend YA actualiza stock al procesar el movimiento
            // ⚠️ NO llamar updateProducto si el movimiento fue exitoso para evitar duplicar stock
            bool movimientoParteExitoso = false;
            try {
              await _inventarioService.registrarMovimiento(movimiento);
              movimientoParteExitoso = true;
              print(
                '📝 Movimiento (PARTE Y PARTE) registrado: ${item.ingredienteNombre} - Stock actualizado por backend',
              );
            } catch (movError) {
              print(
                '⚠️ Error registrando movimiento PARTE Y PARTE: $movError - Se actualizará stock manualmente',
              );
            }

            // 🔄 Solo actualizar producto MANUALMENTE si el movimiento falló (fallback)
            if (!movimientoParteExitoso) {
              final productoActualizado = productoCompleto.copyWith(
                almacen: almacenActual.toInt(),
                bodega: bodegaActual.toInt(),
              );

              try {
                await _productoService.updateProducto(productoActualizado);
                print(
                  '✅ Stock actualizado manualmente (PARTE Y PARTE): ${productoActualizado.nombre} - ALM: ${almacenAnterior.toInt()} → ${almacenActual.toInt()}, BOD: ${bodegaAnterior.toInt()} → ${bodegaActual.toInt()}',
                );
              } catch (updateError) {
                print(
                  '❌ ERROR CRÍTICO actualizando (PARTE Y PARTE): $updateError - Producto: ${productoActualizado.nombre}',
                );
                rethrow;
              }
            }
            continue;
          } else {
            // Por defecto ALMACÉN
            stockAnterior = almacenActual;
            nuevoStock = stockAnterior + item.cantidad;
            almacenActual = nuevoStock; // Actualizar almacén solamente
          }

          // 📋 Crear movimiento de inventario
          final movimiento = MovimientoInventario(
            inventarioId: item.ingredienteId,
            productoId: item.ingredienteId,
            productoNombre: item.ingredienteNombre,
            tipoMovimiento: 'Entrada',
            motivo: 'Compra - Factura ${factura.numeroFactura} (${destino})',
            cantidadAnterior: stockAnterior,
            cantidadMovimiento: item.cantidad,
            cantidadNueva: nuevoStock,
            responsable: 'Sistema',
            referencia: 'FC-${factura.numeroFactura}',
            observaciones: 'Compra a ${factura.proveedorNombre} en ${destino}',
            costoUnitario: item.precioUnitario,
            precioTotal: item.subtotal,
            fecha: DateTime.now(),
            facturaNo: factura.numeroFactura,
            proveedor: factura.proveedorNombre,
          );

          // 📝 Registrar movimiento - el backend YA actualiza stock al procesar el movimiento
          // ⚠️ NO llamar updateProducto si el movimiento fue exitoso para evitar duplicar stock (+2 en vez de +1)
          bool movimientoExitoso = false;
          try {
            await _inventarioService.registrarMovimiento(movimiento);
            movimientoExitoso = true;
            print(
              '📝 Movimiento registrado: ${item.ingredienteNombre} - ${destino}: ${stockAnterior.toInt()} → ${nuevoStock.toInt()} (stock actualizado por backend)',
            );
          } catch (movError) {
            print(
              '⚠️ Error registrando movimiento: $movError - Se actualizará stock manualmente',
            );
          }

          // 🔄 Solo actualizar producto MANUALMENTE si el movimiento falló (fallback)
          if (!movimientoExitoso) {
            final productoActualizado = productoCompleto.copyWith(
              almacen: almacenActual.toInt(),
              bodega: bodegaActual.toInt(),
            );

            print(
              '📤 Fallback - Enviando actualización compra: ${productoActualizado.nombre} - Almacén: ${almacenActual.toInt()}, Bodega: ${bodegaActual.toInt()}',
            );

            try {
              await _productoService.updateProducto(productoActualizado);
              print(
                '✅ Stock actualizado manualmente: ${productoActualizado.nombre} - ${destino}: ${stockAnterior.toInt()} → ${nuevoStock.toInt()}',
              );
            } catch (updateError) {
              print(
                '❌ ERROR CRÍTICO actualizando producto: $updateError - Producto: ${productoActualizado.nombre}',
              );
              rethrow;
            }
          }
        } catch (e) {
          // Continuar con el siguiente item aunque haya error
          print('⚠️ Error registrando movimiento para ${item.ingredienteId}: $e');
        }
      }
    } catch (e) {
      // No lanzar excepción para no interrumpir el flujo de la factura
      print('⚠️ Error general en registro de movimientos: $e');
    }
  }

  // 💰 Actualizar el costo de los productos con el último precio de compra
  Future<void> _actualizarCostoProductos(FacturaCompra factura) async {
    try {
      for (var item in factura.items) {
        try {
          // Buscar el producto en la lista de productos disponibles
          Producto? producto;
          try {
            producto = _productos.firstWhere((p) => p.id == item.ingredienteId);
          } catch (e) {
            producto = null;
          }

          // Log del valor que se va a enviar
          print(
            '[ACTUALIZAR COSTO] Producto: "+item.ingredienteNombre+" (ID: ' +
                item.ingredienteId +
                ") - Costo a enviar: " +
                item.precioUnitario.toString(),
          );

          if (producto != null) {
            // Validar que el costo sea mayor a 0 antes de actualizar
            if (item.precioUnitario > 0) {
              await _productoService.actualizarCostoProducto(
                item.ingredienteId,
                item.precioUnitario,
                precioActual: producto.precio,
              );
            } else {
              print(
                '[ACTUALIZAR COSTO] ❌ No se actualiza porque el costo es <= 0',
              );
            }
          }
        } catch (e) {
          // Continuar con el siguiente item aunque haya error
        }
      }
    } catch (e) {
      // No lanzar excepción para no interrumpir el flujo de la factura
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
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
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
                Text(
                  'Estado:',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
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
                Text(
                  'Pagado desde caja:',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
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

  // Añadir método para formatear fecha con hora (formato 12h con AM/PM)
  String _formatearFechaConHora(DateTime fecha) {
    final hour24 = fecha.hour;
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final period = hour24 >= 12 ? 'PM' : 'AM';
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')} ${hour12.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')} $period';
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
                              style: TextStyle(color: AppTheme.textPrimary),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Cantidad',
                                labelStyle: TextStyle(
                                  color: AppTheme.textSecondary,
                                ),
                                suffixText: 'unidades',
                                suffixStyle: TextStyle(
                                  color: AppTheme.textSecondary,
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
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                    ),
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: '% IVA',
                                      labelStyle: TextStyle(
                                        color: AppTheme.textSecondary,
                                      ),
                                      suffixText: '%',
                                      suffixStyle: TextStyle(
                                        color: AppTheme.textSecondary,
                                      ),
                                      helperText: '0%, 5%, 19%',
                                      helperStyle: TextStyle(
                                        color: AppTheme.textSecondary,
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
                                      color: AppTheme.textPrimary,
                                    ),
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: '% Descuento',
                                      labelStyle: TextStyle(
                                        color: AppTheme.textSecondary,
                                      ),
                                      suffixText: '%',
                                      suffixStyle: TextStyle(
                                        color: AppTheme.textSecondary,
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
                                    color: AppTheme.textSecondary.withOpacity(
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

