import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/reportes_service.dart';

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

  // Estados de carga
  bool _isLoading = false;
  String? _errorMessage;
  final ReportesService _reportesService = ReportesService();

  // Datos para los gráficos (ya no simulados)
  List<Map<String, dynamic>> _ventasPorDia = [];
  List<Map<String, dynamic>> _ventasTopProductos = [];
  List<Map<String, dynamic>> _ventasCategoria = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 6,
      vsync: this,
      initialIndex: widget.initialReportIndex,
    );

    // Agregar listener para cargar datos cuando cambia la pestaña
    _tabController.addListener(_handleTabChange);

    // Cargar datos iniciales
    _cargarDatos();
  }

  void _handleTabChange() {
    // Solo cargar datos cuando el tab se establece, no cuando se está deslizando
    if (_tabController.indexIsChanging) {
      _cargarDatos();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Future.wait([
        _cargarVentasPorDia(),
        _cargarTopProductos(),
        _cargarVentasPorCategoria(),
      ]);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error cargando datos de reportes: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al cargar datos: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _cargarVentasPorDia() async {
    try {
      // Determinar cuántos días cargar según el período seleccionado
      int diasParaCargar = 7; // Por defecto, últimos 7 días

      if (_periodoSeleccionado == 'Hoy') {
        diasParaCargar = 1;
      } else if (_periodoSeleccionado == 'Ayer') {
        diasParaCargar = 1;
      } else if (_periodoSeleccionado == 'Esta semana') {
        // Calcular días desde el inicio de la semana
        final hoy = DateTime.now();
        diasParaCargar = hoy.weekday;
      } else if (_periodoSeleccionado == 'Este mes') {
        // Calcular días desde el inicio del mes
        final hoy = DateTime.now();
        diasParaCargar = hoy.day;
      }

      final ventas = await _reportesService.getVentasPorDia(diasParaCargar);

      // Asegurarse de que los datos tienen el formato esperado
      final ventasFormateadas = ventas.map((item) {
        // Asegurar que siempre tenemos un campo 'ventas' aunque el backend envíe 'total'
        final venta = {...item};
        if (venta['total'] != null && venta['ventas'] == null) {
          venta['ventas'] = venta['total'];
        }
        return venta;
      }).toList();

      if (mounted) {
        setState(() {
          _ventasPorDia = ventasFormateadas;
        });
      }
    } catch (e) {
      print('❌ Error cargando ventas por día: $e');
      rethrow;
    }
  }

  Future<void> _cargarTopProductos() async {
    try {
      final productos = await _reportesService.getTopProductos(5);

      if (mounted) {
        setState(() {
          _ventasTopProductos = productos;
        });
      }
    } catch (e) {
      print('❌ Error cargando top productos: $e');
      rethrow;
    }
  }

  Future<void> _cargarVentasPorCategoria() async {
    try {
      // Intentar obtener datos del endpoint
      try {
        // Llamar al API para obtener ventas por categoría
        final categorias = await _reportesService.getVentasPorCategoria();

        if (mounted) {
          setState(() {
            _ventasCategoria = categorias;
          });
        }
        return;
      } catch (e) {
        print('⚠️ Error al obtener ventas por categoría: $e');
        print('⚠️ Usando datos de fallback temporales');
      }

      // Si el endpoint no está disponible, usamos datos temporales
      final categorias = [
        {'categoria': 'Platos Fuertes', 'ventas': 5320000, 'porcentaje': 42},
        {'categoria': 'Bebidas', 'ventas': 2180000, 'porcentaje': 17},
        {'categoria': 'Entradas', 'ventas': 1845000, 'porcentaje': 15},
        {'categoria': 'Postres', 'ventas': 985000, 'porcentaje': 8},
        {'categoria': 'Otros', 'ventas': 2270000, 'porcentaje': 18},
      ];

      if (mounted) {
        setState(() {
          _ventasCategoria = categorias;
        });
      }
    } catch (e) {
      print('❌ Error cargando ventas por categoría: $e');
      rethrow;
    }
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

  // Formatear la fecha
  String _formatFecha(dynamic fecha) {
    if (fecha == null) return 'N/A';

    try {
      if (fecha is DateTime) {
        return '${fecha.day}/${fecha.month}';
      } else if (fecha is String) {
        // Intentar parsear la fecha en formato ISO (yyyy-MM-dd)
        if (fecha.contains('T')) {
          // Formato ISO completo con hora
          final dt = DateTime.tryParse(fecha);
          if (dt != null) {
            return '${dt.day}/${dt.month}';
          }
        }

        final parts = fecha.split('-');
        if (parts.length >= 3) {
          // Mostrar día/mes
          return '${int.parse(parts[2])}/${int.parse(parts[1])}';
        }
        return fecha;
      }
      return 'N/A';
    } catch (e) {
      print('❌ Error formateando fecha: $fecha');
      return 'N/A';
    }
  }

  // Extraer el valor de ventas de un mapa
  double _getVentasValue(Map<String, dynamic> item) {
    final ventasValue = item['ventas'] ?? item['total'] ?? 0;

    if (ventasValue is int) {
      return ventasValue.toDouble();
    }
    if (ventasValue is double) {
      return ventasValue;
    }

    try {
      return double.parse(ventasValue.toString());
    } catch (e) {
      print('❌ Error convirtiendo ventas a double: $ventasValue');
      return 0.0;
    }
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
            Tab(text: 'Utilidad'),
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
          _buildReporteUtilidad(),
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
                        // Recargar datos con el nuevo período seleccionado
                        _cargarDatos();
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
                            'Cliente A',
                            'Cliente B',
                            'Cliente C',
                            'Cliente D',
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
                      items: <String>['Efectivo', 'Transferencia', 'Crédito']
                          .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          })
                          .toList(),
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
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterBar(),
          SizedBox(height: 20),

          // Tarjetas de resumen
          _isLoading
              ? Center(child: CircularProgressIndicator(color: primary))
              : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 48),
                      SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: textDark),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _cargarDatos,
                        child: Text('Reintentar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                        ),
                      ),
                    ],
                  ),
                )
              : _ventasPorDia.isEmpty
              ? Center(
                  child: Text(
                    'No hay datos disponibles para el período seleccionado',
                    style: TextStyle(color: textDark),
                  ),
                )
              : _buildDashboardContent(),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    final totalVentas = _ventasPorDia.fold<int>(0, (sum, item) {
      final ventas = item['total'] ?? item['ventas'] ?? 0;
      if (ventas is int) return sum + ventas;
      if (ventas is double) return sum + ventas.round();
      try {
        return sum + int.parse(ventas.toString());
      } catch (e) {
        print('❌ Error sumando ventas: $ventas');
        return sum;
      }
    });

    // Calcular el promedio diario
    final promedioDiario = _ventasPorDia.isNotEmpty
        ? totalVentas / _ventasPorDia.length
        : 0;

    // Identificar el mejor día
    final mejorDia = _ventasPorDia.isNotEmpty
        ? _ventasPorDia.reduce((a, b) {
            final ventasA = a['ventas'] ?? a['total'] ?? 0;
            final ventasB = b['ventas'] ?? b['total'] ?? 0;
            return ventasA > ventasB ? a : b;
          })
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            mejorDia != null
                ? _buildSummaryCard(
                    title: 'Mejor día',
                    value: _formatFecha(mejorDia['fecha']),
                    subtitle: _formatearNumero(
                      mejorDia['ventas'] ?? mejorDia['total'] ?? 0,
                    ),
                    icon: Icons.calendar_today,
                  )
                : _buildSummaryCard(
                    title: 'Mejor día',
                    value: 'No disponible',
                    icon: Icons.calendar_today,
                  ),
            _buildSummaryCard(
              title: 'Total pedidos',
              value:
                  'Cargando...', // Este valor se debería obtener de un endpoint
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
                Container(
                  height: 250,
                  child: _ventasPorDia.isEmpty
                      ? Center(
                          child: Text(
                            'No hay datos de ventas disponibles',
                            style: TextStyle(color: textLight),
                          ),
                        )
                      : _buildBarChartVentas(),
                ),
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
                _ventasTopProductos.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Text(
                            'No hay datos de productos disponibles',
                            style: TextStyle(color: textLight),
                          ),
                        ),
                      )
                    : _buildTablaProductosMasVendidos(),
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
                Container(
                  height: 300,
                  child: _ventasCategoria.isEmpty
                      ? Center(
                          child: Text(
                            'No hay datos de categorías disponibles',
                            style: TextStyle(color: textLight),
                          ),
                        )
                      : _buildPieChartCategorias(),
                ),
              ],
            ),
          ),
        ),
      ],
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
    if (_ventasPorDia.isEmpty) {
      return Center(
        child: Text(
          'No hay datos para mostrar',
          style: TextStyle(color: textLight),
        ),
      );
    }

    // Encontrar el valor máximo para escalar el gráfico correctamente
    double maxVenta = 0;
    for (final dia in _ventasPorDia) {
      // Usamos el método _getVentasValue para mantener consistencia
      final venta = _getVentasValue(dia);
      if (venta > maxVenta) {
        maxVenta = venta;
      }
    }

    // Calcular un maxY redondeado para que el gráfico se vea bien
    // Redondear a la siguiente unidad de millón
    double maxY = (maxVenta / 1000000).ceil() * 1000000;
    if (maxY < 1000000) maxY = 1000000; // Mínimo 1M para que se vea bien

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: cardBg,
            tooltipBorder: BorderSide(color: primary.withOpacity(0.2)),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (group.x < 0 || group.x >= _ventasPorDia.length) {
                return null;
              }

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

                final dia = _ventasPorDia[value.toInt()]['fecha'];
                // Usar el método _formatFecha para manejar todos los casos posibles
                final String texto = _formatFecha(dia);

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
                // Escalar valores según maxY
                if (value == 0) {
                  return Text(
                    '0',
                    style: TextStyle(color: textLight, fontSize: 10),
                  );
                }

                // Dividir el eje en 4 partes
                final interval = maxY / 4;
                if (value == interval) {
                  return Text(
                    '${(value / 1000).toInt()}K',
                    style: TextStyle(color: textLight, fontSize: 10),
                  );
                } else if (value == interval * 2) {
                  return Text(
                    '${(value / 1000).toInt()}K',
                    style: TextStyle(color: textLight, fontSize: 10),
                  );
                } else if (value == interval * 3) {
                  return Text(
                    '${(value / 1000).toInt()}K',
                    style: TextStyle(color: textLight, fontSize: 10),
                  );
                } else if (value == maxY) {
                  return Text(
                    '${(value / 1000000).toInt()}M',
                    style: TextStyle(color: textLight, fontSize: 10),
                  );
                }
                return SizedBox();
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
          horizontalInterval: maxY / 4, // 4 líneas horizontales
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
                toY: _getVentasValue(_ventasPorDia[index]),
                color: primary,
                width: 20,
                borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
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
    if (_ventasTopProductos.isEmpty) {
      return Center(
        child: Text(
          'No hay datos de productos disponibles',
          style: TextStyle(color: textLight),
        ),
      );
    }

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
                  Text(
                    producto['nombre'] ?? 'Sin nombre',
                    style: TextStyle(color: textDark),
                  ),
                ),
                DataCell(
                  Text(
                    (producto['cantidad'] ?? 0).toString(),
                    style: TextStyle(color: textDark),
                  ),
                ),
                DataCell(
                  Text(
                    _formatearNumero(producto['total'] ?? 0),
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
    if (_ventasCategoria.isEmpty) {
      return Center(
        child: Text(
          'No hay datos de categorías disponibles',
          style: TextStyle(color: textLight),
        ),
      );
    }

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
                  value: (categoria['porcentaje'] ?? 0).toDouble(),
                  title: '${categoria['porcentaje'] ?? 0}%',
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

          // Muestra el indicador de carga si está cargando
          if (_isLoading)
            Center(child: CircularProgressIndicator(color: primary))
          // Muestra un mensaje de error si hay algún problema
          else if (_errorMessage != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 48),
                  SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: textDark),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _cargarDatos,
                    child: Text('Reintentar'),
                    style: ElevatedButton.styleFrom(backgroundColor: primary),
                  ),
                ],
              ),
            )
          // Si todo está bien, muestra el reporte
          else
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
                    _ventasPorDia.isEmpty
                        ? Center(
                            child: Text(
                              'No hay datos de ventas disponibles para el período seleccionado',
                              style: TextStyle(color: textLight),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Datos actualizados desde el API:',
                                style: TextStyle(color: primary),
                              ),
                              SizedBox(height: 20),
                              Container(
                                height: 300,
                                child: _buildBarChartVentas(),
                              ),
                            ],
                          ),
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

          if (_isLoading)
            Center(child: CircularProgressIndicator(color: primary))
          else if (_errorMessage != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 48),
                  SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: textDark),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _cargarDatos,
                    child: Text('Reintentar'),
                    style: ElevatedButton.styleFrom(backgroundColor: primary),
                  ),
                ],
              ),
            )
          else
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
                    _ventasTopProductos.isEmpty
                        ? Text(
                            'No hay datos de productos disponibles para el período seleccionado',
                            style: TextStyle(color: textLight),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Top productos por ventas:',
                                style: TextStyle(color: primary),
                              ),
                              SizedBox(height: 20),
                              _buildTablaProductosMasVendidos(),
                            ],
                          ),
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

          if (_isLoading)
            Center(child: CircularProgressIndicator(color: primary))
          else if (_errorMessage != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 48),
                  SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: textDark),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _cargarDatos,
                    child: Text('Reintentar'),
                    style: ElevatedButton.styleFrom(backgroundColor: primary),
                  ),
                ],
              ),
            )
          else
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
                      'Esta funcionalidad requiere un nuevo endpoint en el API para obtener el historial de pedidos.',
                      style: TextStyle(color: textLight),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Implementación pendiente: Consulta de pedidos',
                            ),
                            backgroundColor: primary,
                          ),
                        );
                      },
                      child: Text('Implementar API de pedidos'),
                      style: ElevatedButton.styleFrom(backgroundColor: primary),
                    ),
                  ],
                ),
              ),
            ),
          SizedBox(height: 20),
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

          if (_isLoading)
            Center(child: CircularProgressIndicator(color: primary))
          else if (_errorMessage != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 48),
                  SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: textDark),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _cargarDatos,
                    child: Text('Reintentar'),
                    style: ElevatedButton.styleFrom(backgroundColor: primary),
                  ),
                ],
              ),
            )
          else
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
                      'Esta funcionalidad requiere un nuevo endpoint en el API para obtener información sobre clientes.',
                      style: TextStyle(color: textLight),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Implementación pendiente: Consulta de clientes',
                            ),
                            backgroundColor: primary,
                          ),
                        );
                      },
                      child: Text('Implementar API de clientes'),
                      style: ElevatedButton.styleFrom(backgroundColor: primary),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Nuevo método para reporte de utilidad
  Widget _buildReporteUtilidad() {
    return Container(
      color: bgDark,
      child: Column(
        children: [
          // Filtros superiores
          Container(
            padding: EdgeInsets.all(16),
            color: cardBg,
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.analytics, color: primary, size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Análisis de Utilidad',
                      style: TextStyle(
                        color: textDark,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                // Filtros de fecha
                Row(
                  children: [
                    Expanded(child: _buildDateRangePicker()),
                    SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _cargarReporteUtilidad,
                      icon: Icon(Icons.refresh),
                      label: Text('Actualizar'),
                      style: ElevatedButton.styleFrom(backgroundColor: primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Contenido del reporte
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: primary),
                        SizedBox(height: 16),
                        Text(
                          'Calculando utilidades...',
                          style: TextStyle(color: textLight),
                        ),
                      ],
                    ),
                  )
                : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, color: Colors.red, size: 64),
                        SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _cargarReporteUtilidad,
                          child: Text('Reintentar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Tarjetas de resumen
                        Row(
                          children: [
                            Expanded(
                              child: _buildUtilidadCard(
                                'Total Ventas',
                                '\$500,000',
                                Colors.blue,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: _buildUtilidadCard(
                                'Total Costos',
                                '\$300,000',
                                Colors.red,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: _buildUtilidadCard(
                                'Utilidad Bruta',
                                '\$200,000',
                                Colors.green,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: _buildUtilidadCard(
                                'Margen %',
                                '40%',
                                Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 24),

                        // Gráfico de utilidad por producto
                        Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Utilidad por Producto (Top 10)',
                                style: TextStyle(
                                  color: textDark,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 20),
                              Container(
                                height: 300,
                                child: BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.spaceAround,
                                    maxY: 100000,
                                    barTouchData: BarTouchData(enabled: false),
                                    titlesData: FlTitlesData(
                                      show: true,
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 40,
                                          getTitlesWidget: (value, meta) {
                                            const products = [
                                              'Hamburguesa',
                                              'Pizza',
                                              'Pasta',
                                              'Ensalada',
                                              'Bebida',
                                            ];
                                            if (value.toInt() <
                                                products.length) {
                                              return Padding(
                                                padding: EdgeInsets.only(
                                                  top: 8,
                                                ),
                                                child: Text(
                                                  products[value.toInt()],
                                                  style: TextStyle(
                                                    color: textLight,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              );
                                            }
                                            return Text('');
                                          },
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 50,
                                          getTitlesWidget: (value, meta) {
                                            return Text(
                                              '\$${(value / 1000).toStringAsFixed(0)}k',
                                              style: TextStyle(
                                                color: textLight,
                                                fontSize: 10,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      topTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      rightTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                    ),
                                    borderData: FlBorderData(show: false),
                                    barGroups: [
                                      BarChartGroupData(
                                        x: 0,
                                        barRods: [
                                          BarChartRodData(
                                            toY: 85000,
                                            color: primary,
                                          ),
                                        ],
                                      ),
                                      BarChartGroupData(
                                        x: 1,
                                        barRods: [
                                          BarChartRodData(
                                            toY: 72000,
                                            color: primary,
                                          ),
                                        ],
                                      ),
                                      BarChartGroupData(
                                        x: 2,
                                        barRods: [
                                          BarChartRodData(
                                            toY: 61000,
                                            color: primary,
                                          ),
                                        ],
                                      ),
                                      BarChartGroupData(
                                        x: 3,
                                        barRods: [
                                          BarChartRodData(
                                            toY: 45000,
                                            color: primary,
                                          ),
                                        ],
                                      ),
                                      BarChartGroupData(
                                        x: 4,
                                        barRods: [
                                          BarChartRodData(
                                            toY: 38000,
                                            color: primary,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24),

                        // Tabla detallada de productos
                        Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Detalle de Utilidad por Producto',
                                style: TextStyle(
                                  color: textDark,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 16),
                              _buildUtilidadTable(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Método auxiliar para las tarjetas de utilidad
  Widget _buildUtilidadCard(String titulo, String valor, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: TextStyle(color: textLight, fontSize: 14)),
          SizedBox(height: 8),
          Text(
            valor,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Método auxiliar para la tabla de utilidad
  Widget _buildUtilidadTable() {
    return Table(
      columnWidths: {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(1.5),
        2: FlexColumnWidth(1.5),
        3: FlexColumnWidth(1.5),
        4: FlexColumnWidth(1),
      },
      children: [
        // Encabezados
        TableRow(
          children: [
            _buildTableHeader('Producto'),
            _buildTableHeader('Precio'),
            _buildTableHeader('Costo'),
            _buildTableHeader('Utilidad'),
            _buildTableHeader('Margen %'),
          ],
        ),
        // Datos de ejemplo (aquí irían los datos reales del servicio)
        ..._buildUtilidadTableRows(),
      ],
    );
  }

  Widget _buildTableHeader(String text) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.1),
        border: Border.all(color: primary.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textDark,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  List<TableRow> _buildUtilidadTableRows() {
    // Datos de ejemplo (en producción vendrían del servicio)
    final productos = [
      {
        'nombre': 'Hamburguesa Clásica',
        'precio': 15000,
        'costo': 8000,
        'vendidos': 120,
      },
      {
        'nombre': 'Pizza Margarita',
        'precio': 25000,
        'costo': 12000,
        'vendidos': 85,
      },
      {
        'nombre': 'Pasta Carbonara',
        'precio': 18000,
        'costo': 9500,
        'vendidos': 95,
      },
      {
        'nombre': 'Ensalada César',
        'precio': 12000,
        'costo': 6000,
        'vendidos': 65,
      },
      {
        'nombre': 'Bebida Grande',
        'precio': 5000,
        'costo': 2000,
        'vendidos': 200,
      },
    ];

    return productos.map((producto) {
      final precio = producto['precio'] as int;
      final costo = producto['costo'] as int;
      final utilidad = precio - costo;
      final margen = ((utilidad / precio) * 100);

      return TableRow(
        children: [
          _buildTableCell(producto['nombre'].toString(), textDark),
          _buildTableCell('\$${precio.toString()}', textLight),
          _buildTableCell('\$${costo.toString()}', Colors.red.shade300),
          _buildTableCell('\$${utilidad.toString()}', Colors.green.shade300),
          _buildTableCell(
            '${margen.toStringAsFixed(1)}%',
            margen > 30
                ? Colors.green
                : margen > 15
                ? Colors.orange
                : Colors.red,
          ),
        ],
      );
    }).toList();
  }

  Widget _buildTableCell(String text, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: textLight.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }

  // Método para selector de rango de fechas (reutilizado para utilidad)
  Widget _buildDateRangePicker() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Período',
        labelStyle: TextStyle(color: primary),
        border: OutlineInputBorder(borderSide: BorderSide(color: textLight)),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primary),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                _fechaInicio = DateTime.now().subtract(Duration(days: 1));
                _fechaFin = DateTime.now().subtract(Duration(days: 1));
                break;
              case 'Esta semana':
                _fechaInicio = DateTime.now().subtract(
                  Duration(days: DateTime.now().weekday - 1),
                );
                _fechaFin = DateTime.now();
                break;
              case 'Últimos 7 días':
                _fechaInicio = DateTime.now().subtract(Duration(days: 7));
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
            }
          });
          _cargarReporteUtilidad();
        }
      },
      items:
          <String>[
            'Hoy',
            'Ayer',
            'Esta semana',
            'Últimos 7 días',
            'Este mes',
          ].map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value, style: TextStyle(color: textDark)),
            );
          }).toList(),
    );
  }

  // Método para cargar datos del reporte de utilidad
  Future<void> _cargarReporteUtilidad() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Aquí iría la llamada al servicio para obtener datos reales
      // await _reportesService.obtenerReporteUtilidad(_fechaInicio, _fechaFin);

      // Simular carga
      await Future.delayed(Duration(seconds: 1));

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error cargando reporte de utilidad: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Error al cargar el reporte de utilidad: ${e.toString()}';
        });
      }
    }
  }
}
