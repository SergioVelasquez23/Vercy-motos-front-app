import 'package:flutter/material.dart';
import '../models/documento_mesa.dart';
import '../models/mesa.dart';
import '../models/item_pedido.dart';
import '../services/documento_mesa_service.dart';
import 'pedido_screen.dart';

class DocumentosMesaScreen extends StatefulWidget {
  final Mesa? mesa; // Puede ser nulo para mostrar todos los documentos

  const DocumentosMesaScreen({Key? key, this.mesa}) : super(key: key);

  @override
  State<DocumentosMesaScreen> createState() => _DocumentosMesaScreenState();
}

class _DocumentosMesaScreenState extends State<DocumentosMesaScreen>
    with TickerProviderStateMixin {
  final DocumentoMesaService _documentoService = DocumentoMesaService();
  List<DocumentoMesa> _documentos = [];
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  final TextEditingController _searchController = TextEditingController();

  // Constantes de diseño
  static const Color _primary = Color(0xFFFF6B00);
  static const Color _bgDark = Color(0xFF121212);
  static const Color _cardBg = Color(0xFF1E1E1E);
  static const Color _textLight = Color(0xFFE0E0E0);

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
              primary: _primary,
              onPrimary: Colors.white,
              surface: _cardBg,
              onSurface: _textLight,
            ),
            dialogBackgroundColor: _cardBg,
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
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _primary,
        elevation: 0,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _cargarDocumentos),
          if (_esModoPorMesa) // Solo mostrar botón de crear si estamos en modo mesa específica
            IconButton(icon: Icon(Icons.add), onPressed: _crearNuevoDocumento),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
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
      margin: EdgeInsets.all(16),
      color: _cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pendiente',
                    style: TextStyle(color: Colors.amber, fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '\$${_totalPendiente.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '${_documentosPendientes.length} documentos',
                    style: TextStyle(
                      color: _textLight.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 50,
              width: 1,
              color: Colors.grey.withOpacity(0.3),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Text(
                      'Pagado',
                      style: TextStyle(color: Colors.green, fontSize: 14),
                    ),
                  ),
                  SizedBox(height: 4),
                  Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Text(
                      '\$${_totalPagado.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 2),
                  Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Text(
                      '${_documentosPagados.length} documentos',
                      style: TextStyle(
                        color: _textLight.withOpacity(0.7),
                        fontSize: 12,
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
          padding: const EdgeInsets.all(16.0),
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
              SizedBox(height: 16),
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
                  SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _fechaInicio = null;
                        _fechaFin = null;
                        _searchController.clear();
                      });
                    },
                    icon: Icon(Icons.clear),
                    label: Text('Limpiar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {});
                    },
                    icon: Icon(Icons.search),
                    label: Text('Buscar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
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
            width: double.infinity, // Usar todo el ancho disponible
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Scrollbar(
                scrollbarOrientation: ScrollbarOrientation.bottom,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth:
                          MediaQuery.of(context).size.width *
                          1.2, // 20% más ancho
                    ),
                    child: DataTable(
                      columnSpacing: 40, // Aún más espacio entre columnas
                      horizontalMargin: 20, // Margen horizontal mayor
                      dataRowHeight: 68, // Filas aún más altas
                      headingRowHeight: 75, // Encabezado más alto
                      headingRowColor: MaterialStateProperty.all(
                        _primary.withOpacity(0.1),
                      ),
                      dataRowColor: MaterialStateProperty.resolveWith<Color?>((
                        Set<MaterialState> states,
                      ) {
                        if (states.contains(MaterialState.selected)) {
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
                                  color: documento.estadoColor.withOpacity(0.2),
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
                                '\$${documento.total.toStringAsFixed(0)}',
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
                                    icon: Icon(Icons.print, color: Colors.blue),
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
                ),
              ),
            ),
          ),
        ),
      ],
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
                    '\$${documento.total.toStringAsFixed(0)}',
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

  void _mostrarDialogoImpresion(DocumentoMesa documento) {
    // Crear una vista similar al resumen de pedido que se ve en la segunda imagen
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        contentPadding: EdgeInsets.all(0),
        content: Container(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Sopa y Carbón',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        'Dirección del restaurante',
                        style: TextStyle(fontSize: 16, color: Colors.black),
                      ),
                      Text(
                        'Tel: Teléfono del restaurante',
                        style: TextStyle(fontSize: 16, color: Colors.black),
                      ),
                    ],
                  ),
                ),
                Divider(thickness: 1, color: Colors.black),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RESUMEN DE PEDIDO',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildImpresionItem('Pedido:', documento.numeroDocumento),
                      _buildImpresionItem(
                        'Fecha:',
                        '${documento.fecha.year}-${documento.fecha.month.toString().padLeft(2, '0')}-${documento.fecha.day.toString().padLeft(2, '0')}',
                      ),
                      _buildImpresionItem(
                        'Hora:',
                        '${documento.fecha.hour.toString().padLeft(2, '0')}:${documento.fecha.minute.toString().padLeft(2, '0')}',
                      ),
                      _buildImpresionItem('Mesa:', documento.mesaNombre),
                      _buildImpresionItem('Mesero:', documento.vendedor),
                      // Agregar información del pago si está disponible
                      if (documento.formaPago != null)
                        _buildImpresionItem(
                          'Medio de Pago:',
                          documento.formaPago!,
                        ),
                      if (documento.pagadoPor != null)
                        _buildImpresionItem(
                          'Atendido por:',
                          documento.pagadoPor!,
                        ),
                      if (documento.propina != null && documento.propina! > 0)
                        _buildImpresionItem(
                          'Propina:',
                          '\$${documento.propina!.toStringAsFixed(0)}',
                        ),
                    ],
                  ),
                ),
                Divider(thickness: 1, color: Colors.black),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PRODUCTOS:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 8),
                      // Mostrar productos del pedido
                      ..._generarListaProductos(documento),
                    ],
                  ),
                ),
                Divider(thickness: 1, color: Colors.black),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL:',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        '\$${documento.total.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                Center(
                  child: Text(
                    '¡Gracias por su preferencia!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                      color: Colors.black,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'Fecha: ${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}\n'
                      'Hora: ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:${DateTime.now().second.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 14, color: Colors.black),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              // Aquí iría la lógica real de impresión
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Imprimiendo documento ${documento.numeroDocumento}...',
                  ),
                  backgroundColor: Colors.blue,
                  duration: Duration(seconds: 2),
                ),
              );
              Navigator.of(context).pop();
            },
            icon: Icon(Icons.print),
            label: Text('Imprimir'),
            style: TextButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Widget _buildImpresionItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _generarListaProductos(DocumentoMesa documento) {
    List<Widget> widgets = [];

    print('🔍 Debug _generarListaProductos:');
    print('  - Documento ID: ${documento.id}');
    print('  - Número de pedidos: ${documento.pedidos.length}');
    print('  - IDs de pedidos: ${documento.pedidosIds}');

    // Intentar obtener productos del resumen del pedido si está disponible
    // (Los documentos generados automáticamente incluyen un campo resumenPedido)

    // Si tenemos pedidos con detalles
    if (documento.pedidos.isNotEmpty) {
      print('  - Procesando ${documento.pedidos.length} pedidos con detalles');
      for (var pedido in documento.pedidos) {
        print('    - Pedido ${pedido.id} con ${pedido.items.length} items');
        for (var item in pedido.items) {
          // Determinar el mejor nombre para mostrar
          String displayName;
          if (item.producto?.nombre != null &&
              item.producto!.nombre.isNotEmpty) {
            displayName = item.producto!.nombre;
          } else if (item.productoId.isNotEmpty) {
            displayName = item.productoId;
          } else {
            displayName = "Producto";
          }

          print(
            '      - Item: ${item.cantidad}x $displayName - \$${item.subtotal.toStringAsFixed(0)}',
          );

          widgets.add(
            Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${item.cantidad}x $displayName',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '\$${item.subtotal.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (item.notas?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0, top: 2),
                      child: Text(
                        'Obs: ${item.notas}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }
      }
    } else {
      print(
        '  - No hay pedidos con detalles, intentando mostrar productos del resumen',
      );

      // Intentar crear productos ficticios basados en el total
      // Para documentos sin productos detallados, mostrar al menos algo útil
      widgets.add(
        Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Consumo total',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '\$${documento.total.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );

      // Agregar información adicional si es posible
      if (documento.pedidosIds.isNotEmpty) {
        widgets.add(
          Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Pedido(s): ${documento.pedidosIds.join(", ")}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        );
      }
    }

    print('  - Total de widgets generados: ${widgets.length}');
    return widgets;
  }
}
