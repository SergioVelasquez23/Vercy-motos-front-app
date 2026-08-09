import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/traslado.dart';
import '../models/producto.dart';
import '../models/bodega.dart';
import '../services/traslado_service.dart';
import '../services/producto_service.dart';
import '../services/bodega_service.dart';
import '../providers/user_provider.dart';
import '../providers/notificaciones_provider.dart';
import '../theme/app_theme.dart';
import '../config/api_config.dart';
import '../utils/token_storage.dart';
import '../utils/api_error.dart';
import '../utils/dialogs_helper.dart';

class TrasladosScreen extends StatefulWidget {
  const TrasladosScreen({super.key});

  @override
  _TrasladosScreenState createState() => _TrasladosScreenState();
}

class _TrasladosScreenState extends State<TrasladosScreen> {
  final TrasladoService _trasladoService = TrasladoService();
  final ProductoService _productoService = ProductoService();
  final BodegaService _bodegaService = BodegaService();
  final TextEditingController _searchController = TextEditingController();

  List<Traslado> _traslados = [];
  List<Traslado> _trasladosFiltrados = [];
  List<Producto> _productos = [];
  List<Bodega> _bodegas = [];
  Map<String, int> _stockPorBodega = {};
  bool _isLoading = false;
  String _filtroEstado = 'TODOS';
  bool _mostrarFormulario = false;
  NotificacionesProvider? _notifProvider;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _searchController.addListener(_filtrarTraslados);

