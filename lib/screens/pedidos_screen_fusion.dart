import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pedido.dart';
import '../models/producto.dart';
import '../services/pedido_service.dart';
import '../providers/user_provider.dart';
import '../utils/format_utils.dart';
import '../theme/app_theme.dart';

class PedidosScreenFusion extends StatefulWidget {
  const PedidosScreenFusion({super.key});

  @override
  _PedidosScreenFusionState createState() => _PedidosScreenFusionState();
}

class _PedidosScreenFusionState extends State<PedidosScreenFusion>
    with TickerProviderStateMixin {
  String _getProductoNombre(dynamic producto) {
    if (producto == null) return "Producto desconocido";
    if (producto is Producto) return producto.nombre;
    if (producto is Map<String, dynamic>) {
      return Producto.fromJson(producto).nombre;
    }
    return "Producto desconocido";
  }

  // Colores del tema ahora se usan desde AppTheme
  // Variables de compatibilidad temporal para evitar errores de compilación
  Color get primary => AppTheme.primary;
  Color get cardBg => AppTheme.cardBg;
  Color get textDark => AppTheme.textDark;     // Ahora es blanco desde el tema
  Color get textLight => AppTheme.textLight;   // Ahora es gris claro con buen contraste
  Color get bgDark => AppTheme.backgroundDark;

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
        return AppTheme.success;
      case EstadoPedido.pagado:
        return AppTheme.info;
      case EstadoPedido.cancelado:
        return AppTheme.error;
      case EstadoPedido.cortesia:
        return AppTheme.success;
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
        return AppTheme.info;
      case TipoPedido.cortesia:
        return AppTheme.success;
      case TipoPedido.interno:
        return AppTheme.accent;
      case TipoPedido.rt:
        return AppTheme.warning;
      case TipoPedido.cancelado:
        return AppTheme.error;
      case TipoPedido.domicilio:
        return AppTheme.primary;
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
      case TipoPedido.domicilio:
        return 'Domicilio';
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
          backgroundColor: AppTheme.cardBg,
          title: Text('Cancelar Pedido', style: AppTheme.headlineMedium),
          content: Text(
            '¿Estás seguro de que quieres cancelar el pedido de la mesa ${pedido.mesa}?',
            style: AppTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('No', style: TextStyle(color: AppTheme.textSecondary)),
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
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.receipt_long, color: Colors.white, size: 24),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Administración completa',
                  style: AppTheme.headlineSmall.copyWith(color: Colors.white),
                ),
                Text(
                  'Gestión de Pedidos',
                  style: AppTheme.bodySmall.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 16),
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(Icons.refresh, color: Colors.white, size: 20),
              onPressed: _cargarPedidos,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(120), // Reducido de 140 a 120
          child: Column(
            children: [
              // Barra de búsqueda mejorada
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6), // Reducido de 8 a 6
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 3), // Reducido padding
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: AppTheme.primary, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _busquedaController,
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Buscar por ID, cliente, mesa o mesero...',
                          hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    if (_busquedaController.text.isNotEmpty)
                      IconButton(
                        onPressed: () {
                          _busquedaController.clear();
                          _aplicarFiltros();
                        },
                        icon: Icon(Icons.clear, color: AppTheme.textSecondary, size: 18),
                      ),
                  ],
                ),
              ),

              // Tabs mejorados
              Container(
                margin: EdgeInsets.symmetric(horizontal: 8),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppTheme.primary,
                  indicatorWeight: 2,  // Reducido de 3 a 2 para ser menos invasivo
                  indicatorSize: TabBarIndicatorSize.label,  // Solo bajo el texto, no toda la pestaña
                  isScrollable: true,
                  labelColor: Colors.white,  // Blanco sólido para que se vea sobre naranja
                  unselectedLabelColor: Colors.white.withOpacity(0.7), // Mejor contraste
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 2,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ],
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: 13,
                  ),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, size: 16),
                          SizedBox(width: 4),
                          Text('Activos'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 16),
                          SizedBox(width: 4),
                          Text('Pagados'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cancel, size: 16),
                          SizedBox(width: 4),
                          Text('Cancelados'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 16),
                          SizedBox(width: 4),
                          Text('Cortesía'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.business, size: 16),
                          SizedBox(width: 4),
                          Text('Consumo Interno'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 4), // Reducido de 8 a 4
            ],
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primary),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Cargando pedidos...',
                    style: TextStyle(color: textLight, fontSize: 16),
                  ),
                ],
              ),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'Error al cargar pedidos',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(color: textLight),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _cargarPedidos,
                    icon: Icon(Icons.refresh),
                    label: Text('Intentar de nuevo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          : _pedidosFiltrados.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, color: textLight, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'No hay pedidos',
                    style: TextStyle(
                      color: textLight,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'No se encontraron pedidos con los filtros aplicados',
                    style: TextStyle(
                      color: textLight.withOpacity(0.7),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Barra de estadísticas compacta
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  padding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ), // Reducido de 12,8 a 8,4
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primary.withOpacity(0.06), // Reducido opacidad
                        primary.withOpacity(0.02),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(6), // Reducido de 8 a 6
                    border: Border.all(color: primary.withOpacity(0.05)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem(
                        'Total',
                        '${_pedidosFiltrados.length}',
                        Icons.receipt_long,
                      ),
                      _buildStatItem(
                        'Items',
                        '${_pedidosFiltrados.fold<int>(0, (sum, p) => sum + p.items.length)}',
                        Icons.inventory,
                      ),
                      _buildStatItem(
                        'Valor Total',
                        formatCurrency(
                          _pedidosFiltrados.fold<double>(
                            0,
                            (sum, p) => sum + p.total,
                          ),
                        ),
                        Icons.attach_money,
                      ),
                    ],
                  ),
                ),

                // Lista de pedidos compacta y scrollable
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    itemCount: _pedidosFiltrados.length,
                    itemBuilder: (context, index) {
                      final pedido = _pedidosFiltrados[index];
                      return _buildPedidoCard(pedido);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPedidoCard(Pedido pedido) {
    return Card(
      color: cardBg,
      margin: EdgeInsets.only(bottom: 2), // antes 4
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(3), // antes 6
        side: BorderSide(color: primary.withOpacity(0.08)),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.all(3), // antes 6
        childrenPadding: EdgeInsets.symmetric(
          horizontal: 3,
          vertical: 2,
        ), // antes 6,4
        backgroundColor: cardBg,
        collapsedBackgroundColor: cardBg,
        iconColor: primary,
        collapsedIconColor: primary,
        leading: Container(
          width: 96, // más ancho
          height: 36, // más alto
          decoration: BoxDecoration(
            color: primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.restaurant, color: primary, size: 18),
                SizedBox(height: 2),
                Flexible(
                  child: Text(
                    pedido.mesa,
                    style: TextStyle(
                      color: primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Primera fila: Info principal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 1, // antes 2, ahora más angosto
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ID: ${pedido.id}',
                        style: TextStyle(
                          color: textDark,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Mesa: ${pedido.mesa}',
                        style: TextStyle(color: textLight, fontSize: 9),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Chips de tipo y estado
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (pedido.tipo != TipoPedido.normal) ...[
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getTipoColor(pedido.tipo),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              _getTipoTexto(pedido.tipo),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 7,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(width: 2),
                        ],
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _getEstadoColor(pedido.estado),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            _getEstadoTexto(pedido.estado),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text(
                      '\$${pedido.total.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12),

            // Segunda fila: Info detallada en formato tabla
            Container(
              padding: EdgeInsets.all(6), // antes 12
              decoration: BoxDecoration(
                color: cardBg.withOpacity(0.5),
                borderRadius: BorderRadius.circular(4), // antes 8
                border: Border.all(color: primary.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  // Fila de mesero y cliente
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem(
                          Icons.person,
                          'Mesero',
                          pedido.mesero,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildInfoItem(Icons.person_outline, 'Cliente', () {
                          // Debug: Imprimir información del pedido
                          print('🔍 Debug Pedido ID: ${pedido.id}');
                          print('🔍 Debug Cliente: ${pedido.cliente}');
                          print('🔍 Debug Items count: ${pedido.items.length}');
                          if (pedido.items.isNotEmpty) {
                            print(
                              '🔍 Debug Primer producto ID: ${pedido.items.first.productoId}',
                            );
                            print(
                              '🔍 Debug Primer producto nombre: ${_getProductoNombre(pedido.items.first.producto)}',
                            );
                          }

                          // Verificar si hay algún problema con el cliente
                          final clienteInfo = pedido.cliente ?? 'Sin cliente';
                          print('🔍 Debug Cliente final: $clienteInfo');
                          return clienteInfo;
                        }()),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),

                  // Fila de fecha y items
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem(
                          Icons.access_time,
                          'Fecha/Hora',
                          '${pedido.fecha.day}/${pedido.fecha.month}/${pedido.fecha.year}\n${pedido.fecha.hour.toString().padLeft(2, '0')}:${pedido.fecha.minute.toString().padLeft(2, '0')}',
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildInfoItem(Icons.inventory, 'Items', () {
                          if (pedido.items.isEmpty) {
                            return '0 productos';
                          }

                          // Mostrar el primer producto con su nombre si está disponible
                          final primerItem = pedido.items.first;

                          // Prioridad: objeto producto > productoNombre del JSON > ID
                          String nombreProducto;
                          if (_getProductoNombre(primerItem.producto) !=
                                  "Producto desconocido" &&
                              _getProductoNombre(primerItem.producto) !=
                                  "Producto desconocido") {
                            nombreProducto = _getProductoNombre(
                              primerItem.producto,
                            );
                          } else {
                            // Intentar usar productoNombre del JSON como fallback
                            // Este campo viene del backend en el JSON
                            nombreProducto =
                                'ID: ${primerItem.productoId}'; // Fallback al ID
                          }

                          if (pedido.items.length == 1) {
                            return nombreProducto;
                          } else {
                            return '$nombreProducto + ${pedido.items.length - 1} más';
                          }
                        }()),
                      ),
                    ],
                  ),

                  // Botón de cancelar para pedidos activos
                  if (pedido.estado == EstadoPedido.activo) ...[
                    SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _cancelarPedido(pedido),
                        icon: Icon(Icons.cancel, size: 16),
                        label: Text('Cancelar Pedido'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        children: [
          // Contenido expandido: Tabla detallada de productos
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primary.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header de productos
                Row(
                  children: [
                    Icon(Icons.receipt_long, color: primary, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Detalle de Productos',
                      style: TextStyle(
                        color: textDark,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Encabezados de la tabla
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Producto',
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Cant.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Precio U.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Subtotal',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Lista de productos
                ...pedido.items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isEven = index % 2 == 0;

                  return Container(
                    margin: EdgeInsets.only(top: 2),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isEven
                          ? cardBg.withOpacity(0.2)
                          : cardBg.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                _getProductoNombre(item.producto),
                                style: TextStyle(
                                  color: textDark,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: primary.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${item.cantidad}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '\$${item.precio.toStringAsFixed(0)}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: textLight,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '\$${(item.precio * item.cantidad).toStringAsFixed(0)}',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Mostrar notas si existen
                        if (item.notas != null && item.notas!.isNotEmpty) ...[
                          SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.amber.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.note, color: Colors.amber, size: 16),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    item.notas!,
                                    style: TextStyle(
                                      color: textLight,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),

                // Total del pedido
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primary.withOpacity(0.1),
                        primary.withOpacity(0.05),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL DEL PEDIDO',
                            style: TextStyle(
                              color: textLight,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${pedido.items.length} productos',
                            style: TextStyle(
                              color: textLight.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
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
                ),

                // Notas del pedido si existen
                if (pedido.notas != null && pedido.notas!.isNotEmpty) ...[
                  SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.note_alt, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Notas del Pedido:',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                pedido.notas!,
                                style: TextStyle(color: textDark, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Método auxiliar para construir items de información
  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: primary, size: 16),
        SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: textLight.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Método auxiliar para construir items de estadísticas
  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(4), // Reducido de 8 a 4
          decoration: BoxDecoration(
            color: primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6), // Reducido de 8 a 6
          ),
          child: Icon(icon, color: primary, size: 16), // Reducido de 20 a 16
        ),
        SizedBox(height: 2), // Reducido de 4 a 2
        Text(
          value,
          style: TextStyle(
            color: primary,
            fontSize: 14, // Reducido de 16 a 14
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: textLight,
            fontSize: 9, // Reducido de 10 a 9
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
