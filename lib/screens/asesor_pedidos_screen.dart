import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/pedido_asesor.dart';
import '../models/item_pedido.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../models/cliente.dart';
import '../services/pedido_asesor_service.dart';
import '../services/producto_service.dart';
import '../services/cliente_service.dart';
import '../services/traslado_service.dart';
import '../providers/user_provider.dart';
import '../providers/datos_cache_provider.dart';
import '../theme/app_theme.dart';
import '../utils/busqueda_productos_utils.dart';
import '../utils/logger.dart';
import '../utils/datetime_utils.dart';

class AsesorPedidosScreen extends StatefulWidget {
  const AsesorPedidosScreen({super.key});

  @override
  _AsesorPedidosScreenState createState() => _AsesorPedidosScreenState();
}

class _AsesorPedidosScreenState extends State<AsesorPedidosScreen>
    with SingleTickerProviderStateMixin {
  final PedidoAsesorService _pedidoService = PedidoAsesorService();
  final ProductoService _productoService = ProductoService();
  final ClienteService _clienteService = ClienteService();
  final TrasladoService _trasladoService = TrasladoService();
  
  // Controladores
  final TextEditingController _clienteController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _observacionesController =
      TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _codigoBarrasController = TextEditingController();
  final TextEditingController _cantidadController = TextEditingController(
    text: '1',
  );

  // Variables de estado
  List<ItemPedido> _carrito = [];
  List<Producto> _productos = [];
  List<Producto> _productosFiltrados = [];
  List<Categoria> _categorias = [];
  List<Cliente> _clientes = [];
  String? _categoriaSeleccionada;
  Producto? _productoSeleccionado;
  Cliente? _clienteSeleccionado;
  bool _isLoading = false;

  // Controladores de precio editable (solo items de "mano de obra")
  final Map<String, TextEditingController> _precioCtrls = {};
  
  // Totales
  double _subtotal = 0;
  double _total = 0;

  // Tabs y lista de pedidos del asesor
  late TabController _tabController;
  List<PedidoAsesor> _misPedidos = [];
  bool _isLoadingPedidos = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarDatos();
    _cargarMisPedidos();
    _searchController.addListener(_filtrarProductos);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _clienteController.dispose();
    _telefonoController.dispose();
    _observacionesController.dispose();
    _searchController.dispose();
    _codigoBarrasController.dispose();
    _cantidadController.dispose();
    for (final ctrl in _precioCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      // Cargar productos
      final cacheProvider = Provider.of<DatosCacheProvider>(
        context,
        listen: false,
      );
      List<Producto> productos = cacheProvider.productos ?? [];

      if (productos.isEmpty) {
        productos = await _productoService.getProductos();
      }

      // Cargar categorías
      List<Categoria> categorias = [];
      try {
        categorias = await _productoService.getCategorias();
      } catch (e) {
          
      }

      // Cargar clientes
      List<Cliente> clientes = [];
      try {
        clientes = await _clienteService.obtenerClientes();
      } catch (e) {
          
      }

      if (!mounted) return;
      setState(() {
        _productos = productos;
        _productosFiltrados = productos;
        _categorias = categorias;
        _clientes = clientes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _mostrarError('Error al cargar datos: $e');
    }
  }

  Future<void> _cargarMisPedidos() async {
    if (!mounted) return;
    setState(() => _isLoadingPedidos = true);
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final pedidos = await _pedidoService.listarPedidos(
        asesorId: userProvider.userId,
      );
      if (!mounted) return;
      setState(() {
        _misPedidos = pedidos;
        _isLoadingPedidos = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingPedidos = false);
    }
  }

  void _filtrarProductos() {
    final busqueda = _searchController.text.toLowerCase();
    setState(() {
      _productosFiltrados = _productos.where((producto) {
        final coincideBusqueda =
            busquedaInteligente(producto, busqueda);
        
        final coincideCategoria =
            _categoriaSeleccionada == null ||
            producto.categoria?.id == _categoriaSeleccionada;

        return coincideBusqueda && coincideCategoria;
      }).toList();
    });
  }

  void _buscarProductoPorCodigo(String codigo) {
    if (codigo.isEmpty) return;

    final producto = _productos.firstWhere(
      (p) =>
          p.codigo?.toLowerCase() == codigo.toLowerCase() ||
          p.codigoBarras?.toLowerCase() == codigo.toLowerCase(),
      orElse: () =>
          Producto(id: '', nombre: '', precio: 0, costo: 0, utilidad: 0),
    );

    if (producto.id.isNotEmpty) {
      _agregarAlCarrito(producto);
      _codigoBarrasController.clear();
    } else {
      _mostrarError('Producto no encontrado');
    }
  }

  void _seleccionarProducto(Producto producto) {
    setState(() {
      _productoSeleccionado = producto;
      _cantidadController.text = '1';
    });
  }

  void _agregarAlCarrito(Producto producto) async {
    final cantidad = int.tryParse(_cantidadController.text) ?? 1;
    
    // � DEBUG: Ver valores de stock del producto
    appLog('🔍 DEBUG agregar al carrito:');
    appLog('   - Producto: ${producto.nombre}');
    appLog('   - Bodega: ${producto.bodega}');
    appLog('   - Almacén: ${producto.almacen}');
    appLog('   - TipoItem: ${producto.productoOServicio}');

    // 🛠️ MANO DE OBRA: no maneja stock real, se salta la validación de stock
    // y el diálogo de bodega/almacén; en su lugar se pide el precio a cobrar.
    if (_esManoDeObra(producto)) {
      final precioIngresado = await _mostrarDialogoPrecioManoDeObra(producto);
      if (precioIngresado == null) return; // Usuario canceló

      setState(() {
        _carrito.add(
          ItemPedido(
            productoId: producto.id,
            productoNombre: producto.nombre,
            cantidad: cantidad,
            precioUnitario: precioIngresado,
            origen: 'ALMACÉN',
          ),
        );
        _calcularTotales();
        _productoSeleccionado = null;
        _cantidadController.text = '1';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${producto.nombre} agregado (\$${precioIngresado.toStringAsFixed(0)})',
          ),
          backgroundColor: AppTheme.success,
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    // ⚠️ VALIDACIÓN DE STOCK: No aplicar a servicios
    final esServicio = producto.productoOServicio?.toLowerCase() == 'servicio';

    if (!esServicio) {
      final stockAlmacen = producto.almacen ?? 0;
      final stockBodega = producto.bodega ?? 0;
      final stockTotal = stockAlmacen + stockBodega;

      // Validación 1: Si no hay stock en ninguna ubicación, NO PERMITIR agregar
      if (stockTotal <= 0) {
        appLog('   ❌ BLOQUEADO: No hay stock en ninguna ubicación');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ No hay stock disponible para "${producto.nombre}"\n'
              'Stock en ALMACÉN: $stockAlmacen\n'
              'Stock en BODEGA: $stockBodega\n\n'
              'Selecciona otro producto.',
            ),
            backgroundColor: Colors.red.shade700,
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      // Validación 2: Si la cantidad solicitada es mayor al stock total, NO PERMITIR
      if (cantidad > stockTotal) {
        appLog(
          '   ❌ BLOQUEADO: Cantidad solicitada ($cantidad) > stock total ($stockTotal)',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Stock insuficiente para "${producto.nombre}"\n'
              'Stock total disponible: $stockTotal\n'
              'Cantidad solicitada: $cantidad\n\n'
              'Reduce la cantidad o selecciona otro producto.',
            ),
            backgroundColor: Colors.red.shade700,
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      appLog('   ✅ Validación pasada: Stock suficiente');
    } else {
      appLog('   ℹ️  Es servicio - sin validación de stock');
    }
    
    // 📦 Mostrar diálogo para elegir de dónde descontar
    final origen = await _mostrarDialogoSeleccionarOrigen(
      context,
      producto,
      cantidad,
    );
    
    appLog('   - Origen seleccionado: $origen');

    if (origen == null) return; // Usuario canceló
    
    setState(() {
      final index = _carrito.indexWhere(
        (item) => item.productoId == producto.id && item.origen == origen,
      );

      if (index >= 0) {
        // Ya existe un item con el mismo producto y origen, incrementar cantidad
        _carrito[index] = ItemPedido(
          productoId: _carrito[index].productoId,
          productoNombre: _carrito[index].productoNombre ?? 'Producto',
          cantidad: _carrito[index].cantidad + cantidad,
          precioUnitario: _carrito[index].precioUnitario,
          origen: origen,
        );
      } else {
        // Agregar nuevo item con el origen especificado
        _carrito.add(
          ItemPedido(
            productoId: producto.id,
            productoNombre: producto.nombre,
            cantidad: cantidad,
            precioUnitario: producto.precio,
            origen: origen,
          ),
        );
      }

      _calcularTotales();
      _productoSeleccionado = null;
      _cantidadController.text = '1';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${producto.nombre} agregado desde $origen'),
        backgroundColor: AppTheme.success,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _actualizarCantidad(int index, int nuevaCantidad) {
    if (nuevaCantidad <= 0) {
      _eliminarDelCarrito(index);
      return;
    }

    final item = _carrito[index];
    
    // 🔍 Buscar el producto en la lista para validar stock
    final producto = _productos.firstWhere(
      (p) => p.id == item.productoId,
      orElse: () => _productos.first, // Fallback
    );

    // ✅ VALIDACIÓN: No aplicar a servicios ni a "Mano de obra" (sin stock real)
    final tipoProducto = producto.productoOServicio?.trim().toLowerCase();
    final esServicio = tipoProducto == 'servicio' || _esManoDeObra(producto);

    if (!esServicio) {
      // 📦 Validar stock del origen seleccionado
      final stockAlmacen = producto.almacen ?? 0;
      final stockBodega = producto.bodega ?? 0;
      final origen = item.origen.toUpperCase();

      int stockDisponible = 0;
      if (origen == 'BODEGA') {
        stockDisponible = stockBodega;
      } else {
        stockDisponible = stockAlmacen;
      }

      // ⚠️ VALIDACIÓN: No permitir superar el stock disponible
      if (nuevaCantidad > stockDisponible) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Stock insuficiente en $origen\n'
              'Disponible: $stockDisponible\n'
              'Solicitado: $nuevaCantidad',
            ),
            backgroundColor: Colors.red.shade700,
            duration: Duration(seconds: 3),
          ),
        );
        return; // No actualizar la cantidad
      }
    }

    setState(() {
      _carrito[index] = ItemPedido(
        productoId: item.productoId,
        productoNombre: item.productoNombre ?? 'Producto',
        cantidad: nuevaCantidad,
        precioUnitario: item.precioUnitario,
        origen: item.origen, // ✅ Preservar el origen seleccionado
      );
      _calcularTotales();
    });
  }

  void _eliminarDelCarrito(int index) {
    final item = _carrito[index];
    _precioCtrls.remove('${item.productoId}_${item.origen}')?.dispose();
    setState(() {
      _carrito.removeAt(index);
      _calcularTotales();
    });
  }

  // 🔍 Busca el producto original de un item del carrito (por id)
  Producto? _buscarProducto(String? productoId) {
    if (productoId == null) return null;
    for (final p in _productos) {
      if (p.id == productoId) return p;
    }
    return null;
  }

  // 🛠️ Solo los productos cuyo NOMBRE es "Mano de obra" permiten elegir/editar
  // el precio unitario manualmente (cada cobro de mano de obra puede variar)
  // y no manejan stock real, así que se saltan la validación/selección de
  // bodega o almacén.
  bool _esManoDeObra(Producto? producto) {
    final nombre = producto?.nombre.toUpperCase() ?? '';
    return nombre.contains('MANO') && nombre.contains('OBRA');
  }

  TextEditingController _ctrlPrecio(ItemPedido item) {
    final key = '${item.productoId}_${item.origen}';
    return _precioCtrls.putIfAbsent(
      key,
      () => TextEditingController(text: item.precioUnitario.toStringAsFixed(0)),
    );
  }

  void _actualizarPrecioItem(int index, String texto) {
    final nuevoPrecio = double.tryParse(texto.replaceAll(',', '.'));
    if (nuevoPrecio == null || nuevoPrecio < 0) return;
    final item = _carrito[index];
    setState(() {
      _carrito[index] = ItemPedido(
        productoId: item.productoId,
        productoNombre: item.productoNombre,
        cantidad: item.cantidad,
        precioUnitario: nuevoPrecio,
        notas: item.notas,
        porcentajeImpuesto: item.porcentajeImpuesto,
        valorImpuesto: item.valorImpuesto,
        porcentajeDescuento: item.porcentajeDescuento,
        valorDescuento: item.valorDescuento,
        origen: item.origen,
        trasladoId: item.trasladoId,
      );
      _calcularTotales();
    });
  }

  void _calcularTotales() {
    double subtotal = 0;
    for (var item in _carrito) {
      subtotal += item.subtotal;
    }
    setState(() {
      _subtotal = subtotal;
      _total = subtotal;
    });
  }

  Future<void> _guardarPedido() async {
    // Evitar doble click
    if (_isLoading) return;

    if (_clienteSeleccionado == null) {
      _mostrarError('Por favor selecciona un cliente');
      return;
    }

    if (_carrito.isEmpty) {
      _mostrarError('El carrito está vacío');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // Crear traslado para los items que vienen de BODEGA
      List<ItemPedido> carritoFinal = List.from(_carrito);
      appLog('🔍 [Traslado] Total items en carrito: ${_carrito.length}');
      for (final item in _carrito) {
        appLog('🔍 [Traslado]   - ${item.productoNombre} | origen="${item.origen}" | id=${item.productoId}');
      }
      final bodegaItems = _carrito.where((item) => item.origen == 'BODEGA').toList();
      appLog('🔍 [Traslado] Items de BODEGA encontrados: ${bodegaItems.length}');

      if (bodegaItems.isNotEmpty) {
        appLog('🔍 [Traslado] Creando traslado con ${bodegaItems.length} item(s)...');
        try {
          final traslado = await _trasladoService.crearTraslado(
            items: bodegaItems
                .map((item) => {'productoId': item.productoId, 'cantidad': item.cantidad})
                .toList(),
            origen: 'BODEGA',
            destino: 'ALMACEN',
            asesor: userProvider.userName ?? 'Asesor',
            observaciones: 'Pedido asesor - cliente: ${_clienteSeleccionado!.razonSocial ?? '${_clienteSeleccionado!.nombres ?? ''} ${_clienteSeleccionado!.apellidos ?? ''}'.trim()}',
          );
          appLog('✅ [Traslado] Creado con id: ${traslado.id}');
          final trasladoId = traslado.id;
          if (trasladoId != null) {
            carritoFinal = _carrito.map((item) {
              if (item.origen == 'BODEGA') {
                return ItemPedido(
                  productoId: item.productoId,
                  productoNombre: item.productoNombre,
                  cantidad: item.cantidad,
                  precioUnitario: item.precioUnitario,
                  notas: item.notas,
                  origen: item.origen,
                  trasladoId: trasladoId,
                );
              }
              return item;
            }).toList();
          }
        } catch (e) {
          appLog('❌ [Traslado] Error al crear traslado: $e');
          _mostrarError('Error al registrar traslado de bodega: $e');
          setState(() => _isLoading = false);
          return;
        }
      } else {
        appLog('ℹ️ [Traslado] Sin items de BODEGA → no se crea traslado');
      }

      final pedido = PedidoAsesor(
        clienteNombre:
            _clienteSeleccionado!.razonSocial ??
            '${_clienteSeleccionado!.nombres ?? ''} ${_clienteSeleccionado!.apellidos ?? ''}'
                .trim(),
        clienteId: _clienteSeleccionado!.id,
        asesorNombre: userProvider.userName ?? 'Asesor',
        asesorId: userProvider.userId,
        items: carritoFinal,
        subtotal: _subtotal,
        impuestos: 0,
        total: _total,
        fechaCreacion: DateTimeUtils.nowColombia(),
        observaciones: _observacionesController.text.trim().isEmpty
            ? (_telefonoController.text.trim().isNotEmpty
                  ? 'Tel: ${_telefonoController.text.trim()}'
                  : null)
            : '${_observacionesController.text.trim()}${_telefonoController.text.trim().isNotEmpty ? ' | Tel: ${_telefonoController.text.trim()}' : ''}',
      );

      await _pedidoService.crearPedido(pedido);

      _mostrarExito('Pedido creado exitosamente');
      _limpiarFormulario();
    } catch (e) {
      _mostrarError('Error al guardar pedido: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _limpiarFormulario() {
    setState(() {
      _carrito.clear();
      _clienteController.clear();
      _clienteSeleccionado = null;
      _telefonoController.clear();
      _observacionesController.clear();
      _productoSeleccionado = null;
      _cantidadController.text = '1';
      _calcularTotales();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          tooltip: 'Volver al dashboard',
          onPressed: () => context.go('/dashboard'),
        ),
        title: Row(
          children: [
            Icon(Icons.shopping_cart, color: Theme.of(context).colorScheme.onSurface),
            SizedBox(width: 12),
            Text(
              'Pedidos',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        automaticallyImplyLeading: true,
        actions: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                userProvider.userName ?? 'Asesor',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 14),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Theme.of(context).colorScheme.onSurface),
            tooltip: 'Cerrar sesión',
            onPressed: () => _cerrarSesion(context, userProvider),
          ),
          SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(icon: Icon(Icons.add_shopping_cart, size: 18), text: 'Nuevo Pedido'),
            Tab(icon: Icon(Icons.list_alt, size: 18), text: 'Mis Pedidos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildNuevoPedidoTab(),
          _buildMisPedidosTab(),
        ],
      ),
    );
  }

  Widget _buildNuevoPedidoTab() {
    return _isLoading && _productos.isEmpty
        ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
        : LayoutBuilder(
            builder: (context, constraints) {
              final isLargeScreen = constraints.maxWidth > 800;
              if (isLargeScreen) {
                return Row(
                  children: [
                    Expanded(flex: 3, child: _buildProductosPanel()),
                    Container(
                      width: 400,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: Border(
                          left: BorderSide(color: AppTheme.primary.withOpacity(0.3), width: 2),
                        ),
                      ),
                      child: _buildCarritoPanel(),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    Expanded(child: _buildProductosPanel()),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: Border(top: BorderSide(color: AppTheme.primary.withOpacity(0.3), width: 2)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _mostrarCarritoModal(context),
                              icon: const Icon(Icons.shopping_cart, color: Colors.white),
                              label: Text(
                                'Ver Pedido (${_carrito.length}) - \$${_total.toStringAsFixed(0)}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }
            },
          );
  }

  Widget _buildMisPedidosTab() {
    if (_isLoadingPedidos) {
      return Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_misPedidos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('No tienes pedidos registrados',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 16)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _cargarMisPedidos,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _cargarMisPedidos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _misPedidos.length,
        itemBuilder: (context, index) => _buildPedidoCard(_misPedidos[index]),
      ),
    );
  }

  Widget _buildPedidoCard(PedidoAsesor pedido) {
    final estado = pedido.estado;
    final puedeAgregar = estado != 'FACTURADO' && estado != 'CANCELADO';
    final colorEstado = estado == 'FACTURADO'
        ? AppTheme.success
        : estado == 'CANCELADO'
            ? AppTheme.error
            : AppTheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.primary.withOpacity(0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    pedido.clienteNombre,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colorEstado.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(estado, style: TextStyle(fontSize: 11, color: colorEstado, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${pedido.items.length} producto(s) · ${_formatFecha(pedido.fechaCreacion)}',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
            ),
            if (pedido.observaciones != null && pedido.observaciones!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  pedido.observaciones!,
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '\$${pedido.total.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
                if (puedeAgregar)
                  ElevatedButton.icon(
                    onPressed: () => _mostrarAgregarProductosPedido(pedido),
                    icon: const Icon(Icons.add, size: 16, color: Colors.white),
                    label: const Text('Agregar productos', style: TextStyle(color: Colors.white, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatFecha(DateTime? fecha) {
    if (fecha == null) return '-';
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _mostrarAgregarProductosPedido(PedidoAsesor pedido) async {
    List<ItemPedido> nuevosItems = [];
    final searchCtrl = TextEditingController();
    List<Producto> productosFiltrados = List.from(_productos);
    bool guardando = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void filtrar(String q) {
            setSheet(() {
              productosFiltrados = _productos.where((p) => busquedaInteligente(p, q.toLowerCase())).toList();
            });
          }

          Future<void> agregarProducto(Producto producto) async {
            final origen = await _mostrarDialogoSeleccionarOrigen(ctx, producto, 1);
            if (origen == null) return;
            setSheet(() {
              final idx = nuevosItems.indexWhere((i) => i.productoId == producto.id && i.origen == origen);
              if (idx >= 0) {
                nuevosItems[idx] = ItemPedido(
                  productoId: nuevosItems[idx].productoId,
                  productoNombre: nuevosItems[idx].productoNombre,
                  cantidad: nuevosItems[idx].cantidad + 1,
                  precioUnitario: nuevosItems[idx].precioUnitario,
                  origen: origen,
                );
              } else {
                nuevosItems.add(ItemPedido(
                  productoId: producto.id,
                  productoNombre: producto.nombre,
                  cantidad: 1,
                  precioUnitario: producto.precio,
                  origen: origen,
                ));
              }
            });
          }

          Future<void> guardar() async {
            if (nuevosItems.isEmpty || pedido.id == null) return;
            setSheet(() => guardando = true);

            // Gestionar traslados de bodega en los nuevos items
            List<ItemPedido> nuevosFinales = List.from(nuevosItems);
            final bodegaItems = nuevosItems.where((i) => i.origen == 'BODEGA').toList();
            if (bodegaItems.isNotEmpty) {
              try {
                final userProvider = Provider.of<UserProvider>(context, listen: false);
                final traslado = await _trasladoService.crearTraslado(
                  items: bodegaItems.map((i) => {'productoId': i.productoId, 'cantidad': i.cantidad}).toList(),
                  origen: 'BODEGA',
                  destino: 'ALMACEN',
                  asesor: userProvider.userName ?? 'Asesor',
                  observaciones: 'Adición a pedido - cliente: ${pedido.clienteNombre}',
                );
                final trasladoId = traslado.id;
                if (trasladoId != null) {
                  nuevosFinales = nuevosItems.map((i) {
                    if (i.origen == 'BODEGA') {
                      return ItemPedido(
                        productoId: i.productoId,
                        productoNombre: i.productoNombre,
                        cantidad: i.cantidad,
                        precioUnitario: i.precioUnitario,
                        origen: i.origen,
                        trasladoId: trasladoId,
                      );
                    }
                    return i;
                  }).toList();
                }
              } catch (e) {
                setSheet(() => guardando = false);
                _mostrarError('Error al registrar traslado: $e');
                return;
              }
            }

            final todosItems = [...pedido.items, ...nuevosFinales];
            final nuevoTotal = todosItems.fold<double>(0, (sum, i) => sum + i.subtotal);
            final pedidoActualizado = PedidoAsesor(
              clienteNombre: pedido.clienteNombre,
              clienteId: pedido.clienteId,
              asesorNombre: pedido.asesorNombre,
              asesorId: pedido.asesorId,
              items: todosItems,
              subtotal: nuevoTotal,
              impuestos: pedido.impuestos,
              total: nuevoTotal,
              fechaCreacion: pedido.fechaCreacion,
              observaciones: pedido.observaciones,
            );

            try {
              await _pedidoService.actualizarPedido(pedido.id!, pedidoActualizado);
              if (Navigator.canPop(sheetCtx)) Navigator.pop(sheetCtx);
              _cargarMisPedidos();
              _mostrarExito('Pedido actualizado con ${nuevosFinales.length} producto(s)');
            } catch (e) {
              setSheet(() => guardando = false);
              _mostrarError('Error al actualizar pedido: $e');
            }
          }

          final totalNuevos = nuevosItems.fold<double>(0, (s, i) => s + i.subtotal);

          return DraggableScrollableSheet(
            initialChildSize: 0.92,
            minChildSize: 0.5,
            maxChildSize: 0.97,
            builder: (_, scrollCtrl) => Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 4),
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.add_shopping_cart, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Agregar a pedido de ${pedido.clienteNombre}',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Theme.of(context).colorScheme.onSurface)),
                              Text('Pedido actual: ${pedido.items.length} producto(s) · \$${pedido.total.toStringAsFixed(0)}',
                                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: AppTheme.primary.withOpacity(0.2)),
                  // Buscador
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: searchCtrl,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Buscar producto...',
                        hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                        prefixIcon: Icon(Icons.search, color: AppTheme.primary),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.primary.withOpacity(0.3))),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: filtrar,
                    ),
                  ),
                  // Nuevos items seleccionados (si hay)
                  if (nuevosItems.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nuevos (${nuevosItems.length})', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primary)),
                          const SizedBox(height: 4),
                          ...nuevosItems.map((i) => Row(
                            children: [
                              Expanded(child: Text('${i.productoNombre} x${i.cantidad}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface))),
                              Text('\$${i.subtotal.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, color: AppTheme.primary)),
                              IconButton(
                                icon: Icon(Icons.remove_circle_outline, size: 16, color: AppTheme.error),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                onPressed: () => setSheet(() => nuevosItems.remove(i)),
                              ),
                            ],
                          )),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  // Grid de productos
                  Expanded(
                    child: productosFiltrados.isEmpty
                        ? Center(child: Text('Sin productos', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))))
                        : GridView.builder(
                            controller: scrollCtrl,
                            padding: const EdgeInsets.all(12),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: _getCrossAxisCount(context),
                              childAspectRatio: 0.65,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: productosFiltrados.length,
                            itemBuilder: (_, i) {
                              final p = productosFiltrados[i];
                              return InkWell(
                                onTap: () => agregarProducto(p),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.inventory_2, color: AppTheme.primary, size: 32),
                                      const SizedBox(height: 6),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                        child: Text(p.nombre, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                                      ),
                                      const SizedBox(height: 4),
                                      Text('\$${p.precio.toStringAsFixed(0)}', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                                      const SizedBox(height: 2),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          _stockBadge('B', p.bodega ?? 0),
                                          const SizedBox(width: 4),
                                          _stockBadge('A', p.almacen ?? 0),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  // Footer con botón guardar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -2))],
                    ),
                    child: Row(
                      children: [
                        if (nuevosItems.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Text('+\$${totalNuevos.toStringAsFixed(0)}',
                                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 16)),
                          ),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: (nuevosItems.isEmpty || guardando) ? null : guardar,
                            icon: guardando
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save, color: Colors.white, size: 18),
                            label: Text(
                              guardando ? 'Guardando...' : 'Guardar en pedido (${nuevosItems.length})',
                              style: const TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              disabledBackgroundColor: AppTheme.primary.withOpacity(0.4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    searchCtrl.dispose();
  }

  Widget _stockBadge(String label, int qty) {
    final ok = qty > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: (ok ? AppTheme.success : AppTheme.error).withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('$label:$qty', style: TextStyle(fontSize: 9, color: ok ? AppTheme.success : AppTheme.error, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildProductosPanel() {
    return Column(
      children: [
        // Barra de búsqueda y código de barras
        Container(
          padding: EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              // Código de barras
              Row(
                children: [
                  GestureDetector(
                    onTap: _abrirScannerCodigos,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.qr_code_scanner,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'CÓDIGO',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _codigoBarrasController,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Escanee o ingrese código de barras...',
                        hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: _buscarProductoPorCodigo,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              // Búsqueda por nombre y filtro por categoría
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Buscar producto...',
                        hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                        prefixIcon: Icon(Icons.search, color: AppTheme.primary),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _categoriaSeleccionada,
                      decoration: InputDecoration(
                        hintText: 'Categoría',
                        hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text(
                            'Todas',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          ),
                        ),
                        ..._categorias.map(
                          (cat) => DropdownMenuItem<String>(
                            value: cat.id,
                            child: Text(
                              cat.nombre,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _categoriaSeleccionada = value);
                        _filtrarProductos();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Grid de productos
        Expanded(
          child: _productosFiltrados.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No se encontraron productos',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _getCrossAxisCount(context),
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _productosFiltrados.length,
                  itemBuilder: (context, index) {
                    final producto = _productosFiltrados[index];
                    return _buildProductoCard(producto);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProductoCard(Producto producto) {
    final isSelected = _productoSeleccionado?.id == producto.id;
    
    return InkWell(
      onTap: () => _agregarAlCarrito(producto),
      onLongPress: () => _seleccionarProducto(producto),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withOpacity(0.2)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : AppTheme.primary.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Imagen o ícono
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  producto.imagenUrl != null && producto.imagenUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        producto.imagenUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.inventory_2,
                          color: AppTheme.primary,
                          size: 32,
                        ),
                      ),
                    )
                  : Icon(Icons.inventory_2, color: AppTheme.primary, size: 32),
            ),
            SizedBox(height: 8),
            // Nombre
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                producto.nombre,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(height: 4),
            // Código
            if (producto.codigo != null)
              Text(
                producto.codigo!,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 10),
              ),
            SizedBox(height: 4),
            // Precio
            Text(
              '\$${producto.precio.toStringAsFixed(0)}',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            // 📦 Stock por ubicación (Bodega y Almacén)
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Bodega
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (producto.bodega ?? 0) > 0
                        ? AppTheme.success.withOpacity(0.2)
                        : AppTheme.error.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'B: ${producto.bodega ?? 0}',
                    style: TextStyle(
                      color: (producto.bodega ?? 0) > 0
                          ? AppTheme.success
                          : AppTheme.error,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 4),
                // Almacén
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (producto.almacen ?? 0) > 0
                        ? AppTheme.success.withOpacity(0.2)
                        : AppTheme.error.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'A: ${producto.almacen ?? 0}',
                    style: TextStyle(
                      color: (producto.almacen ?? 0) > 0
                          ? AppTheme.success
                          : AppTheme.error,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
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

  Widget _buildCarritoPanel() {
    return Column(
      children: [
        // Encabezado del carrito
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            border: Border(
              bottom: BorderSide(color: AppTheme.primary.withOpacity(0.3)),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.shopping_basket, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Pedido',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_carrito.length} items',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Datos del cliente - compacto
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Datos del Cliente',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              SizedBox(height: 8),
              // Selector de cliente con botón para crear nuevo
              Row(
                children: [
                  Expanded(
                    child: Autocomplete<Cliente>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return _clientes.take(10);
                        }
                        return _clientes
                            .where((Cliente cliente) {
                              final nombre =
                                  (cliente.razonSocial ??
                                          '${cliente.nombres ?? ''} ${cliente.apellidos ?? ''}'
                                              .trim())
                                      .toLowerCase();
                              final documento = cliente.numeroIdentificacion
                                  .toLowerCase();
                              final query = textEditingValue.text.toLowerCase();
                              return nombre.contains(query) ||
                                  documento.contains(query);
                            })
                            .take(15);
                      },
                      displayStringForOption: (Cliente cliente) {
                        return cliente.razonSocial ??
                            '${cliente.nombres ?? ''} ${cliente.apellidos ?? ''}'
                                .trim();
                      },
                      onSelected: (Cliente cliente) {
                        setState(() {
                          _clienteSeleccionado = cliente;
                          _clienteController.text =
                              cliente.razonSocial ??
                              '${cliente.nombres ?? ''} ${cliente.apellidos ?? ''}'
                                  .trim();
                          _telefonoController.text = cliente.telefono ?? '';
                        });
                      },
                      fieldViewBuilder:
                          (
                            BuildContext context,
                            TextEditingController textEditingController,
                            FocusNode focusNode,
                            VoidCallback onFieldSubmitted,
                          ) {
                            if (_clienteSeleccionado != null &&
                                textEditingController.text.isEmpty) {
                              textEditingController.text =
                                  _clienteSeleccionado!.razonSocial ??
                                  '${_clienteSeleccionado!.nombres ?? ''} ${_clienteSeleccionado!.apellidos ?? ''}'
                                      .trim();
                            }
                            return TextField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Cliente *',
                                labelStyle: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                                prefixIcon: Icon(
                                  Icons.person,
                                  color: AppTheme.primary,
                                  size: 18,
                                ),
                                suffixIcon: Icon(
                                  Icons.arrow_drop_down,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surface,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                hintText: 'Buscar cliente...',
                                hintStyle: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                            );
                          },
                      optionsViewBuilder:
                          (
                            BuildContext context,
                            AutocompleteOnSelected<Cliente> onSelected,
                            Iterable<Cliente> options,
                          ) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4.0,
                                color: Theme.of(context).colorScheme.surface,
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
                                      final Cliente cliente = options.elementAt(
                                        index,
                                      );
                                      final nombre =
                                          cliente.razonSocial ??
                                          '${cliente.nombres ?? ''} ${cliente.apellidos ?? ''}'
                                              .trim();
                                      return InkWell(
                                        onTap: () => onSelected(cliente),
                                        child: Container(
                                          padding: EdgeInsets.all(12.0),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)
                                                    .withOpacity(0.2),
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                backgroundColor: AppTheme
                                                    .primary
                                                    .withOpacity(0.2),
                                                radius: 16,
                                                child: Text(
                                                  nombre.isNotEmpty
                                                      ? nombre[0].toUpperCase()
                                                      : '?',
                                                  style: TextStyle(
                                                    color: AppTheme.primary,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      nombre.isEmpty
                                                          ? cliente
                                                                .numeroIdentificacion
                                                          : nombre,
                                                      style: TextStyle(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurface,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        fontSize: 13,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    Text(
                                                      cliente
                                                          .numeroIdentificacion,
                                                      style: TextStyle(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurface
                                                            .withOpacity(0.7),
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
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
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      icon: Icon(
                        Icons.add_circle,
                        color: AppTheme.primary,
                        size: 28,
                      ),
                      padding: EdgeInsets.zero,
                      tooltip: 'Crear nuevo cliente',
                      onPressed: _mostrarDialogoNuevoCliente,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6),
              // Teléfono y observaciones en fila
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        controller: _telefonoController,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 13,
                        ),
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Teléfono (opcional)',
                          labelStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 11,
                          ),
                          prefixIcon: Icon(
                            Icons.phone,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            size: 16,
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 0,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6),
              SizedBox(
                height: 40,
                child: TextField(
                  controller: _observacionesController,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Observaciones (opcional)',
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 11,
                    ),
                    prefixIcon: Icon(
                      Icons.note,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      size: 16,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(color: AppTheme.primary.withOpacity(0.3), height: 1),
        // Lista de items - ahora tiene más espacio
        Expanded(
          child: _carrito.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 40,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Carrito vacío',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Toque un producto para agregarlo',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(8),
                  itemCount: _carrito.length,
                  itemBuilder: (context, index) {
                    final item = _carrito[index];
                    return _buildCarritoItem(item, index);
                  },
                ),
        ),
        // Totales
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(color: AppTheme.primary.withOpacity(0.3)),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Subtotal:',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                  ),
                  Text(
                    '\$${_subtotal.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Divider(color: AppTheme.primary.withOpacity(0.3)),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL:',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    '\$${_total.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Botones de acción
        Container(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _carrito.isEmpty ? null : _limpiarFormulario,
                  icon: Icon(Icons.clear),
                  label: Text('Limpiar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: BorderSide(color: AppTheme.error),
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isLoading || _carrito.isEmpty
                      ? null
                      : _guardarPedido,
                  icon: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(Icons.save, color: Colors.white),
                  label: Text(
                    _isLoading ? 'Guardando...' : 'Guardar Pedido',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    disabledBackgroundColor: AppTheme.primary.withOpacity(0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCarritoItem(ItemPedido item, int index) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          // Info del producto
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.productoNombre ?? 'Producto',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 4),
                    // 📦 Badge de origen
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: item.origen == 'BODEGA'
                            ? AppTheme.primary.withOpacity(0.2)
                            : AppTheme.success.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.origen == 'BODEGA' ? 'B' : 'A',
                        style: TextStyle(
                          color: item.origen == 'BODEGA'
                              ? AppTheme.primary
                              : AppTheme.success,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                _esManoDeObra(_buscarProducto(item.productoId))
                    ? SizedBox(
                        width: 90,
                        height: 32,
                        child: TextField(
                          controller: _ctrlPrecio(item),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            isDense: true,
                            prefixText: '\$ ',
                            suffixText: 'c/u',
                            contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onChanged: (v) => _actualizarPrecioItem(index, v),
                        ),
                      )
                    : Text(
                        '\$${item.precioUnitario.toStringAsFixed(0)} c/u',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 12),
                      ),
              ],
            ),
          ),
          // Controles de cantidad
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.remove, color: AppTheme.error, size: 18),
                  onPressed: () =>
                      _actualizarCantidad(index, item.cantidad - 1),
                  constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
                Container(
                  constraints: BoxConstraints(minWidth: 32),
                  alignment: Alignment.center,
                  child: Text(
                    '${item.cantidad}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add, color: AppTheme.primary, size: 18),
                  onPressed: () =>
                      _actualizarCantidad(index, item.cantidad + 1),
                  constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          // Subtotal
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${item.subtotal.toStringAsFixed(0)}',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: AppTheme.error,
                  size: 18,
                ),
                onPressed: () => _eliminarDelCarrito(index),
                constraints: BoxConstraints(minWidth: 24, minHeight: 24),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _abrirScannerCodigos() async {
    // ❌ No soportado en Web
    if (kIsWeb) {
      _mostrarError(
        '📱 El escáner de códigos de barras solo está disponible en dispositivos móviles (Android/iOS). '
        'Por favor ingresa el código manualmente o usa la app móvil.',
      );
      return;
    }

    // 📷 Solicitar permisos de cámara
    final status = await Permission.camera.request();

    if (!status.isGranted) {
      _mostrarError(
        'Se requiere permiso de cámara para escanear códigos de barras',
      );
      return;
    }

    if (!mounted) return;

    // 📱 Abrir pantalla de scanner
    final codigoEscaneado = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (context) => _ScannerScreen(),
        fullscreenDialog: true,
      ),
    );

    // ✅ Si se capturó un código, buscarlo
    if (codigoEscaneado != null && codigoEscaneado.isNotEmpty) {
      _codigoBarrasController.text = codigoEscaneado;
      _buscarProductoPorCodigo(codigoEscaneado);
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: AppTheme.error),
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: AppTheme.success),
    );
  }

  // 💲 Mostrar diálogo para ingresar el precio de un item de "Mano de obra"
  // (no maneja stock real, así que en vez de bodega/almacén se define el cobro)
  Future<double?> _mostrarDialogoPrecioManoDeObra(Producto producto) async {
    final precioCtrl = TextEditingController(
      text: producto.precio > 0 ? producto.precio.toStringAsFixed(0) : '',
    );

    final precio = await showDialog<double>(
      context: context,
      builder: (context) {
        String? error;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void confirmar() {
              final valor = double.tryParse(precioCtrl.text.replaceAll(',', '.'));
              if (valor == null || valor < 0) {
                setDialogState(() => error = 'Ingresa un precio válido');
                return;
              }
              Navigator.pop(context, valor);
            }

            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: Row(
                children: [
                  Icon(Icons.build, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Precio de mano de obra',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    producto.nombre,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: precioCtrl,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Precio a cobrar',
                      prefixText: '\$ ',
                      errorText: error,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => confirmar(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: confirmar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Agregar'),
                ),
              ],
            );
          },
        );
      },
    );

    precioCtrl.dispose();
    return precio;
  }

  // 📦 Mostrar diálogo para elegir de dónde descontar (Bodega o Almacén)
  Future<String?> _mostrarDialogoSeleccionarOrigen(
    BuildContext context,
    Producto producto,
    int cantidad,
  ) async {
    final bodegaDisponible = producto.bodega ?? 0;
    final almacenDisponible = producto.almacen ?? 0;
    
    // 🔍 DEBUG
    appLog('🔍 _mostrarDialogoSeleccionarOrigen:');
    appLog('   - bodegaDisponible: $bodegaDisponible');
    appLog('   - almacenDisponible: $almacenDisponible');

    // ✅ VALIDACIÓN DE STOCK: Bloquear si no hay stock en ninguna ubicación
    final esServicio = producto.productoOServicio?.toLowerCase() == 'servicio';

    if (!esServicio) {
      if (bodegaDisponible <= 0 && almacenDisponible <= 0) {
        appLog('   ❌ Sin stock en ninguna ubicación');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Sin stock disponible en bodega ni almacén'),
            backgroundColor: Colors.red.shade700,
            duration: Duration(seconds: 3),
          ),
        );
        return null;
      }

      // Si solo hay stock en una ubicación, seleccionar automáticamente
      if (bodegaDisponible > 0 && almacenDisponible <= 0) {
        appLog('   ✅ Solo hay stock en BODEGA, seleccionando automáticamente');
        if (cantidad > bodegaDisponible) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '❌ Stock insuficiente en BODEGA\n'
                'Disponible: $bodegaDisponible\n'
                'Solicitado: $cantidad',
              ),
              backgroundColor: Colors.red.shade700,
              duration: Duration(seconds: 4),
            ),
          );
          return null;
        }
        return 'BODEGA';
      }

      if (almacenDisponible > 0 && bodegaDisponible <= 0) {
        appLog('   ✅ Solo hay stock en ALMACÉN, seleccionando automáticamente');
        if (cantidad > almacenDisponible) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '❌ Stock insuficiente en ALMACÉN\n'
                'Disponible: $almacenDisponible\n'
                'Solicitado: $cantidad',
              ),
              backgroundColor: Colors.red.shade700,
              duration: Duration(seconds: 4),
            ),
          );
          return null;
        }
        return 'ALMACÉN';
      }
    }
    
    appLog(
      '   📋 Hay stock en ambas ubicaciones o es servicio, mostrando diálogo',
    );

    // Si hay stock en ambas ubicaciones, mostrar diálogo para elegir
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Row(
          children: [
            Icon(Icons.warehouse, color: AppTheme.primary),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '¿De dónde descontar?',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              producto.nombre,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Cantidad solicitada: $cantidad',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 12),
            ),
            SizedBox(height: 16),
            // Opción Bodega
            ElevatedButton.icon(
              onPressed: bodegaDisponible >= cantidad
                  ? () => Navigator.pop(context, 'BODEGA')
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '❌ Stock insuficiente en BODEGA\n'
                            'Disponible: $bodegaDisponible\n'
                            'Solicitado: $cantidad',
                          ),
                          backgroundColor: Colors.red.shade700,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    },
              icon: Icon(Icons.store),
              label: Text(
                'BODEGA (Disponible: $bodegaDisponible)',
                style: TextStyle(fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: bodegaDisponible >= cantidad
                    ? AppTheme.primary
                    : Colors.grey,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.centerLeft,
              ),
            ),
            SizedBox(height: 8),
            // Opción Almacén
            ElevatedButton.icon(
              onPressed: almacenDisponible >= cantidad
                  ? () => Navigator.pop(context, 'ALMACÉN')
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '❌ Stock insuficiente en ALMACÉN\n'
                            'Disponible: $almacenDisponible\n'
                            'Solicitado: $cantidad',
                          ),
                          backgroundColor: Colors.red.shade700,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    },
              icon: Icon(Icons.inventory_2),
              label: Text(
                'ALMACÉN (Disponible: $almacenDisponible)',
                style: TextStyle(fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: almacenDisponible >= cantidad
                    ? AppTheme.success
                    : Colors.grey,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.centerLeft,
              ),
            ),
            if (cantidad > bodegaDisponible && cantidad > almacenDisponible)
              Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  '⚠️ Stock insuficiente en ambas ubicaciones',
                  style: TextStyle(color: AppTheme.error, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text('CANCELAR'),
          ),
        ],
      ),
    );
  }

  void _cerrarSesion(BuildContext context, UserProvider userProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Cerrar Sesión',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          '¿Estás seguro de que deseas cerrar sesión?',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await userProvider.logout();
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/login', (route) => false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: Text('Cerrar Sesión', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Determinar número de columnas según ancho de pantalla
  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 5;
    if (width > 900) return 4;
    if (width > 600) return 3;
    return 2; // Móvil
  }

  // Mostrar carrito como modal en móvil
  void _mostrarCarritoModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) => Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Handle visual
                  Container(
                    margin: EdgeInsets.only(top: 8, bottom: 4),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppTheme.primary.withOpacity(0.3),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.shopping_cart, color: AppTheme.primary),
                        SizedBox(width: 8),
                        Text(
                          'Pedido',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Spacer(),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  // Contenido del carrito
                  Expanded(
                    child: _buildCarritoPanelModal(setModalState, modalContext),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Panel del carrito para el modal con su propio setState
  Widget _buildCarritoPanelModal(
    StateSetter setModalState,
    BuildContext modalContext,
  ) {
    return Column(
      children: [
        // Encabezado del carrito
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            border: Border(
              bottom: BorderSide(color: AppTheme.primary.withOpacity(0.3)),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.shopping_basket, color: AppTheme.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Pedido',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_carrito.length} items',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Datos del cliente - compacto
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Datos del Cliente',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              SizedBox(height: 8),
              // Selector de cliente
              Row(
                children: [
                  Expanded(
                    child: Autocomplete<Cliente>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return _clientes.take(10);
                        }
                        return _clientes
                            .where((Cliente cliente) {
                              final nombre =
                                  (cliente.razonSocial ??
                                          '${cliente.nombres ?? ''} ${cliente.apellidos ?? ''}'
                                              .trim())
                                      .toLowerCase();
                              final documento = cliente.numeroIdentificacion
                                  .toLowerCase();
                              final query = textEditingValue.text.toLowerCase();
                              return nombre.contains(query) ||
                                  documento.contains(query);
                            })
                            .take(15);
                      },
                      displayStringForOption: (Cliente cliente) {
                        return cliente.razonSocial ??
                            '${cliente.nombres ?? ''} ${cliente.apellidos ?? ''}'
                                .trim();
                      },
                      onSelected: (Cliente cliente) {
                        setState(() {
                          _clienteSeleccionado = cliente;
                          _clienteController.text =
                              cliente.razonSocial ??
                              '${cliente.nombres ?? ''} ${cliente.apellidos ?? ''}'
                                  .trim();
                          _telefonoController.text = cliente.telefono ?? '';
                        });
                        setModalState(() {});
                      },
                      fieldViewBuilder:
                          (
                            BuildContext context,
                            TextEditingController textEditingController,
                            FocusNode focusNode,
                            VoidCallback onFieldSubmitted,
                          ) {
                            if (_clienteSeleccionado != null &&
                                textEditingController.text.isEmpty) {
                              textEditingController.text =
                                  _clienteSeleccionado!.razonSocial ??
                                  '${_clienteSeleccionado!.nombres ?? ''} ${_clienteSeleccionado!.apellidos ?? ''}'
                                      .trim();
                            }
                            return TextField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Cliente *',
                                labelStyle: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                                prefixIcon: Icon(
                                  Icons.person,
                                  color: AppTheme.primary,
                                  size: 18,
                                ),
                                suffixIcon: Icon(
                                  Icons.arrow_drop_down,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                                filled: true,
                                fillColor: Theme.of(context).colorScheme.surface,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                hintText: 'Buscar cliente...',
                                hintStyle: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                            );
                          },
                      optionsViewBuilder:
                          (
                            BuildContext context,
                            AutocompleteOnSelected<Cliente> onSelected,
                            Iterable<Cliente> options,
                          ) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4.0,
                                color: Theme.of(context).colorScheme.surface,
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
                                      final Cliente cliente = options.elementAt(
                                        index,
                                      );
                                      final nombre =
                                          cliente.razonSocial ??
                                          '${cliente.nombres ?? ''} ${cliente.apellidos ?? ''}'
                                              .trim();
                                      return InkWell(
                                        onTap: () => onSelected(cliente),
                                        child: Container(
                                          padding: EdgeInsets.all(12.0),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)
                                                    .withOpacity(0.2),
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                backgroundColor: AppTheme
                                                    .primary
                                                    .withOpacity(0.2),
                                                radius: 16,
                                                child: Text(
                                                  nombre.isNotEmpty
                                                      ? nombre[0].toUpperCase()
                                                      : '?',
                                                  style: TextStyle(
                                                    color: AppTheme.primary,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      nombre.isEmpty
                                                          ? cliente
                                                                .numeroIdentificacion
                                                          : nombre,
                                                      style: TextStyle(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurface,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        fontSize: 13,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    Text(
                                                      cliente
                                                          .numeroIdentificacion,
                                                      style: TextStyle(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurface
                                                            .withOpacity(0.7),
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
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
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      icon: Icon(
                        Icons.add_circle,
                        color: AppTheme.primary,
                        size: 28,
                      ),
                      padding: EdgeInsets.zero,
                      tooltip: 'Crear nuevo cliente',
                      onPressed: _mostrarDialogoNuevoCliente,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6),
              SizedBox(
                height: 40,
                child: TextField(
                  controller: _telefonoController,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Teléfono (opcional)',
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 11,
                    ),
                    prefixIcon: Icon(
                      Icons.phone,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      size: 16,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 6),
              SizedBox(
                height: 40,
                child: TextField(
                  controller: _observacionesController,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Observaciones (opcional)',
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 11,
                    ),
                    prefixIcon: Icon(
                      Icons.note,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      size: 16,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(color: AppTheme.primary.withOpacity(0.3), height: 1),
        // Lista de items
        Expanded(
          child: _carrito.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 40,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Carrito vacío',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Toque un producto para agregarlo',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(8),
                  itemCount: _carrito.length,
                  itemBuilder: (context, index) {
                    final item = _carrito[index];
                    return _buildCarritoItemModal(item, index, setModalState);
                  },
                ),
        ),
        // Totales y botones
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Subtotal:',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                  ),
                  Text(
                    '\$${_subtotal.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Divider(color: AppTheme.primary.withOpacity(0.3)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL:',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    '\$${_total.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _carrito.isEmpty
                          ? null
                          : () {
                              _limpiarFormulario();
                              setModalState(() {});
                            },
                      icon: Icon(Icons.clear),
                      label: Text('Limpiar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        side: BorderSide(color: AppTheme.error),
                        padding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading || _carrito.isEmpty
                          ? null
                          : () => _guardarPedidoDesdeModal(
                              setModalState,
                              modalContext,
                            ),
                      icon: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(Icons.save, color: Colors.white),
                      label: Text(
                        _isLoading ? 'Guardando...' : 'Guardar Pedido',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        disabledBackgroundColor: AppTheme.primary.withOpacity(
                          0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Método para guardar pedido desde el modal
  Future<void> _guardarPedidoDesdeModal(
    StateSetter setModalState,
    BuildContext modalContext,
  ) async {
    if (_isLoading) return;

    if (_clienteSeleccionado == null) {
      _mostrarError('Por favor selecciona un cliente');
      return;
    }

    if (_carrito.isEmpty) {
      _mostrarError('El carrito está vacío');
      return;
    }

    setState(() => _isLoading = true);
    setModalState(() {});

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // Crear traslado para los items que vienen de BODEGA
      List<ItemPedido> carritoFinal = List.from(_carrito);
      appLog('🔍 [Traslado/Modal] Total items: ${_carrito.length}');
      for (final item in _carrito) {
        appLog('🔍 [Traslado/Modal]   - ${item.productoNombre} | origen="${item.origen}" | id=${item.productoId}');
      }
      final bodegaItems = _carrito.where((item) => item.origen == 'BODEGA').toList();
      appLog('🔍 [Traslado/Modal] Items de BODEGA: ${bodegaItems.length}');

      if (bodegaItems.isNotEmpty) {
        appLog('🔍 [Traslado/Modal] Creando traslado...');
        try {
          final traslado = await _trasladoService.crearTraslado(
            items: bodegaItems
                .map((item) => {'productoId': item.productoId, 'cantidad': item.cantidad})
                .toList(),
            origen: 'BODEGA',
            destino: 'ALMACEN',
            asesor: userProvider.userName ?? 'Asesor',
            observaciones: 'Pedido asesor - cliente: ${_clienteSeleccionado!.razonSocial ?? '${_clienteSeleccionado!.nombres ?? ''} ${_clienteSeleccionado!.apellidos ?? ''}'.trim()}',
          );
          appLog('✅ [Traslado/Modal] Traslado creado: ${traslado.id}');
          final trasladoId = traslado.id;
          if (trasladoId != null) {
            carritoFinal = _carrito.map((item) {
              if (item.origen == 'BODEGA') {
                return ItemPedido(
                  productoId: item.productoId,
                  productoNombre: item.productoNombre,
                  cantidad: item.cantidad,
                  precioUnitario: item.precioUnitario,
                  notas: item.notas,
                  origen: item.origen,
                  trasladoId: trasladoId,
                );
              }
              return item;
            }).toList();
          }
        } catch (e) {
          appLog('❌ [Traslado/Modal] Error: $e');
          _mostrarError('Error al registrar traslado de bodega: $e');
          setState(() => _isLoading = false);
          setModalState(() {});
          return;
        }
      } else {
        appLog('ℹ️ [Traslado/Modal] Sin items de BODEGA → no se crea traslado');
      }

      final pedido = PedidoAsesor(
        clienteNombre:
            _clienteSeleccionado!.razonSocial ??
            '${_clienteSeleccionado!.nombres ?? ''} ${_clienteSeleccionado!.apellidos ?? ''}'
                .trim(),
        clienteId: _clienteSeleccionado!.id,
        asesorNombre: userProvider.userName ?? 'Asesor',
        asesorId: userProvider.userId,
        items: carritoFinal,
        subtotal: _subtotal,
        impuestos: 0,
        total: _total,
        fechaCreacion: DateTimeUtils.nowColombia(),
        observaciones: _observacionesController.text.trim().isEmpty
            ? (_telefonoController.text.trim().isNotEmpty
                  ? 'Tel: ${_telefonoController.text.trim()}'
                  : null)
            : '${_observacionesController.text.trim()}${_telefonoController.text.trim().isNotEmpty ? ' | Tel: ${_telefonoController.text.trim()}' : ''}',
      );

      await _pedidoService.crearPedido(pedido);

      // Cerrar el modal primero
      if (Navigator.canPop(modalContext)) {
        Navigator.pop(modalContext);
      }

      _limpiarFormulario();
      _mostrarExito('Pedido creado exitosamente');

    } catch (e) {
      _mostrarError('Error al guardar pedido: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Item del carrito para el modal
  Widget _buildCarritoItemModal(
    ItemPedido item,
    int index,
    StateSetter setModalState,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.productoNombre ?? 'Producto',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 4),
                    // 📦 Badge de origen
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: item.origen == 'BODEGA'
                            ? AppTheme.primary.withOpacity(0.2)
                            : AppTheme.success.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.origen == 'BODEGA' ? 'B' : 'A',
                        style: TextStyle(
                          color: item.origen == 'BODEGA'
                              ? AppTheme.primary
                              : AppTheme.success,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2),
                _esManoDeObra(_buscarProducto(item.productoId))
                    ? SizedBox(
                        width: 80,
                        height: 30,
                        child: TextField(
                          controller: _ctrlPrecio(item),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            isDense: true,
                            prefixText: '\$ ',
                            contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onChanged: (v) {
                            _actualizarPrecioItem(index, v);
                            setModalState(() {});
                          },
                        ),
                      )
                    : Text(
                        '\$${item.precioUnitario.toStringAsFixed(0)} x ${item.cantidad}',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 11),
                      ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  Icons.remove_circle_outline,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  size: 22,
                ),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () {
                  _actualizarCantidad(index, item.cantidad - 1);
                  setModalState(() {});
                },
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '${item.cantidad}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.add_circle_outline,
                  color: AppTheme.primary,
                  size: 22,
                ),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () {
                  _actualizarCantidad(index, item.cantidad + 1);
                  setModalState(() {});
                },
              ),
            ],
          ),
          Text(
            '\$${item.subtotal.toStringAsFixed(0)}',
            style: TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () {
              _eliminarDelCarrito(index);
              setModalState(() {});
            },
          ),
        ],
      ),
    );
  }

  // Mostrar diálogo para crear nuevo cliente
  void _mostrarDialogoNuevoCliente() {
    final nombreController = TextEditingController();
    final apellidoController = TextEditingController();
    final docController = TextEditingController();
    final telefonoController = TextEditingController();
    final correoController = TextEditingController();
    String tipoDoc = 'CC';
    String tipoPersona = 'Persona Natural';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            'Crear Nuevo Cliente',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tipo de persona
                DropdownButtonFormField<String>(
                  value: tipoPersona,
                  decoration: InputDecoration(
                    labelText: 'Tipo de Persona',
                    labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  items: ['Persona Natural', 'Persona Jurídica']
                      .map(
                        (tipo) =>
                            DropdownMenuItem(value: tipo, child: Text(tipo)),
                      )
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() => tipoPersona = value!);
                  },
                ),
                SizedBox(height: 12),
                // Tipo de documento
                DropdownButtonFormField<String>(
                  value: tipoDoc,
                  decoration: InputDecoration(
                    labelText: 'Tipo Documento',
                    labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  items: ['CC', 'NIT', 'CE', 'Pasaporte', 'TI']
                      .map(
                        (tipo) =>
                            DropdownMenuItem(value: tipo, child: Text(tipo)),
                      )
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() => tipoDoc = value!);
                  },
                ),
                SizedBox(height: 12),
                // Número de documento
                TextField(
                  controller: docController,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Número de Documento *',
                    labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (tipoPersona == 'Persona Natural') ...[
                  SizedBox(height: 12),
                  TextField(
                    controller: nombreController,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Nombres *',
                      labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: apellidoController,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Apellidos *',
                      labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(height: 12),
                  TextField(
                    controller: nombreController,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Razón Social *',
                      labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
                SizedBox(height: 12),
                TextField(
                  controller: telefonoController,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Teléfono',
                    labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: correoController,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Correo',
                    labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (docController.text.trim().isEmpty) {
                  _mostrarError('Ingrese el número de documento');
                  return;
                }

                if (tipoPersona == 'Persona Natural' &&
                    (nombreController.text.trim().isEmpty ||
                        apellidoController.text.trim().isEmpty)) {
                  _mostrarError('Ingrese nombres y apellidos');
                  return;
                }

                if (tipoPersona == 'Persona Jurídica' &&
                    nombreController.text.trim().isEmpty) {
                  _mostrarError('Ingrese la razón social');
                  return;
                }

                try {
                  final nuevoCliente = Cliente(
                    tipoPersona: tipoPersona,
                    tipoIdentificacion: tipoDoc,
                    numeroIdentificacion: docController.text.trim(),
                    nombres: tipoPersona == 'Persona Natural'
                        ? nombreController.text.trim()
                        : null,
                    apellidos: tipoPersona == 'Persona Natural'
                        ? apellidoController.text.trim()
                        : null,
                    razonSocial: tipoPersona == 'Persona Jurídica'
                        ? nombreController.text.trim()
                        : '${nombreController.text.trim()} ${apellidoController.text.trim()}',
                    telefono: telefonoController.text.trim().isEmpty
                        ? null
                        : telefonoController.text.trim(),
                    correo: correoController.text.trim().isEmpty
                        ? null
                        : correoController.text.trim(),
                    responsableIVA: 'No',
                    calidadAgenteRetencion: 'No aplica',
                    diasCredito: 0,
                    cupoCredito: 0,
                    saldoActual: 0,
                    estado: 'activo',
                    habilitadoFacturacionElectronica: false,
                  );

                  final clienteCreado = await _clienteService.crearCliente(
                    nuevoCliente,
                  );

                  setState(() {
                    _clientes.add(clienteCreado);
                    _clienteSeleccionado = clienteCreado;
                    _clienteController.text = clienteCreado.razonSocial ?? '';
                    _telefonoController.text = clienteCreado.telefono ?? '';
                  });

                  Navigator.pop(context);
                  _mostrarExito('Cliente creado exitosamente');
                } catch (e) {
                  _mostrarError('Error al crear cliente: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
              ),
              child: Text('Crear', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// 📷 WIDGET PARA ESCANEAR CÓDIGOS DE BARRAS
class _ScannerScreen extends StatefulWidget {
  @override
  State<_ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<_ScannerScreen> {
  late MobileScannerController _controller;
  bool _isFrontCamera = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture barcodes) {
    if (barcodes.barcodes.isNotEmpty) {
      final barcode = barcodes.barcodes.first;
      final codigo = barcode.rawValue;

      if (codigo != null && codigo.isNotEmpty) {
        // ✅ Regresar con el código capturado
        Navigator.of(context).pop<String>(codigo);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ❌ No soportado en Web
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Escáner no disponible'),
          backgroundColor: AppTheme.primary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_rounded, size: 64, color: AppTheme.warning),
              SizedBox(height: 24),
              Text(
                'Escáner no soportado en Web',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Por favor, usa la versión móvil de la app o ingresa el código manualmente.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cerrar'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Escanear Código de Barras'),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop<String?>(null),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _controller.torchEnabled
                  ? Icons.flashlight_on
                  : Icons.flashlight_off,
            ),
            onPressed: () async {
              await _controller.toggleTorch();
            },
          ),
          IconButton(
            icon: Icon(Icons.flip_camera_ios),
            onPressed: () async {
              _isFrontCamera = !_isFrontCamera;
              await _controller.switchCamera();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
            errorBuilder: (context, error, child) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: AppTheme.error, size: 48),
                    SizedBox(height: 16),
                    Text(
                      'Error al acceder a la cámara',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      error.errorDetails?.message ?? 'Error desconocido',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
          // Overlay con indicaciones
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green, width: 2),
              borderRadius: BorderRadius.circular(12),
              color: Colors.transparent,
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 5,
                ),
              ],
            ),
            margin: EdgeInsets.all(32),
          ),
          // Instrucciones en la parte inferior
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Apunta el código de barras al centro',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
