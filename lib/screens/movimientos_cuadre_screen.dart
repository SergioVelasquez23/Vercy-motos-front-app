import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/cuadre_caja.dart';
import '../models/gasto.dart';
import '../models/ingreso_caja.dart';
import '../services/gasto_service.dart';
import '../services/ingreso_caja_service.dart';
import '../theme/app_theme.dart';
import '../utils/format_utils.dart';

class MovimientosCuadreScreen extends StatefulWidget {
  final CuadreCaja cuadre;

  const MovimientosCuadreScreen({super.key, required this.cuadre});

  @override
  _MovimientosCuadreScreenState createState() => _MovimientosCuadreScreenState();
}

class _MovimientosCuadreScreenState extends State<MovimientosCuadreScreen>
    with SingleTickerProviderStateMixin {
  
  // Getters para compatibilidad temporal con AppTheme
  Color get primary => AppTheme.primary;
  Color get bgDark => AppTheme.backgroundDark;
  Color get cardBg => AppTheme.cardBg;
  Color get textDark => AppTheme.textDark;
  Color get textLight => AppTheme.textLight;

  // Services
  final GastoService _gastoService = GastoService();
  final IngresoCajaService _ingresoCajaService = IngresoCajaService();

  // Tab Controller
  late TabController _tabController;

  // Estado
  List<Gasto> _gastos = [];
  List<IngresoCaja> _ingresos = [];
  bool _isLoadingGastos = false;
  bool _isLoadingIngresos = false;
  String? _errorGastos;
  String? _errorIngresos;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // Resumen, Gastos, Ingresos
    _cargarMovimientos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarMovimientos() async {
    await Future.wait([
      _cargarGastos(),
      _cargarIngresos(),
    ]);
  }

  Future<void> _cargarGastos() async {
    setState(() {
      _isLoadingGastos = true;
      _errorGastos = null;
    });

    try {
      final gastos = await _gastoService.getGastosByCuadre(widget.cuadre.id!);
      setState(() {
        _gastos = gastos;
        _isLoadingGastos = false;
      });
      print('✅ Gastos cargados: ${gastos.length}');
    } catch (e) {
      setState(() {
        _errorGastos = e.toString();
        _isLoadingGastos = false;
      });
      print('❌ Error cargando gastos: $e');
    }
  }

  Future<void> _cargarIngresos() async {
    setState(() {
      _isLoadingIngresos = true;
      _errorIngresos = null;
    });

    try {
      final ingresos = await _ingresoCajaService.obtenerPorCuadreCaja(widget.cuadre.id!);
      setState(() {
        _ingresos = ingresos;
        _isLoadingIngresos = false;
      });
      print('✅ Ingresos cargados: ${ingresos.length}');
    } catch (e) {
      setState(() {
        _errorIngresos = e.toString();
        _isLoadingIngresos = false;
      });
      print('❌ Error cargando ingresos: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if user has admin permissions
    final userProvider = Provider.of<UserProvider>(context);
    if (!userProvider.isAdmin) {
      return Scaffold(
        body: Center(
          child: Text('Acceso restringido. Necesitas permisos de administrador.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: primary,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Movimientos Financieros',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              widget.cuadre.nombre + ' - ${_formatDate(widget.cuadre.fechaApertura)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _cargarMovimientos,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: 'Resumen'),
            Tab(text: 'Gastos (${_gastos.length})'),
            Tab(text: 'Ingresos (${_ingresos.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildResumenTab(),
          _buildGastosTab(),
          _buildIngresosTab(),
        ],
      ),
    );
  }

  Widget _buildResumenTab() {
    double totalGastos = _gastos.fold(0.0, (sum, gasto) => sum + gasto.monto);
    double totalIngresos = _ingresos.fold(0.0, (sum, ingreso) => sum + ingreso.monto);
    double balance = totalIngresos - totalGastos;

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Información del cuadre
          Card(
            color: cardBg,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Información del Cuadre',
                    style: TextStyle(
                      color: primary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  _buildInfoRow('Nombre:', widget.cuadre.nombre),
                  _buildInfoRow('Responsable:', widget.cuadre.responsable),
                  _buildInfoRow('Fecha Apertura:', _formatDate(widget.cuadre.fechaApertura)),
                  if (widget.cuadre.fechaCierre != null)
                    _buildInfoRow('Fecha Cierre:', _formatDate(widget.cuadre.fechaCierre!)),
                  _buildInfoRow('Estado:', widget.cuadre.cerrada ? 'Cerrada' : 'Abierta'),
                  _buildInfoRow('Fondo Inicial:', formatCurrency(widget.cuadre.fondoInicial)),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 16),
          
          // Resumen financiero
          Card(
            color: cardBg,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resumen de Movimientos',
                    style: TextStyle(
                      color: primary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  _buildMoneyRow('Total Ingresos:', totalIngresos, Colors.green),
                  _buildMoneyRow('Total Gastos:', totalGastos, Colors.red),
                  Divider(color: textLight),
                  _buildMoneyRow(
                    'Balance:', 
                    balance, 
                    balance >= 0 ? Colors.green : Colors.red,
                    isTotal: true,
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 16),
          
          // Estadísticas
          Row(
            children: [
              Expanded(
                child: Card(
                  color: Colors.blue.withOpacity(0.1),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.trending_up, color: Colors.green, size: 32),
                        SizedBox(height: 8),
                        Text(
                          '${_ingresos.length}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          'Ingresos',
                          style: TextStyle(color: textLight),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Card(
                  color: Colors.red.withOpacity(0.1),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.trending_down, color: Colors.red, size: 32),
                        SizedBox(height: 8),
                        Text(
                          '${_gastos.length}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        Text(
                          'Gastos',
                          style: TextStyle(color: textLight),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGastosTab() {
    if (_isLoadingGastos) {
      return Center(
        child: CircularProgressIndicator(color: primary),
      );
    }

    if (_errorGastos != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red, size: 64),
            SizedBox(height: 16),
            Text(
              'Error al cargar gastos',
              style: TextStyle(color: Colors.red, fontSize: 18),
            ),
            Text(
              _errorGastos!,
              style: TextStyle(color: textLight),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _cargarGastos,
              child: Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_gastos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt, color: textLight, size: 64),
            SizedBox(height: 16),
            Text(
              'Sin gastos registrados',
              style: TextStyle(color: textLight, fontSize: 18),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _gastos.length,
      itemBuilder: (context, index) {
        final gasto = _gastos[index];
        return _buildGastoCard(gasto);
      },
    );
  }

  Widget _buildIngresosTab() {
    if (_isLoadingIngresos) {
      return Center(
        child: CircularProgressIndicator(color: primary),
      );
    }

    if (_errorIngresos != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red, size: 64),
            SizedBox(height: 16),
            Text(
              'Error al cargar ingresos',
              style: TextStyle(color: Colors.red, fontSize: 18),
            ),
            Text(
              _errorIngresos!,
              style: TextStyle(color: textLight),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _cargarIngresos,
              child: Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_ingresos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet, color: textLight, size: 64),
            SizedBox(height: 16),
            Text(
              'Sin ingresos registrados',
              style: TextStyle(color: textLight, fontSize: 18),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _ingresos.length,
      itemBuilder: (context, index) {
        final ingreso = _ingresos[index];
        return _buildIngresoCard(ingreso);
      },
    );
  }

  Widget _buildGastoCard(Gasto gasto) {
    return Card(
      color: cardBg,
      margin: EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    gasto.concepto,
                    style: TextStyle(
                      color: textDark,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  formatCurrency(gasto.monto),
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person, color: textLight, size: 16),
                SizedBox(width: 4),
                Text(
                  gasto.responsable,
                  style: TextStyle(color: textLight, fontSize: 14),
                ),
                SizedBox(width: 16),
                Icon(Icons.access_time, color: textLight, size: 16),
                SizedBox(width: 4),
                Text(
                  _formatDate(gasto.fechaGasto),
                  style: TextStyle(color: textLight, fontSize: 14),
                ),
              ],
            ),
            if (gasto.tipoGastoNombre != null) ...[
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.category, color: textLight, size: 16),
                  SizedBox(width: 4),
                  Text(
                    gasto.tipoGastoNombre!,
                    style: TextStyle(color: textLight, fontSize: 14),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIngresoCard(IngresoCaja ingreso) {
    return Card(
      color: cardBg,
      margin: EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    ingreso.concepto,
                    style: TextStyle(
                      color: textDark,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  formatCurrency(ingreso.monto),
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person, color: textLight, size: 16),
                SizedBox(width: 4),
                Text(
                  ingreso.responsable,
                  style: TextStyle(color: textLight, fontSize: 14),
                ),
                SizedBox(width: 16),
                Icon(Icons.access_time, color: textLight, size: 16),
                SizedBox(width: 4),
                Text(
                  _formatDate(ingreso.fechaIngreso),
                  style: TextStyle(color: textLight, fontSize: 14),
                ),
              ],
            ),
            Row(
              children: [
                Icon(Icons.payment, color: textLight, size: 16),
                SizedBox(width: 4),
                Text(
                  ingreso.formaPago,
                  style: TextStyle(color: textLight, fontSize: 14),
                ),
              ],
            ),
            if (ingreso.observaciones.isNotEmpty) ...[
              SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note, color: textLight, size: 16),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      ingreso.observaciones,
                      style: TextStyle(color: textLight, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: textLight, fontSize: 14),
          ),
          Text(
            value,
            style: TextStyle(
              color: textDark,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoneyRow(String label, double value, Color color, {bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isTotal ? 8 : 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isTotal ? color : textLight,
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            formatCurrency(value),
            style: TextStyle(
              color: color,
              fontSize: isTotal ? 18 : 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
