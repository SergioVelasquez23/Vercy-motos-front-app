import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../models/documento_mesa.dart';
import '../models/mesa.dart';
import '../services/documento_mesa_service.dart';
import '../services/pdf_service.dart';
import '../services/pdf_service_web.dart';
import '../utils/negocio_info_cache.dart';
import '../utils/format_utils.dart';
import '../utils/impresion_mixin.dart';
import '../widgets/factura_electronica_widgets.dart';
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
  
  // 🚀 NUEVO: Flag para rastrear si se creó un pedido
  bool _pedidoCreado = false;

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
    _tabController = TabController(length: 1, vsync: this);
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

  double get _totalGeneral => _documentos
      .where((doc) => !doc.anulado)
      .fold(0.0, (sum, doc) => sum + doc.total);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // 🚀 Al cerrar la pantalla, devolver información si se creó un pedido
        if (_pedidoCreado && widget.mesa != null) {
          Navigator.of(context).pop({
            'pedidoCreado': true,
            'mesaNombre': widget.mesa!.nombre,
          });
          return false; // No cerrar automáticamente, ya manejamos el pop
        }
        return true; // Cerrar normalmente
      },
      child: Scaffold(
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
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.textDark,
          unselectedLabelColor: AppTheme.textLight,
          tabs: [
            Tab(
              text:
                  'Documentos (${_documentos.where((doc) => !doc.anulado).length})',
            ),
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
      floatingActionButton: _esModoPorMesa
          ? FloatingActionButton(
              onPressed: _crearNuevoDocumento,
              backgroundColor: AppTheme.primary,
              child: Icon(Icons.add, color: Colors.white),
              tooltip: 'Crear Nuevo Documento',
            )
          : null,
      ), // child: Scaffold
    ); // WillPopScope
  }

  Widget _buildResumenCard() {
    final documentosActivos = _documentos.where((doc) => !doc.anulado).toList();

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: _cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Documentos',
                  style: TextStyle(
                    color: _primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '${documentosActivos.length}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Total Ventas',
                  style: TextStyle(
                    color: _primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  formatCurrency(_totalGeneral),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
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

    // Mostrar solo documentos activos (no anulados)
    final List<DocumentoMesa> documentosAMostrar = documentosFiltrados
        .where((doc) => !doc.anulado)
        .toList();

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
                      foregroundColor: Colors.white,
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
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: 1200),
                        child: DataTable(
                          columnSpacing: 24, // Espacio entre columnas aumentado
                          horizontalMargin: 12, // Margen horizontal aumentado
                          dataRowHeight: 44, // Filas más compactas
                          headingRowHeight: 48, // Encabezado más compacto
                          headingRowColor: WidgetStateProperty.all(
                            _primary.withOpacity(0.1),
                          ),
                          dataRowColor: WidgetStateProperty.resolveWith<Color?>(
                            (Set<WidgetState> states) {
                              if (states.contains(WidgetState.selected)) {
                                return _primary.withOpacity(0.2);
                              }
                              return null;
                            },
                          ),
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
                                          Icons.print,
                                          color: Colors.blue,
                                        ),
                                        onPressed: () =>
                                            _mostrarDialogoImpresion(documento),
                                        tooltip: 'Imprimir',
                                        iconSize: 28,
                                        splashRadius: 26,
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.receipt_long,
                                          color: Colors.green,
                                        ),
                                        onPressed: () async {
                                          final resultado =
                                              await showDialog<
                                                Map<String, dynamic>
                                              >(
                                                context: context,
                                                builder: (context) =>
                                                    DatosFacturaElectronicaDialog(
                                                      documentoMesa: documento,
                                                    ),
                                              );
                                          if (resultado != null) {
                                            // Aquí se procesará la factura
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Procesando factura...',
                                                ),
                                                backgroundColor: Colors.blue,
                                              ),
                                            );
                                          }
                                        },
                                        tooltip: 'Generar Factura Electrónica',
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
                  // Primera fila: Número de documento
                  Row(
                    children: [
                      Text(
                        'Doc. #${documento.numeroDocumento}',
                        style: TextStyle(
                          color: _textLight,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
                      SizedBox(width: 8),
                      // Botón Factura Electrónica
                      Expanded(
                        child: BotonSolicitarFacturaElectronica(
                          documentoMesa: documento,
                          onFacturaGenerada: (doc, factura) async {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Factura ${factura.numeroFactura} generada',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                            await _cargarDocumentos();
                          },
                          compact: true,
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
          if (documento.facturaElectronica == null)
            BotonSolicitarFacturaElectronica(
              documentoMesa: documento,
              onFacturaGenerada: (doc, factura) async {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '✅ Factura ${factura.numeroFactura} generada',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
                await _cargarDocumentos();
              },
              compact: true,
            ),
          if (documento.facturaElectronica != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: EstadoFacturaElectronicaWidget(documentoMesa: documento),
            ),
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
      // 🚀 NUEVO: Marcar que se creó un pedido para notificarlo cuando se cierre esta pantalla
      // No cerramos inmediatamente, solo marcamos el flag
      setState(() {
        _pedidoCreado = true;
      });
      
      print('✅ Pedido creado desde documentos para mesa ${widget.mesa!.nombre}');
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
        // Para web, usar directamente PDFServiceWeb como en mesas_screen
        final pdfServiceWeb = PDFServiceWeb();

        _mostrarDialogoCompartirConCliente(documento, resumen, pdfServiceWeb);
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
                              'Preparando documento...',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    );

                    await _pdfService.mostrarVistaPrevia(
                      resumen: resumen,
                      esFactura: false,
                    );

                    Navigator.of(context).pop(); // Cerrar loading

                    // Mostrar mensaje de éxito específico para Windows
                    if (!kIsWeb && Platform.isWindows) {
                      mostrarMensajeExito(
                        'PDF guardado en documentos. Busque el archivo en su carpeta de documentos.',
                      );
                    }
                  } catch (e) {
                    Navigator.of(context).pop(); // Cerrar loading
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

  // ✅ NUEVO: Diálogo para compartir con información del cliente
  void _mostrarDialogoCompartirConCliente(
    DocumentoMesa documento,
    Map<String, dynamic> resumen,
    dynamic pdfServiceWeb,
  ) {
    bool incluirDatosCliente = false;
    String clienteNombre = '';
    String clienteNit = '';
    String clienteCorreo = '';
    String clienteTelefono = '';
    String clienteDireccion = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            'Compartir Resumen',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Documento ${documento.numeroDocumento}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 16),

                // Toggle para incluir datos del cliente
                Row(
                  children: [
                    Switch(
                      value: incluirDatosCliente,
                      onChanged: (value) {
                        setState(() {
                          incluirDatosCliente = value;
                        });
                      },
                      activeColor: Color(0xFFFF6B00),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Incluir datos del cliente en el documento',
                        style: TextStyle(color: Colors.black),
                      ),
                    ),
                  ],
                ),

                // Campos del cliente (solo si está activado)
                if (incluirDatosCliente) ...[
                  SizedBox(height: 16),
                  Text(
                    'Información del Cliente:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Nombre del Cliente',
                      border: OutlineInputBorder(),
                      labelStyle: TextStyle(color: Colors.black54),
                    ),
                    style: TextStyle(color: Colors.black),
                    onChanged: (value) => clienteNombre = value,
                  ),
                  SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'NIT/CC',
                      border: OutlineInputBorder(),
                      labelStyle: TextStyle(color: Colors.black54),
                    ),
                    style: TextStyle(color: Colors.black),
                    onChanged: (value) => clienteNit = value,
                  ),
                  SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Correo Electrónico',
                      border: OutlineInputBorder(),
                      labelStyle: TextStyle(color: Colors.black54),
                    ),
                    style: TextStyle(color: Colors.black),
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (value) => clienteCorreo = value,
                  ),
                  SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Teléfono',
                      border: OutlineInputBorder(),
                      labelStyle: TextStyle(color: Colors.black54),
                    ),
                    style: TextStyle(color: Colors.black),
                    keyboardType: TextInputType.phone,
                    onChanged: (value) => clienteTelefono = value,
                  ),
                  SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Dirección',
                      border: OutlineInputBorder(),
                      labelStyle: TextStyle(color: Colors.black54),
                    ),
                    style: TextStyle(color: Colors.black),
                    onChanged: (value) => clienteDireccion = value,
                  ),
                ],

                SizedBox(height: 20),
                Text(
                  '¿Cómo deseas compartir este resumen?',
                  style: TextStyle(color: Colors.black),
                ),
              ],
            ),
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
                  // Preparar resumen con datos del cliente si están incluidos
                  Map<String, dynamic> resumenFinal = Map.from(resumen);

                  if (incluirDatosCliente) {
                    resumenFinal['clienteNombre'] = clienteNombre;
                    resumenFinal['clienteNit'] = clienteNit;
                    resumenFinal['clienteCorreo'] = clienteCorreo;
                    resumenFinal['clienteTelefono'] = clienteTelefono;
                    resumenFinal['clienteDireccion'] = clienteDireccion;
                    resumenFinal['incluirDatosCliente'] = true;
                  }

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

                  pdfServiceWeb.generarYDescargarPDF(resumen: resumenFinal);
                  Navigator.of(context).pop(); // Cerrar loading

                  // Mostrar mensaje de éxito
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Generando PDF...'),
                      backgroundColor: Colors.green,
                    ),
                  );
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
                  // Preparar resumen con datos del cliente si están incluidos
                  Map<String, dynamic> resumenFinal = Map.from(resumen);

                  if (incluirDatosCliente) {
                    resumenFinal['clienteNombre'] = clienteNombre;
                    resumenFinal['clienteNit'] = clienteNit;
                    resumenFinal['clienteCorreo'] = clienteCorreo;
                    resumenFinal['clienteTelefono'] = clienteTelefono;
                    resumenFinal['clienteDireccion'] = clienteDireccion;
                    resumenFinal['incluirDatosCliente'] = true;
                  }

                  await pdfServiceWeb.compartirTexto(resumen: resumenFinal);
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
      ),
    );
  }
}
