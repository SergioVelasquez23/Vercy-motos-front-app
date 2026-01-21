import 'package:flutter/material.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../services/producto_service.dart';
import '../theme/app_theme.dart';
import '../widgets/vercy_sidebar_layout.dart';
import '../utils/format_utils.dart';

class ProductosListScreen extends StatefulWidget {
  const ProductosListScreen({super.key});

  @override
  _ProductosListScreenState createState() => _ProductosListScreenState();
}

class _ProductosListScreenState extends State<ProductosListScreen> {
  final ProductoService _productoService = ProductoService();

  // Controladores de filtros
  final _filtroCodigoController = TextEditingController();
  final _filtroNombreController = TextEditingController();

  // Filtros
  String _tipoFiltro = 'PRODUCTO';
  String _categoriaSeleccionada = 'TODAS';

  List<Producto> _productos = [];
  List<Producto> _productosFiltrados = [];
  List<Categoria> _categorias = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _filtroCodigoController.dispose();
    _filtroNombreController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final productos = await _productoService.getProductos();
      final categorias = await _productoService.getCategorias();

      setState(() {
        _productos = productos;
        _categorias = categorias;
        _aplicarFiltros();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar datos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _aplicarFiltros() {
    setState(() {
      _productosFiltrados = _productos.where((producto) {
        // Filtro por código
        final matchCodigo =
            _filtroCodigoController.text.isEmpty ||
            (producto.codigo?.toLowerCase().contains(
                  _filtroCodigoController.text.toLowerCase(),
                ) ??
                false) ||
            producto.id.toLowerCase().contains(
              _filtroCodigoController.text.toLowerCase(),
            );

        // Filtro por nombre (Item)
        final matchNombre =
            _filtroNombreController.text.isEmpty ||
            producto.nombre.toLowerCase().contains(
              _filtroNombreController.text.toLowerCase(),
            );

        // Filtro por categoría
        final matchCategoria =
            _categoriaSeleccionada == 'TODAS' ||
            (producto.categoria?.nombre == _categoriaSeleccionada);

        // Filtro por tipo
        final matchTipo =
            _tipoFiltro == 'PRODUCTO' ||
            (_tipoFiltro == 'SERVICIO' &&
                producto.productoOServicio?.toUpperCase() == 'SERVICIO');

        return matchCodigo && matchNombre && matchCategoria && matchTipo;
      }).toList();

      // Ordenar por nombre
      _productosFiltrados.sort((a, b) => a.nombre.compareTo(b.nombre));
    });
  }

  String _getEstadoInventario(Producto producto) {
    final inventario = producto.almacen ?? 0;
    final bajo = producto.inventarioBajo ?? 5;
    final optimo = producto.inventarioOptimo ?? 20;

    if (inventario <= 0) return 'Sin Stock';
    if (inventario <= bajo) return 'Bajo';
    if (inventario >= optimo) return 'Óptimo';
    return 'Normal';
  }

  Color _getColorEstado(String estado) {
    switch (estado) {
      case 'Sin Stock':
        return Colors.red;
      case 'Bajo':
        return Colors.red;
      case 'Óptimo':
        return AppTheme.success;
      case 'Normal':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return VercySidebarLayout(
      title: 'Productos',
      child: Container(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            Text(
              'Lista productos',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 24),

            // Barra de filtros
            _buildBarraFiltros(),
            SizedBox(height: 16),

            // Tabla de productos
            Expanded(child: _buildTabla()),
          ],
        ),
      ),
    );
  }

  Widget _buildBarraFiltros() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Row(
        children: [
          // Dropdown Tipo (PRODUCTO/SERVICIO)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade700),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _tipoFiltro,
                dropdownColor: AppTheme.cardBg,
                style: TextStyle(color: Colors.white, fontSize: 14),
                icon: Icon(Icons.arrow_drop_down, color: Colors.grey),
                items: [
                  DropdownMenuItem(value: 'PRODUCTO', child: Text('PRODUCTO')),
                  DropdownMenuItem(value: 'SERVICIO', child: Text('SERVICIO')),
                ],
                onChanged: (value) {
                  setState(() => _tipoFiltro = value ?? 'PRODUCTO');
                  _aplicarFiltros();
                },
              ),
            ),
          ),
          SizedBox(width: 12),

