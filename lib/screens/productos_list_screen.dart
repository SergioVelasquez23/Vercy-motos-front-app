import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:barcode/barcode.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../services/producto_service.dart';
import '../providers/datos_cache_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/productos/tabs/tab_basico_producto.dart';
import '../widgets/productos/tabs/tab_precios_producto.dart';
import '../widgets/productos/tabs/tab_clasificacion_producto.dart';
import '../widgets/productos/tabs/tab_inventario_producto.dart';
import '../utils/format_utils.dart';
import '../utils/file_download_helper.dart';
import '../utils/logger.dart';
import '../utils/pagination_mixin.dart';
import '../utils/snackbar_helper.dart';
import '../utils/dialogs_helper.dart';
import '../widgets/common/screen_header.dart';
import '../widgets/horizontal_scroll_table.dart';
import '../utils/api_error.dart';

class ProductosListScreen extends StatefulWidget {
  const ProductosListScreen({super.key});

  @override
  _ProductosListScreenState createState() => _ProductosListScreenState();
}

class _ProductosListScreenState extends State<ProductosListScreen> with PaginacionMixin<ProductosListScreen> {
  final ProductoService _productoService = ProductoService();

  // Rol asesor: solo puede ver la lista y las cantidades, no crear, editar,
  // eliminar productos ni cargar cambios masivos por Excel.
  bool get _esAsesor => Provider.of<UserProvider>(context, listen: false).isAsesor;

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

