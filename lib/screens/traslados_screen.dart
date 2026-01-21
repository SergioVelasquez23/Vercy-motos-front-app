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
  bool _mostrarFormulario = false;

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
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.local_shipping, color: Colors.white, size: 20),
          ),
          SizedBox(width: 12),
          Text(
            'Traslados',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
      ),
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.arrow_back, color: Colors.white, size: 18),
        ),
        onPressed: () => Navigator.pushReplacementNamed(context, '/dashboard'),
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
                        style: TextStyle(color: AppTheme.textSecondary),
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
              color: Colors.white.withOpacity(0.2),
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
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.textMuted.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Buscar por número, solicitante, producto...',
              hintStyle: TextStyle(color: AppTheme.textMuted),
              prefixIcon: Icon(Icons.search, color: AppTheme.primary),
              filled: true,
              fillColor: AppTheme.surfaceDark,
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
          SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  'Estado:',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 12),
                ...[
                  {
                    'label': 'Todos',
                    'value': 'TODOS',
                    'icon': Icons.all_inclusive,
                  },
                  {
                    'label': 'Pendiente',
                    'value': 'PENDIENTE',
                    'icon': Icons.hourglass_empty,
                  },
                  {
                    'label': 'Aceptado',
                    'value': 'ACEPTADO',
                    'icon': Icons.check_circle,
                  },
                  {
                    'label': 'Rechazado',
                    'value': 'RECHAZADO',
                    'icon': Icons.cancel,
                  },
                ].map((estado) {
                  final isSelected = _filtroEstado == estado['value'];
                  return Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: Icon(
                        estado['icon'] as IconData,
                        size: 16,
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.textMuted,
                      ),
                      label: Text(estado['label'] as String),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(
                          () => _filtroEstado = estado['value'] as String,
                        );
                        _cargarDatos();
                      },
                      backgroundColor: AppTheme.surfaceDark,
                      selectedColor: AppTheme.primary.withOpacity(0.15),
                      side: BorderSide(
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.textMuted.withOpacity(0.3),
                      ),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? AppTheme.primary
                            : AppTheme.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonesAccion(String userName) {
    return Container(
      margin: EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _buildBotonAccion(
            icon: Icons.refresh,
            label: 'Actualizar',
            color: AppTheme.metal,
            onPressed: _cargarDatos,
          ),
          SizedBox(width: 12),
          _buildBotonAccion(
            icon: Icons.add,
            label: 'Crear Traslados',
            color: AppTheme.primary,
            isPrimary: true,
            onPressed: () => setState(() => _mostrarFormulario = true),
          ),
          SizedBox(width: 12),
          _buildBotonAccion(
            icon: Icons.print,
            label: '',
            color: AppTheme.secondary,
            onPressed: () {
              _mostrarMensaje('Función de impresión en desarrollo');
            },
            isIconOnly: true,
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
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.textMuted.withOpacity(0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                AppTheme.primary.withOpacity(0.1),
              ),
              dataRowColor: WidgetStateProperty.all(AppTheme.cardBg),
              headingRowHeight: 56,
              dataRowMinHeight: 60,
              dataRowMaxHeight: 60,
              columnSpacing: 24,
              horizontalMargin: 20,
              columns: [
                _buildColumn('#'),
                _buildColumn('Fecha'),
                _buildColumn('Solicita'),
                _buildColumn('Origen'),
                _buildColumn('Destino'),
                _buildColumn('Cantidad'),
                _buildColumn('Estado'),
                _buildColumn('Acciones'),
              ],
              rows: _trasladosFiltrados.map((traslado) {
                return DataRow(
                  cells: [
                    DataCell(
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          traslado.numero ?? '-',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        traslado.fechaSolicitud != null
                            ? DateFormat(
                                'yyyy-MM-dd - HH:mm:ss',
                              ).format(traslado.fechaSolicitud!)
                            : '-',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        traslado.solicitante ?? '-',
                        style: TextStyle(color: AppTheme.textPrimary),
                      ),
                    ),
                    DataCell(
                      _buildBodegaChip(traslado.origenBodegaNombre ?? '-'),
                    ),
                    DataCell(
                      _buildBodegaChip(traslado.destinoBodegaNombre ?? '-'),
                    ),
                    DataCell(
                      Text(
                        '${traslado.cantidad?.toStringAsFixed(0) ?? 0}',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
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
      ),
    );
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
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.textMuted.withOpacity(0.2)),
      ),
      child: Text(
        nombre,
        style: TextStyle(color: AppTheme.textPrimary, fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildEstadoBadge(String estado) {
    Color color;
    IconData icon;
    switch (estado) {
      case 'ACEPTADO':
        color = AppTheme.success;
        icon = Icons.check_circle;
        break;
      case 'RECHAZADO':
        color = AppTheme.error;
        icon = Icons.cancel;
        break;
      default:
        color = AppTheme.warning;
        icon = Icons.hourglass_empty;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: 6),
          Text(
            estado == 'ACEPTADO'
                ? 'Aceptado'
                : estado == 'RECHAZADO'
                ? 'Rechazado'
                : 'Pendiente',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
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
        if (traslado.estado == 'PENDIENTE') ...[
          SizedBox(width: 8),
          _buildAccionBoton(
            icon: Icons.check,
            color: AppTheme.success,
            tooltip: 'Aceptar',
            onPressed: () => _mostrarDialogoProcesar(traslado),
          ),
        ],
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
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Crea tu primer traslado de inventario',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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
        backgroundColor: AppTheme.cardBg,
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
              style: TextStyle(color: AppTheme.textPrimary),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('Número:', traslado.numero ?? '-'),
                    Divider(color: AppTheme.textMuted.withOpacity(0.2)),
                    _buildInfoRow('Producto:', traslado.productoNombre ?? '-'),
                    Divider(color: AppTheme.textMuted.withOpacity(0.2)),
                    _buildInfoRow('Cantidad:', '${traslado.cantidad}'),
                    Divider(color: AppTheme.textMuted.withOpacity(0.2)),
                    _buildInfoRow(
                      'Origen:',
                      traslado.origenBodegaNombre ?? '-',
                    ),
                    Divider(color: AppTheme.textMuted.withOpacity(0.2)),
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
              style: TextStyle(color: AppTheme.textSecondary),
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
              await _procesarTraslado(traslado.id!, 'ACEPTAR', aprobador);
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
          Text(label, style: TextStyle(color: AppTheme.textMuted)),
          Text(
            value,
            style: TextStyle(
              color: AppTheme.textPrimary,
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
      _mostrarError('Error al procesar traslado: $e');
    }
  }

  void _verDetalles(Traslado traslado) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
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
            Text(
              'Traslado ${traslado.numero}',
              style: TextStyle(color: AppTheme.textPrimary),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildDetalleItem(
                        'Producto',
                        traslado.productoNombre ?? '-',
                        Icons.inventory_2,
                      ),
                      _buildDetalleItem(
                        'Cantidad',
                        '${traslado.cantidad} ${traslado.unidad ?? ''}',
                        Icons.numbers,
                      ),
                      _buildDetalleItem(
                        'Origen',
                        traslado.origenBodegaNombre ?? '-',
                        Icons.outbox,
                      ),
                      _buildDetalleItem(
                        'Destino',
                        traslado.destinoBodegaNombre ?? '-',
                        Icons.move_to_inbox,
                      ),
                      _buildDetalleItem(
                        'Solicitante',
                        traslado.solicitante ?? '-',
                        Icons.person,
                      ),
                      _buildDetalleItem(
                        'Estado',
                        traslado.estado ?? '-',
                        Icons.flag,
                      ),
                      if (traslado.aprobador != null)
                        _buildDetalleItem(
                          'Aprobador',
                          traslado.aprobador!,
                          Icons.verified_user,
                        ),
                      if (traslado.observaciones != null &&
                          traslado.observaciones!.isNotEmpty)
                        _buildDetalleItem(
                          'Observaciones',
                          traslado.observaciones!,
                          Icons.notes,
                        ),
                      if (traslado.fechaSolicitud != null)
                        _buildDetalleItem(
                          'Fecha Solicitud',
                          DateFormat(
                            'yyyy-MM-dd HH:mm',
                          ).format(traslado.fechaSolicitud!),
                          Icons.calendar_today,
                        ),
                      if (traslado.fechaAprobacion != null)
                        _buildDetalleItem(
                          'Fecha Aprobación',
                          DateFormat(
                            'yyyy-MM-dd HH:mm',
                          ).format(traslado.fechaAprobacion!),
                          Icons.event_available,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: Text('Cerrar'),
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
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
  final _eanController = TextEditingController();
  final _codigoController = TextEditingController();
  final _nombreController = TextEditingController();
  final _cantidadController = TextEditingController();
  final _descripcionController = TextEditingController();

  String? _origenSeleccionado;
  String? _destinoSeleccionado;
  Producto? _productoSeleccionado;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _productosAgregados = [];

  final List<Map<String, String>> _bodegas = [
    {'id': 'BODEGA', 'nombre': 'BODEGA'},
    {'id': 'ALMACEN', 'nombre': 'ALMACEN'},
  ];

  @override
  void dispose() {
    _eanController.dispose();
    _codigoController.dispose();
    _nombreController.dispose();
    _cantidadController.dispose();
    _descripcionController.dispose();
    super.dispose();
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
        _codigoController.text = producto.id ?? '';
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
      for (final item in _productosAgregados) {
        final producto = item['producto'] as Producto;
        await _trasladoService.crearTraslado(
          productoId: producto.id!,
          origenBodegaId: _origenSeleccionado!,
          destinoBodegaId: _destinoSeleccionado!,
          cantidad: item['cantidad'],
          solicitante: widget.userName,
          observaciones: _descripcionController.text.isEmpty
              ? null
              : _descripcionController.text,
        );
      }

      _mostrarExito('Traslados creados exitosamente');
      widget.onTrasladoCreado();
    } catch (e) {
      _mostrarError('Error al crear traslado: $e');
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
              backgroundColor: Colors.white.withOpacity(0.2),
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
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.textMuted.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildDropdownBodega(
              label: 'Origen',
              value: _origenSeleccionado,
              onChanged: (value) => setState(() => _origenSeleccionado = value),
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
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.textMuted.withOpacity(0.2)),
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
            hint: Text('--', style: TextStyle(color: AppTheme.textMuted)),
            dropdownColor: AppTheme.cardBg,
            style: TextStyle(color: AppTheme.textPrimary),
            items: _bodegas.map((bodega) {
              return DropdownMenuItem(
                value: bodega['id'],
                child: Text(bodega['nombre']!),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildSeccionDatosProducto() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.textMuted.withOpacity(0.1)),
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
                  color: AppTheme.textPrimary,
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

          // Fila: Código, Nombre, Cantidad
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
                child: _buildCampoFormulario(
                  label: 'Nombre',
                  controller: _nombreController,
                  readOnly: true,
                ),
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
                      SizedBox(width: 8),
                      _buildBotonCircular(
                        icon: Icons.qr_code_scanner,
                        color: AppTheme.secondary,
                        onPressed: () =>
                            _mostrarMensaje('Escáner en desarrollo'),
                        tooltip: 'Escanear código',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // O seleccionar de lista
          SizedBox(height: 16),
          Text(
            'O seleccionar de la lista:',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.textMuted.withOpacity(0.2)),
            ),
            child: DropdownButtonFormField<Producto>(
              value: _productoSeleccionado,
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                hintText: 'Seleccionar producto',
                hintStyle: TextStyle(color: AppTheme.textMuted),
              ),
              dropdownColor: AppTheme.cardBg,
              style: TextStyle(color: AppTheme.textPrimary),
              isExpanded: true,
              items: widget.productos.map((producto) {
                return DropdownMenuItem(
                  value: producto,
                  child: Text(
                    '${producto.nombre} (Alm: ${producto.almacen ?? 0}, Bod: ${producto.bodega ?? 0})',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _productoSeleccionado = value;
                  _codigoController.text = value?.id ?? '';
                  _nombreController.text = value?.nombre ?? '';
                });
              },
            ),
          ),
        ],
      ),
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
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
            border: Border.all(color: AppTheme.textMuted.withOpacity(0.2)),
          ),
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            keyboardType: keyboardType,
            style: TextStyle(color: AppTheme.textPrimary),
            onSubmitted: onSubmitted,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              hintText: hint,
              hintStyle: TextStyle(color: AppTheme.textMuted),
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
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.textMuted.withOpacity(0.1)),
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
                            color: AppTheme.textMuted,
                            size: 40,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No hay productos agregados',
                            style: TextStyle(color: AppTheme.textMuted),
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
                              color: AppTheme.textMuted.withOpacity(0.1),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                producto.id?.substring(0, 6) ?? '-',
                                style: TextStyle(color: AppTheme.textPrimary),
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Text(
                                producto.nombre ?? '-',
                                style: TextStyle(color: AppTheme.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${item['cantidad']}',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                _origenSeleccionado ?? '-',
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                _destinoSeleccionado ?? '-',
                                style: TextStyle(color: AppTheme.textSecondary),
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
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.textMuted.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Descripción (opcional)',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          TextField(
            controller: _descripcionController,
            maxLines: 3,
            style: TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Observaciones adicionales...',
              hintStyle: TextStyle(color: AppTheme.textMuted),
              filled: true,
              fillColor: AppTheme.surfaceDark,
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
            foregroundColor: AppTheme.textSecondary,
            side: BorderSide(color: AppTheme.textMuted),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
