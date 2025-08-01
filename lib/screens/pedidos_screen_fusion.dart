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

  // Estados disponibles - Ahora incluye cortesía y consumo interno
  final List<EstadoPedido> _estados = [
    EstadoPedido.activo,
    EstadoPedido.pagado,
    EstadoPedido.cancelado,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5, // Activo, Pagado, Cancelado, Cortesía, Consumo Interno
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
      // Reset filtros
      _estadoFiltro = null;
      _tipoFiltro = null;

      // Configurar filtros según el tab seleccionado
      if (_tabController.index <= 2) {
        // Tabs de estados (Activo, Pagado, Cancelado)
        _estadoFiltro = _estados[_tabController.index];
      } else if (_tabController.index == 3) {
        // Tab de Cortesía
        _tipoFiltro = TipoPedido.cortesia;
      } else if (_tabController.index == 4) {
        // Tab de Consumo Interno
        _tipoFiltro = TipoPedido.interno;
      }
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

      // Ordenar pedidos por fecha descendente (más recientes primero)
      pedidos.sort((a, b) => b.fecha.compareTo(a.fecha));

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
      case EstadoPedido.cortesia:
        return Colors.green;
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
      case EstadoPedido.cortesia:
        return 'Cortesía';
    }
  }

  Color _getTipoColor(TipoPedido tipo) {
    switch (tipo) {
      case TipoPedido.normal:
        return Colors.blue;
      case TipoPedido.cortesia:
        return Colors.green;
      case TipoPedido.interno:
        return Colors.purple;
      case TipoPedido.rt:
        return Colors.orange;
      case TipoPedido.cancelado:
        return Colors.red;
    }
  }

  String _getTipoTexto(TipoPedido tipo) {
    switch (tipo) {
      case TipoPedido.normal:
        return 'Normal';
      case TipoPedido.cortesia:
        return 'Cortesía';
      case TipoPedido.interno:
        return 'Consumo Interno';
      case TipoPedido.rt:
        return 'RT';
      case TipoPedido.cancelado:
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

    // NUEVA LÓGICA: Filtrar por tipo específico primero (Cortesía, Consumo Interno)
    if (_tipoFiltro != null) {
      final antes = pedidosFiltrados.length;
      pedidosFiltrados = pedidosFiltrados
          .where((pedido) => pedido.tipo == _tipoFiltro)
          .toList();
      print(
        '⚗️ Después del filtro de tipo: ${pedidosFiltrados.length} (antes: $antes)',
      );
    }
    // Solo filtrar por estado si NO hay filtro de tipo específico
    else if (_estadoFiltro != null) {
      final antes = pedidosFiltrados.length;
      pedidosFiltrados = pedidosFiltrados.where((pedido) {
        // Para el tab "Pagados", excluir cortesía y consumo interno
        // porque tienen sus propios tabs
        if (_estadoFiltro == EstadoPedido.pagado) {
          return pedido.estado == EstadoPedido.pagado &&
              pedido.tipo != TipoPedido.cortesia &&
              pedido.tipo != TipoPedido.interno;
        }
        return pedido.estado == _estadoFiltro;
      }).toList();
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

    // Mantener orden cronológico inverso después del filtrado
    pedidosFiltrados.sort((a, b) => b.fecha.compareTo(a.fecha));

    setState(() {
      _pedidosFiltrados = pedidosFiltrados;
    });
  }

  Future<void> _cancelarPedido(Pedido pedido) async {
    // Mostrar confirmación
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: cardBg,
          title: Text('Cancelar Pedido', style: TextStyle(color: textDark)),
          content: Text(
            '¿Estás seguro de que quieres cancelar el pedido de la mesa ${pedido.mesa}?',
            style: TextStyle(color: textLight),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('No', style: TextStyle(color: textLight)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Sí, Cancelar'),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      try {
        setState(() {
          _isLoading = true;
        });

        // Cancelar el pedido usando el nuevo método con DTO
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final usuarioCancelacion =
            userProvider.userName ?? 'Usuario Desconocido';

        await _pedidoService.cancelarPedidoConDTO(
          pedido.id,
          procesadoPor: usuarioCancelacion,
          notas: 'Pedido cancelado desde la pantalla de pedidos',
        );

        // Recargar la lista de pedidos
        await _cargarPedidos();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pedido cancelado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cancelar pedido: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
                isScrollable: true, // Permitir scroll horizontal para los tabs
                tabs: [
                  Tab(text: 'Activos'),
                  Tab(text: 'Pagados'),
                  Tab(text: 'Cancelados'),
                  Tab(text: 'Cortesía'),
                  Tab(text: 'Consumo Interno'),
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
                Row(
                  children: [
                    // Chip del tipo de pedido
                    if (pedido.tipo != TipoPedido.normal) ...[
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        margin: EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: _getTipoColor(pedido.tipo),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getTipoTexto(pedido.tipo),
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ],
                    // Chip del estado
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: \$${pedido.total.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: primary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Botón de cancelar solo para pedidos activos
                if (pedido.estado == EstadoPedido.activo)
                  TextButton.icon(
                    onPressed: () => _cancelarPedido(pedido),
                    icon: Icon(Icons.cancel, color: Colors.red, size: 16),
                    label: Text(
                      'Cancelar',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size(0, 0),
                    ),
                  ),
              ],
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
