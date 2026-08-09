import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/cotizacion.dart';
import '../models/cliente.dart';
import '../models/negocio_info.dart';
import '../providers/datos_cache_provider.dart';
import '../services/cotizacion_service.dart';
import '../services/cliente_service.dart';
import '../services/negocio_info_service.dart';
import '../services/pdf_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_utils.dart';
import '../utils/logger.dart';
import '../utils/pagination_mixin.dart';
import '../utils/api_error.dart';
import '../utils/dialogs_helper.dart';
import '../widgets/common/screen_header.dart';

class CotizacionesListScreen extends StatefulWidget {
  @override
  _CotizacionesListScreenState createState() => _CotizacionesListScreenState();
}

class _CotizacionesListScreenState extends State<CotizacionesListScreen>
    with PaginacionMixin<CotizacionesListScreen> {
  final CotizacionService _cotizacionService = CotizacionService();
  final ClienteService _clienteService = ClienteService();
  final NegocioInfoService _negocioInfoService = NegocioInfoService();
  final PDFService _pdfService = PDFService();
  final TextEditingController _searchController = TextEditingController();

  List<Cotizacion> _cotizaciones = [];
  List<Cotizacion> _cotizacionesFiltradas = [];
  bool _isLoading = false;
  String _filtroEstado =
      'todos'; // todos, activa, aceptada, rechazada, vencida, convertida

  @override
  void initState() {
    super.initState();
    _cargarCotizaciones();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarCotizaciones() async {
    setState(() => _isLoading = true);

    try {
      final cotizaciones = await _cotizacionService.obtenerCotizaciones();
      setState(() {
        _cotizaciones = cotizaciones;
        _aplicarFiltros();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      showErrorDialog(context, 'Error al cargar cotizaciones: ${errorMessage(e)}');
    }
  }

  void _aplicarFiltros() {
    List<Cotizacion> filtradas = List.from(_cotizaciones);

    // Filtro por estado
    if (_filtroEstado != 'todos') {
      filtradas = filtradas.where((c) => c.estado == _filtroEstado).toList();
    }

    // Filtro por búsqueda
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      filtradas = filtradas.where((c) {
        return c.clienteId.toLowerCase().contains(query) ||
            c.descripcion?.toLowerCase().contains(query) == true;
      }).toList();
    }

    // Ordenar por fecha descendente
    filtradas.sort((a, b) => b.fecha.compareTo(a.fecha));

    resetPagina();
    setState(() => _cotizacionesFiltradas = filtradas);
  }

  Future<void> _facturarCotizacion(Cotizacion cotizacion) async {
    await context.push('/facturar', extra: cotizacion);
    // Recargar lista al regresar (la cotización puede haber quedado convertida)
    _cargarCotizaciones();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            _buildHeader(),
            _buildFiltros(),
            _buildEstadisticas(),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _cotizacionesFiltradas.isEmpty
                  ? _buildEmptyState()
                  : _buildCotizacionesList(),
            ),
          ],
        ),
    );
  }

  Widget _buildHeader() {
    return ScreenHeader(
      icon: Icons.request_quote,
      title: 'Gestión de Cotizaciones',
      badge: '${_cotizacionesFiltradas.length}',
      actions: [
        ScreenHeaderAction.primary(
          icon: Icons.add,
          label: 'Nueva Cotización',
          mobileLabel: 'Nueva',
          onPressed: () => _navegarAFormulario(null),
        ),
      ],
    );
  }

  Widget _buildFiltros() {
    final isMobile = context.isMobile;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Buscador — ocupa todo el espacio restante
          Expanded(
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: onSurface),
              decoration: InputDecoration(
                hintText: 'Buscar cotización...',
                hintStyle: TextStyle(color: onSurface.withOpacity(0.6)),
                prefixIcon: Icon(Icons.search, color: onSurface.withOpacity(0.7)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              onChanged: (value) => _aplicarFiltros(),
            ),
          ),
          SizedBox(width: 12),
          // Filtro por estado — ancho fijo grande para que se lea cómodo
          SizedBox(
            width: isMobile ? 160 : 220,
            child: DropdownButtonFormField<String>(
              value: _filtroEstado,
              dropdownColor: Theme.of(context).colorScheme.surface,
              style: TextStyle(color: onSurface),
              isExpanded: true,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              items: const [
                DropdownMenuItem(value: 'todos', child: Text('Todos los estados')),
                DropdownMenuItem(value: 'activa', child: Text('Activas')),
                DropdownMenuItem(value: 'aceptada', child: Text('Aceptadas')),
                DropdownMenuItem(value: 'rechazada', child: Text('Rechazadas')),
                DropdownMenuItem(value: 'vencida', child: Text('Vencidas')),
                DropdownMenuItem(value: 'convertida', child: Text('Convertidas')),
              ],
              onChanged: (value) {
                setState(() => _filtroEstado = value!);
                _aplicarFiltros();
              },
            ),
          ),
          SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.refresh, color: onSurface),
            onPressed: _cargarCotizaciones,
            tooltip: 'Refrescar',
          ),
        ],
      ),
    );
  }

  Widget _buildEstadisticas() {
    final activas = _cotizaciones.where((c) => c.estado == 'activa').length;
    final aceptadas = _cotizaciones.where((c) => c.estado == 'aceptada').length;
    final rechazadas = _cotizaciones
        .where((c) => c.estado == 'rechazada')
        .length;
    final vencidas = _cotizaciones.where((c) => c.estado == 'vencida').length;
    final convertidas = _cotizaciones
        .where((c) => c.estado == 'convertida')
        .length;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildEstadoChip('Activas', activas, Colors.blue),
            SizedBox(width: 12),
            _buildEstadoChip('Aceptadas', aceptadas, Colors.green),
            SizedBox(width: 12),
            _buildEstadoChip('Rechazadas', rechazadas, Colors.red),
            SizedBox(width: 12),
            _buildEstadoChip('Vencidas', vencidas, Colors.orange),
            SizedBox(width: 12),
            _buildEstadoChip('Convertidas', convertidas, AppTheme.secondary),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoChip(String label, int count, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
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
          Icon(Icons.request_quote_outlined, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty
                ? 'No hay cotizaciones registradas'
                : 'No se encontraron cotizaciones',
            style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onSurface),
          ),
          SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _navegarAFormulario(null),
            icon: Icon(Icons.add),
            label: Text('Crear primera cotización'),
          ),
        ],
      ),
    );
  }

  Widget _buildCotizacionesList() {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              itemCount: paginarLista(_cotizacionesFiltradas).length,
              separatorBuilder: (context, index) => Divider(height: 1),
              itemBuilder: (context, index) {
                final cotizacion = paginarLista(_cotizacionesFiltradas)[index];
                return _buildCotizacionItem(cotizacion);
              },
            ),
          ),
          buildPaginacion(
            totalItems: _cotizacionesFiltradas.length,
            accentColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildCotizacionItem(Cotizacion cotizacion) {
    final estadoColor = _getEstadoColor(cotizacion.estado);
    final diasVigencia =
        cotizacion.fechaVencimiento?.difference(DateTime.now()).inDays ?? 0;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isMobile = context.isMobile;

    final icono = Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: estadoColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(_getEstadoIcon(cotizacion.estado), color: estadoColor),
    );

    final encabezado = Row(
      children: [
        Expanded(
          child: Text(
            'Cotización #${cotizacion.id?.substring(0, 8) ?? 'N/A'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: onSurface,
            ),
          ),
        ),
        Chip(
          label: Text(
            _getEstadoLabel(cotizacion.estado),
            style: TextStyle(fontSize: 12, color: Colors.white),
          ),
          backgroundColor: estadoColor,
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );

    // ⚠️ Antes esto era el `subtitle` de un ListTile: con 4 filas de texto +
    // el badge de total, fácilmente supera la altura que ListTile reserva
    // para su subtítulo y genera un "BOTTOM OVERFLOWED" en pantallas
    // angostas donde el texto necesita más líneas. Un Column suelto (sin las
    // restricciones de alto de ListTile) no tiene ese problema.
    final detalle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.person, size: 14, color: onSurface),
            SizedBox(width: 4),
            Flexible(
              child: Text(
                'Cliente: ${cotizacion.clienteNombre ?? 'CONSUMIDOR FINAL'}',
                style: TextStyle(color: onSurface),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today, size: 14, color: onSurface),
                SizedBox(width: 4),
                Text(
                  'Fecha: ${cotizacion.fecha.day}/${cotizacion.fecha.month}/${cotizacion.fecha.year}',
                  style: TextStyle(color: onSurface),
                ),
              ],
            ),
            if (cotizacion.fechaVencimiento != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event, size: 14, color: onSurface),
                  SizedBox(width: 4),
                  Text(
                    'Vence: ${cotizacion.fechaVencimiento!.day}/${cotizacion.fechaVencimiento!.month}/${cotizacion.fechaVencimiento!.year}',
                    style: TextStyle(
                      color: diasVigencia < 0 ? Colors.red : onSurface,
                    ),
                  ),
                ],
              ),
          ],
        ),
        SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.shopping_cart, size: 14, color: onSurface),
            SizedBox(width: 4),
            Text(
              '${cotizacion.items.length} items',
              style: TextStyle(color: onSurface),
            ),
          ],
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'Total: ${CurrencyUtils.format(cotizacion.totalFinal)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
        ),
      ],
    );

    final acciones = _buildAcciones(cotizacion);

    // 📱 En mobile las acciones bajan debajo del contenido en vez de ir a la
    // derecha (mismo motivo que en la lista de clientes: no caben 3-4
    // IconButtons junto al encabezado sin aplastarlo).
    if (isMobile) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                icono,
                SizedBox(width: 12),
                Expanded(child: encabezado),
              ],
            ),
            Padding(padding: EdgeInsets.only(left: 62), child: detalle),
            Align(alignment: Alignment.centerRight, child: acciones),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          icono,
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [encabezado, detalle],
            ),
          ),
          acciones,
        ],
      ),
    );
  }

  Widget _buildAcciones(Cotizacion cotizacion) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (cotizacion.puedeConvertirseAFactura)
          IconButton(
            icon: Icon(Icons.point_of_sale, color: AppTheme.primary),
            onPressed: () => _facturarCotizacion(cotizacion),
            tooltip: 'Facturar',
          ),
        IconButton(
          icon: Icon(Icons.picture_as_pdf, color: Colors.orange),
          onPressed: () => _verPDF(cotizacion),
          tooltip: 'Ver PDF',
        ),
        IconButton(
          icon: Icon(Icons.edit, color: Colors.blue),
          onPressed: () => _navegarAFormulario(cotizacion),
          tooltip: 'Editar',
        ),
        IconButton(
          icon: Icon(Icons.delete, color: Colors.red),
          onPressed: () => _confirmarEliminar(cotizacion),
          tooltip: 'Eliminar',
        ),
      ],
    );
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'activa':
        return Colors.blue;
      case 'aceptada':
        return Colors.green;
      case 'rechazada':
        return Colors.red;
      case 'vencida':
        return Colors.orange;
      case 'convertida':
        return AppTheme.secondary;
      default:
        return Colors.grey[600]!;
    }
  }

  IconData _getEstadoIcon(String estado) {
    switch (estado) {
      case 'activa':
        return Icons.pending;
      case 'aceptada':
        return Icons.check_circle;
      case 'rechazada':
        return Icons.cancel;
      case 'vencida':
        return Icons.access_time;
      case 'convertida':
        return Icons.receipt;
      default:
        return Icons.help;
    }
  }

  String _getEstadoLabel(String estado) {
    switch (estado) {
      case 'activa':
        return 'ACTIVA';
      case 'aceptada':
        return 'ACEPTADA';
      case 'rechazada':
        return 'RECHAZADA';
      case 'vencida':
        return 'VENCIDA';
      case 'convertida':
        return 'CONVERTIDA';
      default:
        return estado.toUpperCase();
    }
  }

  void _navegarAFormulario(Cotizacion? cotizacion) async {
    final resultado = await context.push(
      '/cotizaciones/form',
      extra: cotizacion,
    );

    if (resultado == true) {
      _cargarCotizaciones();
    }
  }

  Future<void> _verPDF(Cotizacion cotizacion) async {
    try {
      setState(() => _isLoading = true);

      // 🔥 OBTENER DATOS COMPLETOS DEL CLIENTE - IGUAL QUE EN FACTURACION_SCREEN
      Cliente? clienteCompleto;
      final nombreClienteCotizacion = cotizacion.clienteNombre ?? '';
      
      appLog('📋 Buscando cliente para cotización...');
      appLog('   - clienteId: ${cotizacion.clienteId}');
      appLog('   - clienteNombre guardado: $nombreClienteCotizacion');

      // Estrategia 1: Buscar por ID
      if (cotizacion.clienteId.isNotEmpty) {
        try {
          clienteCompleto = await _clienteService.obtenerClientePorId(
            cotizacion.clienteId,
          );
          if (clienteCompleto != null) {
            appLog(
              '✅ Cliente encontrado por ID: ${clienteCompleto.nombreCompleto}',
            );
          }
        } catch (e) {
          appLog('⚠️ Error obteniendo cliente por ID: $e');
        }
      }

      // Estrategia 2: Si no se encontró por ID, buscar por nombre
      if (clienteCompleto == null && 
          nombreClienteCotizacion.isNotEmpty && 
          nombreClienteCotizacion != 'CONSUMIDOR FINAL') {
        try {
          appLog('🔍 Buscando cliente por nombre: "$nombreClienteCotizacion"');
          final resultados = await _clienteService.buscarClientes(nombreClienteCotizacion);
          if (resultados.isNotEmpty) {
            // Buscar coincidencia exacta primero
            final exacto = resultados.where(
              (c) => c.nombreCompleto.toLowerCase() == nombreClienteCotizacion.toLowerCase(),
            );
            clienteCompleto = exacto.isNotEmpty ? exacto.first : resultados.first;
            appLog(
              '✅ Cliente encontrado por nombre: ${clienteCompleto.nombreCompleto}',
            );
          } else {
            appLog('❌ No se encontró cliente con ese nombre');
          }
        } catch (e) {
          appLog('⚠️ Error buscando cliente por nombre: $e');
        }
      }

      // Nombre final para usar en el PDF
      final nombreCliente = clienteCompleto?.nombreCompleto ?? 
                           (nombreClienteCotizacion.isNotEmpty 
                             ? nombreClienteCotizacion 
                             : 'CONSUMIDOR FINAL');
      
      appLog('📝 Nombre final para PDF: $nombreCliente');

      // Info real del negocio (igual que en facturas_list_screen.dart)
      NegocioInfo? negocioInfo;
      try {
        negocioInfo = await _negocioInfoService.getNegocioInfo();
      } catch (e) {
        appLog('⚠️ No se pudo obtener info del negocio: $e');
      }

      // Mapa productoId → código interno para mostrar en PDF
      final codigoPorId = <String, String>{};
      try {
        final cache = Provider.of<DatosCacheProvider>(context, listen: false);
        for (final p in cache.productos ?? []) {
          if (p.codigo != null && p.codigo!.isNotEmpty) {
            codigoPorId[p.id] = p.codigo!;
          }
        }
      } catch (_) {}

      // Preparar datos del resumen para el PDF
      final resumen = {
        // Información del negocio - USAR NOMBRES DE CAMPOS QUE ESPERA PDF_SERVICE
        'nombreNegocio': negocioInfo?.nombre ?? 'VERCY MOTOS',
        'nombreRestaurante': negocioInfo?.nombre ?? 'VERCY MOTOS',
        'nit': negocioInfo?.nit ?? '',
        'email': negocioInfo?.email ?? '',
        'telefonoRestaurante': negocioInfo?.telefono ?? '',
        'direccionRestaurante': negocioInfo?.direccion ?? '',
        'ciudad': negocioInfo?.ciudad ?? 'MANIZALES',
        'departamento': negocioInfo?.departamento ?? 'CALDAS',

        // Información del cliente - USAR NOMBRES DE CAMPOS QUE ESPERA PDF_SERVICE
        'cliente': nombreCliente,  // ⚠️ PDF espera 'cliente', no 'clienteNombre'
        'clienteNit': clienteCompleto != null
            ? '${clienteCompleto.tipoIdentificacion} ${clienteCompleto.numeroIdentificacion}${clienteCompleto.digitoVerificacion != null ? "-${clienteCompleto.digitoVerificacion}" : ""}'
            : cotizacion.clienteId,
        'clienteCiudad': clienteCompleto?.ciudad ?? 'MANIZALES',
        'clienteTelefono':
            clienteCompleto?.telefono ?? (cotizacion.clienteTelefono ?? ''),
        'clienteCorreo':  // ⚠️ PDF espera 'clienteCorreo', no 'clienteEmail'
            clienteCompleto?.correo ?? (cotizacion.clienteEmail ?? ''),
        'clienteDepartamento': clienteCompleto?.departamento ?? 'CALDAS',
        'clienteDireccion': clienteCompleto?.direccion ?? '',
        'clienteTipoId': clienteCompleto?.tipoIdentificacion ?? 'CC',

        // Información de la cotización
        'numeroCotizacion':
            cotizacion.numeroCotizacion ??
            'COT-${cotizacion.id?.substring(0, 8) ?? 'NEW'}',
        'fechaCotizacion':
            '${cotizacion.fecha.year}-${cotizacion.fecha.month.toString().padLeft(2, '0')}-${cotizacion.fecha.day.toString().padLeft(2, '0')}',
        'fechaVence': cotizacion.fechaVencimiento != null
            ? '${cotizacion.fechaVencimiento!.year}-${cotizacion.fechaVencimiento!.month.toString().padLeft(2, '0')}-${cotizacion.fechaVencimiento!.day.toString().padLeft(2, '0')}'
            : '',

        // Items - Convertir de ItemCotizacion a formato esperado POR EL PDF
        'items': cotizacion.items
            .map(
              (item) => {
                'codigo': codigoPorId[item.productoId] ?? item.codigoProducto ?? '',
                'productoNombre': item.productoNombre ?? 'Producto sin nombre',
                'cantidad': item.cantidad,
                'precioUnitario': item.precioUnitario,
                'porcentajeDescuento': item.porcentajeDescuento,
                'valorDescuento': item.valorDescuento,
                'porcentajeImpuesto': item.porcentajeImpuesto,
                'valorImpuesto': item.valorImpuesto,
                'subtotal': item.subtotal,
                'total': item.valorTotal,
              },
            )
            .toList(),

        // Totales
        'subtotal': cotizacion.subtotal,
        'totalIva': cotizacion.totalImpuestos,
        'totalDescuentos': cotizacion.totalDescuentos,
        'totalRetenciones': cotizacion.totalRetenciones,
        'total': cotizacion.totalFinal,
        'totalSinIva': cotizacion.subtotal - cotizacion.totalDescuentos,
        'baseImp': cotizacion.subtotal - cotizacion.totalDescuentos,

        // Detalles de retenciones
        'retencion': cotizacion.valorRetencion,
        'reteIVA': cotizacion.valorReteIVA,
        'reteICA': cotizacion.valorReteICA,

        // Cantidades
        'cantidadArticulos': cotizacion.items.length,
        'cantidadProductos': cotizacion.items.length,

        // Observaciones
        'observaciones': cotizacion.descripcion ?? '',

        // Tipo de documento
        'tipoDocumento': 'COTIZACIÓN',
      };

      // Generar el PDF usando el servicio existente
      await _pdfService.mostrarDialogoImpresion(
        resumen: resumen,
        esFactura: true,
      );

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('PDF de cotización generado correctamente'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      showErrorDialog(context, 'Error al generar PDF: ${errorMessage(e)}');
    }
  }

  Future<void> _confirmarEliminar(Cotizacion cotizacion) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar eliminación'),
        content: Text('¿Está seguro de eliminar esta cotización?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _cotizacionService.eliminarCotizacion(cotizacion.id!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cotización eliminada'),
            backgroundColor: Colors.green,
          ),
        );
        _cargarCotizaciones();
      } catch (e) {
        showErrorDialog(context, 'Error al eliminar: ${errorMessage(e)}');
      }
    }
  }
}
