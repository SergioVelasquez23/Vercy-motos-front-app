import 'package:flutter/material.dart';

class DocumentosScreen extends StatefulWidget {
  const DocumentosScreen({Key? key}) : super(key: key);

  @override
  _DocumentosScreenState createState() {
    print('DocumentosScreen - Creating State');
    return _DocumentosScreenState();
  }
}

class _DocumentosScreenState extends State<DocumentosScreen>
    with SingleTickerProviderStateMixin {
  final Color primary = Color(0xFFFF6B00); // Color naranja fuego
  final Color bgDark = Color(0xFF1E1E1E); // Color de fondo negro
  final Color cardBg = Color(0xFF252525); // Color de tarjetas
  final Color textDark = Color(0xFFE0E0E0); // Color de texto claro
  final Color textLight = Color(0xFFA0A0A0); // Color de texto más suave
  final Color accentOrange = Color(0xFFFF8800); // Naranja más brillante

  // Variable para controlar el modo de visualización
  bool _mostrarComoTabla = false; // Por defecto, mostrar como tarjetas

  late TabController _tabController;
  TextEditingController _searchController = TextEditingController();
  String _filtro = '';

  // Fechas para el filtro
  TextEditingController _fechaInicioController = TextEditingController();
  TextEditingController _fechaFinController = TextEditingController();

  // Lista de estados posibles de los documentos
  List<String> _tiposDocumento = [
    'Todos',
    'Factura',
    'Recibo',
    'Nota de crédito',
    'Comanda',
  ];
  // Tipo de documento seleccionado para filtrar
  // Se inicializa en initState() y se utiliza en _filtrarDocumentos()
  String? _tipoSeleccionado;

  // Datos simulados de documentos para demostración
  List<Map<String, dynamic>> _documentos = [
    {
      'id': 'FAC-001',
      'fecha': '2025-06-28',
      'hora': '14:35:42',
      'cliente': 'Juan Diego Restrepo',
      'tipo': 'Factura',
      'estado': 'Pagada',
      'total': 96000,
      'proveedorDomicilio': '', // Proveedor del domicilio si aplica
      'facturador': 'Sopa y Carbon', // Quien factura
      'mesa': '', // Identificador de mesa si aplica
      'medioPago': 'Efectivo', // Forma de pago
      'pagadoCon': 'Efectivo: 96000', // Detalle del pago
      'fechaPago': '2025-06-28 14:35:42', // Fecha y hora del pago
      'base': 80672, // Base imponible
      'totalImp': 15328, // Total impuestos
      'propina': 0, // Propina
      'comisionProveedor': 0, // Comisión al proveedor de domicilio
      'domicilio': false, // Si es domicilio
      'items': [
        {
          'producto': 'Asado Mixto',
          'cantidad': 1,
          'precio': 34000,
          'total': 34000,
        },
        {
          'producto': 'Hígado Encebollado',
          'cantidad': 1,
          'precio': 27000,
          'total': 27000,
        },
        {'producto': 'Coca Cola', 'cantidad': 2, 'precio': 4500, 'total': 9000},
        {
          'producto': 'Papas a la Francesa',
          'cantidad': 1,
          'precio': 9000,
          'total': 9000,
        },
        {
          'producto': 'Entrada de Chicharrón',
          'cantidad': 1,
          'precio': 17000,
          'total': 17000,
        },
      ],
    },
    {
      'id': 'REC-002',
      'fecha': '2025-06-28',
      'hora': '15:30:12',
      'cliente': 'Domicilio - Sopa y Carbon',
      'tipo': 'Recibo',
      'estado': 'Generado',
      'total': 25000,
      'proveedorDomicilio': 'Rappi', // Proveedor del domicilio si aplica
      'facturador': 'Sopa y Carbon', // Quien factura
      'mesa': '', // Identificador de mesa si aplica
      'medioPago': 'Efectivo', // Forma de pago
      'pagadoCon': 'Efectivo: 25000', // Detalle del pago
      'fechaPago': '2025-06-28 15:30:12', // Fecha y hora del pago
      'base': 21008, // Base imponible
      'totalImp': 3992, // Total impuestos
      'propina': 0, // Propina
      'comisionProveedor': 3750, // Comisión al proveedor de domicilio (15%)
      'domicilio': true, // Si es domicilio
      'items': [
        {
          'producto': 'Ejecutivo',
          'cantidad': 1,
          'precio': 19000,
          'total': 19000,
        },
        {'producto': 'Patacón', 'cantidad': 2, 'precio': 3000, 'total': 6000},
      ],
    },
    {
      'id': 'FAC-003',
      'fecha': '2025-06-28',
      'hora': '13:15:30',
      'cliente': 'María López Gómez',
      'tipo': 'Factura',
      'estado': 'Pagada',
      'total': 52000,
      'proveedorDomicilio': '', // Proveedor del domicilio si aplica
      'facturador': 'Sopa y Carbon', // Quien factura
      'mesa': 'Mesa B3', // Identificador de mesa si aplica
      'medioPago': 'Tarjeta', // Forma de pago
      'pagadoCon': 'Tarjeta: 52000', // Detalle del pago
      'fechaPago': '2025-06-28 13:15:30', // Fecha y hora del pago
      'base': 43697, // Base imponible
      'totalImp': 8303, // Total impuestos
      'propina': 5200, // Propina (10%)
      'comisionProveedor': 0, // Comisión al proveedor de domicilio
      'domicilio': false, // Si es domicilio
      'items': [
        {
          'producto': 'Pechuga a la plancha',
          'cantidad': 1,
          'precio': 24000,
          'total': 24000,
        },
        {
          'producto': 'Jugo Natural',
          'cantidad': 1,
          'precio': 8000,
          'total': 8000,
        },
        {
          'producto': 'Postre de la casa',
          'cantidad': 2,
          'precio': 10000,
          'total': 20000,
        },
      ],
    },
    {
      'id': 'COM-004',
      'fecha': '2025-06-28',
      'hora': '12:45:18',
      'cliente': 'Mesa C2',
      'tipo': 'Comanda',
      'estado': 'En cocina',
      'total': 42000,
      'proveedorDomicilio': '', // Proveedor del domicilio si aplica
      'facturador': 'Sopa y Carbon', // Quien factura
      'mesa': 'Mesa C2', // Identificador de mesa si aplica
      'medioPago': 'Pendiente', // Forma de pago
      'pagadoCon': '', // Detalle del pago
      'fechaPago': '', // Fecha y hora del pago
      'base': 35294, // Base imponible
      'totalImp': 6706, // Total impuestos
      'propina': 0, // Propina
      'comisionProveedor': 0, // Comisión al proveedor de domicilio
      'domicilio': false, // Si es domicilio
      'items': [
        {
          'producto': 'Bandeja Paisa',
          'cantidad': 1,
          'precio': 32000,
          'total': 32000,
        },
        {
          'producto': 'Cerveza Nacional',
          'cantidad': 1,
          'precio': 10000,
          'total': 10000,
        },
      ],
    },
    {
      'id': 'CRE-005',
      'fecha': '2025-06-27',
      'hora': '11:20:05',
      'cliente': 'Andrea Ruiz Ospina',
      'tipo': 'Nota de crédito',
      'estado': 'Aplicada',
      'total': 28000,
      'proveedorDomicilio': '', // Proveedor del domicilio si aplica
      'facturador': 'Sopa y Carbon', // Quien factura
      'mesa': '', // Identificador de mesa si aplica
      'medioPago': 'Efectivo', // Forma de pago
      'pagadoCon': 'Efectivo: 28000', // Detalle del pago
      'fechaPago': '2025-06-27 11:20:05', // Fecha y hora del pago
      'base': 23529, // Base imponible
      'totalImp': 4471, // Total impuestos
      'propina': 0, // Propina
      'comisionProveedor': 0, // Comisión al proveedor de domicilio
      'domicilio': false, // Si es domicilio
      'items': [
        {
          'producto': 'Pescado Frito',
          'cantidad': 1,
          'precio': 28000,
          'total': 28000,
        },
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    print('DocumentosScreen - initState called');

    // Inicializar TabController inmediatamente
    _tabController = TabController(
      length: _tiposDocumento.length,
      vsync: this,
      initialIndex: 0,
    );

    // Agregar un listener para debug y para manejar el cambio de tab
    _tabController.addListener(() {
      print('DocumentosScreen - Tab changed to: ${_tabController.index}');
      if (_tabController.indexIsChanging) {
        setState(() {
          // Actualizar el tipo seleccionado cuando cambia el tab
          _tipoSeleccionado = _tiposDocumento[_tabController.index];
        });
      }
    });

    // Inicializar fechas a hoy
    final now = DateTime.now();
    _fechaInicioController.text =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _fechaFinController.text =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Inicializar el tipo seleccionado
    _tipoSeleccionado = 'Todos';

    // Extra log para debugging
    print('DocumentosScreen - Tipo seleccionado: $_tipoSeleccionado');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _fechaInicioController.dispose();
    _fechaFinController.dispose();
    super.dispose();
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'Pagada':
        return Colors.green;
      case 'Generado':
        return Colors.blue;
      case 'En cocina':
        return accentOrange;
      case 'Aplicada':
        return Colors.purple;
      case 'Anulada':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  List<Map<String, dynamic>> _filtrarDocumentos(String tipo) {
    var documentosFiltrados = _documentos;

    // Actualizar el tipo seleccionado para otros filtros
    _tipoSeleccionado = tipo;

    // Filtrar por tipo de documento si se especifica
    if (tipo != 'Todos') {
      documentosFiltrados = documentosFiltrados
          .where((d) => d['tipo'] == tipo)
          .toList();
    }

    // Filtrar por texto de búsqueda
    if (_filtro.isNotEmpty) {
      documentosFiltrados = documentosFiltrados.where((d) {
        return d['id'].toLowerCase().contains(_filtro.toLowerCase()) ||
            d['cliente'].toLowerCase().contains(_filtro.toLowerCase()) ||
            d['estado'].toLowerCase().contains(_filtro.toLowerCase());
      }).toList();
    }

    return documentosFiltrados;
  }

  String _formatearNumero(dynamic valor) {
    if (valor == null) return '\$0';

    // Asegurarse de que el valor sea un entero
    int valorInt;
    if (valor is int) {
      valorInt = valor;
    } else if (valor is double) {
      valorInt = valor.round();
    } else {
      try {
        valorInt = int.parse(valor.toString());
      } catch (e) {
        print('❌ Error convirtiendo valor a entero: $valor');
        return '\$0';
      }
    }

    return '\$${valorInt.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  @override
  Widget build(BuildContext context) {
    // Imprimir para depuración
    print(
      'Construyendo DocumentosScreen con ${_documentos.length} documentos y tipoSeleccionado: $_tipoSeleccionado',
    );

    return WillPopScope(
      // Interceptamos el botón de regreso para asegurar una navegación limpia
      onWillPop: () async {
        print('DocumentosScreen - Back button pressed');
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: bgDark,
        appBar: AppBar(
          title: Text(
            'Documentos',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: primary,
          elevation: 0,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            isScrollable: true,
            tabs: _tiposDocumento.map((tipo) => Tab(text: tipo)).toList(),
          ),
          actions: [
            // Botón para alternar entre vista tabla y tarjetas
            IconButton(
              icon: Icon(
                _mostrarComoTabla ? Icons.view_module : Icons.table_chart,
              ),
              tooltip: _mostrarComoTabla
                  ? 'Ver como tarjetas'
                  : 'Ver como tabla',
              onPressed: () {
                setState(() {
                  _mostrarComoTabla = !_mostrarComoTabla;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _mostrarComoTabla
                            ? 'Cambiado a vista de tabla'
                            : 'Cambiado a vista de tarjetas',
                      ),
                      duration: Duration(seconds: 1),
                    ),
                  );
                });
              },
            ),
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  // Aquí se recargarían los datos desde el servidor
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Actualizando documentos...')),
                );
              },
            ),
            SizedBox(width: 16),
          ],
        ),
        body: Column(
          children: [
            // Filtros
            _buildFiltros(),

            // TabBarView para los diferentes tipos de documentos
            Expanded(
              child: _tabController.index < _tiposDocumento.length
                  ? TabBarView(
                      controller: _tabController,
                      children: _tiposDocumento
                          .map((tipo) => _buildDocumentosList(tipo))
                          .toList(),
                    )
                  : Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(primary),
                      ),
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            _mostrarOpcionesNuevoDocumento(context);
          },
          backgroundColor: primary,
          child: Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildFiltros() {
    return Card(
      color: cardBg,
      elevation: 4,
      margin: EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "FILTROS DE BÚSQUEDA",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                // Fecha inicio
                Expanded(
                  child: TextFormField(
                    controller: _fechaInicioController,
                    style: TextStyle(color: textDark),
                    decoration: InputDecoration(
                      labelText: 'Fecha Inicio',
                      labelStyle: TextStyle(color: textLight),
                      suffixIcon: Icon(Icons.calendar_today, color: primary),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade800),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: primary),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.2),
                    ),
                    readOnly: true,
                    onTap: () async {
                      // Aquí iría el código para mostrar un selector de fecha
                      // Por ahora solo mostraremos un mensaje
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Selector de fecha')),
                      );
                    },
                  ),
                ),
                SizedBox(width: 16),
                // Fecha fin
                Expanded(
                  child: TextFormField(
                    controller: _fechaFinController,
                    style: TextStyle(color: textDark),
                    decoration: InputDecoration(
                      labelText: 'Fecha Fin',
                      labelStyle: TextStyle(color: textLight),
                      suffixIcon: Icon(Icons.calendar_today, color: primary),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade800),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: primary),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.2),
                    ),
                    readOnly: true,
                    onTap: () async {
                      // Aquí iría el código para mostrar un selector de fecha
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Selector de fecha')),
                      );
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            // Barra de búsqueda
            TextField(
              controller: _searchController,
              style: TextStyle(color: textDark),
              decoration: InputDecoration(
                hintText: 'Buscar por ID, cliente o estado...',
                hintStyle: TextStyle(color: textLight),
                prefixIcon: Icon(Icons.search, color: primary),
                suffixIcon: _filtro.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: textLight),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _filtro = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.black.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade800),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primary),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade800),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _filtro = value;
                });
              },
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.search),
                  label: Text('Buscar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    // Lógica para filtrar documentos
                    setState(() {
                      // Aquí se aplicarían los filtros
                    });
                  },
                ),
                SizedBox(width: 16),
                OutlinedButton.icon(
                  icon: Icon(Icons.refresh),
                  label: Text('Limpiar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textDark,
                    side: BorderSide(color: textLight),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _filtro = '';

                      // Resetear fechas a hoy
                      final now = DateTime.now();
                      _fechaInicioController.text =
                          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                      _fechaFinController.text =
                          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Usaremos un booleano en el state para esto
  Widget _buildDocumentosList(String tipo) {
    final documentos = _filtrarDocumentos(tipo);

    if (documentos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description, size: 80, color: primary.withOpacity(0.5)),
            SizedBox(height: 16),
            Text(
              'No hay documentos${tipo != 'Todos' ? ' tipo ' + tipo.toLowerCase() : ''}',
              style: TextStyle(color: textLight, fontSize: 18),
            ),
          ],
        ),
      );
    }

    if (_mostrarComoTabla) {
      // Vista de tabla - Usamos la variable de estado para determinar la vista
      return Container(
        height: MediaQuery.of(context).size.height - 300,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado de tabla
                Container(
                  color: cardBg,
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          'ID',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 150,
                        child: Text(
                          'Fecha',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: Text(
                          'No.',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          'Mesa',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 150,
                        child: Text(
                          'Facturador',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          'Estado',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: Text(
                          'Medio de Pago',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 150,
                        child: Text(
                          'Pagado con',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: Text(
                          'Total',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          'Base',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          'Imp.',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          'Propina',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          'Comisión',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: Text(
                          'Domicilio',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 150,
                        child: Text(
                          'Cliente',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          'Acciones',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Filas de documentos
                ...documentos.map((doc) {
                  return Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
                      ),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            doc['id'],
                            style: TextStyle(color: primary),
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          child: Text(
                            '${doc['fecha']}\n${doc['hora']}',
                            style: TextStyle(color: textLight),
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: Text(
                            doc['id'].split('-')[1],
                            style: TextStyle(color: textLight),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text(
                            doc['mesa'] ?? '',
                            style: TextStyle(color: textLight),
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          child: Text(
                            doc['facturador'],
                            style: TextStyle(color: textLight),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getEstadoColor(
                                doc['estado'],
                              ).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              doc['estado'],
                              style: TextStyle(
                                color: _getEstadoColor(doc['estado']),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: Text(
                            doc['medioPago'],
                            style: TextStyle(color: textLight),
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          child: Text(
                            doc['pagadoCon'],
                            style: TextStyle(color: textLight),
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: Text(
                            _formatearNumero(doc['total']),
                            style: TextStyle(
                              color: primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text(
                            _formatearNumero(doc['base']),
                            style: TextStyle(color: textLight),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text(
                            _formatearNumero(doc['totalImp']),
                            style: TextStyle(color: textLight),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text(
                            _formatearNumero(doc['propina']),
                            style: TextStyle(color: textLight),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text(
                            _formatearNumero(doc['comisionProveedor']),
                            style: TextStyle(color: textLight),
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: Text(
                            doc['proveedorDomicilio'],
                            style: TextStyle(color: textLight),
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          child: Text(
                            doc['cliente'],
                            style: TextStyle(color: textLight),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.print,
                                  size: 18,
                                  color: textLight,
                                ),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Imprimiendo documento ${doc['id']}...',
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.email,
                                  size: 18,
                                  color: Colors.blue,
                                ),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Enviando documento ${doc['id']}...',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      );
    } else {
      // Vista de tarjetas (la original)
      return ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: documentos.length,
        itemBuilder: (context, index) {
          final documento = documentos[index];
          return _buildDocumentoCard(documento);
        },
      );
    }
  }

  Widget _buildDocumentoCard(Map<String, dynamic> documento) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      color: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        documento['id'],
                        style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getEstadoColor(
                          documento['estado'],
                        ).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        documento['estado'],
                        style: TextStyle(
                          color: _getEstadoColor(documento['estado']),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  documento['hora'],
                  style: TextStyle(color: textLight, fontSize: 14),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Tipo: ${documento['tipo']}',
                              style: TextStyle(color: textDark),
                            ),
                          ),
                          documento['mesa'] != ''
                              ? Container(
                                  margin: EdgeInsets.only(right: 10),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primary.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    documento['mesa'],
                                    style: TextStyle(
                                      color: primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              : Container(),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Cliente: ${documento['cliente']}',
                        style: TextStyle(color: textDark),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Fecha: ${documento['fecha']} ${documento['hora']}',
                        style: TextStyle(color: textLight),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Medio pago: ${documento['medioPago']}',
                            style: TextStyle(color: textLight),
                          ),
                          SizedBox(width: 10),
                          documento['domicilio']
                              ? Row(
                                  children: [
                                    Icon(
                                      Icons.delivery_dining,
                                      color: primary,
                                      size: 16,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Domicilio: ${documento['proveedorDomicilio']}',
                                      style: TextStyle(
                                        color: primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                )
                              : Container(),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _formatearNumero(documento['total']),
                    style: TextStyle(
                      color: primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                'Detalles del documento',
                style: TextStyle(color: textDark, fontWeight: FontWeight.bold),
              ),
              children: [
                ...documento['items'].map<Widget>((item) {
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      item['producto'],
                      style: TextStyle(color: textDark),
                    ),
                    subtitle: Text(
                      '${_formatearNumero(item['precio'])} x ${item['cantidad']}',
                      style: TextStyle(color: textLight),
                    ),
                    trailing: Text(
                      _formatearNumero(item['total']),
                      style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
                Divider(color: Colors.grey.withOpacity(0.5)),

                // Información adicional de los impuestos y valores
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      // Fila de base e impuestos
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Base:', style: TextStyle(color: textLight)),
                          Text(
                            _formatearNumero(documento['base']),
                            style: TextStyle(color: textLight),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Impuestos:',
                            style: TextStyle(color: textLight),
                          ),
                          Text(
                            _formatearNumero(documento['totalImp']),
                            style: TextStyle(color: textLight),
                          ),
                        ],
                      ),

                      // Mostrar propina si existe
                      documento['propina'] > 0
                          ? Column(
                              children: [
                                SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Propina:',
                                      style: TextStyle(color: textLight),
                                    ),
                                    Text(
                                      _formatearNumero(documento['propina']),
                                      style: TextStyle(color: textLight),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Container(),

                      // Mostrar comisión de domicilio si existe
                      documento['comisionProveedor'] > 0
                          ? Column(
                              children: [
                                SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Comisión ${documento['proveedorDomicilio']}:',
                                      style: TextStyle(color: textLight),
                                    ),
                                    Text(
                                      _formatearNumero(
                                        documento['comisionProveedor'],
                                      ),
                                      style: TextStyle(color: textLight),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Container(),

                      SizedBox(height: 8),
                      Divider(color: Colors.grey.withOpacity(0.5)),
                      SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total:',
                            style: TextStyle(
                              color: textDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _formatearNumero(documento['total']),
                            style: TextStyle(
                              color: primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),

                      // Información adicional de pago
                      documento['pagadoCon'] != ''
                          ? Column(
                              children: [
                                SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Pagado con: ',
                                      style: TextStyle(
                                        color: textLight,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      documento['pagadoCon'],
                                      style: TextStyle(
                                        color: textLight,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Container(),

                      // Fecha de pago
                      documento['fechaPago'] != ''
                          ? Column(
                              children: [
                                SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Fecha de pago: ',
                                      style: TextStyle(
                                        color: textLight,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      documento['fechaPago'],
                                      style: TextStyle(
                                        color: textLight,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Container(),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  icon: Icon(Icons.print, size: 18),
                  label: Text('Imprimir'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textDark,
                    side: BorderSide(color: Colors.grey.withOpacity(0.5)),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Imprimiendo documento ${documento['id']}...',
                        ),
                      ),
                    );
                  },
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: Icon(Icons.email, size: 18),
                      label: Text('Enviar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: BorderSide(color: Colors.blue.withOpacity(0.5)),
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Enviando documento ${documento['id']}...',
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(width: 8),
                    if (documento['estado'] != 'Anulada')
                      OutlinedButton.icon(
                        icon: Icon(Icons.cancel, size: 18),
                        label: Text('Anular'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(color: Colors.red.withOpacity(0.5)),
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        onPressed: () {
                          _mostrarDialogoConfirmacion(
                            context,
                            'Anular documento',
                            '¿Está seguro que desea anular el documento ${documento['id']}?',
                            () {
                              setState(() {
                                documento['estado'] = 'Anulada';
                              });
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Documento ${documento['id']} anulado',
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarOpcionesNuevoDocumento(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: cardBg,
          title: Text(
            'Crear nuevo documento',
            style: TextStyle(color: textDark),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.receipt, color: primary),
                title: Text('Factura', style: TextStyle(color: textDark)),
                onTap: () {
                  Navigator.pop(context);
                  _crearNuevoDocumento('Factura');
                },
              ),
              ListTile(
                leading: Icon(Icons.receipt_long, color: primary),
                title: Text('Recibo', style: TextStyle(color: textDark)),
                onTap: () {
                  Navigator.pop(context);
                  _crearNuevoDocumento('Recibo');
                },
              ),
              ListTile(
                leading: Icon(Icons.note_alt, color: primary),
                title: Text(
                  'Nota de crédito',
                  style: TextStyle(color: textDark),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _crearNuevoDocumento('Nota de crédito');
                },
              ),
              ListTile(
                leading: Icon(Icons.restaurant_menu, color: primary),
                title: Text('Comanda', style: TextStyle(color: textDark)),
                onTap: () {
                  Navigator.pop(context);
                  _crearNuevoDocumento('Comanda');
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Cancelar', style: TextStyle(color: primary)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _crearNuevoDocumento(String tipo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Creando nuevo documento tipo $tipo...'),
        duration: Duration(seconds: 2),
      ),
    );

    // En un futuro, aquí iría la navegación a la pantalla de creación de documento
    // Por ahora, simulamos la creación de un documento después de un breve delay
    Future.delayed(Duration(milliseconds: 800), () {
      final now = DateTime.now();
      final String fecha =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final String hora =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      final String id =
          tipo.substring(0, 3).toUpperCase() +
          '-' +
          (100 + _documentos.length).toString();

      final String fechaPago = tipo == 'Comanda' ? '' : '$fecha $hora';
      final esDomicilio = false;
      final String mesa = tipo == 'Comanda' ? 'Mesa Nueva' : '';

      final nuevoDocumento = {
        'id': id,
        'fecha': fecha,
        'hora': hora,
        'cliente': 'Cliente Nuevo',
        'tipo': tipo,
        'estado': tipo == 'Comanda' ? 'En cocina' : 'Generado',
        'total': 0,
        'proveedorDomicilio': '', // Proveedor del domicilio si aplica
        'facturador': 'Sopa y Carbon', // Quien factura
        'mesa': mesa, // Identificador de mesa si aplica
        'medioPago': tipo == 'Comanda'
            ? 'Pendiente'
            : 'Efectivo', // Forma de pago
        'pagadoCon': tipo == 'Comanda' ? '' : 'Efectivo: 0', // Detalle del pago
        'fechaPago': fechaPago, // Fecha y hora del pago
        'base': 0, // Base imponible
        'totalImp': 0, // Total impuestos
        'propina': 0, // Propina
        'comisionProveedor': 0, // Comisión al proveedor de domicilio
        'domicilio': esDomicilio, // Si es domicilio
        'items': [],
      };

      setState(() {
        _documentos.insert(0, nuevoDocumento);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Documento $id creado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    });
  }

  void _mostrarDialogoConfirmacion(
    BuildContext context,
    String titulo,
    String mensaje,
    Function onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: cardBg,
          title: Text(titulo, style: TextStyle(color: textDark)),
          content: Text(mensaje, style: TextStyle(color: textLight)),
          actions: [
            TextButton(
              child: Text('Cancelar', style: TextStyle(color: textLight)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Confirmar'),
              onPressed: () {
                onConfirm();
              },
            ),
          ],
        );
      },
    );
  }
}