          // Código
          Expanded(
            child: _buildCampoFiltro(
              controller: _filtroCodigoController,
              hint: 'Código',
              onChanged: (_) => _aplicarFiltros(),
            ),
          ),
          SizedBox(width: 12),

          // Item (Nombre)
          Expanded(
            flex: 2,
            child: _buildCampoFiltro(
              controller: _filtroNombreController,
              hint: 'Item',
              onChanged: (_) => _aplicarFiltros(),
            ),
          ),
          SizedBox(width: 12),

          // Dropdown Categoría (Otros)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade700),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _categoriaSeleccionada,
                dropdownColor: AppTheme.cardBg,
                style: TextStyle(color: Colors.white, fontSize: 14),
                icon: Icon(Icons.arrow_drop_down, color: Colors.grey),
                hint: Text('Otros', style: TextStyle(color: Colors.grey)),
                items: [
                  DropdownMenuItem(value: 'TODAS', child: Text('Todos')),
                  ..._categorias.map((cat) {
                    return DropdownMenuItem(
                      value: cat.nombre,
                      child: Text(cat.nombre),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() => _categoriaSeleccionada = value ?? 'TODAS');
                  _aplicarFiltros();
                },
              ),
            ),
          ),

          Spacer(),

          // Botón Movimientos
          ElevatedButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, '/historial-inventario'),
            icon: Icon(Icons.swap_horiz, color: Colors.white),
            label: Text(
              'Movimientos',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampoFiltro({
    required TextEditingController controller,
    required String hint,
    required Function(String) onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade500),
        filled: true,
        fillColor: AppTheme.surfaceDark,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildTabla() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        children: [
          // Encabezado de la tabla
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                _buildEncabezadoColumna('Código', flex: 2),
                _buildEncabezadoColumna('Nombre', flex: 3),
                _buildEncabezadoColumna(
                  'Valor',
                  flex: 2,
                  align: TextAlign.right,
                ),
                _buildEncabezadoColumna(
                  'Inventario',
                  flex: 1,
                  align: TextAlign.center,
                ),
                _buildEncabezadoColumna(
                  'Costo',
                  flex: 2,
                  align: TextAlign.right,
                ),
                _buildEncabezadoColumna(
                  'Ubicaciones',
                  flex: 1,
                  align: TextAlign.center,
                ),
                _buildEncabezadoColumna(
                  'Estado\ninventario',
                  flex: 2,
                  align: TextAlign.center,
                ),
                _buildEncabezadoColumna('', flex: 1), // Acciones
              ],
            ),
          ),

          // Filas de la tabla
          Expanded(
            child: _productosFiltrados.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey.shade600,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No hay productos registrados',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _productosFiltrados.length,
                    itemBuilder: (context, index) {
                      final producto = _productosFiltrados[index];
                      return _buildFilaTabla(producto, index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEncabezadoColumna(
    String texto, {
    int flex = 1,
    TextAlign align = TextAlign.left,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        texto,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        textAlign: align,
      ),
    );
  }

  Widget _buildFilaTabla(Producto producto, int index) {
    final isEven = index % 2 == 0;
    final backgroundColor = isEven ? AppTheme.cardBg : AppTheme.surfaceDark;
    final estadoInventario = _getEstadoInventario(producto);
    final colorEstado = _getColorEstado(estadoInventario);

    // Código para mostrar
    String codigoMostrar = producto.codigo ?? producto.id;
    if (codigoMostrar.length > 12) {
      codigoMostrar = codigoMostrar.substring(0, 12);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade800, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Código (clickeable, verde)
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: () => _mostrarDetalleProducto(producto),
              child: Text(
                codigoMostrar.toUpperCase(),
                style: TextStyle(
                  color: AppTheme.success,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          // Nombre
          Expanded(
            flex: 3,
            child: Text(
              producto.nombre.toUpperCase(),
              style: TextStyle(color: Colors.white, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Valor (Precio)
          Expanded(
            flex: 2,
            child: Text(
              '\$ ${formatNumberWithDots(producto.precio)}',
              style: TextStyle(color: Colors.white, fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),

          // Inventario
          Expanded(
            flex: 1,
            child: Text(
              '${producto.almacen ?? 0},00',
              style: TextStyle(color: Colors.white, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),

          // Costo
          Expanded(
            flex: 2,
            child: Text(
              '\$ ${formatNumberWithDots(producto.costo)}',
              style: TextStyle(color: Colors.white, fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),

          // Ubicaciones
          Expanded(
            flex: 1,
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.success,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.grid_view, color: Colors.white, size: 18),
                  onPressed: () => _mostrarUbicaciones(producto),
                  tooltip: 'Ver ubicaciones',
                ),
              ),
            ),
          ),

          // Estado inventario
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colorEstado, width: 1.5),
                ),
                child: Text(
                  estadoInventario,
                  style: TextStyle(
                    color: colorEstado,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          // Acciones (Ver)
          Expanded(
            flex: 1,
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.success,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.visibility, color: Colors.white, size: 18),
                  onPressed: () => _mostrarDetalleProducto(producto),
                  tooltip: 'Ver detalles',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDetalleProducto(Producto producto) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Row(
          children: [
            Icon(Icons.inventory_2, color: AppTheme.primary),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                producto.nombre,
                style: TextStyle(color: Colors.white, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Container(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetalleItem('Código', producto.codigo ?? producto.id),
                _buildDetalleItem('Nombre', producto.nombre),
                _buildDetalleItem(
                  'Precio Venta',
                  '\$ ${formatNumberWithDots(producto.precio)}',
                ),
                _buildDetalleItem(
                  'Costo',
                  '\$ ${formatNumberWithDots(producto.costo)}',
                ),
                _buildDetalleItem(
                  'Utilidad',
                  '\$ ${formatNumberWithDots(producto.utilidad)}',
                ),
                _buildDetalleItem('Inventario', '${producto.almacen ?? 0}'),
                _buildDetalleItem(
                  'Inv. Bajo',
                  '${producto.inventarioBajo ?? 5}',
                ),
                _buildDetalleItem(
                  'Inv. Óptimo',
                  '${producto.inventarioOptimo ?? 20}',
                ),
                _buildDetalleItem('Estado', _getEstadoInventario(producto)),
                if (producto.categoria != null)
                  _buildDetalleItem('Categoría', producto.categoria!.nombre),
                if (producto.marca != null && producto.marca!.isNotEmpty)
                  _buildDetalleItem('Marca', producto.marca!),
                if (producto.codigoBarras != null &&
                    producto.codigoBarras!.isNotEmpty)
                  _buildDetalleItem('Código Barras', producto.codigoBarras!),
                if (producto.nombreProveedor != null &&
                    producto.nombreProveedor!.isNotEmpty)
                  _buildDetalleItem('Proveedor', producto.nombreProveedor!),
                if (producto.descripcion != null &&
                    producto.descripcion!.isNotEmpty)
                  _buildDetalleItem('Descripción', producto.descripcion!),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar', style: TextStyle(color: AppTheme.primary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/productos');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
            child: Text('Editar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalleItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _mostrarUbicaciones(Producto producto) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Row(
          children: [
            Icon(Icons.location_on, color: AppTheme.primary),
            SizedBox(width: 12),
            Text('Ubicaciones', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Container(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                producto.nombre,
                style: TextStyle(
                  color: AppTheme.success,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 16),
              _buildUbicacionItem('Almacén', '${producto.almacen ?? 0}'),
              _buildUbicacionItem('Bodega', '${producto.bodega ?? 0}'),
              if (producto.ubicacion1 != null &&
                  producto.ubicacion1!.isNotEmpty)
                _buildUbicacionItem('Ubicación 1', producto.ubicacion1!),
              if (producto.ubicacion2 != null &&
                  producto.ubicacion2!.isNotEmpty)
                _buildUbicacionItem('Ubicación 2', producto.ubicacion2!),
              if (producto.ubicacion3 != null &&
                  producto.ubicacion3!.isNotEmpty)
                _buildUbicacionItem('Ubicación 3', producto.ubicacion3!),
              if (producto.ubicacion4 != null &&
                  producto.ubicacion4!.isNotEmpty)
                _buildUbicacionItem('Ubicación 4', producto.ubicacion4!),
              if (producto.localizacion != null &&
                  producto.localizacion!.isNotEmpty)
                _buildUbicacionItem('Localización', producto.localizacion!),
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

  Widget _buildUbicacionItem(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade400)),
          Text(
            value,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
