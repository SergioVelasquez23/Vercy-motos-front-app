import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ReportesScreen extends StatefulWidget {
  final int initialReportIndex;

  const ReportesScreen({Key? key, this.initialReportIndex = 0})
    : super(key: key);

  @override
  _ReportesScreenState createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen>
    with SingleTickerProviderStateMixin {
  final Color primary = Color(0xFFFF6B00); // Color naranja fuego
  final Color bgDark = Color(0xFF1E1E1E); // Color de fondo negro
  final Color cardBg = Color(0xFF252525); // Color de tarjetas
  final Color textDark = Color(0xFFE0E0E0); // Color de texto claro
  final Color textLight = Color(0xFFA0A0A0); // Color de texto más suave
  final Color accentOrange = Color(0xFFFF8800); // Naranja más brillante

  late TabController _tabController;
  DateTime _fechaInicio = DateTime.now().subtract(Duration(days: 7));
  DateTime _fechaFin = DateTime.now();
  String _periodoSeleccionado = 'Últimos 7 días';
  bool _mostrarFiltrosAvanzados = false;
  String? _selectedCategoria;
  String? _selectedProducto;
  String? _selectedCliente;
  String? _selectedFormaPago;

  // Datos simulados para los gráficos
  List<Map<String, dynamic>> _ventasPorDia = [];
  List<Map<String, dynamic>> _ventasTopProductos = [];
  List<Map<String, dynamic>> _ventasCategoria = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialReportIndex,
    );
    _generarDatosSimulados();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _generarDatosSimulados() {
    // Generar datos de ventas por día para los últimos 7 días
    final now = DateTime.now();
    _ventasPorDia = List.generate(7, (index) {
      final date = now.subtract(Duration(days: 6 - index));
      // Valor entre 500,000 y 1,500,000
      final ventasDia =
          500000 +
          (1000000 * (index / 10 + 0.5) * (index % 3 == 0 ? 1.2 : 0.9));
      return {'fecha': date, 'ventas': ventasDia.round()};
    });

    // Top productos más vendidos
    _ventasTopProductos = [
      {
        'nombre': 'Ejecutivo (Res a la plancha)',
        'cantidad': 102,
        'total': 1938000,
      },
      {'nombre': 'Asado Mixto', 'cantidad': 87, 'total': 2958000},
      {'nombre': 'Coca Cola', 'cantidad': 236, 'total': 1062000},
      {'nombre': 'Pechuga a la plancha', 'cantidad': 76, 'total': 1444000},
      {'nombre': 'Patacón', 'cantidad': 114, 'total': 342000},
    ];

    // Ventas por categoría
    _ventasCategoria = [
      {'categoria': 'Platos Fuertes', 'ventas': 5320000, 'porcentaje': 42},
      {'categoria': 'Bebidas', 'ventas': 2180000, 'porcentaje': 17},
      {'categoria': 'Entradas', 'ventas': 1845000, 'porcentaje': 15},
      {'categoria': 'Postres', 'ventas': 985000, 'porcentaje': 8},
      {'categoria': 'Otros', 'ventas': 2270000, 'porcentaje': 18},
    ];
  }

  String _formatearNumero(int valor) {
    return '\$${valor.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        title: Text(
          'Reportes',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            Tab(text: 'Dashboard'),
            Tab(text: 'Ventas'),
            Tab(text: 'Productos'),
            Tab(text: 'Pedidos'),
            Tab(text: 'Clientes'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.save_alt),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Exportando reporte...'),
                  backgroundColor: primary,
                ),
              );
            },
            tooltip: 'Exportar',
          ),
          SizedBox(width: 16),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        physics: BouncingScrollPhysics(),
        children: [
          _buildDashboard(),
          _buildReporteVentas(),
          _buildReporteProductos(),
          _buildReportePedidos(),
          _buildReporteClientes(),
        ],
      ),
      drawer: _buildMenuLateral(),
    );
  }

  Widget _buildMenuLateral() {
    return Drawer(
      backgroundColor: bgDark,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primary, accentOrange],
              ),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics, color: Colors.white, size: 30),
                  SizedBox(width: 10),
                  Text(
                    'Reportes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 3,
                          color: Colors.black.withOpacity(0.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildDrawerItem(
            icon: Icons.dashboard,
            text: 'Dashboard',
            iconColor: primary,
            onTap: () => _tabController.animateTo(0),
            trailingIcon: null,
          ),
          _buildDrawerItem(
            icon: Icons.attach_money,
            text: 'Ventas',
            iconColor: primary,
            onTap: () => _tabController.animateTo(1),
            trailingIcon: null,
          ),
          _buildDrawerItem(
            icon: Icons.restaurant_menu,
            text: 'Productos',
            iconColor: primary,
            onTap: () => _tabController.animateTo(2),
            trailingIcon: null,
          ),
          _buildDrawerItem(
            icon: Icons.receipt_long,
            text: 'Pedidos',
            iconColor: primary,
            onTap: () => _tabController.animateTo(3),
            trailingIcon: null,
          ),
          _buildDrawerItem(
            icon: Icons.people,
            text: 'Clientes',
            iconColor: primary,
            onTap: () => _tabController.animateTo(4),
            trailingIcon: null,
          ),
          Divider(color: Colors.grey.withOpacity(0.3)),
          _buildDrawerItem(
            icon: Icons.picture_as_pdf,
            text: 'Exportar a PDF',
            iconColor: primary,
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Exportando a PDF...'),
                  backgroundColor: primary,
                ),
              );
            },
            trailingIcon: null,
          ),
          _buildDrawerItem(
            icon: Icons.table_chart,
            text: 'Exportar a Excel',
            iconColor: primary,
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Exportando a Excel...'),
                  backgroundColor: primary,
                ),
              );
            },
            trailingIcon: null,
          ),
          Spacer(),
          Divider(color: Colors.grey.withOpacity(0.3)),
          _buildDrawerItem(
            icon: Icons.home,
            text: 'Dashboard',
            iconColor: primary,
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacementNamed('/dashboard');
            },
            trailingIcon: null,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String text,
    required Color iconColor,
    required VoidCallback onTap,
    required Widget? trailingIcon,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(text, style: TextStyle(color: textDark)),
      trailing: trailingIcon,
      onTap: onTap,
    );
  }

  Widget _buildFilterBar() {
    return Card(
      color: cardBg,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Periodo',
                      labelStyle: TextStyle(color: textLight),
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: primary),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    style: TextStyle(color: textDark),
                    dropdownColor: cardBg,
                    value: _periodoSeleccionado,
                    onChanged: (String? value) {
                      if (value != null) {
                        setState(() {
                          _periodoSeleccionado = value;
                          switch (value) {
                            case 'Hoy':
                              _fechaInicio = DateTime.now();
                              _fechaFin = DateTime.now();
                              break;
                            case 'Ayer':
                              _fechaInicio = DateTime.now().subtract(
                                Duration(days: 1),
                              );
                              _fechaFin = DateTime.now().subtract(
                                Duration(days: 1),
                              );
                              break;
                            case 'Esta semana':
                              _fechaInicio = DateTime.now().subtract(
                                Duration(days: DateTime.now().weekday - 1),
                              );
                              _fechaFin = DateTime.now();
                              break;
                            case 'Últimos 7 días':
                              _fechaInicio = DateTime.now().subtract(
                                Duration(days: 7),
                              );
                              _fechaFin = DateTime.now();
                              break;
                            case 'Este mes':
                              _fechaInicio = DateTime(
                                DateTime.now().year,
                                DateTime.now().month,
                                1,
                              );
                              _fechaFin = DateTime.now();
                              break;
                            case 'Personalizado':
                              // Mantener fechas actuales pero mostrar selector
                              break;
                          }
                        });
                      }
                    },
                    items:
                        <String>[
                          'Hoy',
                          'Ayer',
                          'Esta semana',
                          'Últimos 7 días',
                          'Este mes',
                          'Personalizado',
                        ].map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                  ),
                ),
                SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: Icon(
                    _mostrarFiltrosAvanzados
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                  ),
                  label: Text(
                    _mostrarFiltrosAvanzados ? 'Menos filtros' : 'Más filtros',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _mostrarFiltrosAvanzados = !_mostrarFiltrosAvanzados;
                    });
                  },
                ),
              ],
            ),
            if (_periodoSeleccionado == 'Personalizado') ...[
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        // Aquí se integraría un DatePicker
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Fecha inicio',
                          labelStyle: TextStyle(color: textLight),
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(
                            Icons.calendar_today,
                            color: primary,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          '${_fechaInicio.day}/${_fechaInicio.month}/${_fechaInicio.year}',
                          style: TextStyle(color: textDark),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        // Aquí se integraría un DatePicker
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Fecha fin',
                          labelStyle: TextStyle(color: textLight),
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(
                            Icons.calendar_today,
                            color: primary,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          '${_fechaFin.day}/${_fechaFin.month}/${_fechaFin.year}',
                          style: TextStyle(color: textDark),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (_mostrarFiltrosAvanzados) ...[
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Categoría',
                        labelStyle: TextStyle(color: textLight),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: primary),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      style: TextStyle(color: textDark),
                      dropdownColor: cardBg,
                      value: _selectedCategoria,
                      hint: Text('Todas', style: TextStyle(color: textLight)),
                      onChanged: (String? value) {
                        setState(() {
                          _selectedCategoria = value;
                        });
                      },
                      items:
                          <String>[
                            'Platos Fuertes',
                            'Bebidas',
                            'Entradas',
                            'Postres',
                          ].map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Producto',
                        labelStyle: TextStyle(color: textLight),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: primary),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      style: TextStyle(color: textDark),
                      dropdownColor: cardBg,
                      value: _selectedProducto,
                      hint: Text('Todos', style: TextStyle(color: textLight)),
                      onChanged: (String? value) {
                        setState(() {
                          _selectedProducto = value;
                        });
                      },
                      items:
                          <String>[
                            'Ejecutivo (Res a la plancha)',
                            'Asado Mixto',
                            'Coca Cola',
                            'Pechuga a la plancha',
                            'Patacón',
                          ].map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Cliente',
                        labelStyle: TextStyle(color: textLight),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: primary),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      style: TextStyle(color: textDark),
                      dropdownColor: cardBg,
                      value: _selectedCliente,
                      hint: Text('Todos', style: TextStyle(color: textLight)),
                      onChanged: (String? value) {
                        setState(() {
                          _selectedCliente = value;
                        });
                      },
                      items:
                          <String>[
                            'Juan Diego',
                            'Sopa y Carbon',
                            'María López',
                            'Carlos Gómez',
                          ].map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Forma de pago',
                        labelStyle: TextStyle(color: textLight),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: primary),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      style: TextStyle(color: textDark),
                      dropdownColor: cardBg,
                      value: _selectedFormaPago,
                      hint: Text('Todas', style: TextStyle(color: textLight)),
                      onChanged: (String? value) {
                        setState(() {
                          _selectedFormaPago = value;
                        });
                      },
                      items:
                          <String>[
                            'Efectivo',
                            'Tarjeta',
                            'Transferencia',
                            'Crédito',
                          ].map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.search),
                  label: Text('Generar reporte'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Generando reporte...'),
                        backgroundColor: primary,
                      ),
                    );
                  },
                ),
                SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: Icon(Icons.refresh),
                  label: Text('Limpiar filtros'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade700,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _periodoSeleccionado = 'Últimos 7 días';
                      _fechaInicio = DateTime.now().subtract(Duration(days: 7));
                      _fechaFin = DateTime.now();
                      _selectedCategoria = null;
                      _selectedProducto = null;
                      _selectedCliente = null;
                      _selectedFormaPago = null;
                      _mostrarFiltrosAvanzados = false;
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

  Widget _buildDashboard() {
    final totalVentas = _ventasPorDia.fold<int>(
      0,
      (sum, item) => sum + (item['ventas'] as int),
    );

    // Calcular el promedio diario
    final promedioDiario = totalVentas / _ventasPorDia.length;

    // Identificar el mejor día
    final mejorDia = _ventasPorDia.reduce(
      (a, b) => a['ventas'] > b['ventas'] ? a : b,
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterBar(),
          SizedBox(height: 20),

          // Tarjetas de resumen
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildSummaryCard(
                title: 'Ventas del período',
                value: _formatearNumero(totalVentas),
                icon: Icons.attach_money,
              ),
              _buildSummaryCard(
                title: 'Promedio diario',
                value: _formatearNumero(promedioDiario.round()),
                icon: Icons.show_chart,
              ),
              _buildSummaryCard(
                title: 'Mejor día',
                value: '${mejorDia['fecha'].day}/${mejorDia['fecha'].month}',
                subtitle: _formatearNumero(mejorDia['ventas']),
                icon: Icons.calendar_today,
              ),
              _buildSummaryCard(
                title: 'Total pedidos',
                value: '356',
                icon: Icons.receipt_long,
              ),
            ],
          ),
          SizedBox(height: 20),

          // Gráfico de ventas diarias
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
                  Text(
                    'Ventas Diarias',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(height: 250, child: _buildBarChartVentas()),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),

          // Productos más vendidos
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
                  Text(
                    'Productos Más Vendidos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildTablaProductosMasVendidos(),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),

          // Ventas por categoría
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
                  Text(
                    'Ventas por Categoría',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(height: 300, child: _buildPieChartCategorias()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
  }) {
    return Container(
      width: MediaQuery.of(context).size.width > 600
          ? (MediaQuery.of(context).size.width / 2) - 24
          : MediaQuery.of(context).size.width - 32,
      child: Card(
        color: cardBg,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: primary, size: 28),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 14, color: textLight),
                    ),
                    SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 14, color: primary),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarChartVentas() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 2000000,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: cardBg,
            tooltipBorder: BorderSide(color: primary.withOpacity(0.2)),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String formattedValue = _formatearNumero(rod.toY.round());
              return BarTooltipItem(
                formattedValue,
                TextStyle(color: primary, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value < 0 || value >= _ventasPorDia.length) {
                  return SizedBox();
                }

                final dia = _ventasPorDia[value.toInt()]['fecha'] as DateTime;
                final String texto = '${dia.day}/${dia.month}';

                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    texto,
                    style: TextStyle(color: textLight, fontSize: 12),
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                String text = '';
                if (value == 0) {
                  text = '0';
                } else if (value == 500000) {
                  text = '500K';
                } else if (value == 1000000) {
                  text = '1M';
                } else if (value == 1500000) {
                  text = '1.5M';
                } else if (value == 2000000) {
                  text = '2M';
                }
                return Text(
                  text,
                  style: TextStyle(color: textLight, fontSize: 10),
                );
              },
              reservedSize: 35,
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          horizontalInterval: 500000,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
              dashArray: [5, 5],
            );
          },
        ),
        barGroups: List.generate(
          _ventasPorDia.length,
          (index) => BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: _ventasPorDia[index]['ventas'].toDouble(),
                color: primary,
                width: 20,
                borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: 2000000,
                  color: Colors.grey.withOpacity(0.1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTablaProductosMasVendidos() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade800),
        borderRadius: BorderRadius.circular(4),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(
            Colors.black.withOpacity(0.3),
          ),
          dataRowColor: MaterialStateProperty.all(cardBg.withOpacity(0.7)),
          columns: [
            DataColumn(
              label: Text(
                'Producto',
                style: TextStyle(color: textDark, fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Cantidad',
                style: TextStyle(color: textDark, fontWeight: FontWeight.bold),
              ),
              numeric: true,
            ),
            DataColumn(
              label: Text(
                'Total',
                style: TextStyle(color: textDark, fontWeight: FontWeight.bold),
              ),
              numeric: true,
            ),
          ],
          rows: _ventasTopProductos.map((producto) {
            return DataRow(
              cells: [
                DataCell(
                  Text(producto['nombre'], style: TextStyle(color: textDark)),
                ),
                DataCell(
                  Text(
                    producto['cantidad'].toString(),
                    style: TextStyle(color: textDark),
                  ),
                ),
                DataCell(
                  Text(
                    _formatearNumero(producto['total']),
                    style: TextStyle(color: textDark),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPieChartCategorias() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sections: _ventasCategoria.asMap().entries.map((entry) {
                int idx = entry.key;
                Map<String, dynamic> categoria = entry.value;
                final List<Color> colorList = [
                  primary,
                  accentOrange,
                  primary.withOpacity(0.7),
                  accentOrange.withOpacity(0.7),
                  Colors.amber,
                ];

                return PieChartSectionData(
                  color: colorList[idx % colorList.length],
                  value: categoria['porcentaje'].toDouble(),
                  title: '${categoria['porcentaje']}%',
                  radius: 100,
                  titleStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              startDegreeOffset: -90,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _ventasCategoria.asMap().entries.map((entry) {
              int idx = entry.key;
              Map<String, dynamic> categoria = entry.value;
              final List<Color> colorList = [
                primary,
                accentOrange,
                primary.withOpacity(0.7),
                accentOrange.withOpacity(0.7),
                Colors.amber,
              ];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorList[idx % colorList.length],
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            categoria['categoria'],
                            style: TextStyle(
                              color: textDark,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _formatearNumero(categoria['ventas']),
                            style: TextStyle(color: textLight, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildReporteVentas() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterBar(),
          SizedBox(height: 20),
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
                  Text(
                    'Reporte de Ventas',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  SizedBox(height: 16),
                  // Aquí iría una implementación más específica del reporte de ventas
                  Text(
                    'Esta sección mostrará información detallada de ventas con filtros para diferentes formas de pago, empleados, horas, etc.',
                    style: TextStyle(color: textLight),
                  ),
                  SizedBox(height: 20),
                  Container(height: 300, child: _buildBarChartVentas()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReporteProductos() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterBar(),
          SizedBox(height: 20),
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
                  Text(
                    'Reporte de Productos',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Esta sección mostrará información sobre los productos más vendidos, rentabilidad por producto, categorías más populares, etc.',
                    style: TextStyle(color: textLight),
                  ),
                  SizedBox(height: 20),
                  _buildTablaProductosMasVendidos(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportePedidos() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterBar(),
          SizedBox(height: 20),
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
                  Text(
                    'Reporte de Pedidos',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Esta sección mostrará información sobre pedidos por mesa, tiempo promedio de atención, pedidos cancelados, etc.',
                    style: TextStyle(color: textLight),
                  ),
                  // Aquí iría una implementación más específica
                ],
              ),
            ),
          ),
          SizedBox(height: 20),
          // Agregar tabla simulada de pedidos recientes
        ],
      ),
    );
  }

  Widget _buildReporteClientes() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterBar(),
          SizedBox(height: 20),
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
                  Text(
                    'Reporte de Clientes',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Esta sección mostrará información sobre clientes frecuentes, gasto promedio por cliente, preferencias, etc.',
                    style: TextStyle(color: textLight),
                  ),
                  // Aquí iría una implementación más específica
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
