import 'package:flutter/material.dart';
import '../models/cotizacion.dart';
import '../models/cliente.dart';
import '../models/factura.dart';
import '../services/cotizacion_service.dart';
import '../services/cliente_service.dart';
import '../services/pdf_service.dart';
import '../theme/app_theme.dart';
import '../widgets/vercy_sidebar_layout.dart';
import '../utils/logger.dart';
import '../utils/pagination_mixin.dart';
import '../services/factura_service.dart';
import '../models/item_pedido.dart';

class CotizacionesListScreen extends StatefulWidget {
  @override
  _CotizacionesListScreenState createState() => _CotizacionesListScreenState();
}

class _CotizacionesListScreenState extends State<CotizacionesListScreen>
    with PaginacionMixin<CotizacionesListScreen> {
  final CotizacionService _cotizacionService = CotizacionService();
  final FacturaService _facturaService = FacturaService();
  final ClienteService _clienteService = ClienteService();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar cotizaciones: $e'),
          backgroundColor: Colors.red,
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    return VercySidebarLayout(
      title: 'Cotizaciones',
      child: Scaffold(
        backgroundColor: AppTheme.backgroundDark,
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
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _navegarAFormulario(null),
          backgroundColor: AppTheme.primary,
          icon: Icon(Icons.add),
          label: Text('Nueva Cotización'),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.request_quote, color: AppTheme.primary, size: 32),
          SizedBox(width: 12),
          Text(
            'Gestión de Cotizaciones',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Spacer(),
          Text(
            '${_cotizacionesFiltradas.length} cotizaciones',
            style: TextStyle(fontSize: 16, color: Colors.black),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          // Buscador
          Expanded(
            flex: 3,
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Buscar cotización...',
                hintStyle: TextStyle(color: Colors.black),
                prefixIcon: Icon(Icons.search, color: Colors.black),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                filled: true,
                fillColor: AppTheme.surfaceDark,
              ),
              onChanged: (value) => _aplicarFiltros(),
            ),
          ),
          SizedBox(width: 16),
          // Filtro por estado
          DropdownButton<String>(
            value: _filtroEstado,
            dropdownColor: AppTheme.cardBg,
            style: TextStyle(color: AppTheme.textPrimary),
            items: [
              DropdownMenuItem(
                value: 'todos',
                child: Text('Todos los estados'),
              ),
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
          SizedBox(width: 16),
          // Botón refrescar
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
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
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildEstadoChip('Activas', activas, Colors.blue),
          _buildEstadoChip('Aceptadas', aceptadas, Colors.green),
          _buildEstadoChip('Rechazadas', rechazadas, Colors.red),
          _buildEstadoChip('Vencidas', vencidas, Colors.orange),
          _buildEstadoChip('Convertidas', convertidas, AppTheme.secondary),
        ],
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
            style: TextStyle(fontSize: 18, color: Colors.black),
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
        color: AppTheme.cardBg,
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

    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: estadoColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(_getEstadoIcon(cotizacion.estado), color: estadoColor),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              'Cotización #${cotizacion.id?.substring(0, 8) ?? 'N/A'}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
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
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.person, size: 14, color: Colors.black),
              SizedBox(width: 4),
              Text(
                'Cliente: ${cotizacion.clienteNombre ?? 'CONSUMIDOR FINAL'}',
                style: TextStyle(color: Colors.black),
              ),
            ],
          ),
          SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.black),
              SizedBox(width: 4),
              Text(
                'Fecha: ${cotizacion.fecha.day}/${cotizacion.fecha.month}/${cotizacion.fecha.year}',
                style: TextStyle(color: Colors.black),
              ),
              SizedBox(width: 16),
              if (cotizacion.fechaVencimiento != null) ...[
                Icon(Icons.event, size: 14, color: Colors.black),
                SizedBox(width: 4),
                Text(
                  'Vence: ${cotizacion.fechaVencimiento!.day}/${cotizacion.fechaVencimiento!.month}/${cotizacion.fechaVencimiento!.year}',
                  style: TextStyle(
                    color: diasVigencia < 0 ? Colors.red : Colors.black,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.shopping_cart, size: 14, color: Colors.black),
              SizedBox(width: 4),
              Text(
                '${cotizacion.items.length} items',
                style: TextStyle(color: Colors.black),
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
              'Total: \$${cotizacion.totalFinal.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
      trailing: _buildAcciones(cotizacion),
    );
  }

  Widget _buildAcciones(Cotizacion cotizacion) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.picture_as_pdf, color: Colors.orange),
          onPressed: () => _verPDF(cotizacion),
          tooltip: 'Ver PDF',
        ),
        if (cotizacion.estado == 'activa') ...[
          IconButton(
            icon: Icon(Icons.check_circle, color: Colors.green),
            onPressed: () => _aceptarCotizacion(cotizacion),
            tooltip: 'Aceptar',
          ),
          IconButton(
            icon: Icon(Icons.cancel, color: Colors.red),
            onPressed: () => _rechazarCotizacion(cotizacion),
            tooltip: 'Rechazar',
          ),
        ],
        if (cotizacion.puedeConvertirseAFactura) ...[
          IconButton(
            icon: Icon(Icons.receipt, color: AppTheme.secondary),
            onPressed: () => _convertirAFactura(cotizacion),
            tooltip: 'Convertir a factura',
          ),
        ],
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
    final resultado = await Navigator.pushNamed(
      context,
      '/cotizaciones/form',
      arguments: cotizacion,
    );

    if (resultado == true) {
      _cargarCotizaciones();
    }
  }

  Future<void> _aceptarCotizacion(Cotizacion cotizacion) async {
    try {
      await _cotizacionService.aceptarCotizacion(cotizacion.id!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cotización aceptada'),
          backgroundColor: Colors.green,
        ),
      );
      _cargarCotizaciones();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _rechazarCotizacion(Cotizacion cotizacion) async {
    try {
      await _cotizacionService.rechazarCotizacion(cotizacion.id!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cotización rechazada'),
          backgroundColor: Colors.orange,
        ),
      );
      _cargarCotizaciones();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _convertirAFactura(Cotizacion cotizacion) async {
    if (cotizacion.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se puede convertir una cotización sin ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text(
          'Convertir a factura',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Se creará una factura a partir de la cotización #${cotizacion.id?.substring(0, 8) ?? ""}\n\nCliente: ${cotizacion.clienteNombre}\nTotal: ${cotizacion.totalFinal}',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Convertir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      // 1. Crear factura desde la cotización
      final factura = Factura(
        clienteNombre: cotizacion.clienteNombre ?? 'Cliente General',
        clienteNit: null, // Asume null si no existe clienteNit
        clienteTelefono: cotizacion.clienteTelefono,
        total: cotizacion.totalFinal,
        subtotal: cotizacion.subtotal,
        descuento: cotizacion.totalDescuentos,
        estadoPago: 'PENDIENTE',
        items: cotizacion.items
            ?.map(
              (i) => ItemPedido(
                productoId: i.productoId,
                productoNombre: i.productoNombre,
                cantidad: i.cantidad,
                precioUnitario: i.precioUnitario,
              ),
            )
            .toList(),
        fechaCreacion: DateTime.now(),
        datosAdicionales: {'origenCotizacion': cotizacion.id},
      );
      final facturaCreada = await _facturaService.crearFactura(factura);
      if (facturaCreada == null) throw Exception('No se pudo crear la factura');

      // 2. Marcar cotización como convertida
      await _cotizacionService.convertirAFactura(
        cotizacion.id!,
        facturaCreada.id!,
      );
      await _cargarCotizaciones();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Factura #\${facturaCreada.numero ?? facturaCreada.id} creada exitosamente',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al convertir: \$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

      // Preparar datos del resumen para el PDF
      final resumen = {
        // Información del negocio
        'negocioNombre': 'VERCY MOTOS',
        'negocioNit': '1002378776-7',
        'negocioTelefono': '(6) 8839844',
        'negocioDireccion': 'Carrera 19 Calle 23, Caldas - Manizales, Caldas',
        'negocioCorreo': 'juandiegocaycedo1@gmail.com',

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
                'codigo': item.codigoProducto ?? item.productoId,
                'detalle': item.productoNombre ?? 'Producto sin nombre',
                'cantidad': item.cantidad,
                'valorUnit': item.precioUnitario,
                'dcto': item.porcentajeDescuento,
                'valorDcto': item.valorDescuento,
                'iva': item.porcentajeImpuesto,
                'valorIVA': item.valorImpuesto,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al generar PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