    // El centro de notificaciones ya consulta traslados nuevos cada 60s
    // (ver NotificacionesProvider.startAutoRefresh, arrancado desde
    // AppShell). Nos enganchamos a esos refrescos para que, si el usuario
    // ya está parado en esta pantalla, la lista se actualice sola en vez de
    // requerir el botón "Actualizar" manual.
    _notifProvider = Provider.of<NotificacionesProvider>(context, listen: false);
    _notifProvider?.addListener(_onNotificacionesChanged);
  }

  @override
  void dispose() {
    _notifProvider?.removeListener(_onNotificacionesChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onNotificacionesChanged() {
    if (!mounted) return;
    _recargarTraslados();
  }

  /// Refresco silencioso (sin spinner de pantalla completa) que solo trae
  /// la lista de traslados — evita repetir la carga de productos/bodegas
  /// que hace [_cargarDatos] cada vez que llega un refresco periódico.
  Future<void> _recargarTraslados() async {
    try {
      final traslados = await _trasladoService.listarTraslados(
        estado: _filtroEstado != 'TODOS' ? _filtroEstado : null,
      );
      if (!mounted) return;
      setState(() => _traslados = traslados);
      _filtrarTraslados();
    } catch (_) {
      // Silencioso: si falla el refresco en segundo plano, el botón
      // "Actualizar" sigue disponible para reintentar manualmente.
    }
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      // ⚡ OPTIMIZACIÓN: Cargar en paralelo (3x más rápido)
      final results = await Future.wait([
        _trasladoService.listarTraslados(
          estado: _filtroEstado != 'TODOS' ? _filtroEstado : null,
        ),
        // ⚡ NUEVO: Usar método optimizado para traslados (sin imágenes)
        _productoService.obtenerProductosParaTraslados(),
        _bodegaService.obtenerBodegas(),
      ], eagerError: true);

      final traslados = results[0] as List<Traslado>;
      final productos = results[1] as List<Producto>;
      final bodegas = results[2] as List<Bodega>;

      // ⚡ OPTIMIZACIÓN: Calcular stock solo si es necesario (lazy loading)
      // Se calcula bajo demanda en _calcularStockPorBodega()
      final bodegasActivas = bodegas.where((b) => b.activa).toList();

      setState(() {
        _traslados = traslados;
        _trasladosFiltrados = traslados;
        _productos = productos;
        _bodegas = bodegasActivas;
        // Stock se calcula bajo demanda
        _stockPorBodega = {};
      });
    } catch (e) {
      _mostrarError('Error al cargar datos: ${errorMessage(e)}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Calcula el stock por bodega bajo demanda (lazy loading)
  Future<int> _obtenerStockBodega(String nombreBodega) async {
    if (_stockPorBodega.containsKey(nombreBodega)) {
      return _stockPorBodega[nombreBodega] ?? 0;
    }

    int totalStock = 0;
    for (final producto in _productos) {
      if (nombreBodega.toUpperCase() == 'ALMACEN') {
        totalStock += producto.almacen ?? 0;
      } else if (nombreBodega.toUpperCase() == 'BODEGA') {
        totalStock += producto.bodega ?? 0;
      }
    }

    setState(() {
      _stockPorBodega[nombreBodega] = totalStock;
    });

    return totalStock;
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: _mostrarFormulario
          ? _FormularioCrearTraslado(
              productos: _productos,
              userName: userName,
              onTrasladoCreado: () {
                setState(() => _mostrarFormulario = false);
                _cargarDatos();
              },
              onCancelar: () => setState(() => _mostrarFormulario = false),
            )
          : _buildListaTraslados(userName),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: Row(
        children: [
          Icon(Icons.local_shipping, color: AppTheme.primary, size: 24),
          SizedBox(width: 12),
          Text(
            'Traslados',
            style: TextStyle(color: onSurface, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: onSurface),
        onPressed: () => context.go('/dashboard'),
      ),
    );
  }

  Widget _buildListaTraslados(String userName) {
    return Column(
      children: [
        _buildHeader(),
        _buildFiltros(),
        _buildBotonesAccion(userName),
        Expanded(
          child: _isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppTheme.primary),
                      SizedBox(height: 16),
                      Text(
                        'Cargando traslados...',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                      ),
                    ],
                  ),
                )
              : _trasladosFiltrados.isEmpty
              ? _buildEmptyState()
              : _buildTablaTraslados(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.primaryShadow,
      ),
      child: Row(
        children: [
          Icon(Icons.swap_horiz, color: Colors.white, size: 32),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lista de Traslados',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Gestiona los traslados de inventario entre bodegas',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_trasladosFiltrados.length} traslados',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.1)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Buscar por número, solicitante, producto...',
              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
              prefixIcon: Icon(Icons.search, color: AppTheme.primary),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonesAccion(String userName) {
    return Container(
      margin: EdgeInsets.all(16),
      // Wrap en vez de Row: 3 botones con texto ("Ubicaciones",
      // "Actualizar", "Crear Traslados") no caben en una fila en mobile — en
      // vez de desbordarse a la derecha, el que no quepa baja a una
      // siguiente línea.
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 12,
        runSpacing: 12,
        children: [
          _buildBotonAccion(
            icon: Icons.warehouse,
            label: 'Ubicaciones',
            color: AppTheme.secondary,
            onPressed: () => context.push('/bodegas'),
          ),
          _buildBotonAccion(
            icon: Icons.refresh,
            label: 'Actualizar',
            color: AppTheme.metal,
            onPressed: _cargarDatos,
          ),
          _buildBotonAccion(
            icon: Icons.add,
            label: 'Crear Traslados',
            color: AppTheme.primary,
            isPrimary: true,
            onPressed: () => setState(() => _mostrarFormulario = true),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonAccion({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    bool isPrimary = false,
    bool isIconOnly = false,
  }) {
    if (isIconOnly) {
      return Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: color),
          tooltip: 'Imprimir',
        ),
      );
    }

    return Container(
      decoration: isPrimary
          ? BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(10),
              boxShadow: AppTheme.primaryShadow,
            )
          : BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: isPrimary ? Colors.white : color, size: 20),
                SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isPrimary ? Colors.white : color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTablaTraslados() {
    // ⚡ OPTIMIZACIÓN: Usar ListView.builder en lugar de DataTable
    // Renderiza solo los elementos visibles (scroll virtual)
    //
    // 📱 8 columnas con Expanded/flex no cabían en un teléfono — "Origen"/
    // "Destino" (BODEGA/ALMACÉN) se partían letra por letra y "Acciones" se
    // desbordaba a la derecha. Ahora la tabla tiene ancho fijo por columna y
    // se scrollea horizontal en pantallas angostas (encabezado y filas
    // juntos, para que no se desalineen).
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: _anchoTotalTablaTraslados,
            child: Column(
              children: [
                // Encabezado fijo
                Container(
                  color: AppTheme.primary.withOpacity(0.1),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _celdaTraslado(_anchosColumnasTraslado[0], _buildColumnHeader('#')),
                      _celdaTraslado(_anchosColumnasTraslado[1], _buildColumnHeader('Fecha')),
                      _celdaTraslado(_anchosColumnasTraslado[2], _buildColumnHeader('Asesor')),
                      _celdaTraslado(_anchosColumnasTraslado[3], _buildColumnHeader('Origen')),
                      _celdaTraslado(_anchosColumnasTraslado[4], _buildColumnHeader('Destino')),
                      _celdaTraslado(_anchosColumnasTraslado[5], _buildColumnHeader('Cant.')),
                      _celdaTraslado(_anchosColumnasTraslado[6], _buildColumnHeader('Producto')),
                      _celdaTraslado(_anchosColumnasTraslado[7], _buildColumnHeader('Acciones')),
                    ],
                  ),
                ),
                // Lista con scroll virtual (vertical — el ClipRRect/Container
                // de más arriba ya limita la altura visible de la pantalla)
                Expanded(
                  child: ListView.builder(
                    itemCount: _trasladosFiltrados.length,
                    itemBuilder: (context, index) {
                      final traslado = _trasladosFiltrados[index];
                      return _buildFilaTraslado(traslado);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const List<double> _anchosColumnasTraslado = [50, 100, 90, 90, 90, 50, 140, 90];
  static const double _gapColumnasTraslado = 8;
  static double get _anchoTotalTablaTraslados =>
      _anchosColumnasTraslado.reduce((a, b) => a + b) +
      _gapColumnasTraslado * _anchosColumnasTraslado.length;

  Widget _celdaTraslado(double width, Widget child) {
    return Padding(
      padding: EdgeInsets.only(right: _gapColumnasTraslado),
      child: SizedBox(width: width, child: child),
    );
  }

  Widget _buildColumnHeader(String label) {
    return Text(
      label,
      style: TextStyle(
        color: AppTheme.primary,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    );
  }

  Widget _buildFilaTraslado(Traslado traslado) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.1)),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _celdaTraslado(
            _anchosColumnasTraslado[0],
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                traslado.numero ?? '-',
                style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          _celdaTraslado(
            _anchosColumnasTraslado[1],
            Text(
              traslado.fechaSolicitud != null
                  ? DateFormat('yy-MM-dd HH:mm').format(traslado.fechaSolicitud!)
                  : '-',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _celdaTraslado(
            _anchosColumnasTraslado[2],
            Text(
              traslado.solicitante ?? '-',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _celdaTraslado(_anchosColumnasTraslado[3], _buildBodegaChip(traslado.origenBodegaNombre ?? '-')),
          _celdaTraslado(_anchosColumnasTraslado[4], _buildBodegaChip(traslado.destinoBodegaNombre ?? '-')),
          _celdaTraslado(
            _anchosColumnasTraslado[5],
            Text(
              '${traslado.cantidad?.toStringAsFixed(0) ?? 0}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          _celdaTraslado(
            _anchosColumnasTraslado[6],
            Text(
              traslado.items.isNotEmpty
                  ? traslado.items.map((i) => i.nombreProducto ?? '-').join(', ')
                  : traslado.productoNombre ?? '-',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 11),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          _celdaTraslado(_anchosColumnasTraslado[7], _buildAccionesCompactas(traslado)),
        ],
      ),
    );
  }

  Widget _buildAccionesCompactas(Traslado traslado) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.visibility, size: 18),
          color: AppTheme.primary,
          onPressed: () => _verDetalles(traslado),
          tooltip: 'Ver detalles',
          splashRadius: 20,
        ),
        IconButton(
          icon: Icon(Icons.delete, size: 18),
          color: AppTheme.error,
          onPressed: () => _confirmarEliminarTraslado(traslado),
          tooltip: 'Eliminar traslado',
          splashRadius: 20,
        ),
      ],
    );
  }

  void _confirmarEliminarTraslado(Traslado traslado) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          '¿Eliminar Traslado?',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          '¿Está seguro que desea eliminar el traslado ${traslado.numero ?? ''}?\n\n'
          'Producto: ${traslado.productoNombre ?? '-'}\n'
          'Cantidad: ${traslado.cantidad?.toStringAsFixed(0) ?? '-'}',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _eliminarTraslado(traslado);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _eliminarTraslado(Traslado traslado) async {
    if (traslado.id == null) return;
    try {
      await _trasladoService.eliminarTraslado(traslado.id!);
      _mostrarExito('Traslado eliminado correctamente');
      _cargarDatos();
    } catch (e) {
      _mostrarError('Error al eliminar traslado: ${errorMessage(e)}');
    }
  }

  DataColumn _buildColumn(String label) {
    return DataColumn(
      label: Text(
        label,
        style: TextStyle(
          color: AppTheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildBodegaChip(String nombre) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.2)),
      ),
      child: Text(
        nombre,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13,
        ),
      ),
    );
  }


  Widget _buildAcciones(Traslado traslado) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildAccionBoton(
          icon: Icons.picture_as_pdf,
          color: AppTheme.error,
          tooltip: 'Generar PDF',
          onPressed: () => _mostrarMensaje('Generando PDF...'),
        ),
        SizedBox(width: 8),
        _buildAccionBoton(
          icon: Icons.info,
          color: AppTheme.primary,
          tooltip: 'Ver detalles',
          onPressed: () => _verDetalles(traslado),
        ),
      ],
    );
  }

  Widget _buildAccionBoton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.all(8),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              Icons.local_shipping_outlined,
              size: 64,
              color: AppTheme.primary,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No hay traslados',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Crea tu primer traslado de inventario',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 14),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => setState(() => _mostrarFormulario = true),
            icon: Icon(Icons.add, color: Colors.white),
            label: Text(
              'Crear Traslado',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoProcesar(Traslado traslado) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final aprobador = userProvider.userName ?? 'Usuario';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.swap_horiz, color: Colors.white, size: 20),
            ),
            SizedBox(width: 12),
            Text(
              'Procesar Traslado',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
        content: SizedBox(
          width: dialogWidth(context, 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('Número:', traslado.numero ?? '-'),
                    Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.2)),
                    _buildInfoRow('Producto:', traslado.productoNombre ?? '-'),
                    Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.2)),
                    _buildInfoRow('Cantidad:', '${traslado.cantidad}'),
                    Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.2)),
                    _buildInfoRow(
                      'Origen:',
                      traslado.origenBodegaNombre ?? '-',
                    ),
                    Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.2)),
                    _buildInfoRow(
                      'Destino:',
                      traslado.destinoBodegaNombre ?? '-',
                    ),
                  ],
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
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _procesarTraslado(traslado.id!, 'RECHAZAR', aprobador);
            },
            icon: Icon(Icons.close, size: 18),
            label: Text('Rechazar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _aceptarTraslado(traslado, aprobador);
            },
            icon: Icon(Icons.check, size: 18),
            label: Text('Aceptar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
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
      _mostrarError('Error al procesar traslado: ${errorMessage(e)}');
    }
  }

  // Aceptar traslado usando el endpoint de traslado rápido
  Future<void> _aceptarTraslado(Traslado traslado, String aprobador) async {
    try {
      // Buscar el producto para obtener los valores actuales
      final producto = _productos.firstWhere(
        (p) => p.id == traslado.productoId,
        orElse: () => throw Exception('Producto no encontrado'),
      );

        
        
        
        
        
        
        

      // Determinar si origen/destino son ALMACEN o BODEGA
      final origenEsAlmacen =
          traslado.origenBodegaNombre?.toUpperCase().contains('ALMACEN') ==
          true;
      final destinoEsAlmacen =
          traslado.destinoBodegaNombre?.toUpperCase().contains('ALMACEN') ==
          true;

      // Calcular nuevos valores
      int nuevoAlmacen = producto.almacen ?? 0;
      int nuevoBodega = producto.bodega ?? 0;

      if (origenEsAlmacen) {
        nuevoAlmacen -= traslado.cantidad!.toInt();
      } else {
        nuevoBodega -= traslado.cantidad!.toInt();
      }

      if (destinoEsAlmacen) {
        nuevoAlmacen += traslado.cantidad!.toInt();
      } else {
        nuevoBodega += traslado.cantidad!.toInt();
      }

        
        

      // Actualizar producto directamente
      final productoJson = producto.toJson();
      productoJson['almacen'] = nuevoAlmacen;
      productoJson['bodega'] = nuevoBodega;
      productoJson['cantidadAlmacen'] = nuevoAlmacen;
      productoJson['cantidadBodega'] = nuevoBodega;

      // Hacer petición PUT con headers básicos
      final token = await readJwtToken();
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final apiConfig = ApiConfig();
      final response = await http.put(
        Uri.parse('${apiConfig.baseUrl}/api/productos/${producto.id}'),
        headers: headers,
        body: json.encode(productoJson),
      );

      if (response.statusCode != 200) {
        throw Exception('Error al actualizar producto');
      }

      // 🎯 Usar el nuevo endpoint /completar para marcar el traslado como completado
      await _trasladoService.completarTraslado(
        trasladoId: traslado.id!,
        aprobador: aprobador,
      );

               _mostrarExito('Traslado aceptado y ejecutado correctamente');
      _cargarDatos();
    } catch (e) {
        
      _mostrarError('Error al aceptar traslado: ${errorMessage(e)}');
    }
  }

  void _verDetalles(Traslado traslado) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.info_outline, color: Colors.white, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Traslado ${traslado.numero ?? traslado.id?.substring(0, 8) ?? ''}',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: dialogWidth(context, 450),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetalleItem('Asesor', traslado.asesor ?? '-', Icons.person),
                      _buildDetalleItem('Origen', traslado.origenBodegaNombre ?? '-', Icons.outbox),
                      _buildDetalleItem('Destino', traslado.destinoBodegaNombre ?? '-', Icons.move_to_inbox),
                      _buildDetalleItem('Estado', traslado.estado ?? '-', Icons.flag),
                      if (traslado.fechaSolicitud != null)
                        _buildDetalleItem(
                          'Fecha',
                          DateFormat('yyyy-MM-dd HH:mm').format(traslado.fechaSolicitud!),
                          Icons.calendar_today,
                        ),
                      if (traslado.observaciones != null && traslado.observaciones!.isNotEmpty)
                        _buildDetalleItem('Observaciones', traslado.observaciones!, Icons.notes),
                      SizedBox(height: 12),
                      Text(
                        'Productos trasladados',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 8),
                      ...traslado.items.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Icon(Icons.inventory_2, size: 16, color: AppTheme.primary),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.nombreProducto ?? item.productoId ?? '-',
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                                  ),
                                ),
                                Text(
                                  '× ${item.cantidad}',
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )),
                      if (traslado.fechaSolicitud != null)
                        _buildDetalleItem(
                          'Fecha Solicitud',
                          DateFormat('yyyy-MM-dd HH:mm').format(traslado.fechaSolicitud!),
                          Icons.calendar_today,
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
            child: Text(
              'Cerrar',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalleItem(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 18),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 12),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarError(String mensaje) {
    showErrorDialog(context, mensaje);
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ==================== FORMULARIO CREAR TRASLADO ====================

class _FormularioCrearTraslado extends StatefulWidget {
  final List<Producto> productos;
  final String userName;
  final VoidCallback onTrasladoCreado;
  final VoidCallback onCancelar;

  const _FormularioCrearTraslado({
    required this.productos,
    required this.userName,
    required this.onTrasladoCreado,
    required this.onCancelar,
  });

  @override
  _FormularioCrearTrasladoState createState() =>
      _FormularioCrearTrasladoState();
}

class _FormularioCrearTrasladoState extends State<_FormularioCrearTraslado> {
  final TrasladoService _trasladoService = TrasladoService();
  final BodegaService _bodegaService = BodegaService();
  final _eanController = TextEditingController();
  final _codigoController = TextEditingController();
  final _nombreController = TextEditingController();
  final _cantidadController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _buscarProductoController = TextEditingController();

  String? _origenSeleccionado;
  String? _destinoSeleccionado;
  Producto? _productoSeleccionado;
  bool _isLoading = false;
  bool _cargandoBodegas = true;

  final List<Map<String, dynamic>> _productosAgregados = [];

  // Bodegas cargadas dinámicamente desde el servicio
  List<Bodega> _bodegas = [];

  @override
  void initState() {
    super.initState();
    _cargarBodegas();
  }

  Future<void> _cargarBodegas() async {
    try {
      final bodegas = await _bodegaService.obtenerBodegas();
      final activas = bodegas.where((b) => b.activa).toList();
      setState(() {
        _bodegas = activas;
        _cargandoBodegas = false;
        _aplicarDefectosBodegas(activas);
      });
    } catch (e) {
      // Fallback a bodegas por defecto
      final fallback = [
        Bodega(id: 'BODEGA', nombre: 'BODEGA', activa: true),
        Bodega(id: 'ALMACEN', nombre: 'ALMACEN', activa: true),
      ];
      setState(() {
        _bodegas = fallback;
        _cargandoBodegas = false;
        _aplicarDefectosBodegas(fallback);
      });
    }
  }

  void _aplicarDefectosBodegas(List<Bodega> bodegas) {
    // Origen por defecto: primera bodega cuyo nombre contiene "BODEGA"
    if (_origenSeleccionado == null) {
      final bodega = bodegas.firstWhere(
        (b) => b.nombre.toUpperCase().contains('BODEGA'),
        orElse: () => bodegas.first,
      );
      _origenSeleccionado = bodega.id;
    }
    // Destino por defecto: primera bodega cuyo nombre contiene "ALMACEN"
    if (_destinoSeleccionado == null) {
      final almacen = bodegas.firstWhere(
        (b) => b.nombre.toUpperCase().contains('ALMACEN'),
        orElse: () => bodegas.last,
      );
      _destinoSeleccionado = almacen.id;
    }
  }

  @override
  void dispose() {
    _eanController.dispose();
    _codigoController.dispose();
    _nombreController.dispose();
    _cantidadController.dispose();
    _descripcionController.dispose();
    _buscarProductoController.dispose();
    super.dispose();
  }

  // Obtener stock disponible según la bodega origen seleccionada
  double _obtenerStockOrigen() {
    if (_productoSeleccionado == null || _origenSeleccionado == null) {
      return 0.0;
    }

    // Buscar la bodega seleccionada para determinar si es almacén o bodega
    final bodega = _bodegas.firstWhere(
      (b) => b.id == _origenSeleccionado,
      orElse: () => Bodega(
        id: _origenSeleccionado!,
        nombre: _origenSeleccionado!,
        activa: false,
      ),
    );
    
      
      
      
    
    // Si el nombre contiene "ALMACEN" → usar producto.almacen
    // Si no → usar producto.bodega (por defecto)
    if (bodega.nombre.toUpperCase().contains('ALMACEN')) {
      final stock = (_productoSeleccionado!.almacen ?? 0).toDouble();
        
      return stock;
    } else {
      final stock = (_productoSeleccionado!.bodega ?? 0).toDouble();
        
      return stock;
    }
  }

  void _buscarProductoPorEAN() {
    final ean = _eanController.text.trim();
    if (ean.isEmpty) return;

    final productoIndex = widget.productos.indexWhere(
      (p) => p.codigoBarras == ean || p.id == ean,
    );

    if (productoIndex != -1) {
      final producto = widget.productos[productoIndex];
      setState(() {
        _productoSeleccionado = producto;
        _codigoController.text = producto.codigo ?? producto.id ?? '';
        _nombreController.text = producto.nombre ?? '';
      });
    } else {
      _mostrarError('Producto no encontrado');
    }
  }

  void _agregarProducto() {
    if (_productoSeleccionado == null) {
      _mostrarError('Seleccione un producto');
      return;
    }

    if (_cantidadController.text.isEmpty) {
      _mostrarError('Ingrese la cantidad');
      return;
    }

    final cantidad = double.tryParse(_cantidadController.text);
    if (cantidad == null || cantidad <= 0) {
      _mostrarError('La cantidad debe ser mayor a 0');
      return;
    }

    // VALIDAR STOCK EN BODEGA ORIGEN
    final stockDisponible = _obtenerStockOrigen();
    if (cantidad > stockDisponible) {
      _mostrarError(
        'Stock insuficiente en bodega origen.\n'
        'Disponible: $stockDisponible unidades\n'
        'Solicitado: $cantidad unidades',
      );
      return;
    }

    setState(() {
      _productosAgregados.add({
        'producto': _productoSeleccionado,
        'cantidad': cantidad,
      });
      _limpiarFormularioProducto();
    });
  }

  void _limpiarFormularioProducto() {
    _eanController.clear();
    _codigoController.clear();
    _nombreController.clear();
    _cantidadController.clear();
    _productoSeleccionado = null;
  }

  void _eliminarProducto(int index) {
    setState(() {
      _productosAgregados.removeAt(index);
    });
  }

  Future<void> _crearTraslados() async {
    if (_origenSeleccionado == null || _destinoSeleccionado == null) {
      _mostrarError('Seleccione origen y destino');
      return;
    }

    if (_origenSeleccionado == _destinoSeleccionado) {
      _mostrarError('El origen y destino deben ser diferentes');
      return;
    }

    if (_productosAgregados.isEmpty) {
      _mostrarError('Agregue al menos un producto');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final items = _productosAgregados.map((item) {
        final producto = item['producto'] as Producto;
        return {
          'productoId': producto.id,
          'cantidad': (item['cantidad'] as double).toInt(),
        };
      }).toList();

      await _trasladoService.crearTraslado(
        items: items,
        origen: _origenSeleccionado!,
        destino: _destinoSeleccionado!,
        asesor: widget.userName,
        observaciones: _descripcionController.text.isEmpty
            ? null
            : _descripcionController.text,
      );

      _mostrarExito('Traslados creados exitosamente');
      widget.onTrasladoCreado();
    } catch (e) {
      _mostrarError('Error al crear traslado: ${errorMessage(e)}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildFormHeader(),
          SizedBox(height: 20),

          // Selectores de bodega
          _buildSelectoresBodega(),
          SizedBox(height: 24),

          // Sección datos producto
          _buildSeccionDatosProducto(),
          SizedBox(height: 24),

          // Tabla de productos agregados
          _buildTablaProductos(),
          SizedBox(height: 24),

          // Descripción
          _buildCampoDescripcion(),
          SizedBox(height: 32),

          // Botones de acción
          _buildBotonesFormulario(),
        ],
      ),
    );
  }

  Widget _buildFormHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.primaryShadow,
      ),
      child: Row(
        children: [
          Icon(Icons.add_box, color: Colors.white, size: 32),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Crear Traslado',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Complete los datos para crear un nuevo traslado',
                  style: TextStyle(color: Colors.white.withOpacity(0.8)),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: widget.onCancelar,
            icon: Icon(Icons.list_alt),
            label: Text('Ver Traslados'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.2),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectoresBodega() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildDropdownBodega(
              label: 'Origen',
              value: _origenSeleccionado,
              onChanged: (value) {
                setState(() => _origenSeleccionado = value);
              },
            ),
          ),
          SizedBox(width: 24),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(Icons.arrow_forward, color: AppTheme.primary),
          ),
          SizedBox(width: 24),
          Expanded(
            child: _buildDropdownBodega(
              label: 'Destino',
              value: _destinoSeleccionado,
              onChanged: (value) =>
                  setState(() => _destinoSeleccionado = value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownBodega({
    required String label,
    required String? value,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.2)),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            hint: _cargandoBodegas
                ? Text(
                    'Cargando...',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                  )
                : Text(
                    'Seleccione',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                  ),
            dropdownColor: Theme.of(context).colorScheme.surface,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            items: _bodegas.map((bodega) {
              return DropdownMenuItem(
                value: bodega.id,
                child: Row(
                  children: [
                    Icon(
                      bodega.tipo == 'ALMACEN' ? Icons.store : Icons.warehouse,
                      size: 18,
                      color: AppTheme.primary,
                    ),
                    SizedBox(width: 8),
                    Text(bodega.nombre),
                  ],
                ),
              );
            }).toList(),
            onChanged: _cargandoBodegas ? null : onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildSeccionDatosProducto() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.inventory_2, color: Colors.white, size: 20),
              ),
              SizedBox(width: 12),
              Text(
                'Datos Producto',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Campo EAN
          _buildCampoFormulario(
            label: 'EAN',
            controller: _eanController,
            hint: 'Escanear o ingresar código',
            onSubmitted: (_) => _buscarProductoPorEAN(),
            suffixIcon: IconButton(
              icon: Icon(Icons.search, color: AppTheme.primary),
              onPressed: _buscarProductoPorEAN,
            ),
          ),
          SizedBox(height: 16),

          // Fila: Código, Nombre (Dropdown), Cantidad
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildCampoFormulario(
                  label: 'Código',
                  controller: _codigoController,
                  readOnly: true,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: _buildDropdownProducto(),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildCampoFormulario(
                  label: 'Cant',
                  controller: _cantidadController,
                  keyboardType: TextInputType.number,
                ),
              ),
              SizedBox(width: 12),
              Column(
                children: [
                  SizedBox(height: 24),
                  Row(
                    children: [
                      _buildBotonCircular(
                        icon: Icons.add,
                        color: AppTheme.primary,
                        onPressed: _agregarProducto,
                        tooltip: 'Agregar producto',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          
          // Mostrar stock del producto seleccionado
          if (_productoSeleccionado != null)
            _buildStockProductoSeleccionado(),
        ],
      ),
    );
  }

  Widget _buildStockProductoSeleccionado() {
    // Obtener stock de la bodega origen seleccionada
    final stockOrigen = _obtenerStockOrigen();
    
    // Valores de almacen y bodega
    final stockAlmacen = _productoSeleccionado!.almacen ?? 0;
    final stockBodega = _productoSeleccionado!.bodega ?? 0;
    
    return Container(
      margin: EdgeInsets.only(top: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withOpacity(0.1),
            AppTheme.secondary.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
              SizedBox(width: 8),
              Text(
                'Stock del producto',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          
          // STOCK REAL EN BODEGA ORIGEN
          if (_origenSeleccionado != null) ...[
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: stockOrigen > 0 
                    ? AppTheme.success.withOpacity(0.15)
                    : AppTheme.error.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: stockOrigen > 0 
                      ? AppTheme.success.withOpacity(0.4)
                      : AppTheme.error.withOpacity(0.4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2,
                        color: stockOrigen > 0 ? AppTheme.success : AppTheme.error,
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BODEGA ORIGEN',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '$stockOrigen unidades',
                            style: TextStyle(
                              color: stockOrigen > 0 ? AppTheme.success : AppTheme.error,
                              fontSize: 18,
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
            SizedBox(height: 12),
          ] else ...[
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.warning.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: AppTheme.warning, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Seleccione una bodega origen para ver el stock disponible',
                      style: TextStyle(
                        color: AppTheme.warning,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
          ],
          
          // Información adicional de stock por ubicación
          Row(
            children: [
              Expanded(
                child: _buildStockInfoCard(
                  'En Almacén',
                  stockAlmacen,
                  Icons.store,
                  AppTheme.info,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildStockInfoCard(
                  'En Bodega',
                  stockBodega,
                  Icons.warehouse,
                  AppTheme.metal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStockInfoCard(
    String label,
    int cantidad,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              fontSize: 10,
            ),
          ),
          Text(
            '$cantidad',
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDropdownProducto() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Text(
            'Producto',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
            border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.2)),
          ),
          child: RawAutocomplete<Producto>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              // Siempre mostrar opciones (vacío = primeros 30, con texto = filtrados)
              if (textEditingValue.text.isEmpty) {
                return widget.productos.take(30);
              }
              final query = textEditingValue.text.toLowerCase();
              return widget.productos
                  .where((producto) {
                    return producto.nombre.toLowerCase().contains(query) ||
                        (producto.codigo?.toLowerCase().contains(query) ??
                            false) ||
                        (producto.codigoBarras?.toLowerCase().contains(query) ??
                            false) ||
                        producto.id.toLowerCase().contains(query);
                  })
                  .take(50);
            },
            displayStringForOption: (Producto producto) => producto.nombre,
            fieldViewBuilder:
                (context, controller, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    onTap: () {
                      // Mostrar opciones al tocar el campo
                      if (controller.text.isEmpty) {
                        controller.text = '';
                        controller.selection = TextSelection.fromPosition(
                          TextPosition(offset: controller.text.length),
                        );
                      }
                    },
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      hintText: 'Buscar o seleccionar producto...',
                      hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (controller.text.isNotEmpty)
                            IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                size: 18,
                              ),
                              onPressed: () {
                                controller.clear();
                                setState(() {
                                  _productoSeleccionado = null;
                                  _codigoController.clear();
                                  _nombreController.clear();
                                });
                              },
                            ),
                          Icon(
                            Icons.arrow_drop_down,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                          SizedBox(width: 8),
                        ],
                      ),
                    ),
                  );
                },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 8,
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 500,
                    constraints: BoxConstraints(maxHeight: 350),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(8),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.inventory_2,
                                color: AppTheme.primary,
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Text(
                                '${options.length} productos encontrados',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final producto = options.elementAt(index);
                              final stockAlmacen = producto.almacen ?? 0;
                              final stockBodega = producto.bodega ?? 0;
                              return InkWell(
                                onTap: () => onSelected(producto),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(
                                          0.1,
                                        ),
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withOpacity(
                                            0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.inventory_2,
                                          color: AppTheme.primary,
                                          size: 16,
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              producto.nombre,
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onSurface,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 13,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              'Cod: ${producto.codigo ?? (producto.id.length >= 8 ? producto.id.substring(0, 8) : producto.id)}',
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.success.withOpacity(
                                            0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.store,
                                              color: AppTheme.success,
                                              size: 12,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              '$stockAlmacen',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.success,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.warning.withOpacity(
                                            0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.warehouse,
                                              color: AppTheme.warning,
                                              size: 12,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              '$stockBodega',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.warning,
                                                fontWeight: FontWeight.bold,
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
                      ],
                    ),
                  ),
                ),
              );
            },
            onSelected: (Producto producto) {
              setState(() {
                _productoSeleccionado = producto;
                _codigoController.text = producto.codigo ?? producto.id;
                _nombreController.text = producto.nombre;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCampoFormulario({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool readOnly = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    Function(String)? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
            border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.2)),
          ),
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            keyboardType: keyboardType,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            onSubmitted: onSubmitted,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              hintText: hint,
              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
              suffixIcon: suffixIcon,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBotonCircular({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.all(10),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildTablaProductos() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.1)),
      ),
      child: Column(
        children: [
          // Header de la tabla
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusMedium - 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text('Código', style: _headerStyle())),
                Expanded(flex: 4, child: Text('Nombre', style: _headerStyle())),
                Expanded(flex: 2, child: Text('Canti.', style: _headerStyle())),
                Expanded(flex: 2, child: Text('Origen', style: _headerStyle())),
                Expanded(
                  flex: 2,
                  child: Text('Destino', style: _headerStyle()),
                ),
                SizedBox(width: 40),
              ],
            ),
          ),
          // Contenido
          Container(
            constraints: BoxConstraints(minHeight: 100, maxHeight: 250),
            child: _productosAgregados.isEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            size: 40,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No hay productos agregados',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _productosAgregados.length,
                    itemBuilder: (context, index) {
                      final item = _productosAgregados[index];
                      final producto = item['producto'] as Producto;
                      return Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.1),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                producto.codigo ?? producto.id?.substring(0, 6) ?? '-',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Text(
                                producto.nombre ?? '-',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${item['cantidad']}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                _origenSeleccionado ?? '-',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                _destinoSeleccionado ?? '-',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete,
                                color: AppTheme.error,
                                size: 20,
                              ),
                              onPressed: () => _eliminarProducto(index),
                              tooltip: 'Eliminar',
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  TextStyle _headerStyle() {
    return TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 13,
    );
  }

  Widget _buildCampoDescripcion() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6).withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Descripción (opcional)',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          TextField(
            controller: _descripcionController,
            maxLines: 3,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Observaciones adicionales...',
              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonesFormulario() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton.icon(
          onPressed: widget.onCancelar,
          icon: Icon(Icons.close),
          label: Text('Cancelar'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            side: BorderSide(color: Theme.of(context).colorScheme.outline),
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
        SizedBox(width: 16),
        Container(
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(10),
            boxShadow: AppTheme.primaryShadow,
          ),
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _crearTraslados,
            icon: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(Icons.save),
            label: Text('Guardar Traslados'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  void _mostrarError(String mensaje) {
    showErrorDialog(context, mensaje);
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
