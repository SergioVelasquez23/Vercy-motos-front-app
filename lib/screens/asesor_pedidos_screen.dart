import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pedido_asesor.dart';
import '../models/item_pedido.dart';
import '../models/producto.dart';
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
  final TextEditingController _clienteController = TextEditingController();
  final TextEditingController _observacionesController =
      TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<ItemPedido> _carrito = [];
  List<Producto> _productos = [];
  List<Producto> _productosFiltrados = [];
  bool _isLoading = false;
  double _subtotal = 0;
  double _impuestos = 0;
  double _total = 0;

  @override
  void initState() {
    super.initState();
    _cargarProductos();
    _searchController.addListener(_filtrarProductos);
  }

  @override
  void dispose() {
    _clienteController.dispose();
    _observacionesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarProductos() async {
    setState(() => _isLoading = true);
    try {
      // Intentar cargar desde cache
      final cacheProvider = Provider.of<DatosCacheProvider>(
        context,
        listen: false,
      );
      List<Producto> productos = cacheProvider.productos ?? [];

      // Si no hay en cache, cargar del servicio
      if (productos.isEmpty) {
        productos = await _productoService.getProductos();
      }

      setState(() {
        _productos = productos;
        _productosFiltrados = productos;
      });
    } catch (e) {
      _mostrarError('Error al cargar productos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filtrarProductos() {
    final busqueda = _searchController.text.toLowerCase();
    setState(() {
      _productosFiltrados = _productos.where((producto) {
        return producto.nombre.toLowerCase().contains(busqueda) ||
            (producto.codigo?.toLowerCase().contains(busqueda) ?? false);
      }).toList();
    });
  }

  void _agregarAlCarrito(Producto producto) {
    setState(() {
      // Buscar si ya existe en el carrito
      final index = _carrito.indexWhere(
        (item) => item.productoId == producto.id,
      );

      if (index >= 0) {
        // Si existe, aumentar cantidad
        _carrito[index] = ItemPedido(
          productoId: _carrito[index].productoId,
          productoNombre: _carrito[index].productoNombre ?? 'Producto',
          cantidad: _carrito[index].cantidad + 1,
          precioUnitario: _carrito[index].precioUnitario,
        );
      } else {
        // Si no existe, agregar nuevo
        _carrito.add(
          ItemPedido(
            productoId: producto.id!,
            productoNombre: producto.nombre,
            cantidad: 1,
            precioUnitario: producto.precio,
          ),
        );
      }

      _calcularTotales();
    });
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
    double impuestos = 0;

    for (var item in _carrito) {
      subtotal += item.subtotal;
      // No hay campo de impuestos en ItemPedido, así que asumimos 0% por ahora
      // Si necesitas impuestos, deberás agregar un campo al producto o calcularlos después
    }

    setState(() {
      _subtotal = subtotal;
      _impuestos = impuestos;
      _total = subtotal + impuestos;
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
        impuestos: _impuestos,
        total: _total,
        fechaCreacion: DateTime.now(),
        observaciones: _observacionesController.text.trim().isEmpty
            ? null
            : _observacionesController.text.trim(),
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
      _observacionesController.clear();
      _calcularTotales();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text('Crear Pedido', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () =>
              Navigator.pushReplacementNamed(context, '/dashboard'),
        ),
      ),
      body: Row(
        children: [
          // Lista de productos (izquierda)
          Expanded(flex: 3, child: _buildProductosSection()),
          // Carrito (derecha)
          Expanded(flex: 2, child: _buildCarritoSection()),
        ],
      ),
    );
  }

  Widget _buildProductosSection() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Buscador
          TextField(
            controller: _searchController,
            style: TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Buscar productos...',
              hintStyle: TextStyle(color: AppTheme.textSecondary),
              prefixIcon: Icon(Icons.search, color: AppTheme.primary),
              filled: true,
              fillColor: AppTheme.cardBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          SizedBox(height: 16),
          // Grid de productos
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  )
                : GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.75,
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
      ),
    );
  }

  Widget _buildProductoCard(Producto producto) {
    return InkWell(
      onTap: () => _agregarAlCarrito(producto),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag, size: 48, color: AppTheme.primary),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                producto.nombre,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '\$${producto.precio.toStringAsFixed(0)}',
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarritoSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(
          left: BorderSide(color: AppTheme.primary.withOpacity(0.3)),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.primary),
            child: Row(
              children: [
                Icon(Icons.shopping_cart, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Carrito (${_carrito.length})',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Cliente
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _clienteController,
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Nombre del Cliente',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
                prefixIcon: Icon(Icons.person, color: AppTheme.primary),
                filled: true,
                fillColor: AppTheme.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // Items del carrito
          Expanded(
            child: _carrito.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 64,
                          color: AppTheme.textSecondary,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Carrito vacío',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _carrito.length,
                    itemBuilder: (context, index) {
                      final item = _carrito[index];
                      return _buildCarritoItem(item, index);
                    },
                  ),
          ),
          // Observaciones
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _observacionesController,
              style: TextStyle(color: AppTheme.textPrimary),
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Observaciones (opcional)',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // Totales y botón
          _buildTotalesSection(),
        ],
      ),
    );
  }

  Widget _buildCarritoItem(ItemPedido item, int index) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productoNombre ?? 'Producto',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '\$${item.precioUnitario.toStringAsFixed(0)} x ${item.cantidad}',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          // Controles de cantidad
          Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.remove_circle,
                  color: AppTheme.error,
                  size: 20,
                ),
                onPressed: () => _actualizarCantidad(index, item.cantidad - 1),
              ),
              Text(
                '${item.cantidad}',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.add_circle, color: AppTheme.primary, size: 20),
                onPressed: () => _actualizarCantidad(index, item.cantidad + 1),
              ),
            ],
          ),
          SizedBox(width: 8),
          Text(
            '\$${item.subtotal.toStringAsFixed(0)}',
            style: TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete, color: AppTheme.error, size: 20),
            onPressed: () => _eliminarDelCarrito(index),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalesSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        border: Border(
          top: BorderSide(color: AppTheme.primary.withOpacity(0.3)),
        ),
      ),
      child: Column(
        children: [
          _buildTotalRow('Subtotal:', _subtotal),
          _buildTotalRow('Impuestos:', _impuestos),
          Divider(color: AppTheme.primary.withOpacity(0.3)),
          _buildTotalRow('TOTAL:', _total, isTotal: true),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _carrito.isEmpty ? null : _limpiarFormulario,
                  icon: Icon(Icons.clear, color: Colors.white),
                  label: Text('Limpiar', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    padding: EdgeInsets.symmetric(vertical: 16),
                    disabledBackgroundColor: Colors.grey[800],
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
                    style: TextStyle(color: Colors.white, fontSize: 16),
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
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double valor, {bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isTotal ? AppTheme.textPrimary : AppTheme.textSecondary,
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '\$${valor.toStringAsFixed(0)}',
            style: TextStyle(
              color: isTotal ? AppTheme.primary : AppTheme.textPrimary,
              fontSize: isTotal ? 20 : 16,
              fontWeight: FontWeight.bold,
            ),
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
