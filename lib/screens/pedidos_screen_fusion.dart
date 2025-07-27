import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pedido.dart';
import '../services/pedido_service.dart';
import '../providers/user_provider.dart';

class PedidosScreenFusion extends StatefulWidget {
  const PedidosScreenFusion({Key? key}) : super(key: key);

  @override
  _PedidosScreenFusionState createState() => _PedidosScreenFusionState();
}

class _PedidosScreenFusionState extends State<PedidosScreenFusion>
    with TickerProviderStateMixin {
  final Color primary = Color(0xFFFF6B00);
  final Color bgDark = Color(0xFF1E1E1E);
  final Color cardBg = Color(0xFF252525);
  final Color textDark = Color(0xFFE0E0E0);
  final Color textLight = Color(0xFFA0A0A0);
  final Color accentOrange = Color(0xFFFF8800);

  final TextEditingController _busquedaController = TextEditingController();
  late TabController _tabController;

  final PedidoService _pedidoService = PedidoService();
  List<Pedido> _pedidos = [];
  List<Pedido> _pedidosFiltrados = [];
  bool _isLoading = true;
  String? _error;

  // Filtros
  TipoPedido? _tipoFiltro;
  EstadoPedido? _estadoFiltro;

  // Estados disponibles
  final List<EstadoPedido> _estados = [
    EstadoPedido.activo,
    EstadoPedido.pagado,
    EstadoPedido.cancelado,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3, // Activo, pagado y cancelado
      vsync: this,
    );
    _tabController.addListener(_onTabChanged);
    _cargarPedidos();
    _busquedaController.addListener(_aplicarFiltros);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _busquedaController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;

    setState(() {
      _estadoFiltro = _estados[_tabController.index];
    });
    _aplicarFiltros();
  }

  Future<void> _cargarPedidos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final pedidos = await _pedidoService.getAllPedidos();
      setState(() {
        _pedidos = pedidos;
        _isLoading = false;
      });
      _aplicarFiltros();
    } catch (e) {
      setState(() {
        _error = 'Error al cargar pedidos: $e';
        _isLoading = false;
      });
    }
  }

  Color _getEstadoColor(EstadoPedido estado) {
    switch (estado) {
      case EstadoPedido.activo:
        return Colors.green;
      case EstadoPedido.pagado:
        return Colors.blue;
      case EstadoPedido.cancelado:
        return Colors.red;
    }
  }

  String _getEstadoTexto(EstadoPedido estado) {
    switch (estado) {
      case EstadoPedido.activo:
        return 'Activo';
      case EstadoPedido.pagado:
        return 'Pagado';
      case EstadoPedido.cancelado:
        return 'Cancelado';
    }
  }

  void _aplicarFiltros() {
    if (!mounted) return;

    print('🔍 Aplicando filtros...');
    print('📊 Total de pedidos originales: ${_pedidos.length}');
    print('🎯 Tipo filtro: $_tipoFiltro');
    print('📈 Estado filtro: $_estadoFiltro');
    print('🔎 Búsqueda: "${_busquedaController.text}"');

    List<Pedido> pedidosFiltrados = List.from(_pedidos);

    // Filtrar por tipo
    if (_tipoFiltro != null) {
      final antes = pedidosFiltrados.length;
      pedidosFiltrados = pedidosFiltrados
          .where((pedido) => pedido.tipo == _tipoFiltro)
          .toList();
      print(
        '⚗️ Después del filtro de tipo: ${pedidosFiltrados.length} (antes: $antes)',
      );
    }

    // Filtrar por estado
    if (_estadoFiltro != null) {
      final antes = pedidosFiltrados.length;
      pedidosFiltrados = pedidosFiltrados
          .where((pedido) => pedido.estado == _estadoFiltro)
          .toList();
      print(
        '⚗️ Después del filtro de estado: ${pedidosFiltrados.length} (antes: $antes)',
      );
    }

    // Filtrar por búsqueda
    if (_busquedaController.text.isNotEmpty) {
      final antes = pedidosFiltrados.length;
      final query = _busquedaController.text.toLowerCase();
      pedidosFiltrados = pedidosFiltrados.where((pedido) {
        return pedido.id.toLowerCase().contains(query) ||
            (pedido.cliente?.toLowerCase().contains(query) ?? false) ||
            pedido.mesa.toLowerCase().contains(query) ||
            pedido.mesero.toLowerCase().contains(query);
      }).toList();
      print(
        '⚗️ Después del filtro de búsqueda: ${pedidosFiltrados.length} (antes: $antes)',
      );
    }

    print('✅ Pedidos filtrados finales: ${pedidosFiltrados.length}');

    setState(() {
      _pedidosFiltrados = pedidosFiltrados;
    });
  }

  // El método _cambiarEstadoPedido ha sido eliminado
  // porque ya no se utiliza en esta pantalla

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
        backgroundColor: bgDark,
        elevation: 0,
        title: Text(
          'Pedidos',
          style: TextStyle(
            color: textDark,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: primary),
            onPressed: _cargarPedidos,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(120),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _busquedaController,
                  style: TextStyle(color: textDark),
                  decoration: InputDecoration(
                    hintText: 'Buscar pedidos...',
                    hintStyle: TextStyle(color: textLight),
                    prefixIcon: Icon(Icons.search, color: textLight),
                    filled: true,
                    fillColor: cardBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                indicatorColor: primary,
                tabs: [
                  Tab(text: 'Activos'),
                  Tab(text: 'Pagados'),
                  Tab(text: 'Cancelados'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primary),
              ),
            )
          : _error != null
          ? Center(
              child: Text(_error!, style: TextStyle(color: Colors.red)),
            )
          : _pedidosFiltrados.isEmpty
          ? Center(
              child: Text('No hay pedidos', style: TextStyle(color: textLight)),
            )
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _pedidosFiltrados.length,
              itemBuilder: (context, index) {
                final pedido = _pedidosFiltrados[index];
                return _buildPedidoCard(pedido);
              },
            ),
    );
  }

  Widget _buildPedidoCard(Pedido pedido) {
    return Card(
      color: cardBg,
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: primary.withOpacity(0.2)),
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
                  'Mesa: ${pedido.mesa}',
                  style: TextStyle(color: textDark, fontSize: 16),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getEstadoColor(pedido.estado),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getEstadoTexto(pedido.estado),
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Mesero: ${pedido.mesero}',
              style: TextStyle(color: textLight),
            ),
            if (pedido.cliente != null) ...[
              SizedBox(height: 4),
              Text(
                'Cliente: ${pedido.cliente}',
                style: TextStyle(color: textLight),
              ),
            ],
            SizedBox(height: 12),
            Text(
              'Total: \$${pedido.total.toStringAsFixed(0)}',
              style: TextStyle(
                color: primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            // Nota: Los botones de pago y cancelación han sido eliminados
            // Para gestionar pagos, dirigirse a la pantalla de mesas
          ],
        ),
      ),
    );
  }

  // Los métodos _mostrarDialogoPago y _mostrarDialogoCancelacion han sido eliminados
  // porque la funcionalidad de pago y cancelación de pedidos
  // debe manejarse exclusivamente desde la pantalla de mesas (mesas_screen.dart)
}
