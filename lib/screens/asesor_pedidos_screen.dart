import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pedido_asesor.dart';
import '../models/item_pedido.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../services/pedido_asesor_service.dart';
import '../services/producto_service.dart';
import '../providers/user_provider.dart';
import '../providers/datos_cache_provider.dart';
import '../theme/app_theme.dart';

class AsesorPedidosScreen extends StatefulWidget {
  const AsesorPedidosScreen({super.key});

  @override
  _AsesorPedidosScreenState createState() => _AsesorPedidosScreenState();
}

class _AsesorPedidosScreenState extends State<AsesorPedidosScreen> {
  final PedidoAsesorService _pedidoService = PedidoAsesorService();
  final ProductoService _productoService = ProductoService();
  
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
  String? _categoriaSeleccionada;
  Producto? _productoSeleccionado;
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
        print('Error al cargar categorías: $e');
      }

      setState(() {
        _productos = productos;
        _productosFiltrados = productos;
        _categorias = categorias;
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
            producto.nombre.toLowerCase().contains(busqueda) ||
            (producto.codigo?.toLowerCase().contains(busqueda) ?? false);
        
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

  void _agregarAlCarrito(Producto producto) {
    final cantidad = int.tryParse(_cantidadController.text) ?? 1;
    
    setState(() {
      final index = _carrito.indexWhere(
        (item) => item.productoId == producto.id,
      );

      if (index >= 0) {
        _carrito[index] = ItemPedido(
          productoId: _carrito[index].productoId,
          productoNombre: _carrito[index].productoNombre ?? 'Producto',
          cantidad: _carrito[index].cantidad + cantidad,
          precioUnitario: _carrito[index].precioUnitario,
        );
      } else {
        _carrito.add(
          ItemPedido(
            productoId: producto.id!,
            productoNombre: producto.nombre,
            cantidad: cantidad,
            precioUnitario: producto.precio,
          ),
        );
      }

      _calcularTotales();
      _productoSeleccionado = null;
      _cantidadController.text = '1';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${producto.nombre} agregado al pedido'),
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

    setState(() {
      final item = _carrito[index];
      _carrito[index] = ItemPedido(
        productoId: item.productoId,
        productoNombre: item.productoNombre ?? 'Producto',
        cantidad: nuevaCantidad,
        precioUnitario: item.precioUnitario,
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
    if (_clienteController.text.trim().isEmpty) {
      _mostrarError('Por favor ingresa el nombre del cliente');
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
        clienteNombre: _clienteController.text.trim(),
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
    } catch (e) {
      _mostrarError('Error al guardar pedido: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _limpiarFormulario() {
    setState(() {
      _carrito.clear();
      _clienteController.clear();
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
        automaticallyImplyLeading: false,
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
          : Row(
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
                    crossAxisCount: 4,
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
            // Cantidad disponible
            if (producto.cantidad > 0)
              Text(
                'Disp: ${producto.cantidad}',
                style: TextStyle(
                  color: producto.cantidad > 0
                      ? AppTheme.success
                      : AppTheme.error,
                  fontSize: 10,
                ),
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
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            border: Border(
              bottom: BorderSide(color: AppTheme.primary.withOpacity(0.3)),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.shopping_basket, color: AppTheme.primary),
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
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_carrito.length} items',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Datos del cliente
        Container(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Datos del Cliente',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _clienteController,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Nombre del cliente *',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                  prefixIcon: Icon(Icons.person, color: AppTheme.primary),
                  filled: true,
                  fillColor: AppTheme.surfaceDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _telefonoController,
                style: TextStyle(color: AppTheme.textPrimary),
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Teléfono (opcional)',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                  prefixIcon: Icon(Icons.phone, color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: AppTheme.surfaceDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _observacionesController,
                style: TextStyle(color: AppTheme.textPrimary),
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Observaciones (opcional)',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                  prefixIcon: Icon(Icons.note, color: AppTheme.textSecondary),
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
                        size: 48,
                        color: AppTheme.textSecondary,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Carrito vacío',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Toque un producto para agregarlo',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
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
                Text(
                  item.productoNombre ?? 'Producto',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
}
