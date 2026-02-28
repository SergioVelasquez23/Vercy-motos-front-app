import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pedido_asesor.dart';
import '../models/item_pedido.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../models/cliente.dart';
import '../services/pedido_asesor_service.dart';
import '../services/producto_service.dart';
import '../services/cliente_service.dart';
import '../providers/user_provider.dart';
import '../providers/datos_cache_provider.dart';
import '../theme/app_theme.dart';
import '../utils/busqueda_productos_utils.dart';

class AsesorPedidosScreen extends StatefulWidget {
  const AsesorPedidosScreen({super.key});

  @override
  _AsesorPedidosScreenState createState() => _AsesorPedidosScreenState();
}

class _AsesorPedidosScreenState extends State<AsesorPedidosScreen> {
  final PedidoAsesorService _pedidoService = PedidoAsesorService();
  final ProductoService _productoService = ProductoService();
  final ClienteService _clienteService = ClienteService();
  
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
  
  // Totales
  double _subtotal = 0;
  double _total = 0;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _searchController.addListener(_filtrarProductos);
  }

  @override
  void dispose() {
    _clienteController.dispose();
    _telefonoController.dispose();
    _observacionesController.dispose();
    _searchController.dispose();
    _codigoBarrasController.dispose();
    _cantidadController.dispose();
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

      setState(() {
        _productos = productos;
        _productosFiltrados = productos;
        _categorias = categorias;
        _clientes = clientes;
      });
    } catch (e) {
      _mostrarError('Error al cargar datos: $e');
    } finally {
      setState(() => _isLoading = false);
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

    if (producto.id != null && producto.id!.isNotEmpty) {
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
    print('🔍 DEBUG agregar al carrito:');
    print('   - Producto: ${producto.nombre}');
    print('   - Bodega: ${producto.bodega}');
    print('   - Almacén: ${producto.almacen}');
    print('   - TipoItem: ${producto.productoOServicio}');

    // ⚠️ VALIDACIÓN DE STOCK: No aplicar a servicios
    final esServicio = producto.productoOServicio?.toLowerCase() == 'servicio';

    if (!esServicio) {
      final stockAlmacen = producto.almacen ?? 0;
      final stockBodega = producto.bodega ?? 0;
      final stockTotal = stockAlmacen + stockBodega;

      // Validación 1: Si no hay stock en ninguna ubicación, NO PERMITIR agregar
      if (stockTotal <= 0) {
        print('   ❌ BLOQUEADO: No hay stock en ninguna ubicación');
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
        print(
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

      print('   ✅ Validación pasada: Stock suficiente');
    } else {
      print('   ℹ️  Es servicio - sin validación de stock');
    }
    
    // 📦 Mostrar diálogo para elegir de dónde descontar
    final origen = await _mostrarDialogoSeleccionarOrigen(
      context,
      producto,
      cantidad,
    );
    
    print('   - Origen seleccionado: $origen');

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
            productoId: producto.id!,
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

    // ✅ VALIDACIÓN: No aplicar a servicios
    final tipoProducto = producto.productoOServicio?.trim().toLowerCase();
    final esServicio = tipoProducto == 'servicio';

    if (!esServicio) {
      // 📦 Validar stock del origen seleccionado
      final stockAlmacen = producto.almacen ?? 0;
      final stockBodega = producto.bodega ?? 0;
      final origen = item.origen?.toUpperCase() ?? 'ALMACÉN';

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
    setState(() {
      _carrito.removeAt(index);
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

      final pedido = PedidoAsesor(
        clienteNombre:
            _clienteSeleccionado!.razonSocial ??
            '${_clienteSeleccionado!.nombres ?? ''} ${_clienteSeleccionado!.apellidos ?? ''}'
                .trim(),
        clienteId: _clienteSeleccionado!.id,
        asesorNombre: userProvider.userName ?? 'Asesor',
        asesorId: userProvider.userId,
        items: _carrito,
        subtotal: _subtotal,
        impuestos: 0,
        total: _total,
        fechaCreacion: DateTime.now(),
        observaciones: _observacionesController.text.trim().isEmpty
            ? (_telefonoController.text.trim().isNotEmpty
                  ? 'Tel: ${_telefonoController.text.trim()}'
                  : null)
            : '${_observacionesController.text.trim()}${_telefonoController.text.trim().isNotEmpty ? ' | Tel: ${_telefonoController.text.trim()}' : ''}',
      );

      await _pedidoService.crearPedido(pedido);

      _mostrarExito('Pedido creado exitosamente');
      _limpiarFormulario();
      
      // Navegar a la lista de pedidos asesores
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/admin-pedidos-asesor');
      }
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
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Volver al dashboard',
          onPressed: () =>
              Navigator.pushReplacementNamed(context, '/dashboard'),
        ),
        title: Row(
          children: [
            Icon(Icons.shopping_cart, color: Colors.white),
            SizedBox(width: 12),
            Text(
              'Crear Pedido',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        automaticallyImplyLeading: true,
        actions: [
          // Información del usuario
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                userProvider.userName ?? 'Asesor',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ),
          // Botón de cerrar sesión
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            tooltip: 'Cerrar sesión',
            onPressed: () => _cerrarSesion(context, userProvider),
          ),
          SizedBox(width: 8),
        ],
      ),
      body: _isLoading && _productos.isEmpty
          ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : LayoutBuilder(
              builder: (context, constraints) {
                // Determinar si es pantalla grande (tablet/desktop)
                final isLargeScreen = constraints.maxWidth > 800;

                if (isLargeScreen) {
                  // Layout para desktop/tablet - dos columnas
                  return Row(
                    children: [
                      // Panel izquierdo - Productos
                      Expanded(flex: 3, child: _buildProductosPanel()),
                      // Panel derecho - Carrito
                      Container(
                        width: 400,
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          border: Border(
                            left: BorderSide(
                              color: AppTheme.primary.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                        ),
                        child: _buildCarritoPanel(),
                      ),
                    ],
                  );
                } else {
                  // Layout para móvil - columna única
                  return Column(
                    children: [
                      // Panel de productos (ocupa la mayor parte)
                      Expanded(child: _buildProductosPanel()),
                      // Botón flotante para ver carrito
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          border: Border(
                            top: BorderSide(
                              color: AppTheme.primary.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _mostrarCarritoModal(context),
                                icon: Icon(
                                  Icons.shopping_cart,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  'Ver Pedido (${_carrito.length}) - \$${_total.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  padding: EdgeInsets.symmetric(vertical: 16),
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
            ),
    );
  }

  Widget _buildProductosPanel() {
    return Column(
      children: [
        // Barra de búsqueda y código de barras
        Container(
          padding: EdgeInsets.all(16),
          color: AppTheme.cardBg,
          child: Column(
            children: [
              // Código de barras
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _codigoBarrasController,
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Escanee o ingrese código de barras...',
                        hintStyle: TextStyle(color: AppTheme.textSecondary),
                        filled: true,
                        fillColor: AppTheme.surfaceDark,
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
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Buscar producto...',
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
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _categoriaSeleccionada,
                      decoration: InputDecoration(
                        hintText: 'Categoría',
                        hintStyle: TextStyle(color: AppTheme.textSecondary),
                        filled: true,
                        fillColor: AppTheme.surfaceDark,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      style: TextStyle(color: AppTheme.textPrimary),
                      dropdownColor: AppTheme.cardBg,
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text(
                            'Todas',
                            style: TextStyle(color: AppTheme.textPrimary),
                          ),
                        ),
                        ..._categorias.map(
                          (cat) => DropdownMenuItem<String>(
                            value: cat.id,
                            child: Text(
                              cat.nombre,
                              style: TextStyle(color: AppTheme.textPrimary),
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
                        color: AppTheme.textSecondary,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No se encontraron productos',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
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
                    childAspectRatio: 0.85,
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
              : AppTheme.cardBg,
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
                  color: AppTheme.textPrimary,
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
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
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
                  color: AppTheme.textPrimary,
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
            color: AppTheme.surfaceDark.withOpacity(0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Datos del Cliente',
                style: TextStyle(
                  color: AppTheme.textPrimary,
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
                                color: AppTheme.textPrimary,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Cliente *',
                                labelStyle: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                                prefixIcon: Icon(
                                  Icons.person,
                                  color: AppTheme.primary,
                                  size: 18,
                                ),
                                suffixIcon: Icon(
                                  Icons.arrow_drop_down,
                                  color: AppTheme.textSecondary,
                                ),
                                filled: true,
                                fillColor: AppTheme.surfaceDark,
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
                                  color: AppTheme.textSecondary,
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
                                                color: AppTheme.textSecondary
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
                                                        color: AppTheme
                                                            .textPrimary,
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
                                                        color: AppTheme
                                                            .textSecondary,
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
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                        ),
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Teléfono (opcional)',
                          labelStyle: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                          prefixIcon: Icon(
                            Icons.phone,
                            color: AppTheme.textSecondary,
                            size: 16,
                          ),
                          filled: true,
                          fillColor: AppTheme.surfaceDark,
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
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Observaciones (opcional)',
                    labelStyle: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                    prefixIcon: Icon(
                      Icons.note,
                      color: AppTheme.textSecondary,
                      size: 16,
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceDark,
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
                        color: AppTheme.textSecondary,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Carrito vacío',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Toque un producto para agregarlo',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
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
            color: AppTheme.surfaceDark,
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
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  Text(
                    '\$${_subtotal.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
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
                      color: AppTheme.textPrimary,
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
        color: AppTheme.cardBg,
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
                          color: AppTheme.textPrimary,
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
                Text(
                  '\$${item.precioUnitario.toStringAsFixed(0)} c/u',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          // Controles de cantidad
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
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
                      color: AppTheme.textPrimary,
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

  // 📦 Mostrar diálogo para elegir de dónde descontar (Bodega o Almacén)
  Future<String?> _mostrarDialogoSeleccionarOrigen(
    BuildContext context,
    Producto producto,
    int cantidad,
  ) async {
    final bodegaDisponible = producto.bodega ?? 0;
    final almacenDisponible = producto.almacen ?? 0;
    
    // 🔍 DEBUG
    print('🔍 _mostrarDialogoSeleccionarOrigen:');
    print('   - bodegaDisponible: $bodegaDisponible');
    print('   - almacenDisponible: $almacenDisponible');

    // ✅ VALIDACIÓN DE STOCK: Bloquear si no hay stock en ninguna ubicación
    final esServicio = producto.productoOServicio?.toLowerCase() == 'servicio';

    if (!esServicio) {
      if (bodegaDisponible <= 0 && almacenDisponible <= 0) {
        print('   ❌ Sin stock en ninguna ubicación');
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
        print('   ✅ Solo hay stock en BODEGA, seleccionando automáticamente');
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
        print('   ✅ Solo hay stock en ALMACÉN, seleccionando automáticamente');
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
    
    print(
      '   📋 Hay stock en ambas ubicaciones o es servicio, mostrando diálogo',
    );

    // Si hay stock en ambas ubicaciones, mostrar diálogo para elegir
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Row(
          children: [
            Icon(Icons.warehouse, color: AppTheme.primary),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '¿De dónde descontar?',
                style: TextStyle(color: AppTheme.textPrimary),
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
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Cantidad solicitada: $cantidad',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
        backgroundColor: AppTheme.cardBg,
        title: Text(
          'Cerrar Sesión',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          '¿Estás seguro de que deseas cerrar sesión?',
          style: TextStyle(color: AppTheme.textSecondary),
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
                color: AppTheme.cardBg,
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
                      color: AppTheme.textSecondary.withOpacity(0.3),
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
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Spacer(),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: AppTheme.textSecondary,
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
                  color: AppTheme.textPrimary,
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
            color: AppTheme.surfaceDark.withOpacity(0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Datos del Cliente',
                style: TextStyle(
                  color: AppTheme.textPrimary,
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
                                color: AppTheme.textPrimary,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Cliente *',
                                labelStyle: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                                prefixIcon: Icon(
                                  Icons.person,
                                  color: AppTheme.primary,
                                  size: 18,
                                ),
                                suffixIcon: Icon(
                                  Icons.arrow_drop_down,
                                  color: AppTheme.textSecondary,
                                ),
                                filled: true,
                                fillColor: AppTheme.surfaceDark,
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
                                  color: AppTheme.textSecondary,
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
                                                color: AppTheme.textSecondary
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
                                                        color: AppTheme
                                                            .textPrimary,
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
                                                        color: AppTheme
                                                            .textSecondary,
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
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Teléfono (opcional)',
                    labelStyle: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                    prefixIcon: Icon(
                      Icons.phone,
                      color: AppTheme.textSecondary,
                      size: 16,
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceDark,
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
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Observaciones (opcional)',
                    labelStyle: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                    prefixIcon: Icon(
                      Icons.note,
                      color: AppTheme.textSecondary,
                      size: 16,
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceDark,
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
                        color: AppTheme.textSecondary,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Carrito vacío',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Toque un producto para agregarlo',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
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
            color: AppTheme.surfaceDark,
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
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  Text(
                    '\$${_subtotal.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
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
                      color: AppTheme.textPrimary,
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

      final pedido = PedidoAsesor(
        clienteNombre:
            _clienteSeleccionado!.razonSocial ??
            '${_clienteSeleccionado!.nombres ?? ''} ${_clienteSeleccionado!.apellidos ?? ''}'
                .trim(),
        clienteId: _clienteSeleccionado!.id,
        asesorNombre: userProvider.userName ?? 'Asesor',
        asesorId: userProvider.userId,
        items: _carrito,
        subtotal: _subtotal,
        impuestos: 0,
        total: _total,
        fechaCreacion: DateTime.now(),
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

      // Navegar a la lista de pedidos asesores
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/admin-pedidos-asesor');
      }
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
        color: AppTheme.cardBg,
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
                          color: AppTheme.textPrimary,
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
                Text(
                  '\$${item.precioUnitario.toStringAsFixed(0)} x ${item.cantidad}',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
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
                  color: AppTheme.textSecondary,
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
                    color: AppTheme.textPrimary,
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
          backgroundColor: AppTheme.cardBg,
          title: Text(
            'Crear Nuevo Cliente',
            style: TextStyle(color: AppTheme.textPrimary),
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
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.surfaceDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(color: AppTheme.textPrimary),
                  dropdownColor: AppTheme.surfaceDark,
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
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.surfaceDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(color: AppTheme.textPrimary),
                  dropdownColor: AppTheme.surfaceDark,
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
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Número de Documento *',
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.surfaceDark,
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
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Nombres *',
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
                  TextField(
                    controller: apellidoController,
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Apellidos *',
                      labelStyle: TextStyle(color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.surfaceDark,
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
                    style: TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Razón Social *',
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
                SizedBox(height: 12),
                TextField(
                  controller: telefonoController,
                  style: TextStyle(color: AppTheme.textPrimary),
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Teléfono',
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
                TextField(
                  controller: correoController,
                  style: TextStyle(color: AppTheme.textPrimary),
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Correo',
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
