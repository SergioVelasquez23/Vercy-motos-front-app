import 'package:flutter/material.dart';
import '../models/pedido.dart';
import '../services/pedido_service.dart';

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

  Future<void> _cambiarEstadoPedido(
    String pedidoId,
    EstadoPedido nuevoEstado,
  ) async {
    try {
      await _pedidoService.actualizarEstadoPedido(pedidoId, nuevoEstado);
      print('✅ Estado actualizado exitosamente');
      _cargarPedidos(); // Recargar para obtener datos actualizados
    } catch (e) {
      print('❌ Error actualizando estado: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al actualizar estado: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
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
            if (pedido.estado == EstadoPedido.activo) ...[
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _mostrarDialogoPago(pedido),
                      child: Text('Pagar pedido'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _mostrarDialogoCancelacion(pedido),
                      child: Text('Cancelar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
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

  void _mostrarDialogoPago(Pedido pedido) async {
    final Color cardBg = Color(0xFF252525);
    final Color textLight = Color(0xFFE0E0E0);
    final Color primary = Color(0xFFFF6B00);

    String medioPago = 'efectivo';
    bool incluyePropina = false;
    TextEditingController descuentoPorcentajeController =
        TextEditingController();
    TextEditingController descuentoValorController = TextEditingController();

    final formResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          padding: EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pagar Pedido',
                  style: TextStyle(
                    color: textLight,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),

                // Información del pedido
                Text(
                  'Mesa: ${pedido.mesa}',
                  style: TextStyle(color: textLight),
                ),
                Text(
                  'Mesero: ${pedido.mesero}',
                  style: TextStyle(color: textLight),
                ),
                if (pedido.cliente != null)
                  Text(
                    'Cliente: ${pedido.cliente}',
                    style: TextStyle(color: textLight),
                  ),
                SizedBox(height: 16),

                // Detalle de productos
                Text(
                  'Productos:',
                  style: TextStyle(
                    color: textLight,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ...pedido.items.map(
                  (item) => Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.cantidad}x ${item.producto?.nombre ?? item.productoId}',
                            style: TextStyle(color: textLight),
                          ),
                        ),
                        Text(
                          '\$${((item.producto?.precio ?? 0) * item.cantidad).toStringAsFixed(0)}',
                          style: TextStyle(color: textLight),
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(color: textLight.withOpacity(0.3)),

                // Campos de descuento
                Text(
                  'Descuentos:',
                  style: TextStyle(
                    color: textLight,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: descuentoPorcentajeController,
                        decoration: InputDecoration(
                          labelText: 'Descuento %',
                          labelStyle: TextStyle(color: textLight),
                          suffixText: '%',
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: textLight.withOpacity(0.3),
                            ),
                          ),
                        ),
                        style: TextStyle(color: textLight),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: descuentoValorController,
                        decoration: InputDecoration(
                          labelText: 'Descuento \$',
                          labelStyle: TextStyle(color: textLight),
                          prefixText: '\$',
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: textLight.withOpacity(0.3),
                            ),
                          ),
                        ),
                        style: TextStyle(color: textLight),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Forma de pago
                Text(
                  'Forma de pago:',
                  style: TextStyle(
                    color: textLight,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Radio<String>(
                      value: 'efectivo',
                      groupValue: medioPago,
                      onChanged: (value) {
                        setState(() => medioPago = value!);
                      },
                      activeColor: primary,
                    ),
                    Text('Efectivo', style: TextStyle(color: textLight)),
                    SizedBox(width: 16),
                    Radio<String>(
                      value: 'tarjeta',
                      groupValue: medioPago,
                      onChanged: (value) {
                        setState(() => medioPago = value!);
                      },
                      activeColor: primary,
                    ),
                    Text('Tarjeta', style: TextStyle(color: textLight)),
                  ],
                ),

                // Propina
                SwitchListTile(
                  title: Text(
                    'Incluir propina',
                    style: TextStyle(color: textLight),
                  ),
                  value: incluyePropina,
                  onChanged: (value) {
                    setState(() => incluyePropina = value);
                  },
                  activeColor: primary,
                ),

                SizedBox(height: 16),

                // Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total:',
                      style: TextStyle(
                        color: textLight,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '\$${pedido.total.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: primary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 24),

                // Botones de acción
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancelar'),
                      style: TextButton.styleFrom(foregroundColor: textLight),
                    ),
                    SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, {
                          'medioPago': medioPago,
                          'incluyePropina': incluyePropina,
                          'descuentoPorcentaje':
                              descuentoPorcentajeController.text,
                          'descuentoValor': descuentoValorController.text,
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Confirmar pago'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (formResult != null) {
      await _cambiarEstadoPedido(pedido.id, EstadoPedido.pagado);
      // Aquí podrías guardar la información del pago si es necesario
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pedido pagado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _mostrarDialogoCancelacion(Pedido pedido) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        title: Text('Cancelar Pedido', style: TextStyle(color: textDark)),
        content: Text(
          '¿Estás seguro de que quieres cancelar el pedido de la mesa ${pedido.mesa}?',
          style: TextStyle(color: textLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No', style: TextStyle(color: textLight)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _cambiarEstadoPedido(pedido.id, EstadoPedido.cancelado);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pedido cancelado exitosamente'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