  DatosCacheProvider? _cacheProvider;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newProvider = Provider.of<DatosCacheProvider>(context, listen: false);
    if (_cacheProvider != newProvider) {
      _cacheProvider?.removeListener(_onCacheActualizado);
      _cacheProvider = newProvider;
      _cacheProvider!.addListener(_onCacheActualizado);
    }
  }

  @override
  void dispose() {
    _cacheProvider?.removeListener(_onCacheActualizado);
    _filtroCodigoController.dispose();
    _filtroNombreController.dispose();
    super.dispose();
  }

  void _onCacheActualizado() {
    if (!mounted) return;
    final productosCache = _cacheProvider?.productos;
    if (productosCache != null && productosCache.isNotEmpty) {
      setState(() {
        _productos = List.from(productosCache);
        _aplicarFiltros();
      });
    }
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      // ⚡ OPTIMIZACIÓN: Cargar en paralelo + sin imágenes
      final results = await Future.wait([
        _productoService.obtenerProductosParaTraslados(), // ⚡ Sin imágenes
        _productoService.getCategorias(),
      ], eagerError: true);

      final productos = results[0] as List<Producto>;
      final categorias = results[1] as List<Categoria>;

      // 🔍 LOG: Verificar valores de inventario recibidos del endpoint /ligero
      appLog('📦 Productos cargados: ${productos.length}');
      for (var i = 0; i < productos.length && i < 5; i++) {
        final p = productos[i];
        appLog('   - ${p.nombre}: Almacén=${p.almacen}, Bodega=${p.bodega}');
      }

      setState(() {
        _productos = productos;
        _categorias = categorias;
        _aplicarFiltros();
      });
    } catch (e) {
      showErrorSnackBar(context, 'Error al cargar datos: ${errorMessage(e)}');
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
      resetPagina();
    });
  }

  String _getEstadoInventario(Producto producto) {
    // Calcular stock total sumando almacén + bodega
    final stockAlmacen = producto.almacen ?? 0;
    final stockBodega = producto.bodega ?? 0;
    final inventarioTotal = stockAlmacen + stockBodega;
    
    final bajo = producto.inventarioBajo ?? 5;
    final optimo = producto.inventarioOptimo ?? 20;

    if (inventarioTotal <= 0) return 'Sin Stock';
    if (inventarioTotal <= bajo) return 'Bajo';
    if (inventarioTotal >= optimo) return 'Óptimo';
    return 'Normal';
  }
  
  // Obtener el stock total para mostrar en la tabla
  int _getStockTotal(Producto producto) {
    return (producto.almacen ?? 0) + (producto.bodega ?? 0);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScreenHeader(
          icon: Icons.inventory_2,
          title: 'Lista productos',
          badge: '${_productosFiltrados.length}',
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Excel',
              onSelected: (value) {
                if (value.startsWith('carga-')) {
                  final tipo = value.replaceFirst('carga-', '');
                  _mostrarCargaMasivaProductos(tipo: tipo);
                } else if (value.startsWith('descarga-')) {
                  final tipo = value.replaceFirst('descarga-', '');
                  _descargarProductosExcel(tipo: tipo);
                }
              },
              itemBuilder: (BuildContext context) => [
                // La carga masiva modifica cantidades/productos en bloque —
                // el rol asesor solo puede ver y descargar, no cargar cambios.
                if (!_esAsesor) ...[
                  PopupMenuItem<String>(
                    value: 'carga-bodega',
                    child: Row(children: [
                      Icon(Icons.cloud_upload, color: AppTheme.success),
                      SizedBox(width: 12),
                      Text('Carga - Bodega'),
                    ]),
                  ),
                  PopupMenuItem<String>(
                    value: 'carga-almacen',
                    child: Row(children: [
                      Icon(Icons.cloud_upload, color: AppTheme.info),
                      SizedBox(width: 12),
                      Text('Carga - Almacén'),
                    ]),
                  ),
                  PopupMenuItem<String>(
                    value: 'carga-ambos',
                    child: Row(children: [
                      Icon(Icons.cloud_upload, color: Colors.purple),
                      SizedBox(width: 12),
                      Text('Carga - Ambos'),
                    ]),
                  ),
                  const PopupMenuDivider(),
                ],
                PopupMenuItem<String>(
                  value: 'descarga-bodega',
                  child: Row(children: [
                    Icon(Icons.download, color: Colors.orange),
                    SizedBox(width: 12),
                    Text('Descargar - Bodega'),
                  ]),
                ),
                PopupMenuItem<String>(
                  value: 'descarga-almacen',
                  child: Row(children: [
                    Icon(Icons.download, color: Colors.deepOrange),
                    SizedBox(width: 12),
                    Text('Descargar - Almacén'),
                  ]),
                ),
                PopupMenuItem<String>(
                  value: 'descarga-ambos',
                  child: Row(children: [
                    Icon(Icons.download, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Descargar - Ambos'),
                  ]),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.more_vert, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text('Excel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            if (!_esAsesor)
              ScreenHeaderAction.primary(
                icon: Icons.add,
                label: 'Nuevo Producto',
                mobileLabel: 'Nuevo',
                onPressed: _crearNuevoProducto,
              ),
          ],
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(context.isMobile ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildBarraFiltros(),
                const SizedBox(height: 16),
                Expanded(child: _buildTabla()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBarraFiltros() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Row(
        children: [
          // Dropdown Tipo (PRODUCTO/SERVICIO)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade700),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _tipoFiltro,
                dropdownColor: Theme.of(context).colorScheme.surface,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
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
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade700),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _categoriaSeleccionada,
                dropdownColor: Theme.of(context).colorScheme.surface,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
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
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade500),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
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

  // Anchos fijos de columna (px): la tabla se vuelve horizontalmente
  // desplazable en vez de comprimir el contenido en pantallas angostas.
  static const double _colCodigo = 110;
  static const double _colNombre = 220;
  static const double _colValor = 100;
  static const double _colInventario = 70;
  static const double _colCosto = 100;
  static const double _colUbicaciones = 70;
  static const double _colEstado = 110;
  static const double _colAcciones = 190;
  static const double _anchoColumnas = _colCodigo +
      _colNombre +
      _colValor +
      _colInventario +
      _colCosto +
      _colUbicaciones +
      _colEstado +
      _colAcciones;
  static const double _anchoTabla = _anchoColumnas + 32; // + padding horizontal del Container

  Widget _buildTabla() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        children: [
          Expanded(
            child: HorizontalScrollTable(
              contentWidth: _anchoTabla,
              child: Column(
                children: [
                  // Encabezado de la tabla
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Row(
                      children: [
                        buildEncabezadoColumnaFija(context, 'Código', width: _colCodigo),
                        buildEncabezadoColumnaFija(context, 'Nombre', width: _colNombre),
                        buildEncabezadoColumnaFija(context, 'Valor', width: _colValor, align: TextAlign.right),
                        buildEncabezadoColumnaFija(context, 'Inventario', width: _colInventario, align: TextAlign.center),
                        buildEncabezadoColumnaFija(context, 'Costo', width: _colCosto, align: TextAlign.right),
                        buildEncabezadoColumnaFija(context, 'Ubicaciones', width: _colUbicaciones, align: TextAlign.center),
                        buildEncabezadoColumnaFija(context, 'Estado\ninventario', width: _colEstado, align: TextAlign.center),
                        buildEncabezadoColumnaFija(context, 'Acciones', width: _colAcciones),
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
                            itemCount: paginarLista(_productosFiltrados).length,
                            itemBuilder: (context, index) {
                              final producto = paginarLista(_productosFiltrados)[index];
                              return _buildFilaTabla(producto, index);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          buildPaginacion(
            totalItems: _productosFiltrados.length,
            accentColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildFilaTabla(Producto producto, int index) {
    final isEven = index % 2 == 0;
    final backgroundColor = isEven ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.surface;
    final estadoInventario = _getEstadoInventario(producto);
    final colorEstado = _getColorEstado(estadoInventario);

    // Código para mostrar
    String codigoMostrar =
        (producto.codigo != null && producto.codigo!.isNotEmpty)
        ? producto.codigo!
        : 'SIN CÓDIGO';
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
          SizedBox(
            width: _colCodigo,
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

          // Nombre (con scroll horizontal propio para ver el nombre completo)
          SizedBox(
            width: _colNombre,
            child: Scrollbar(
              thumbVisibility: false,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  producto.nombre.toUpperCase(),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                  softWrap: false,
                ),
              ),
            ),
          ),

          // Valor (Precio)
          SizedBox(
            width: _colValor,
            child: Text(
              '\$ ${formatNumberWithDots(producto.precio)}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),

          // Inventario (total: almacén + bodega)
          SizedBox(
            width: _colInventario,
            child: Tooltip(
              message:
                  'Almacén: ${producto.almacen ?? 0}\nBodega: ${producto.bodega ?? 0}',
              child: Text(
                '${_getStockTotal(producto)}',
                style: TextStyle(
                  color: _getStockTotal(producto) > 0
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.red,
                  fontSize: 13,
                  fontWeight: _getStockTotal(producto) == 0
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Costo
          SizedBox(
            width: _colCosto,
            child: Text(
              '\$ ${formatNumberWithDots(producto.costo)}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),

          // Ubicaciones
          SizedBox(
            width: _colUbicaciones,
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
          SizedBox(
            width: _colEstado,
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

          // Acciones
          SizedBox(
            width: _colAcciones,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                  Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.success,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.visibility, color: Colors.white, size: 16),
                      onPressed: () => _mostrarDetalleProducto(producto),
                      tooltip: 'Ver detalles',
                    ),
                  ),
                  if (!_esAsesor)
                    Container(
                      width: 32,
                      height: 32,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.edit, color: Colors.white, size: 16),
                        onPressed: () => _editarProducto(producto),
                        tooltip: 'Editar producto',
                      ),
                    ),
                  Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade600,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.qr_code, color: Colors.white, size: 16),
                      onPressed: () =>
                          _mostrarDialogoImprimirCodigoBarras(producto),
                      tooltip: 'Imprimir código de barras',
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.history, color: Colors.white, size: 16),
                      onPressed: () => _mostrarMovimientosStock(producto),
                      tooltip: 'Movimientos de stock',
                    ),
                  ),
                  if (!_esAsesor)
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.delete, color: Colors.white, size: 16),
                        onPressed: () => _eliminarProducto(producto),
                        tooltip: 'Eliminar producto',
                      ),
                    ),
                ],
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
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Row(
          children: [
            Icon(Icons.inventory_2, color: AppTheme.primary),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                producto.nombre,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18),
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
                _buildDetalleItem(
                  'Código',
                  (producto.codigo != null && producto.codigo!.isNotEmpty)
                      ? producto.codigo!
                      : 'SIN CÓDIGO',
                ),
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
            child: Text(value, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          ),
        ],
      ),
    );
  }

  void _mostrarUbicaciones(Producto producto) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Row(
          children: [
            Icon(Icons.location_on, color: AppTheme.primary),
            SizedBox(width: 12),
            Text('Ubicaciones', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade400)),
          Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Funciones para manejo de CRUD
  void _crearNuevoProducto() {
    _mostrarFormularioProductoCompleto();
  }

  void _editarProducto(Producto producto) {
    // Cargar el producto completo del servidor antes de editar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text('Cargando producto...'),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 10),
      ),
    );

    // Guardar los valores locales que ya tenemos (productoOServicio puede venir correcto de la lista)
    final productoOServicioLocal = producto.productoOServicio;
    appLog('🔍 [_editarProducto] productoOServicio local: "$productoOServicioLocal"');

    _productoService
        .getProducto(producto.id)
        .then((productoCompleto) {
          if (productoCompleto != null) {
            ScaffoldMessenger.of(context).clearSnackBars();
            // ✅ FIX: Si el producto del servidor no tiene productoOServicio pero el local sí, preservar el local
            Producto productoFinal = productoCompleto;
            if ((productoCompleto.productoOServicio == null || productoCompleto.productoOServicio!.isEmpty) 
                && productoOServicioLocal != null && productoOServicioLocal.isNotEmpty) {
              productoFinal = productoCompleto.copyWith(
                productoOServicio: productoOServicioLocal,
              );
              appLog('🔍 [_editarProducto] productoOServicio restaurado del local: "$productoOServicioLocal"');
            }
            appLog('🔍 [_editarProducto] productoFinal.productoOServicio: "${productoFinal.productoOServicio}"');
            _mostrarFormularioProductoCompleto(producto: productoFinal);
          } else {
            ScaffoldMessenger.of(context).clearSnackBars();
            showErrorSnackBar(context, 'No se pudo cargar el producto');
          }
        })
        .catchError((e) {
          ScaffoldMessenger.of(context).clearSnackBars();
          showErrorSnackBar(context, 'Error: ${errorMessage(e)}');
        });
  }

  void _mostrarFormularioProductoCompleto({Producto? producto}) {
    final bool isEditing = producto != null;

    // Controladores para el formulario - INFORMACIÓN BÁSICA
    final nombreController = TextEditingController(
      text: isEditing ? producto.nombre : '',
    );
    final descripcionController = TextEditingController(
      text: isEditing ? (producto.descripcion ?? '') : '',
    );
    final codigoController = TextEditingController(
      text: isEditing
          ? ((producto.codigo != null && producto.codigo!.isNotEmpty)
                ? producto.codigo!
                : '')
          : '',
    );
    final codigoBarrasController = TextEditingController(
      text: isEditing ? (producto.codigoBarras ?? '') : '',
    );

    // PRECIOS
    final precioController = TextEditingController(
      text: isEditing ? producto.precio.toString() : '',
    );
    final costoController = TextEditingController(
      text: isEditing ? producto.costo.toString() : '',
    );
    final porcentajeImpuestoController = TextEditingController(
      text: isEditing ? (producto.porcentajeImpuesto?.toString() ?? '') : '',
    );

    // PRECIOS OPCIONALES
    final precioVentaOpc1Controller = TextEditingController(
      text: isEditing ? (producto.precioVentaOpc1?.toString() ?? '') : '',
    );
    final precioVentaOpc2Controller = TextEditingController(
      text: isEditing ? (producto.precioVentaOpc2?.toString() ?? '') : '',
    );
    final precioVentaOpc3Controller = TextEditingController(
      text: isEditing ? (producto.precioVentaOpc3?.toString() ?? '') : '',
    );

    // CLASIFICACIÓN
    final marcaController = TextEditingController(
      text: isEditing ? (producto.marca ?? '') : '',
    );
    final tipoProductoNombreController = TextEditingController(
      text: isEditing ? (producto.tipoProductoNombre ?? '') : '',
    );
    final lineaProductoNombreController = TextEditingController(
      text: isEditing ? (producto.lineaProductoNombre ?? '') : '',
    );
    final claseProductoNombreController = TextEditingController(
      text: isEditing ? (producto.claseProductoNombre ?? '') : '',
    );

    // PROVEEDOR
    final nombreProveedorController = TextEditingController(
      text: isEditing ? (producto.nombreProveedor ?? '') : '',
    );
    final nitProveedorController = TextEditingController(
      text: isEditing ? (producto.nitProveedor ?? '') : '',
    );

    // INVENTARIO
    final almacenController = TextEditingController(
      text: isEditing ? (producto.almacen?.toString() ?? '0') : '0',
    );
    final bodegaController = TextEditingController(
      text: isEditing ? (producto.bodega?.toString() ?? '0') : '0',
    );
    final inventarioBajoController = TextEditingController(
      text: isEditing ? (producto.inventarioBajo?.toString() ?? '5') : '5',
    );
    final inventarioOptimoController = TextEditingController(
      text: isEditing ? (producto.inventarioOptimo?.toString() ?? '20') : '20',
    );

    // UBICACIONES
    final ubicacion1Controller = TextEditingController(
      text: isEditing ? (producto.ubicacion1 ?? '') : '',
    );
    final ubicacion2Controller = TextEditingController(
      text: isEditing ? (producto.ubicacion2 ?? '') : '',
    );
    final ubicacion3Controller = TextEditingController(
      text: isEditing ? (producto.ubicacion3 ?? '') : '',
    );
    final ubicacion4Controller = TextEditingController(
      text: isEditing ? (producto.ubicacion4 ?? '') : '',
    );
    final localizacionController = TextEditingController(
      text: isEditing ? (producto.localizacion ?? '') : '',
    );

    // Estados para dropdowns - usar listas para mutabilidad
    String? categoriaSeleccionada = isEditing ? producto.categoria?.id : null;
    final tipoSeleccionado = [isEditing
        ? (producto.productoOServicio?.toUpperCase() ?? 'PRODUCTO')
        : 'PRODUCTO'];
    appLog('🔍 [DIALOG INIT] tipoSeleccionado inicial: "${tipoSeleccionado[0]}"');
    appLog('🔍 [DIALOG INIT] producto.productoOServicio: "${producto?.productoOServicio}"');
    final controlInventarioSeleccionado = [isEditing
        ? (producto.controlInventario ?? 'SI')
        : 'SI'];

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit : Icons.add_box,
                    color: AppTheme.primary,
                  ),
                  SizedBox(width: 12),
                  Text(
                    isEditing ? 'Editar Producto' : 'Nuevo Producto',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  ),
                ],
              ),
              content: Container(
                width: 800,
                height: 600,
                child: DefaultTabController(
                  length: 4,
                  child: Column(
                    children: [
                      TabBar(
                        indicatorColor: AppTheme.primary,
                        labelColor: AppTheme.primary,
                        unselectedLabelColor: Colors.grey.shade800,
                        tabs: [
                          Tab(text: 'Básico'),
                          Tab(text: 'Precios'),
                          Tab(text: 'Clasificación'),
                          Tab(text: 'Inventario'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Tab 1: Información Básica
                            TabBasicoProducto(
                              nombreController: nombreController,
                              descripcionController: descripcionController,
                              codigoController: codigoController,
                              codigoBarrasController: codigoBarrasController,
                              tipoSeleccionado: tipoSeleccionado[0],
                              categoriaSeleccionada: categoriaSeleccionada,
                              setState: setDialogState,
                              tipoSeleccionadoList: tipoSeleccionado,
                              categorias: _categorias,
                              onCategoriaChanged: (value) {
                                setDialogState(() {
                                  categoriaSeleccionada = value;
                                });
                              },
                            ),
                            // Tab 2: Precios
                            TabPreciosProducto(
                              precioController: precioController,
                              costoController: costoController,
                              porcentajeImpuestoController: porcentajeImpuestoController,
                              precioVentaOpc1Controller: precioVentaOpc1Controller,
                              precioVentaOpc2Controller: precioVentaOpc2Controller,
                              precioVentaOpc3Controller: precioVentaOpc3Controller,
                            ),
                            // Tab 3: Clasificación y Proveedor
                            TabClasificacionProducto(
                              marcaController: marcaController,
                              tipoProductoNombreController: tipoProductoNombreController,
                              lineaProductoNombreController: lineaProductoNombreController,
                              claseProductoNombreController: claseProductoNombreController,
                              nombreProveedorController: nombreProveedorController,
                              nitProveedorController: nitProveedorController,
                            ),
                            // Tab 4: Inventario y Ubicaciones
                            TabInventarioProducto(
                              almacenController: almacenController,
                              bodegaController: bodegaController,
                              inventarioBajoController: inventarioBajoController,
                              inventarioOptimoController: inventarioOptimoController,
                              ubicacion1Controller: ubicacion1Controller,
                              ubicacion2Controller: ubicacion2Controller,
                              ubicacion3Controller: ubicacion3Controller,
                              ubicacion4Controller: ubicacion4Controller,
                              localizacionController: localizacionController,
                              controlInventarioSeleccionado: controlInventarioSeleccionado[0],
                              setState: setDialogState,
                              controlInventarioSeleccionadoList: controlInventarioSeleccionado,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Validación básica
                    if (nombreController.text.trim().isEmpty ||
                        precioController.text.trim().isEmpty ||
                        costoController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Por favor completa todos los campos obligatorios (Nombre, Precio, Costo)',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // ✅ Primero guardar el producto y actualizar la lista
                    appLog('🔍 [GUARDAR] tipoSeleccionado antes de guardar: "${tipoSeleccionado[0]}"');
                    final guardadoExitoso = await _guardarProductoCompleto(
                      producto: producto,
                      // Información básica
                      nombre: nombreController.text.trim(),
                      descripcion: descripcionController.text.trim(),
                      codigo: codigoController.text.trim(),
                      codigoBarras: codigoBarrasController.text.trim(),
                      tipo: tipoSeleccionado[0],
                      // Precios
                      precio: double.tryParse(precioController.text) ?? 0,
                      costo: double.tryParse(costoController.text) ?? 0,
                      porcentajeImpuesto: double.tryParse(
                        porcentajeImpuestoController.text,
                      ),
                      precioVentaOpc1: double.tryParse(
                        precioVentaOpc1Controller.text,
                      ),
                      precioVentaOpc2: double.tryParse(
                        precioVentaOpc2Controller.text,
                      ),
                      precioVentaOpc3: double.tryParse(
                        precioVentaOpc3Controller.text,
                      ),
                      // Clasificación
                      categoriaId: categoriaSeleccionada,
                      marca: marcaController.text.trim(),
                      tipoProductoNombre: tipoProductoNombreController.text
                          .trim(),
                      lineaProductoNombre: lineaProductoNombreController.text
                          .trim(),
                      claseProductoNombre: claseProductoNombreController.text
                          .trim(),
                      // Proveedor
                      nombreProveedor: nombreProveedorController.text.trim(),
                      nitProveedor: nitProveedorController.text.trim(),
                      // Inventario
                      controlInventario: controlInventarioSeleccionado[0],
                      inventarioBajo:
                          int.tryParse(inventarioBajoController.text) ?? 5,
                      inventarioOptimo:
                          int.tryParse(inventarioOptimoController.text) ?? 20,
                      almacen: int.tryParse(almacenController.text) ?? 0,
                      bodega: int.tryParse(bodegaController.text) ?? 0,
                      // Ubicaciones
                      ubicacion1: ubicacion1Controller.text.trim(),
                      ubicacion2: ubicacion2Controller.text.trim(),
                      ubicacion3: ubicacion3Controller.text.trim(),
                      ubicacion4: ubicacion4Controller.text.trim(),
                      localizacion: localizacionController.text.trim(),
                    );
                    
                    // ✅ Cerrar el diálogo solo si se guardó exitosamente
                    if (guardadoExitoso && context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isEditing ? 'Actualizar' : 'Crear'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _mostrarFormularioProducto({Producto? producto}) {
    final bool isEditing = producto != null;

    // Controladores para el formulario
    final nombreController = TextEditingController(
      text: isEditing ? producto.nombre : '',
    );
    final descripcionController = TextEditingController(
      text: isEditing ? (producto.descripcion ?? '') : '',
    );
    final codigoController = TextEditingController(
      text: isEditing ? (producto.codigo ?? '') : '',
    );
    final precioController = TextEditingController(
      text: isEditing ? producto.precio.toString() : '',
    );
    final costoController = TextEditingController(
      text: isEditing ? producto.costo.toString() : '',
    );

    // Estado para categoría seleccionada
    String? categoriaSeleccionada = isEditing ? producto.categoria?.id : null;
    String tipoSeleccionado = isEditing
        ? (producto.productoOServicio?.toUpperCase() ?? 'PRODUCTO')
        : 'PRODUCTO';

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit : Icons.add_box,
                    color: AppTheme.primary,
                  ),
                  SizedBox(width: 12),
                  Text(
                    isEditing ? 'Editar Producto' : 'Nuevo Producto',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  ),
                ],
              ),
              content: Container(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Tipo de producto
                      DropdownButtonFormField<String>(
                        value: tipoSeleccionado,
                        dropdownColor: Theme.of(context).colorScheme.surface,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Tipo',
                          labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'PRODUCTO',
                            child: Text('PRODUCTO'),
                          ),
                          DropdownMenuItem(
                            value: 'SERVICIO',
                            child: Text('SERVICIO'),
                          ),
                        ],
                        onChanged: (value) {
                          appLog('🔍 [DROPDOWN LIST] Cambio detectado: "$value"');
                          setDialogState(
                            () {
                              tipoSeleccionado = value ?? 'PRODUCTO';
                              appLog('🔍 [DROPDOWN LIST] tipoSeleccionado actualizado: "$tipoSeleccionado"');
                            },
                          );
                        },
                      ),
                      SizedBox(height: 16),

                      // Código
                      TextField(
                        controller: codigoController,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Código',
                          labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                          border: OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Nombre
                      TextField(
                        controller: nombreController,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Nombre *',
                          labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                          border: OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Descripción
                      TextField(
                        controller: descripcionController,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Descripción',
                          labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                          border: OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Categoría
                      DropdownButtonFormField<String>(
                        value: categoriaSeleccionada,
                        dropdownColor: Theme.of(context).colorScheme.surface,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Categoría',
                          labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text('Sin categoría'),
                          ),
                          ..._categorias.map((categoria) {
                            return DropdownMenuItem(
                              value: categoria.id,
                              child: Text(categoria.nombre),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setDialogState(() => categoriaSeleccionada = value);
                        },
                      ),
                      SizedBox(height: 16),

                      // Precios en fila
                      Row(
                        children: [
                          // Costo
                          Expanded(
                            child: TextField(
                              controller: costoController,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Costo *',
                                labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                                border: OutlineInputBorder(),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.grey),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          // Precio
                          Expanded(
                            child: TextField(
                              controller: precioController,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Precio *',
                                labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                                border: OutlineInputBorder(),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.grey),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Validación básica
                    if (nombreController.text.trim().isEmpty ||
                        precioController.text.trim().isEmpty ||
                        costoController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Por favor completa todos los campos obligatorios',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    Navigator.pop(context);
                    appLog('🔍 [GUARDA PRODUCTO LIST] tipo a guardar: "$tipoSeleccionado"');
                    await _guardarProducto(
                      producto: producto,
                      nombre: nombreController.text.trim(),
                      descripcion: descripcionController.text.trim(),
                      codigo: codigoController.text.trim(),
                      precio: double.tryParse(precioController.text) ?? 0,
                      costo: double.tryParse(costoController.text) ?? 0,
                      categoriaId: categoriaSeleccionada,
                      tipo: tipoSeleccionado,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isEditing ? 'Actualizar' : 'Crear'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _guardarProducto({
    Producto? producto,
    required String nombre,
    required String descripcion,
    required String codigo,
    required double precio,
    required double costo,
    String? categoriaId,
    required String tipo,
  }) async {
    try {
      appLog('🔍 [_guardarProducto] Parámetro tipo recibido: "$tipo"');
      final service = ProductoService();

      // Encontrar la categoría seleccionada
      Categoria? categoriaSeleccionada;
      if (categoriaId != null) {
        categoriaSeleccionada = _categorias.firstWhere(
          (cat) => cat.id == categoriaId,
          orElse: () => Categoria(id: categoriaId, nombre: 'Unknown'),
        );
      }

      if (producto != null) {
        // Editar producto existente
        appLog('🔍 [_guardarProducto] Editando producto existente');
        appLog('🔍 [_guardarProducto] tipo.toLowerCase(): "${tipo.toLowerCase()}"');
        final productoActualizado = Producto(
          id: producto.id,
          nombre: nombre,
          descripcion: descripcion.isNotEmpty ? descripcion : null,
          codigo: codigo.isNotEmpty ? codigo : null,
          precio: precio,
          costo: costo,
          categoria: categoriaSeleccionada,
          productoOServicio: tipo.toLowerCase(),
          almacen: producto.almacen,
          bodega: producto.bodega,
          inventarioBajo: producto.inventarioBajo,
          inventarioOptimo: producto.inventarioOptimo,
          impuestos: producto.impuestos,
          utilidad: producto.utilidad,
        );
        
        appLog('🔍 [_guardarProducto] productoActualizado.productoOServicio: "${productoActualizado.productoOServicio}"');

        await service.updateProducto(productoActualizado);

        showSuccessSnackBar(context, 'Producto actualizado correctamente');
      } else {
        // Crear nuevo producto
        final nuevoProducto = Producto(
          id: '', // El backend asignará el ID
          nombre: nombre,
          descripcion: descripcion.isNotEmpty ? descripcion : null,
          codigo: codigo.isNotEmpty ? codigo : null,
          precio: precio,
          costo: costo,
          categoria: categoriaSeleccionada,
          productoOServicio: tipo.toLowerCase(),
          almacen: 0,
          bodega: 0,
          inventarioBajo: 5,
          inventarioOptimo: 20,
          impuestos: 0,
          utilidad: precio - costo, // Calcular utilidad como diferencia
        );

        await service.addProducto(nuevoProducto);

        showSuccessSnackBar(context, 'Producto creado correctamente');
      }

      _cargarDatos(); // Recargar la lista
    } catch (e) {
      showErrorSnackBar(context, 'Error al guardar producto: ${errorMessage(e)}');
    }
  }

  void _eliminarProducto(Producto producto) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 12),
              Text(
                'Confirmar eliminación',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Estás seguro de que deseas eliminar este producto?',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Producto: ${producto.nombre}',
                      style: TextStyle(
                        color: AppTheme.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (producto.codigo?.isNotEmpty ?? false)
                      Text(
                        'Código: ${producto.codigo}',
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Esta acción no se puede deshacer.',
                style: TextStyle(color: Colors.red.shade300),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _confirmarEliminacion(producto);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmarEliminacion(Producto producto) async {
    try {
      final service = ProductoService();
      await service.deleteProducto(producto.id!);

      showSuccessSnackBar(context, 'Producto eliminado correctamente');

      _cargarDatos(); // Recargar la lista
    } catch (e) {
      showErrorSnackBar(context, 'Error al eliminar producto: ${errorMessage(e)}');
    }
  }

  void _mostrarCargaMasivaProductos({required String tipo}) {
    final esBodega = tipo == 'bodega';
    final esAlmacen = tipo == 'almacen';
    final esAmbos = tipo == 'ambos';

    final titulo = esAmbos
        ? 'Carga Masiva - Bodega y Almacén'
        : esBodega
        ? 'Carga Masiva - Bodega'
        : 'Carga Masiva - Almacén';
    
    final ultimaColumna = esAmbos
        ? 'BODEGA y ALMACEN'
        : esBodega
        ? 'BODEGA'
        : 'ALMACEN';
    
    // 🔀 Modo de carga: 'actualizar' (sobrescribe precio/costo/inventario) o
    // 'sumar' (mantiene precio/costo del Excel pero SUMA la cantidad al
    // inventario actual en vez de reemplazarlo). Solo aplica a productos que
    // ya existen; los nuevos siempre se crean con lo que traiga el Excel.
    String modoCarga = 'actualizar';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Row(
            children: [
              Icon(Icons.upload_file, color: AppTheme.primary),
              SizedBox(width: 12),
              Text(
                titulo,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
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
                  Text(
                    'Selecciona un archivo Excel (.xlsx) con los datos de los productos.\nÚltima columna: $ultimaColumna',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Si el producto ya existe:',
                    style: TextStyle(
                      color: AppTheme.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  RadioListTile<String>(
                    value: 'actualizar',
                    groupValue: modoCarga,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppTheme.primary,
                    onChanged: (v) => setDialogState(() => modoCarga = v!),
                    title: Text(
                      'Actualizar inventario, precio y costo',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                    ),
                    subtitle: Text(
                      'Reemplaza el inventario, precio y costo por lo que traiga el Excel',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                    ),
                  ),
                  RadioListTile<String>(
                    value: 'sumar',
                    groupValue: modoCarga,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppTheme.primary,
                    onChanged: (v) => setDialogState(() => modoCarga = v!),
                    title: Text(
                      'Sumar al inventario actual',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                    ),
                    subtitle: Text(
                      'Suma la cantidad del Excel al inventario que ya hay (precio y costo se actualizan igual)',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                    ),
                  ),
                  RadioListTile<String>(
                    value: 'solo_precio',
                    groupValue: modoCarga,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppTheme.primary,
                    onChanged: (v) => setDialogState(() => modoCarga = v!),
                    title: Text(
                      'Solo actualizar precio',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                    ),
                    subtitle: Text(
                      'No toca el inventario ni otros datos. Ignora las filas de productos que no existan',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Columnas requeridas (en orden):',
                          style: TextStyle(
                            color: AppTheme.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '1. CODIGO*\n'
                          '2. NOMBRE*\n'
                          '3. CANTIDAD\n'
                          '4. UNIDAD MEDIDA\n'
                          '5. PRECIO UNITARIO\n'
                          '6. COSTO PROMEDIO UNITARIO\n'
                          '7. COSTO TOTAL\n'
                          '8. OPORTUNIDAD DE GANANCIA\n'
                          '9. % UTILIDAD\n'
                          '10. TIPO IMPUESTO\n'
                          '11. PORCENTAJE IMPUESTO\n'
                          '12. TIPO LINEA\n'
                          '13. CLASE\n'
                          '14. SUBCLASE\n'
                          '15. ILIMITADO\n'
                          '16. INVENTARIO BAJO\n'
                          '17. INVENTARIO OPTIMO\n'
                          '18. MARCA\n'
                          '19. PROVEEDOR\n'
                          '20. ESTADO\n'
                          '21. ESTADO INV\n'
                          '22. LISTA PRECIO 1\n'
                          '23. LISTA PRECIO 2\n'
                          '24. LISTA PRECIO 3\n'
                          '25. LISTA PRECIO 4\n'
                          '26. LISTA PRECIO 5\n'
                          '27. COD. BARRAS\n'
                          '28. $ultimaColumna*',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 11,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '* Campos obligatorios',
                          style: TextStyle(
                            color: Colors.orange.shade400,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _seleccionarArchivoCargaMasiva(tipo: tipo, diagnosticar: true);
              },
              icon: Icon(Icons.search, color: Colors.white),
              label: Text('Diagnosticar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _seleccionarArchivoCargaMasiva(tipo: tipo, modo: modoCarga);
              },
              icon: Icon(Icons.file_upload, color: Colors.white),
              label: Text('Cargar Excel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                foregroundColor: Colors.white,
              ),
            ),
          ],
            );
          },
        );
      },
    );
  }

  Future<void> _seleccionarArchivoCargaMasiva({
    required String tipo,
    bool diagnosticar = false,
    String modo = 'actualizar',
  }) async {
    try {
      // Seleccionar archivo Excel
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final bytes = result.files.first.bytes;
        if (bytes != null) {
          if (diagnosticar) {
            await _diagnosticarExcel(bytes, tipo: tipo);
          } else {
            await _procesarArchivoExcel(bytes, tipo: tipo, modo: modo);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Error al seleccionar archivo: ${errorMessage(e)}');
      }
    }
  }

  Future<void> _diagnosticarExcel(
    Uint8List bytes, {
    required String tipo,
  }) async {
    try {
      // Mostrar diálogo de progreso
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          content: Row(
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              SizedBox(width: 16),
              Text(
                'Analizando archivo Excel...',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
            ],
          ),
        ),
      );

      // Enviar archivo al backend para diagnóstico
      final resultado = await _productoService.diagnosticarExcel(
        bytes.toList(),
      );

      // Cerrar diálogo de progreso
      if (mounted) Navigator.pop(context);

      // Mostrar resultados del diagnóstico
      if (mounted) {
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Text(
              'Diagnóstico del Excel',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            content: Container(
              width: 500,
              constraints: BoxConstraints(maxHeight: 400),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Resumen
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Resumen del archivo:',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Total columnas: ${resultado['totalColumnas']}',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          ),
                          Text(
                            'Total filas: ${resultado['totalFilas']}',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                resultado['tieneColumnaNombre'] == true
                                    ? Icons.check_circle
                                    : Icons.error,
                                color: resultado['tieneColumnaNombre'] == true
                                    ? Colors.green
                                    : Colors.red,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Columna NOMBRE: ${resultado['tieneColumnaNombre'] == true ? "✓ Detectada" : "✗ No detectada"}',
                                style: TextStyle(
                                  color: resultado['tieneColumnaNombre'] == true
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(
                                resultado['tieneColumnaPrecio'] == true
                                    ? Icons.check_circle
                                    : Icons.error,
                                color: resultado['tieneColumnaPrecio'] == true
                                    ? Colors.green
                                    : Colors.red,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Columna PRECIO: ${resultado['tieneColumnaPrecio'] == true ? "✓ Detectada" : "✗ No detectada"}',
                                style: TextStyle(
                                  color: resultado['tieneColumnaPrecio'] == true
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),

                    // Columnas detectadas
                    Text(
                      'Columnas detectadas:',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      constraints: BoxConstraints(maxHeight: 200),
                      child: SingleChildScrollView(
                        child: Column(
                          children:
                              (resultado['columnas'] as List<dynamic>?)
                                  ?.map(
                                    (col) => Padding(
                                      padding: EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 30,
                                            child: Text(
                                              '${col['indice']}:',
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              '${col['original']}',
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onSurface,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          if (col['normalizado'] !=
                                              col['original'])
                                            Expanded(
                                              child: Text(
                                                '→ ${col['normalizado']}',
                                                style: TextStyle(
                                                  color: Colors.grey.shade400,
                                                  fontSize: 11,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  )
                                  ?.toList() ??
                              [],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text(
                  'Cerrar',
                  style: TextStyle(color: AppTheme.primary),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Cerrar diálogo de progreso si está abierto
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      appLog('Error al diagnosticar archivo Excel: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Text(
              'Error en diagnóstico',
              style: TextStyle(color: Colors.red),
            ),
            content: Text(
              'Error al analizar el archivo:\n$e',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text(
                  'Cerrar',
                  style: TextStyle(color: AppTheme.primary),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _procesarArchivoExcel(
    Uint8List bytes, {
    required String tipo,
    String modo = 'actualizar',
  }) async {
    // Guardamos el contexto del diálogo de progreso para cerrarlo correctamente
    // sin afectar al navegador principal (GoRouter)
    BuildContext? dialogCtx;

    try {
      // Mostrar diálogo de progreso
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) {
          dialogCtx = c;
          return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            content: Row(
              children: [
                CircularProgressIndicator(color: AppTheme.primary),
                SizedBox(width: 16),
                Text(
                  'Procesando archivo Excel...',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                ),
              ],
            ),
          );
        },
      );

      // Enviar archivo al backend
      final resultado = await _productoService.cargaMasivaProductos(
        bytes.toList(),
        tipo: tipo,
        modo: modo,
      );

      // Cerrar diálogo de progreso usando el contexto del propio diálogo
      if (dialogCtx != null && dialogCtx!.mounted) {
        Navigator.of(dialogCtx!).pop();
        dialogCtx = null;
      }

      // Recargar lista
      await _cargarDatos();

      // Extraer datos del resultado
      final creados = resultado['productosCreados'] ?? 0;
      final actualizados = resultado['productosActualizados'] ?? 0;
      final errores = resultado['errores'] as List<dynamic>? ?? [];

      // Mostrar resumen
      if (mounted) {
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Text(
              'Carga Completada',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Productos creados: $creados',
                  style: TextStyle(color: AppTheme.success, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Productos actualizados: $actualizados',
                  style: TextStyle(color: Colors.blue, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Errores: ${errores.length}',
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
                if (errores.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Text(
                    'Detalles de errores:',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    constraints: BoxConstraints(maxHeight: 200),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: errores
                            .take(10)
                            .map(
                              (e) => Padding(
                                padding: EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '• $e',
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                  if (errores.length > 10)
                    Text(
                      '... y ${errores.length - 10} más',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text(
                  'Cerrar',
                  style: TextStyle(color: AppTheme.primary),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Cerrar diálogo de progreso usando su propio contexto
      if (dialogCtx != null && dialogCtx!.mounted) {
        Navigator.of(dialogCtx!).pop();
        dialogCtx = null;
      }

      appLog('Error al procesar archivo Excel: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Text('Error', style: TextStyle(color: Colors.red)),
            content: Text(
              'Error al procesar el archivo:\n$e',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text(
                  'Cerrar',
                  style: TextStyle(color: AppTheme.primary),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  // Nueva función para guardar producto con todos los campos
  Future<bool> _guardarProductoCompleto({
    Producto? producto,
    // Información básica
    required String nombre,
    required String descripcion,
    required String codigo,
    required String codigoBarras,
    required String tipo,
    // Precios
    required double precio,
    required double costo,
    double? porcentajeImpuesto,
    double? precioVentaOpc1,
    double? precioVentaOpc2,
    double? precioVentaOpc3,
    // Clasificación
    String? categoriaId,
    required String marca,
    required String tipoProductoNombre,
    required String lineaProductoNombre,
    required String claseProductoNombre,
    // Proveedor
    required String nombreProveedor,
    required String nitProveedor,
    // Inventario
    required String controlInventario,
    required int inventarioBajo,
    required int inventarioOptimo,
    required int almacen,
    required int bodega,
    // Ubicaciones
    required String ubicacion1,
    required String ubicacion2,
    required String ubicacion3,
    required String ubicacion4,
    required String localizacion,
  }) async {
    appLog('🔍 [_guardarProductoCompleto] Recibido tipo: "$tipo"');
    appLog('🔍 [_guardarProductoCompleto] Convirtiendo a lowercase: "${tipo.toLowerCase()}"');
    try {
      final service = ProductoService();

      // Encontrar la categoría seleccionada
      Categoria? categoriaSeleccionada;
      if (categoriaId != null && categoriaId.isNotEmpty) {
        categoriaSeleccionada = _categorias.firstWhere(
          (cat) => cat.id == categoriaId,
          orElse: () => Categoria(id: categoriaId, nombre: 'Unknown'),
        );
      }

      if (producto != null) {
        // Editar producto existente
        final productoActualizado = Producto(
          id: producto.id,
          nombre: nombre,
          descripcion: descripcion.isNotEmpty ? descripcion : null,
          codigo: codigo.isNotEmpty ? codigo : null,
          codigoBarras: codigoBarras.isNotEmpty ? codigoBarras : null,
          precio: precio,
          costo: costo,
          categoria: categoriaSeleccionada,
          productoOServicio: tipo.toLowerCase(),
          porcentajeImpuesto: porcentajeImpuesto,
          precioVentaOpc1: precioVentaOpc1,
          precioVentaOpc2: precioVentaOpc2,
          precioVentaOpc3: precioVentaOpc3,
          marca: marca.isNotEmpty ? marca : null,
          tipoProductoNombre: tipoProductoNombre.isNotEmpty
              ? tipoProductoNombre
              : null,
          lineaProductoNombre: lineaProductoNombre.isNotEmpty
              ? lineaProductoNombre
              : null,
          claseProductoNombre: claseProductoNombre.isNotEmpty
              ? claseProductoNombre
              : null,
          nombreProveedor: nombreProveedor.isNotEmpty ? nombreProveedor : null,
          nitProveedor: nitProveedor.isNotEmpty ? nitProveedor : null,
          controlInventario: controlInventario,
          inventarioBajo: inventarioBajo,
          inventarioOptimo: inventarioOptimo,
          almacen: almacen,
          bodega: bodega,
          ubicacion1: ubicacion1.isNotEmpty ? ubicacion1 : null,
          ubicacion2: ubicacion2.isNotEmpty ? ubicacion2 : null,
          ubicacion3: ubicacion3.isNotEmpty ? ubicacion3 : null,
          ubicacion4: ubicacion4.isNotEmpty ? ubicacion4 : null,
          localizacion: localizacion.isNotEmpty ? localizacion : null,
          impuestos: producto.impuestos,
          utilidad: precio - costo,
        );

        await service.updateProducto(productoActualizado);

        // ✅ Actualizar el producto en la lista local
        if (mounted) {
          setState(() {
            final index = _productos.indexWhere((p) => p.id == producto.id);
            if (index != -1) {
              _productos[index] = productoActualizado;
              _aplicarFiltros();
            }
          });
        }

        showSuccessSnackBar(context, 'Producto actualizado correctamente');
      } else {
        // Crear nuevo producto
        final nuevoProducto = Producto(
          id: '', // El backend asignará el ID
          nombre: nombre,
          descripcion: descripcion.isNotEmpty ? descripcion : null,
          codigo: codigo.isNotEmpty ? codigo : null,
          codigoBarras: codigoBarras.isNotEmpty ? codigoBarras : null,
          precio: precio,
          costo: costo,
          categoria: categoriaSeleccionada,
          productoOServicio: tipo,
          porcentajeImpuesto: porcentajeImpuesto,
          precioVentaOpc1: precioVentaOpc1,
          precioVentaOpc2: precioVentaOpc2,
          precioVentaOpc3: precioVentaOpc3,
          marca: marca.isNotEmpty ? marca : null,
          tipoProductoNombre: tipoProductoNombre.isNotEmpty
              ? tipoProductoNombre
              : null,
          lineaProductoNombre: lineaProductoNombre.isNotEmpty
              ? lineaProductoNombre
              : null,
          claseProductoNombre: claseProductoNombre.isNotEmpty
              ? claseProductoNombre
              : null,
          nombreProveedor: nombreProveedor.isNotEmpty ? nombreProveedor : null,
          nitProveedor: nitProveedor.isNotEmpty ? nitProveedor : null,
          controlInventario: controlInventario,
          inventarioBajo: inventarioBajo,
          inventarioOptimo: inventarioOptimo,
          almacen: almacen,
          bodega: bodega,
          ubicacion1: ubicacion1.isNotEmpty ? ubicacion1 : null,
          ubicacion2: ubicacion2.isNotEmpty ? ubicacion2 : null,
          ubicacion3: ubicacion3.isNotEmpty ? ubicacion3 : null,
          ubicacion4: ubicacion4.isNotEmpty ? ubicacion4 : null,
          localizacion: localizacion.isNotEmpty ? localizacion : null,
          impuestos: 0,
          utilidad: precio - costo,
        );

        appLog('🔍 Creando producto: ${nuevoProducto.nombre}');
        final productoCreado = await service.addProducto(nuevoProducto);
        appLog('🔍 Producto recibido del servicio, ID: "${productoCreado.id}"');

        // ✅ Verificar que el producto tenga un ID válido
        if (productoCreado.id.isEmpty) {
          appLog(
            '⚠️ WARNING: El producto creado no tiene ID. Recargando lista completa...',
          );
          // Si no hay ID válido, recargar toda la lista
          await _cargarDatos();

          showWarningSnackBar(context, 'Producto creado (recargando lista)');
        } else {
          // ✅ ID válido: Agregar el producto a la lista local sin esperar recargar cache
          if (mounted) {
            final cacheProvider = Provider.of<DatosCacheProvider>(
              context,
              listen: false,
            );

            setState(() {
              // Agregar al inicio con el ID asignado por el backend
              _productos.insert(0, productoCreado);
              _aplicarFiltros();
            });

            // Actualizar también el Provider cache para futuras referencias
            cacheProvider.agregarProductoAlCache(productoCreado);

            appLog(
              '✅ Producto agregado a la lista local con ID: ${productoCreado.id}',
            );
          }

          showSuccessSnackBar(context, 'Producto creado correctamente');
        }
      }

      // ⚡ OPTIMIZADO: Ya no recargar todo, el producto ya está en la lista local
      return true; // ✅ Retornar éxito
    } catch (e) {
      appLog('❌ Error al guardar producto: $e');
      showErrorSnackBar(context, 'Error al guardar producto: ${errorMessage(e)}');
      return false; // ❌ Retornar error
    }
  }

  // Funciones auxiliares para el formulario completo con tabs
  Widget _buildTabBasico(TextEditingController nombreController, TextEditingController descripcionController, TextEditingController codigoController, TextEditingController codigoBarrasController, String tipoSeleccionado, String? categoriaSeleccionada, StateSetter setState, List<String> tipoSeleccionadoList) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Row(
              children: [
                // Tipo de producto
                Expanded(
                  child: _buildDropdown(
                    'Tipo *',
                    tipoSeleccionado,
                    ['PRODUCTO', 'SERVICIO'],
                    (value) {
                      appLog('🔍 [DROPDOWN] Cambio de tipo detectado: "$value"');
                      setState(() {
                        tipoSeleccionadoList[0] = value ?? 'PRODUCTO';
                        appLog('🔍 [DROPDOWN] tipoSeleccionado actualizado a: "${tipoSeleccionadoList[0]}"');
                      });
                    },
                  ),
                ),
                SizedBox(width: 16),
                // Código
                Expanded(
                  child: _buildTextField('Código', codigoController),
                ),
              ],
            ),
            SizedBox(height: 16),
            
            // Código de barras
            _buildTextField('Código de barras', codigoBarrasController),
            SizedBox(height: 16),
            
            // Nombre (ancho completo)
            _buildTextField('Nombre *', nombreController),
            SizedBox(height: 16),

            // Descripción (ancho completo, multilinea)
            _buildTextField('Descripción', descripcionController, maxLines: 4),
            SizedBox(height: 16),

            // Categoría
            _buildCategoriaDropdown(categoriaSeleccionada, (value) {
              setState(() => categoriaSeleccionada = value);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTabPrecios(TextEditingController precioController, TextEditingController costoController, TextEditingController porcentajeImpuestoController, TextEditingController precioVentaOpc1Controller, TextEditingController precioVentaOpc2Controller, TextEditingController precioVentaOpc3Controller) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Precios Principales', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildTextField('Costo *', costoController, isNumeric: true)),
                SizedBox(width: 16),
                Expanded(child: _buildTextField('Precio *', precioController, isNumeric: true)),
                SizedBox(width: 16),
                Expanded(child: _buildTextField('% Impuesto', porcentajeImpuestoController, isNumeric: true)),
              ],
            ),
            SizedBox(height: 24),
            
            Text('Precios Opcionales', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildTextField('Precio Opc. 1', precioVentaOpc1Controller, isNumeric: true)),
                SizedBox(width: 16),
                Expanded(child: _buildTextField('Precio Opc. 2', precioVentaOpc2Controller, isNumeric: true)),
                SizedBox(width: 16),
                Expanded(child: _buildTextField('Precio Opc. 3', precioVentaOpc3Controller, isNumeric: true)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabClasificacion(TextEditingController marcaController, TextEditingController tipoProductoNombreController, TextEditingController lineaProductoNombreController, TextEditingController claseProductoNombreController, TextEditingController nombreProveedorController, TextEditingController nitProveedorController) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Clasificación', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 16),
            _buildTextField('Marca', marcaController),
            SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(child: _buildTextField('Tipo Producto', tipoProductoNombreController)),
                SizedBox(width: 16),
                Expanded(child: _buildTextField('Línea Producto', lineaProductoNombreController)),
              ],
            ),
            SizedBox(height: 16),
            _buildTextField('Clase Producto', claseProductoNombreController),
            SizedBox(height: 24),

            Text('Proveedor', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildTextField('Nombre Proveedor', nombreProveedorController)),
                SizedBox(width: 16),
                Expanded(child: _buildTextField('NIT Proveedor', nitProveedorController)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabInventario(TextEditingController almacenController, TextEditingController bodegaController, TextEditingController inventarioBajoController, TextEditingController inventarioOptimoController, TextEditingController ubicacion1Controller, TextEditingController ubicacion2Controller, TextEditingController ubicacion3Controller, TextEditingController ubicacion4Controller, TextEditingController localizacionController, String controlInventarioSeleccionado, StateSetter setState, List<String> controlInventarioSeleccionadoList) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Control de Inventario', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    'Control Inventario',
                    controlInventarioSeleccionado,
                    ['SI', 'NO'],
                    (value) => setState(() => controlInventarioSeleccionadoList[0] = value ?? 'SI'),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(child: _buildTextField('Inv. Bajo', inventarioBajoController, isNumeric: true)),
                SizedBox(width: 16),
                Expanded(child: _buildTextField('Inv. Óptimo', inventarioOptimoController, isNumeric: true)),
              ],
            ),
            SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(child: _buildTextField('Almacén', almacenController, isNumeric: true)),
                SizedBox(width: 16),
                Expanded(child: _buildTextField('Bodega', bodegaController, isNumeric: true)),
              ],
            ),
            SizedBox(height: 24),

            Text('Ubicaciones', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildTextField('Ubicación 1', ubicacion1Controller)),
                SizedBox(width: 16),
                Expanded(child: _buildTextField('Ubicación 2', ubicacion2Controller)),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildTextField('Ubicación 3', ubicacion3Controller)),
                SizedBox(width: 16),
                Expanded(child: _buildTextField('Ubicación 4', ubicacion4Controller)),
              ],
            ),
            SizedBox(height: 16),
            _buildTextField('Localización', localizacionController),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1, bool isNumeric = false}) {
    return TextField(
      controller: controller,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      maxLines: maxLines,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
        border: OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppTheme.primary),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: Theme.of(context).colorScheme.surface,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
        border: OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppTheme.primary),
        ),
      ),
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildCategoriaDropdown(String? value, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: Theme.of(context).colorScheme.surface,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: 'Categoría',
        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
        border: OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppTheme.primary),
        ),
      ),
      items: [
        DropdownMenuItem(value: null, child: Text('Sin categoría')),
        ..._categorias.map((categoria) {
          return DropdownMenuItem(
            value: categoria.id,
            child: Text(categoria.nombre),
          );
        }),
      ],
      onChanged: onChanged,
    );
  }

  // ==================== IMPRESIÓN DE CÓDIGOS DE BARRAS ====================

  void _mostrarDialogoImprimirCodigoBarras(Producto producto) {
    bool incluirFecha = true;
    bool incluirCodigo = true;
    bool incluirPrecio = true;
    int cantidad = 1;
    final cantidadController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            'Imprimir código de barras',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          content: Container(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nombre del producto
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade700),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Producto:',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        producto.nombre,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // Opciones de impresión
                Text(
                  'Opciones de impresión:',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),

                // Checkbox: Incluir fecha
                CheckboxListTile(
                  title: Text(
                    'Incluir fecha',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  ),
                  value: incluirFecha,
                  activeColor: AppTheme.primary,
                  checkColor: Colors.white,
                  onChanged: (value) {
                    setDialogState(() {
                      incluirFecha = value ?? false;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),

                // Checkbox: Incluir código
                CheckboxListTile(
                  title: Text(
                    'Incluir código del producto',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  ),
                  value: incluirCodigo,
                  activeColor: AppTheme.primary,
                  checkColor: Colors.white,
                  onChanged: (value) {
                    setDialogState(() {
                      incluirCodigo = value ?? false;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),

                // Checkbox: Incluir precio
                CheckboxListTile(
                  title: Text(
                    'Incluir precio',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  ),
                  value: incluirPrecio,
                  activeColor: AppTheme.primary,
                  checkColor: Colors.white,
                  onChanged: (value) {
                    setDialogState(() {
                      incluirPrecio = value ?? false;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),

                SizedBox(height: 12),

                // Campo de cantidad
                TextField(
                  controller: cantidadController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Cantidad de códigos a imprimir',
                    labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                    hintText: 'Ej: 2',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade700),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primary),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    cantidad = int.tryParse(value) ?? 1;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _generarPDFCodigoBarras(
                  producto,
                  incluirFecha: incluirFecha,
                  incluirCodigo: incluirCodigo,
                  incluirPrecio: incluirPrecio,
                  cantidad: cantidad,
                );
              },
              icon: Icon(Icons.print, color: Colors.white),
              label: Text('Imprimir', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generarPDFCodigoBarras(
    Producto producto, {
    required bool incluirFecha,
    required bool incluirCodigo,
    required bool incluirPrecio,
    required int cantidad,
  }) async {
    try {
      final pdf = pw.Document();

      // Si el producto no tiene codigoBarras, obtener el producto completo
      String? codigoBarras = producto.codigoBarras;

      // DEBUG inicial
      appLog('🔍 DEBUG CODIGO BARRAS:');
      appLog('  - producto.codigoBarras: ${producto.codigoBarras}');
      appLog('  - producto.codigo: ${producto.codigo}');
      appLog('  - producto.id: ${producto.id}');
      appLog('  - producto.nombre: ${producto.nombre}');

      if (codigoBarras == null || codigoBarras.isEmpty) {
        appLog('⏳ Obteniendo producto completo para código de barras...');

        try {
          // Obtener producto completo desde el backend
          final productoCompleto = await _productoService.getProducto(
            producto.id,
          );

          appLog('📦 Producto completo obtenido:');
          appLog('  - productoCompleto: ${productoCompleto != null}');
          if (productoCompleto != null) {
            appLog(
              '  - productoCompleto.codigoBarras: ${productoCompleto.codigoBarras}',
            );
          }

          if (productoCompleto != null &&
              productoCompleto.codigoBarras != null &&
              productoCompleto.codigoBarras!.isNotEmpty) {
            codigoBarras = productoCompleto.codigoBarras;
            appLog('✅ Código de barras obtenido: $codigoBarras');
          } else {
            appLog('❌ El producto completo tampoco tiene código de barras');
          }
        } catch (e) {
          appLog('❌ Error obteniendo producto completo: $e');
        }
      }

      appLog('🔍 CODIGO DE BARRAS FINAL: $codigoBarras');

      if (codigoBarras == null || codigoBarras.isEmpty) {
        if (mounted) {
          showErrorDialog(context, 'El producto no tiene código de barras asignado');
        }
        return;
      }

      // Formato para impresora térmica Honeywell PC42E-T
      // Papel de 10cm de ancho, etiquetas de 3cm x 2.5cm
      const double cmToPt = 28.35; // 1cm = 28.35 puntos
      final double anchoHoja = 10 * cmToPt; // 10cm = 283.5pt
      final double altoEtiqueta = 2.5 * cmToPt; // 2.5cm = 70.875pt
      final int filasNecesarias = (cantidad / 3).ceil();
      final double altoHoja =
          (altoEtiqueta * filasNecesarias) + 15; // Alto dinámico

      final formatoPagina = PdfPageFormat(
        anchoHoja,
        altoHoja,
        marginTop: 5,
        marginBottom: 0,
        marginLeft: 0,
        marginRight: 0,
      );

      // Crear etiquetas (máximo 3 por fila)
      final etiquetas = <pw.Widget>[];
      for (int i = 0; i < cantidad; i++) {
        etiquetas.add(
          _crearEtiquetaCodigoBarras(
            producto: producto,
            codigoBarras: codigoBarras,
            incluirFecha: incluirFecha,
            incluirCodigo: incluirCodigo,
            incluirPrecio: incluirPrecio,
          ),
        );
      }

      // Agrupar en filas de 3 etiquetas (3cm cada una = 9cm + márgenes)
      final filas = <pw.Widget>[];
      for (int i = 0; i < etiquetas.length; i += 3) {
        final etiquetasFila = <pw.Widget>[];

        // Agregar hasta 3 etiquetas por fila
        for (int j = 0; j < 3 && (i + j) < etiquetas.length; j++) {
          etiquetasFila.add(etiquetas[i + j]);
        }

        filas.add(
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.start,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: etiquetasFila,
          ),
        );
      }

      // Usar Page simple en lugar de MultiPage para evitar problemas de spanning
      pdf.addPage(
        pw.Page(
          pageFormat: formatoPagina,
          build: (context) => pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.start,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: filas,
          ),
        ),
      );

      // Opciones de impresión mejoradas para mejor detección de impresoras
      await _mostrarOpcionesImpresion(pdf, producto);

      if (mounted) {
        showSuccessSnackBar(context, 'PDF generado correctamente');
      }
    } catch (e) {
      appLog('Error al generar PDF: $e');
      if (mounted) {
        showErrorSnackBar(context, 'Error al generar PDF: ${errorMessage(e)}');
      }
    }
  }

  Future<void> _mostrarOpcionesImpresion(
    pw.Document pdf,
    Producto producto,
  ) async {
    final fileName = 'codigo_barras_${producto.codigo ?? producto.id}.pdf';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Seleccionar método de impresión',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          'Elige el método que mejor funcione con tu impresora:',
          style: TextStyle(color: Colors.grey.shade300),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(c);
              await _imprimirConDialogoSistema(pdf, fileName);
            },
            icon: Icon(Icons.system_update_alt, color: Colors.white),
            label: Text(
              'Diálogo del sistema',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(c);
              await _imprimirConVistaPrevia(pdf, fileName);
            },
            icon: Icon(Icons.preview, color: Colors.white),
            label: Text('Vista previa', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(c);
              await _imprimirDirecto(pdf, fileName);
            },
            icon: Icon(Icons.print, color: Colors.white),
            label: Text(
              'Impresión directa',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
          ),
        ],
      ),
    );
  }

  Future<void> _imprimirConDialogoSistema(
    pw.Document pdf,
    String fileName,
  ) async {
    try {
      // Usar el diálogo del sistema operativo (mejor compatibilidad con impresoras)
      await Printing.sharePdf(bytes: await pdf.save(), filename: fileName);

      if (mounted) {
        _mostrarMensajeExito('Se abrió el diálogo del sistema para imprimir');
      }
    } catch (e) {
      appLog('Error en impresión con diálogo del sistema: $e');
      _mostrarMensajeError('Error al abrir diálogo del sistema: ${errorMessage(e)}');
    }
  }

  Future<void> _imprimirConVistaPrevia(pw.Document pdf, String fileName) async {
    try {
      // Vista previa con mejor configuración para impresoras
      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: fileName,
        format: PdfPageFormat.letter, // Formato vertical para evitar rotación
        usePrinterSettings: true,
      );

      if (mounted) {
        _mostrarMensajeExito('Vista previa generada correctamente');
      }
    } catch (e) {
      appLog('Error en vista previa: $e');
      _mostrarMensajeError('Error en vista previa: ${errorMessage(e)}');
    }
  }

  Future<void> _imprimirDirecto(pw.Document pdf, String fileName) async {
    try {
      // Intento de impresión directa sin vista previa
      final printers = await Printing.listPrinters();

      if (printers.isNotEmpty) {
        // Mostrar lista de impresoras disponibles
        _mostrarSelectorImpresoras(printers, pdf, fileName);
      } else {
        // Si no detecta impresoras, usar método alternativo
        await Printing.directPrintPdf(
          printer: Printer(url: ''),
          onLayout: (format) async => pdf.save(),
          name: fileName,
          format: PdfPageFormat.letter, // Formato vertical para evitar rotación
        );

        if (mounted) {
          _mostrarMensajeExito('Enviado a la impresora predeterminada');
        }
      }
    } catch (e) {
      appLog('Error en impresión directa: $e');
      _mostrarMensajeError(
        'Error en impresión directa: ${errorMessage(e)}\nIntenta con "Vista previa"',
      );
    }
  }

  void _mostrarSelectorImpresoras(
    List<Printer> printers,
    pw.Document pdf,
    String fileName,
  ) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Seleccionar impresora',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Container(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Impresoras detectadas:',
                style: TextStyle(color: Colors.grey.shade300),
              ),
              SizedBox(height: 10),
              ...printers
                  .map(
                    (printer) => ListTile(
                      leading: Icon(Icons.print, color: Colors.white),
                      title: Text(
                        printer.name,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      ),
                      subtitle: printer.location != null
                          ? Text(
                              printer.location!,
                              style: TextStyle(color: Colors.grey.shade400),
                            )
                          : null,
                      onTap: () async {
                        Navigator.pop(c);
                        await _imprimirEnImpresora(printer, pdf, fileName);
                      },
                    ),
                  )
                  .toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Future<void> _imprimirEnImpresora(
    Printer printer,
    pw.Document pdf,
    String fileName,
  ) async {
    try {
      await Printing.directPrintPdf(
        printer: printer,
        onLayout: (format) async => pdf.save(),
        name: fileName,
        format: PdfPageFormat.letter, // Formato vertical para evitar rotación
      );

      if (mounted) {
        _mostrarMensajeExito('Impreso en: ${printer.name}');
      }
    } catch (e) {
      appLog('Error imprimiendo en ${printer.name}: $e');
      _mostrarMensajeError('Error imprimiendo en ${printer.name}: ${errorMessage(e)}');
    }
  }

  void _mostrarMensajeExito(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: AppTheme.success,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _mostrarMensajeError(String mensaje) {
    if (!mounted) return;
    showErrorDialog(context, mensaje);
  }

  pw.Widget _crearEtiquetaCodigoBarras({
    required Producto producto,
    required String codigoBarras,
    required bool incluirFecha,
    required bool incluirCodigo,
    required bool incluirPrecio,
  }) {
    // Dimensiones: 3cm x 2.5cm = 85pt x 71pt
    const double cmToPt = 28.35;
    const double anchoEtiqueta = 3 * cmToPt; // 85pt
    const double altoEtiqueta = 2.5 * cmToPt; // 71pt

    return pw.Container(
      width: anchoEtiqueta,
      height: altoEtiqueta,
      padding: pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Nombre del producto (compacto)
          pw.Text(
            producto.nombre.toUpperCase(),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
            maxLines: 1,
          ),

          // Precio y fecha en la misma línea
          if (incluirPrecio || incluirFecha)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                if (incluirPrecio)
                  pw.Text(
                    formatCurrency(producto.precio),
                    style: pw.TextStyle(
                      fontSize: 5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                if (incluirPrecio && incluirFecha) pw.SizedBox(width: 3),
                if (incluirFecha)
                  pw.Text(
                    DateFormat('dd/MM/yy').format(DateTime.now()),
                    style: pw.TextStyle(fontSize: 5, color: PdfColors.black),
                  ),
              ],
            ),

          pw.SizedBox(height: 1),

          // Código de barras - Code128 soporta todos los caracteres
          pw.BarcodeWidget(
            barcode: Barcode.code128(),
            data: codigoBarras,
            width: anchoEtiqueta - 10,
            height: 28,
            drawText: false,
            color: PdfColors.black,
          ),

          // Código debajo del código de barras
          if (incluirCodigo)
            pw.Text(
              codigoBarras,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 5, color: PdfColors.black),
            ),
        ],
      ),
    );
  }

  /// Descarga productos en formato Excel
  Future<void> _descargarProductosExcel({required String tipo}) async {
    bool dialogoMostrado = false;
    try {
      // Mostrar diálogo de carga
      if (mounted) {
        dialogoMostrado = true;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => AlertDialog(
            backgroundColor: Theme.of(c).colorScheme.surface,
            content: Row(
              children: [
                CircularProgressIndicator(color: AppTheme.primary),
                const SizedBox(width: 16),
                Text(
                  'Descargando productos...',
                  style: TextStyle(color: Theme.of(c).colorScheme.onSurface),
                ),
              ],
            ),
          ),
        );
      }

      // Descargar archivo
      final bytes = await _productoService.descargarProductosExcel();

      // Cerrar diálogo antes de disparar la descarga para evitar conflicto de Navigator.
      // showDialog() usa useRootNavigator:true por defecto, así que el diálogo vive en
      // el Navigator raíz — no en el Navigator anidado del ShellRoute de esta pantalla.
      // Navigator.of(context).pop() (sin rootNavigator:true) cerraba el Navigator
      // anidado equivocado en vez del diálogo, causando el crash
      // "!_debugLocked" al desmontarse de golpe parte del árbol de widgets.
      if (mounted && dialogoMostrado) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogoMostrado = false;
      }

      // Esperar un frame para que el diálogo se cierre completamente
      await Future.delayed(const Duration(milliseconds: 80));

      // Descargar el archivo
      final timestamp = DateTime.now();
      final tipoLabel = tipo == 'ambos'
          ? 'completo'
          : tipo == 'bodega'
          ? 'bodega'
          : 'almacen';
      final filename =
          'productos_${tipoLabel}_${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}_${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}.xlsx';

      FileDownloadHelper.downloadFile(
        bytes,
        filename: filename,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      // Mostrar éxito
      if (mounted) {
        showSuccessSnackBar(context, 'Archivo descargado: $filename');
      }
    } catch (e) {
      // Cerrar diálogo si está abierto (mismo rootNavigator:true que arriba)
      if (mounted && dialogoMostrado) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
      }

      // Mostrar error
      if (mounted) {
        showErrorSnackBar(context, 'Error descargando productos: ${errorMessage(e)}');
      }
    }
  }

  /// Muestra el historial de movimientos de stock del producto
  void _mostrarMovimientosStock(Producto producto) {
    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder(
          future: _productoService.getMovimientosStock(producto.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return AlertDialog(
                title: Text('Movimientos: ${producto.nombre}'),
                content: const Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return AlertDialog(
                title: Text('Movimientos: ${producto.nombre}'),
                content: Text('Error: ${snapshot.error}'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'),
                  ),
                ],
              );
            }

            final response = snapshot.data;
            final movimientos = response?.data ?? [];

            return AlertDialog(
              title: Text('Movimientos: ${producto.nombre}'),
              content: SizedBox(
                width: dialogWidth(context, 600),
                height: 400,
                child: movimientos.isEmpty
                    ? const Center(child: Text('Sin movimientos registrados'))
                    : ListView.builder(
                        itemCount: movimientos.length,
                        itemBuilder: (context, index) {
                          final mov = movimientos[index];
                          final esEntrada = mov.cantidad > 0;

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 0,
                            ),
                            child: ListTile(
                              leading: Container(
                                decoration: BoxDecoration(
                                  color: esEntrada
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  esEntrada
                                      ? '+${mov.cantidad}'
                                      : '${mov.cantidad}',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              title: Text(
                                mov.tipoLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat(
                                      'dd/MM/yyyy HH:mm',
                                    ).format(mov.fecha),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  if (mov.usuario != null)
                                    Text(
                                      'Por: ${mov.usuario}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  if (mov.observaciones != null &&
                                      mov.observaciones!.isNotEmpty)
                                    Text(
                                      mov.observaciones!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
