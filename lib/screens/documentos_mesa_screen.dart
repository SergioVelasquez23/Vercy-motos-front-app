import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/documento_mesa.dart';
import '../models/mesa.dart';
import '../services/documento_mesa_service.dart';
import '../services/pdf_service.dart';
import '../services/pdf_service_web.dart';
import '../utils/negocio_info_cache.dart';
import '../utils/format_utils.dart';
import '../utils/impresion_mixin.dart';
import 'pedido_screen.dart';
import '../theme/app_theme.dart';

class DocumentosMesaScreen extends StatefulWidget {
  final Mesa? mesa; // Puede ser nulo para mostrar todos los documentos

  const DocumentosMesaScreen({super.key, this.mesa});

  @override
  State<DocumentosMesaScreen> createState() => _DocumentosMesaScreenState();
}

class _DocumentosMesaScreenState extends State<DocumentosMesaScreen>
    with TickerProviderStateMixin, ImpresionMixin {
  final DocumentoMesaService _documentoService = DocumentoMesaService();
  final PDFService _pdfService = PDFService();
  List<DocumentoMesa> _documentos = [];
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  final TextEditingController _searchController = TextEditingController();

  // Getters para compatibilidad con AppTheme
  Color get _primary => AppTheme.primary;
  Color get _bgDark => AppTheme.backgroundDark;
  Color get _cardBg => AppTheme.cardBg;
  Color get _textLight => AppTheme.textLight;

  // Variables para modo global o por mesa
  bool get _esModoPorMesa => widget.mesa != null;

  // Selector de fecha para filtros
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppTheme.primary,
              onPrimary: AppTheme.textDark,
              surface: AppTheme.cardBg,
              onSurface: AppTheme.textLight,
            ),
            dialogTheme: DialogThemeData(backgroundColor: AppTheme.cardBg),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _fechaInicio = picked;
        } else {
          _fechaFin = picked;
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarDocumentos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarDocumentos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final documentos = _esModoPorMesa
          ? await _documentoService.getDocumentosPorMesa(widget.mesa!.nombre)
          : await _documentoService.getDocumentos();

      // Debug: verificar qué datos de pago están llegando
      print('📋 Documentos cargados: ${documentos.length}');
      for (var doc in documentos.take(3)) {
        // Solo los primeros 3 para no saturar el log
        print('  🧾 Documento ${doc.numeroDocumento}:');
        print('    - formaPago: ${doc.formaPago}');
        print('    - pagadoPor: ${doc.pagadoPor}');
        print('    - pagado: ${doc.pagado}');
        print('    - propina: ${doc.propina}');
      }

      // Ordenar documentos por fecha descendente (más recientes primero)
      documentos.sort((a, b) {
        final fechaA = a.fechaCreacion ?? a.fecha;
        final fechaB = b.fechaCreacion ?? b.fecha;
        return fechaB.compareTo(fechaA);
      });

      setState(() {
        _documentos = documentos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar documentos: $e';
        _isLoading = false;
      });
    }
  }

  List<DocumentoMesa> get _documentosPendientes =>
      _documentos.where((doc) => !doc.pagado && !doc.anulado).toList();

  List<DocumentoMesa> get _documentosPagados =>
      _documentos.where((doc) => doc.pagado && !doc.anulado).toList();

  double get _totalPendiente =>
      _documentosPendientes.fold(0.0, (sum, doc) => sum + doc.total);

  double get _totalPagado =>
      _documentosPagados.fold(0.0, (sum, doc) => sum + doc.total);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        title: Text(
          _esModoPorMesa
              ? "${widget.mesa!.nombre} - Documentos"
              : "Documentos de Mesas",
          style: AppTheme.headlineSmall.copyWith(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.backgroundDark,
        elevation: 0,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _cargarDocumentos),
          if (_esModoPorMesa) // Solo mostrar botón de crear si estamos en modo mesa específica
            IconButton(icon: Icon(Icons.add), onPressed: _crearNuevoDocumento),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.textDark,
          unselectedLabelColor: AppTheme.textLight,
          tabs: [
            Tab(text: 'Todos (${_documentos.length})'),
            Tab(text: 'Pendientes (${_documentosPendientes.length})'),
            Tab(text: 'Pagados (${_documentosPagados.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildResumenCard(),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: _primary))
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, style: TextStyle(color: Colors.red)),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _cargarDocumentos,
                          child: Text('Reintentar'),
                        ),
                      ],
                    ),
                  )
                : _buildTablaDocumentos(),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenCard() {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: _cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pendiente',
                    style: TextStyle(color: Colors.amber, fontSize: 12),
                  ),
                  SizedBox(height: 2),
                  Text(
                    formatCurrency(_totalPendiente),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    '${_documentosPendientes.length} documentos',
                    style: TextStyle(
                      color: _textLight.withOpacity(0.7),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 36,
              width: 1,
              color: Colors.grey.withOpacity(0.3),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text(
                      'Pagado',
                      style: TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ),
                  SizedBox(height: 2),
                  Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text(
                      formatCurrency(_totalPagado),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 1),
                  Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text(
                      '${_documentosPagados.length} documentos',
                      style: TextStyle(
                        color: _textLight.withOpacity(0.7),
                        fontSize: 10,
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
  }

  // Construye una vista de tabla para los documentos
  Widget _buildTablaDocumentos() {
    // Obtener documentos según filtros de fechas y texto
    List<DocumentoMesa> documentosFiltrados = _documentos;

    // Aplicar filtro de fechas si están definidas
    if (_fechaInicio != null || _fechaFin != null) {
      documentosFiltrados = documentosFiltrados.where((doc) {
        final fechaDoc = doc.fechaCreacion ?? doc.fecha;
        if (_fechaInicio != null && _fechaFin != null) {
          return fechaDoc.isAfter(_fechaInicio!) &&
              fechaDoc.isBefore(_fechaFin!.add(Duration(days: 1)));
        } else if (_fechaInicio != null) {
          return fechaDoc.isAfter(_fechaInicio!);
        } else {
          return fechaDoc.isBefore(_fechaFin!.add(Duration(days: 1)));
        }
      }).toList();
    }

    // Aplicar filtro de texto si está definido
    if (_searchController.text.isNotEmpty) {
      final searchText = _searchController.text.toLowerCase();
      documentosFiltrados = documentosFiltrados
          .where(
            (doc) =>
                doc.numeroDocumento.toLowerCase().contains(searchText) ||
                doc.mesaNombre.toLowerCase().contains(searchText) ||
                doc.vendedor.toLowerCase().contains(searchText) ||
                (doc.formaPago?.toLowerCase().contains(searchText) ?? false),
          )
          .toList();
    }

    // Determinar qué documentos mostrar según la pestaña seleccionada
    final List<DocumentoMesa> documentosAMostrar;
    switch (_tabController.index) {
      case 1:
        documentosAMostrar = documentosFiltrados
            .where((doc) => !doc.pagado && !doc.anulado)
            .toList();
        break;
      case 2:
        documentosAMostrar = documentosFiltrados
            .where((doc) => doc.pagado && !doc.anulado)
            .toList();
        break;
      default:
        documentosAMostrar = documentosFiltrados;
    }

    if (documentosAMostrar.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.table_chart,
              size: 64,
              color: _textLight.withOpacity(0.5),
            ),
            SizedBox(height: 16),
            Text(
              'No hay documentos para mostrar',
              style: TextStyle(color: _textLight.withOpacity(0.7)),
            ),
          ],
        ),
      );
    }

    // Construir la vista con filtros y tabla
    return Column(
      children: [
        // Filtros de búsqueda
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Column(
            children: [
              // Primera fila de filtros: Fechas
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context, true),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Desde',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _fechaInicio != null
                                  ? '${_fechaInicio!.day}/${_fechaInicio!.month}/${_fechaInicio!.year}'
                                  : 'Seleccionar fecha',
                              style: TextStyle(fontSize: 14),
                            ),
                            Icon(Icons.calendar_today, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context, false),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Hasta',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _fechaFin != null
                                  ? '${_fechaFin!.day}/${_fechaFin!.month}/${_fechaFin!.year}'
                                  : 'Seleccionar fecha',
                              style: TextStyle(fontSize: 14),
                            ),
                            Icon(Icons.calendar_today, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              // Segunda fila: Campo de búsqueda y botón de búsqueda
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Buscar',
                        hintText: 'Número, mesa, facturador...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {});
                      },
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _fechaInicio = null;
                        _fechaFin = null;
                        _searchController.clear();
                      });
                    },
                    icon: Icon(Icons.clear, size: 18),
                    label: Text('Limpiar', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                  ),
                  SizedBox(width: 4),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {});
                    },
                    icon: Icon(Icons.search, size: 18),
                    label: Text('Buscar', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Tabla de datos con mayor tamaño y mejor espaciado
        Expanded(
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Detectar si es móvil
                final isMovil = constraints.maxWidth < 768;

                if (isMovil) {
                  // Layout móvil: Lista de cards
                  return _buildMobileDocumentsList(documentosAMostrar);
                } else {
                  // Layout desktop: DataTable con scroll horizontal
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        columnSpacing: 18, // Menos espacio entre columnas
                        horizontalMargin: 8, // Margen horizontal menor
                        dataRowHeight: 44, // Filas más compactas
                        headingRowHeight: 48, // Encabezado más compacto
                        headingRowColor: WidgetStateProperty.all(
                          _primary.withOpacity(0.1),
                        ),
                        dataRowColor: WidgetStateProperty.resolveWith<Color?>((
                          Set<WidgetState> states,
                        ) {
                          if (states.contains(WidgetState.selected)) {
                            return _primary.withOpacity(0.2);
                          }
                          return null;
                        }),
                        columns: [
                          DataColumn(
                            label: Text(
                              'No.',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Mesa',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Facturador',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Estado',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Medio de Pago',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Total',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Fecha',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Acciones',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                        rows: documentosAMostrar.map((documento) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  documento.numeroDocumento,
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                              DataCell(
                                Text(
                                  documento.mesaNombre,
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                              DataCell(
                                Text(
                                  documento.vendedor,
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: documento.estadoColor.withOpacity(
                                      0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    documento.estadoTexto,
                                    style: TextStyle(
                                      color: documento.estadoColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  documento.formaPago ?? 'Sin especificar',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: documento.formaPago == null
                                        ? _textLight.withOpacity(0.6)
                                        : _textLight,
                                    fontStyle: documento.formaPago == null
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  formatCurrency(documento.total),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  documento.fechaFormateada,
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.visibility,
                                        color: _primary,
                                      ),
                                      onPressed: () =>
                                          _verDetalleDocumento(documento),
                                      tooltip: 'Ver detalle',
                                      iconSize: 28,
                                      splashRadius: 26,
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.print,
                                        color: Colors.blue,
                                      ),
                                      onPressed: () =>
                                          _mostrarDialogoImpresion(documento),
                                      tooltip: 'Imprimir',
                                      iconSize: 28,
                                      splashRadius: 26,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  // Layout móvil: Lista de cards
  Widget _buildMobileDocumentsList(List<DocumentoMesa> documentos) {
    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: documentos.length,
      itemBuilder: (context, index) {
        final documento = documentos[index];
        return Card(
          color: _cardBg,
          margin: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: InkWell(
            onTap: () => _verDetalleDocumento(documento),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Primera fila: Número y estado
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Doc. #${documento.numeroDocumento}',
                        style: TextStyle(
                          color: _textLight,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: documento.anulado
                              ? Colors.red.withOpacity(0.2)
                              : documento.pagado
                              ? Colors.green.withOpacity(0.2)
                              : Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          documento.anulado
                              ? 'ANULADO'
                              : documento.pagado
                              ? 'PAGADO'
                              : 'PENDIENTE',
                          style: TextStyle(
                            color: documento.anulado
                                ? Colors.red
                                : documento.pagado
                                ? Colors.green
                                : Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),

                  // Segunda fila: Mesa y fecha
                  Row(
                    children: [
                      Icon(Icons.table_restaurant, size: 16, color: _primary),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          documento.mesaNombre,
                          style: TextStyle(color: _textLight, fontSize: 14),
                        ),
                      ),
                      Icon(Icons.calendar_today, size: 16, color: _primary),
                      SizedBox(width: 4),
                      Text(
                        documento.fechaFormateada,
                        style: TextStyle(
                          color: _textLight.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),

                  // Tercera fila: Vendedor y total
                  Row(
                    children: [
                      Icon(Icons.person, size: 16, color: _primary),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          documento.vendedor,
                          style: TextStyle(
                            color: _textLight.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Text(
                        formatCurrency(documento.total),
                        style: TextStyle(
                          color: _primary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  // Cuarta fila: Forma de pago (si existe)
                  if (documento.formaPago != null) ...[
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.payment, size: 16, color: _primary),
                        SizedBox(width: 4),
                        Text(
                          documento.formaPago!,
                          style: TextStyle(
                            color: _textLight.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Botones de acción
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Botón Ver
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _verDetalleDocumento(documento),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary.withOpacity(0.2),
                            foregroundColor: _primary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          icon: Icon(Icons.visibility, size: 16),
                          label: Text('Ver', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      SizedBox(width: 8),

                      // Botón Imprimir
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _mostrarDialogoImpresion(documento),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.withOpacity(0.2),
                            foregroundColor: Colors.green,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          icon: Icon(Icons.print, size: 16),
                          label: Text(
                            'Imprimir',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _verDetalleDocumento(DocumentoMesa documento) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text(
          'Documento #${documento.numeroDocumento}',
          style: TextStyle(color: _textLight),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetalleItem('Fecha', documento.fechaFormateada),
              _buildDetalleItem('Vendedor', documento.vendedor),
              _buildDetalleItem('Mesa', documento.mesaNombre),
              if (documento.pagado)
                _buildDetalleItem('Pagado por', documento.pagadoPor ?? 'N/A'),
              if (documento.formaPago != null)
                _buildDetalleItem('Forma de pago', documento.formaPago!),
              if (documento.fechaPago != null)
                _buildDetalleItem(
                  'Fecha de pago',
                  '${documento.fechaPago!.day}/${documento.fechaPago!.month}/${documento.fechaPago!.year} ${documento.fechaPago!.hour}:${documento.fechaPago!.minute.toString().padLeft(2, '0')}',
                ),
              Divider(color: Colors.grey.withOpacity(0.5)),
              // Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL',
                    style: TextStyle(
                      color: _textLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    formatCurrency(documento.total),
                    style: TextStyle(
                      color: _primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _mostrarDialogoImpresion(documento);
            },
            icon: Icon(Icons.print, color: Colors.blue),
            label: Text('Imprimir', style: TextStyle(color: Colors.blue)),
          ),
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close, color: _textLight),
            label: Text('Cerrar', style: TextStyle(color: _textLight)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalleItem(
    String label,
    String value, {
    bool isHighlighted = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: TextStyle(
                color: _textLight.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                color: isHighlighted ? Colors.red : _textLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _crearNuevoDocumento() async {
    if (widget.mesa == null) return;

    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PedidoScreen(mesa: widget.mesa!)),
    );

    if (resultado == true) {
      _cargarDocumentos();
    }
  }

  void _mostrarDialogoImpresion(DocumentoMesa documento) async {
    try {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );

      // Preparar resumen para impresión usando el backend
      final Map<String, dynamic>? resumen = await prepararResumenDocumento(
        documento,
      );

      // Obtener info del negocio
      final negocioInfo = await NegocioInfoCache.getNegocioInfo();
      if (negocioInfo != null && resumen != null) {
        resumen['nombreRestaurante'] = negocioInfo.nombre;
        resumen['direccionRestaurante'] = negocioInfo.direccion;
        resumen['telefonoRestaurante'] = negocioInfo.contacto;
      }

      // Cerrar indicador de carga
      Navigator.of(context).pop();

      if (resumen == null) {
        mostrarMensajeError('No se pudo preparar el resumen para impresión');
        return;
      }

      // Detectar plataforma y usar el servicio apropiado
      if (kIsWeb) {
        // Para web, usar el servicio web especializado
        final pdfServiceWeb = PDFServiceWeb();

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: Text(
              'Compartir Resumen',
              style: TextStyle(color: Colors.black),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Documento ${documento.numeroDocumento}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  '¿Cómo deseas compartir este resumen?',
                  style: TextStyle(color: Colors.black),
                ),
                SizedBox(height: 20),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              'Generando PDF...',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    );

                    pdfServiceWeb.generarYDescargarPDF(resumen: resumen);
                    Navigator.of(context).pop(); // Cerrar loading
                  } catch (e) {
                    Navigator.of(context).pop(); // Cerrar loading
                    mostrarMensajeError('Error generando PDF: $e');
                  }
                },
                icon: Icon(Icons.picture_as_pdf),
                label: Text('PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFF6B00),
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await pdfServiceWeb.compartirTexto(resumen: resumen);
                  } catch (e) {
                    mostrarMensajeError('Error compartiendo: $e');
                  }
                },
                icon: Icon(Icons.share),
                label: Text('Texto'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      } else {
        // Para móvil, usar el servicio tradicional
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: Text(
              'Opciones de Impresión',
              style: TextStyle(color: Colors.black),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Documento ${documento.numeroDocumento}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  '¿Cómo deseas imprimir este documento?',
                  style: TextStyle(color: Colors.black),
                ),
                SizedBox(height: 20),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await _pdfService.mostrarVistaPrevia(
                      resumen: resumen,
                      esFactura: false,
                    );
                  } catch (e) {
                    mostrarMensajeError('Error en vista previa: $e');
                  }
                },
                icon: Icon(Icons.print),
                label: Text('Imprimir'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFF6B00),
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await compartirPedido(resumen);
                    mostrarMensajeExito('PDF compartido correctamente');
                  } catch (e) {
                    mostrarMensajeError('Error compartiendo: $e');
                  }
                },
                icon: Icon(Icons.share),
                label: Text('Compartir'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      mostrarMensajeError('Error preparando documento: $e');
    }
  }
}
