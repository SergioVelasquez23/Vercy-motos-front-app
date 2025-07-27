import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class CuadreCajaScreen extends StatefulWidget {
  @override
  _CuadreCajaScreenState createState() => _CuadreCajaScreenState();
}

class _CuadreCajaScreenState extends State<CuadreCajaScreen>
    with SingleTickerProviderStateMixin {
  final Color primary = Color(0xFFFF6B00); // Color naranja fuego
  final Color bgDark = Color(0xFF1E1E1E); // Color de fondo negro
  final Color cardBg = Color(0xFF252525); // Color de tarjetas
  final Color textDark = Color(0xFFE0E0E0); // Color de texto claro
  final Color textLight = Color(0xFFA0A0A0); // Color de texto más suave
  final Color accentOrange = Color(0xFFFF8800); // Naranja más brillante

  // Controllers para los filtros de búsqueda
  final TextEditingController _desdeController = TextEditingController();
  final TextEditingController _hastaController = TextEditingController();
  final TextEditingController _idMaquinaController = TextEditingController();

  // Controllers para el formulario de apertura/cierre
  final TextEditingController _montoAperturaController =
      TextEditingController();
  final TextEditingController _montoEfectivoController =
      TextEditingController();
  final TextEditingController _montoTransferenciasController =
      TextEditingController();

  // Variables para el estado
  double _totalIngresos = 0;
  double _totalEgresos = 0;
  bool _showSearchResults = true;
  bool _showCashRegisterForm = false;
  bool _menuDigitalSwitch = false;
  bool _cerrarCajaSwitch = false;

  // Lista de registros de caja (simulada)
  List<Map<String, dynamic>> _registrosCaja = [];

  // Lista de cajeros (simulada)
  List<String> _cajeros = [
    'Alejandra Montoya Rojas',
    'Alejandro Giraldo',
    'Camila Giraldo',
    'Daniel Vargas',
  ];

  String? _selectedCaja;
  String? _selectedResponsable;
  String? _selectedEstado;
  String? _selectedCajero;

  @override
  void initState() {
    super.initState();
    _montoAperturaController.text = '100000';
    _actualizarTotales();
    _cargarDatosSimulados();
  }

  void _cargarDatosSimulados() {
    _registrosCaja = [
      {
        'fechaInicio': '2025-06-28 04:04:50 p. m.',
        'fechaFin': '',
        'nombreCaja': 'Caja Principal',
        'responsable': 'Sopa y Carbon',
        'totalInicial': 400000,
        'cerrada': false,
      },
      {
        'fechaInicio': '2025-06-28 09:57:35 a. m.',
        'fechaFin': '2025-06-28 04:04:21 p. m.',
        'nombreCaja': 'Caja Principal',
        'responsable': 'Sopa y Carbon',
        'totalInicial': 370000,
        'cerrada': true,
      },
      {
        'fechaInicio': '2025-06-27 03:36:44 p. m.',
        'fechaFin': '2025-06-27 10:51:28 p. m.',
        'nombreCaja': 'Caja Principal',
        'responsable': 'Sopa y Carbon',
        'totalInicial': 400000,
        'cerrada': true,
      },
      {
        'fechaInicio': '2025-06-27 09:54:47 a. m.',
        'fechaFin': '2025-06-27 03:36:36 p. m.',
        'nombreCaja': 'Caja Principal',
        'responsable': 'Sopa y Carbon',
        'totalInicial': 378500,
        'cerrada': true,
      },
      {
        'fechaInicio': '2025-06-26 10:06:17 a. m.',
        'fechaFin': '2025-06-26 04:16:36 p. m.',
        'nombreCaja': 'Caja Principal',
        'responsable': 'Sopa y Carbon',
        'totalInicial': 400000,
        'cerrada': true,
      },
    ];
  }

  void _actualizarTotales() {
    double efectivo = double.tryParse(_montoEfectivoController.text) ?? 0;
    double transferencias =
        double.tryParse(_montoTransferenciasController.text) ?? 0;

    setState(() {
      _totalIngresos = efectivo + transferencias;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Check if user has admin permissions
    final userProvider = Provider.of<UserProvider>(context);
    if (!userProvider.isAdmin) {
      // If user is not admin, redirect to dashboard
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Acceso restringido. Necesitas permisos de administrador.',
            ),
          ),
        );
      });
      return Container(); // Return empty container while redirecting
    }

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        title: Text(
          'Cuadres de Caja',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primary,
        elevation: 0,
        actions: [
          _showCashRegisterForm
              ? TextButton.icon(
                  icon: Icon(Icons.save, color: Colors.white),
                  label: Text('Guardar', style: TextStyle(color: Colors.white)),
                  onPressed: () {
                    setState(() {
                      _showCashRegisterForm = false;
                      _showSearchResults = true;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Cuadre de caja guardado'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                )
              : TextButton.icon(
                  icon: Icon(Icons.add, color: Colors.white),
                  label: Text('Nueva', style: TextStyle(color: Colors.white)),
                  style: TextButton.styleFrom(
                    backgroundColor: primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: () {
                    setState(() {
                      _showCashRegisterForm = true;
                      _showSearchResults = false;
                    });
                  },
                ),
          SizedBox(width: 16),
        ],
      ),
      body: _showCashRegisterForm
          ? _buildCashRegisterForm()
          : _buildSearchAndResults(),
    );
  }

  Widget _buildSearchAndResults() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          Center(
            child: Text(
              'CUADRES DE CAJA',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textDark,
                shadows: [
                  Shadow(
                    offset: Offset(1, 1),
                    blurRadius: 3,
                    color: Colors.black.withOpacity(0.3),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20), // Filtros de búsqueda
          Card(
            color: cardBg,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filtros de fechas
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _desdeController,
                          decoration: InputDecoration(
                            labelText: 'Desde',
                            labelStyle: TextStyle(color: textLight),
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(
                              Icons.calendar_today,
                              color: primary,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: primary),
                            ),
                          ),
                          onTap: () async {
                            // Aquí se podría mostrar un DatePicker
                          },
                          readOnly: true,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _hastaController,
                          decoration: InputDecoration(
                            labelText: 'Hasta',
                            labelStyle: TextStyle(color: textLight),
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(
                              Icons.calendar_today,
                              color: primary,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: primary),
                            ),
                          ),
                          onTap: () async {
                            // Aquí se podría mostrar un DatePicker
                          },
                          readOnly: true,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Filtros de dropdown
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Caja',
                            labelStyle: TextStyle(color: textLight),
                            border: OutlineInputBorder(),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: primary),
                            ),
                          ),
                          style: TextStyle(color: textDark),
                          value: _selectedCaja,
                          hint: Text(
                            '-- Caja --',
                            style: TextStyle(color: textLight),
                          ),
                          items: <String>['Caja Principal', 'Caja Secundaria']
                              .map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              })
                              .toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedCaja = newValue;
                            });
                          },
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Responsable',
                            labelStyle: TextStyle(color: textLight),
                            border: OutlineInputBorder(),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: primary),
                            ),
                          ),
                          style: TextStyle(color: textDark),
                          value: _selectedResponsable,
                          hint: Text(
                            '-- Responsable --',
                            style: TextStyle(color: textLight),
                          ),
                          items: <String>['Sopa y Carbon', 'Sergio Pérez']
                              .map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              })
                              .toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedResponsable = newValue;
                            });
                          },
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Estado',
                            labelStyle: TextStyle(color: textLight),
                            border: OutlineInputBorder(),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: primary),
                            ),
                          ),
                          style: TextStyle(color: textDark),
                          value: _selectedEstado,
                          hint: Text(
                            '-- Estado --',
                            style: TextStyle(color: textLight),
                          ),
                          items: <String>['Abierta', 'Cerrada']
                              .map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              })
                              .toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedEstado = newValue;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16), // Botón de búsqueda
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 4,
                      ),
                      onPressed: () {
                        // Realizar búsqueda
                      },
                      child: Text('Buscar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20), // Toggle para menú digital
          Row(
            children: [
              Text(
                'Abrir Menú Digital',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
              SizedBox(width: 10),
              Switch(
                value: _menuDigitalSwitch,
                onChanged: (value) {
                  setState(() {
                    _menuDigitalSwitch = value;
                  });
                },
                activeColor: primary,
              ),
            ],
          ),
          SizedBox(height: 10),

          // Tabla de resultados
          Container(
            width: double.infinity,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(
                  Colors.black.withOpacity(0.3),
                ),
                dataRowColor: MaterialStateProperty.all(
                  cardBg.withOpacity(0.7),
                ),
                columns: [
                  DataColumn(
                    label: Text(
                      'Fecha Inicio',
                      style: TextStyle(
                        color: textDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Fecha Fin',
                      style: TextStyle(
                        color: textDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Nombre de Caja',
                      style: TextStyle(
                        color: textDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Responsable',
                      style: TextStyle(
                        color: textDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Total Inicial',
                      style: TextStyle(
                        color: textDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Cerrada',
                      style: TextStyle(
                        color: textDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      '',
                      style: TextStyle(
                        color: textDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Comprobante diario',
                      style: TextStyle(
                        color: textDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Inventario',
                      style: TextStyle(
                        color: textDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                rows: _registrosCaja.map((registro) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          registro['fechaInicio'].toString(),
                          style: TextStyle(color: textDark),
                        ),
                      ),
                      DataCell(
                        Text(
                          registro['fechaFin'].toString(),
                          style: TextStyle(color: textDark),
                        ),
                      ),
                      DataCell(
                        Text(
                          registro['nombreCaja'].toString(),
                          style: TextStyle(color: textDark),
                        ),
                      ),
                      DataCell(
                        Text(
                          registro['responsable'].toString(),
                          style: TextStyle(color: textDark),
                        ),
                      ),
                      DataCell(
                        Text(
                          '\$ ${registro['totalInicial']}',
                          style: TextStyle(color: textDark),
                        ),
                      ),
                      DataCell(
                        Text(
                          registro['cerrada'] ? 'Sí' : 'No',
                          style: TextStyle(
                            color: registro['cerrada'] ? Colors.green : primary,
                          ),
                        ),
                      ),
                      DataCell(
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 3,
                          ),
                          onPressed: () {
                            // Ver o cerrar caja
                            setState(() {
                              _showCashRegisterForm = true;
                              _showSearchResults = false;
                            });
                          },
                          child: Text(
                            registro['cerrada'] ? 'Ver' : 'Ver/Cerrar',
                          ),
                        ),
                      ),
                      DataCell(
                        IconButton(
                          icon: Icon(Icons.print, color: primary),
                          onPressed: () {
                            // Imprimir comprobante
                          },
                        ),
                      ),
                      DataCell(
                        IconButton(
                          icon: Icon(Icons.print, color: primary),
                          onPressed: () {
                            // Imprimir inventario
                          },
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashRegisterForm() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Cuadre de caja",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          SizedBox(height: 20), // Información del responsable y caja
          Card(
            elevation: 4,
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Responsable",
                    style: TextStyle(fontSize: 16, color: textLight),
                  ),
                  Text(
                    "Sopa y Carbon Vargas Rendón",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Caja",
                    style: TextStyle(fontSize: 16, color: textLight),
                  ),
                  Text(
                    "Caja Principal",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20), // Selección de cajeros
          Card(
            elevation: 4,
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Cajeros",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primary,
                        ),
                      ),
                      Text("*", style: TextStyle(color: primary, fontSize: 20)),
                    ],
                  ),
                  SizedBox(height: 10),

                  // Dropdown para seleccionar cajero
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 15,
                            ),
                          ),
                          value: _selectedCajero,
                          hint: Text("-- Seleccione --"),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedCajero = newValue;
                            });
                          },
                          items: _cajeros.map<DropdownMenuItem<String>>((
                            String value,
                          ) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                        ),
                      ),
                      SizedBox(width: 10),
                      IconButton(
                        icon: Icon(
                          Icons.add_circle_outline,
                          color: primary,
                          size: 30,
                        ),
                        onPressed: () {
                          // Agregar nuevo cajero
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 10), // Lista de cajeros seleccionados
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade800),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      children: [
                        // Encabezado de la tabla
                        Container(
                          color: Colors.black.withOpacity(0.3),
                          padding: EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 16,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "Cajero",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: textDark,
                                  ),
                                ),
                              ),
                              SizedBox(width: 50),
                            ],
                          ),
                        ),
                        // Filas de cajeros
                        ..._cajeros
                            .map(
                              (cajero) => Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                                padding: EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 16,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        cajero,
                                        style: TextStyle(color: textDark),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () {
                                        // Eliminar cajero
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20), // Identificación máquina
          Card(
            elevation: 4,
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Identificación máquina:",
                    style: TextStyle(fontSize: 16, color: textDark),
                  ),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: _idMaquinaController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20), // Ventas
          Card(
            elevation: 4,
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Ventas",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  SizedBox(height: 16), // Tabla de ventas
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade800),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Table(
                      columnWidths: {
                        0: FlexColumnWidth(1),
                        1: FlexColumnWidth(1),
                      },
                      border: TableBorder.all(
                        color: Colors.grey.shade800,
                        width: 1,
                      ),
                      children: [
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                "Medio de pago",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                "Ventas",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text("Efectivo"),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextFormField(
                                controller: _montoEfectivoController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 8,
                                  ),
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (_) => _actualizarTotales(),
                              ),
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text("Transferencia"),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextFormField(
                                controller: _montoTransferenciasController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 8,
                                  ),
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (_) => _actualizarTotales(),
                              ),
                            ),
                          ],
                        ),
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                "Total",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                "\$ ${_totalIngresos.toStringAsFixed(0)}",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20), // Cerrar caja
          Card(
            elevation: 4,
            color: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    "Cerrar caja",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  SizedBox(width: 16),
                  Switch(
                    value: _cerrarCajaSwitch,
                    onChanged: (value) {
                      setState(() {
                        _cerrarCajaSwitch = value;
                      });
                    },
                    activeColor: primary,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 30), // Botón guardar cambios
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 4,
              ),
              onPressed: () {
                // Guardar cambios
                setState(() {
                  _showCashRegisterForm = false;
                  _showSearchResults = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Cambios guardados correctamente'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: Text("Guardar cambios"),
            ),
          ),
        ],
      ),
    );
  }
}
