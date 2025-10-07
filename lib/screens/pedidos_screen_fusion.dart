import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pedido.dart';
import '../models/producto.dart';
import '../models/cuadre_caja.dart';
import '../services/pedido_service.dart';
import '../services/cuadre_caja_service.dart';
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
  Color get textDark => AppTheme.textDark; // Ahora es blanco desde el tema
  Color get textLight =>
      AppTheme.textLight; // Ahora es gris claro con buen contraste
  Color get bgDark => AppTheme.backgroundDark;

  final TextEditingController _busquedaController = TextEditingController();
  late TabController _tabController;
  late ScrollController _scrollController;

  final PedidoService _pedidoService = PedidoService();
  final CuadreCajaService _cuadreCajaService = CuadreCajaService();
  List<Pedido> _pedidos = [];
  List<Pedido> _pedidosFiltrados = [];
  List<Pedido> _pedidosPorPeriodoCaja =
      []; // Pedidos del período de caja actual
  bool _isLoading = true;
  String? _error;
  CuadreCaja? _cajaActiva;

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
    _scrollController = ScrollController();
    _tabController.addListener(_onTabChanged);
    _cargarPedidos();
    _busquedaController.addListener(_aplicarFiltros);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scrollController.dispose();
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
      // Cargar pedidos y caja activa en paralelo
      final futures = await Future.wait([
        _pedidoService.getAllPedidos(),
        _cuadreCajaService.getCajaActiva(),
      ]);

      final pedidos = futures[0] as List<Pedido>;
      final cajaActiva = futures[1] as CuadreCaja?;

      // Ordenar pedidos por fecha descendente (más recientes primero)
      pedidos.sort((a, b) => b.fecha.compareTo(a.fecha));

      // Filtrar pedidos por período de caja (solo pedidos PAGADOS desde la apertura de caja)
      List<Pedido> pedidosPorPeriodoCaja = [];
      if (cajaActiva != null) {
        pedidosPorPeriodoCaja = pedidos.where((pedido) {
          // Solo incluir pedidos pagados que estén dentro del período de caja
          // y excluir mesas que quedan pendientes (activas)
          return pedido.estado == EstadoPedido.pagado &&
              pedido.fecha.isAfter(cajaActiva.fechaApertura);
        }).toList();

        print(
          '📊 Caja activa: ${cajaActiva.nombre} (${cajaActiva.fechaApertura})',
        );
        print(
          '💰 Pedidos del período de caja: ${pedidosPorPeriodoCaja.length}',
        );
      } else {
        print('⚠️ No hay caja activa - mostrando todas las estadísticas');
        // Si no hay caja activa, mostrar solo pedidos pagados del día actual
        final hoy = DateTime.now();
        final inicioDelDia = DateTime(hoy.year, hoy.month, hoy.day);
        pedidosPorPeriodoCaja = pedidos.where((pedido) {
          return pedido.estado == EstadoPedido.pagado &&
              pedido.fecha.isAfter(inicioDelDia);
        }).toList();
      }

      setState(() {
        _pedidos = pedidos;
        _cajaActiva = cajaActiva;
        _pedidosPorPeriodoCaja = pedidosPorPeriodoCaja;
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

    // Filtrar pedidos vacíos o sin contenido válido
    pedidosFiltrados = pedidosFiltrados.where((pedido) {
      // Eliminar pedidos que parecen ser movimientos vacíos
      if (pedido.total <= 0 && pedido.items.isEmpty) {
        print(
          '⚠️ Pedido filtrado (vacío): ${pedido.id} - Mesa: ${pedido.mesa}',
        );
        return false;
      }
      return true;
    }).toList();

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
              child: Text(
                'No',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
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

  Future<void> _mostrarDialogoEliminarPedidos() async {
    // Obtener pedidos activos y pagados que pueden ser eliminados
    final pedidosActivos = _pedidosFiltrados
        .where((pedido) => pedido.estado == EstadoPedido.activo)
        .toList();

    final pedidosPagados = _pedidosFiltrados
        .where((pedido) => pedido.estado == EstadoPedido.pagado)
        .toList();

    if (pedidosActivos.isEmpty && pedidosPagados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hay pedidos que se puedan eliminar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Mostrar lista de pedidos para seleccionar cuáles eliminar
    List<String> pedidosActivosSeleccionados = [];
    List<String> pedidosPagadosSeleccionados = [];

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppTheme.cardBg,
              title: Row(
                children: [
                  Icon(Icons.delete_forever, color: Colors.red, size: 28),
                  SizedBox(width: 8),
                  Text(
                    'Eliminar Pedidos',
                    style: AppTheme.headlineMedium.copyWith(color: Colors.red),
                  ),
                ],
              ),
              content: Container(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selecciona los pedidos que deseas eliminar:',
                      style: AppTheme.bodyMedium,
                    ),
                    SizedBox(height: 16),

                    // Sección de pedidos activos
                    if (pedidosActivos.isNotEmpty) ...[
                      Text(
                        '🔄 Pedidos Activos (${pedidosActivos.length})',
                        style: AppTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        height: 120,
                        child: ListView.builder(
                          itemCount: pedidosActivos.length,
                          itemBuilder: (context, index) {
                            final pedido = pedidosActivos[index];
                            final isSelected = pedidosActivosSeleccionados
                                .contains(pedido.id);

                            return CheckboxListTile(
                              value: isSelected,
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    pedidosActivosSeleccionados.add(pedido.id);
                                  } else {
                                    pedidosActivosSeleccionados.remove(
                                      pedido.id,
                                    );
                                  }
                                });
                              },
                              title: Text(
                                'Mesa ${pedido.mesa} - ${pedido.cliente ?? "Sin cliente"}',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                'Total: ${formatCurrency(pedido.total)}',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              activeColor: Colors.orange,
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 16),
                    ],

                    // Sección de pedidos pagados
                    if (pedidosPagados.isNotEmpty) ...[
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '💰 Pedidos Pagados (${pedidosPagados.length})',
                              style: AppTheme.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '⚠️ IMPORTANTE: Al eliminar pedidos pagados se reversará automáticamente el dinero de las ventas y se descontará de la caja.',
                              style: AppTheme.bodySmall.copyWith(
                                color: Colors.red[700],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: pedidosPagados.length,
                          itemBuilder: (context, index) {
                            final pedido = pedidosPagados[index];
                            final isSelected = pedidosPagadosSeleccionados
                                .contains(pedido.id);

                            return CheckboxListTile(
                              value: isSelected,
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    pedidosPagadosSeleccionados.add(pedido.id);
                                  } else {
                                    pedidosPagadosSeleccionados.remove(
                                      pedido.id,
                                    );
                                  }
                                });
                              },
                              title: Text(
                                'Mesa ${pedido.mesa} - ${pedido.cliente ?? "Sin cliente"}',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                'Total: ${formatCurrency(pedido.total)} - ${pedido.formaPago ?? "N/A"}',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              activeColor: Colors.red,
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      (pedidosActivosSeleccionados.isEmpty &&
                          pedidosPagadosSeleccionados.isEmpty)
                      ? null
                      : () async {
                          Navigator.of(context).pop();

                          // Eliminar pedidos activos primero
                          if (pedidosActivosSeleccionados.isNotEmpty) {
                            await _eliminarPedidosSeleccionados(
                              pedidosActivosSeleccionados,
                            );
                          }

                          // Luego eliminar pedidos pagados
                          if (pedidosPagadosSeleccionados.isNotEmpty) {
                            await _eliminarPedidosPagadosSeleccionados(
                              pedidosPagadosSeleccionados,
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: Text(
                    'Eliminar ${pedidosActivosSeleccionados.length + pedidosPagadosSeleccionados.length} pedido(s)',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _eliminarPedidosSeleccionados(List<String> pedidosIds) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final usuarioEliminacion = userProvider.userName ?? 'Usuario Desconocido';

      int exitosos = 0;
      int fallidos = 0;

      for (String pedidoId in pedidosIds) {
        try {
          await _pedidoService.eliminarPedido(pedidoId);
          exitosos++;
          print(
            '✅ Pedido $pedidoId eliminado exitosamente por $usuarioEliminacion',
          );
        } catch (e) {
          fallidos++;
          print('❌ Error eliminando pedido $pedidoId: $e');
        }
      }

      // Recargar la lista de pedidos
      await _cargarPedidos();

      // Mostrar resultado
      String mensaje;
      Color color;

      if (fallidos == 0) {
        mensaje = '✅ Se eliminaron $exitosos pedido(s) correctamente';
        color = Colors.green;
      } else if (exitosos == 0) {
        mensaje = '❌ No se pudo eliminar ningún pedido';
        color = Colors.red;
      } else {
        mensaje = '⚠️ Se eliminaron $exitosos pedido(s). $fallidos falló(s)';
        color = Colors.orange;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: color,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error eliminando pedidos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Eliminar pedidos pagados - Revierte automáticamente el dinero de las ventas
  Future<void> _eliminarPedidosPagadosSeleccionados(
    List<String> pedidosIds,
  ) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final usuarioEliminacion = userProvider.userName ?? 'Usuario Desconocido';

      int exitosos = 0;
      int fallidos = 0;

      for (String pedidoId in pedidosIds) {
        try {
          await _pedidoService.eliminarPedidoPagado(pedidoId);
          exitosos++;
          print(
            '✅ Pedido pagado $pedidoId eliminado exitosamente (con reversión de dinero) por $usuarioEliminacion',
          );
        } catch (e) {
          fallidos++;
          print('❌ Error eliminando pedido pagado $pedidoId: $e');
        }
      }

      // Recargar la lista de pedidos
      await _cargarPedidos();

      // Mostrar resultado
      String mensaje;
      Color color;

      if (fallidos == 0) {
        mensaje =
            '✅ Se eliminaron $exitosos pedido(s) pagado(s) correctamente\n💰 El dinero fue revertido automáticamente';
        color = Colors.green;
      } else if (exitosos == 0) {
        mensaje = '❌ No se pudo eliminar ningún pedido pagado';
        color = Colors.red;
      } else {
        mensaje =
            '⚠️ Se eliminaron $exitosos pedido(s) pagado(s). $fallidos falló(s)\n💰 Se revirtió el dinero de los exitosos';
        color = Colors.orange;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: color,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error eliminando pedidos pagados: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if user has admin permissions
    final userProvider = Provider.of<UserProvider>(context);
    if (!userProvider.isAdmin) {
      // Si el usuario no es admin, mostrar pantalla de acceso restringido
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              backgroundColor: AppTheme.primary,
              elevation: 0,
              floating: true,
              pinned: false,
              expandedHeight: 120.0,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: EdgeInsets.only(left: 16, bottom: 16),
                title: Text(
                  'Pedidos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SliverFillRemaining(
              child: Center(
                child: Container(
                  margin: EdgeInsets.all(20),
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock, color: Colors.red, size: 64),
                      SizedBox(height: 16),
                      Text(
                        'Acceso Restringido',
                        style: TextStyle(
                          color: AppTheme.textDark,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Necesitas permisos de administrador para acceder a esta sección.',
                        style: TextStyle(color: AppTheme.textLight),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // AppBar que se oculta al hacer scroll
          SliverAppBar(
            backgroundColor: AppTheme.primary,
            elevation: 0,
            floating: true, // Se muestra al scroll hacia arriba
            pinned: false, // No se queda fijo arriba
            expandedHeight: 120.0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.only(left: 16, bottom: 16),
              title: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.receipt_long,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Gestión de Pedidos',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Administración completa',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              // Botón para eliminar pedidos seleccionados
              Container(
                margin: EdgeInsets.only(right: 8),
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.delete_forever,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => _mostrarDialogoEliminarPedidos(),
                  tooltip: 'Eliminar pedidos',
                ),
              ),
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
                  tooltip: 'Actualizar pedidos',
                ),
              ),
            ],
          ),

          // Barra de búsqueda que también se oculta al hacer scroll
          SliverPersistentHeader(
            floating: true, // Reaparece al scroll hacia arriba
            delegate: _SearchBarDelegate(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Buscar por ID, cliente, mesa o mesero...',
                          hintStyle: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
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
                        icon: Icon(
                          Icons.clear,
                          color: AppTheme.textSecondary,
                          size: 18,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Tabs que también se ocultan al hacer scroll
          SliverPersistentHeader(
            floating: true, // Reaparece al scroll hacia arriba
            delegate: _TabBarDelegate(
              tabBar: Container(
                margin: EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  indicatorWeight: 2,
                  indicatorSize: TabBarIndicatorSize.label,
                  isScrollable: true,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withOpacity(0.7),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
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
            ),
          ),

          // Contenido principal
          SliverToBoxAdapter(
            child: Container(
              height: MediaQuery.of(context).size.height,
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: AppTheme.primary),
                          SizedBox(height: 16),
                          Text(
                            'Cargando pedidos...',
                            style: AppTheme.bodyMedium,
                          ),
                        ],
                      ),
                    )
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: AppTheme.error,
                            size: 64,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Error al cargar datos',
                            style: AppTheme.headlineMedium.copyWith(
                              color: AppTheme.error,
                            ),
                          ),
                          SizedBox(height: 8),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              _error!,
                              style: AppTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _cargarPedidos,
                            icon: Icon(Icons.refresh),
                            label: Text('Reintentar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
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
                          Icon(
                            Icons.inbox_outlined,
                            color: AppTheme.textSecondary,
                            size: 64,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No se encontraron pedidos',
                            style: AppTheme.headlineMedium,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No hay pedidos que coincidan con los filtros seleccionados',
                            style: AppTheme.bodyMedium.copyWith(
                              color: AppTheme.textSecondary,
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
                          margin: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: cardBg.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: primary.withOpacity(0.2)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatItem(
                                'Total',
                                '${_pedidosPorPeriodoCaja.length}',
                                Icons.receipt_long,
                              ),
                              _buildStatItem(
                                'Monto',
                                formatCurrency(
                                  _pedidosPorPeriodoCaja.fold<double>(
                                    0,
                                    (sum, pedido) => sum + pedido.total,
                                  ),
                                ),
                                Icons.attach_money,
                              ),
                              _buildStatItem(
                                'Items',
                                '${_pedidosPorPeriodoCaja.fold<int>(0, (sum, pedido) => sum + pedido.items.length)}',
                                Icons.shopping_cart,
                              ),
                            ],
                          ),
                        ),

                        // Indicador de período de caja
                        if (_cajaActiva != null)
                          Container(
                            margin: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: primary.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.schedule, size: 14, color: primary),
                                SizedBox(width: 6),
                                Text(
                                  'Período de caja: ${_cajaActiva!.nombre} (desde ${_formatearFecha(_cajaActiva!.fechaApertura)})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: textDark.withOpacity(0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Lista de pedidos compacta y scrollable
                        Expanded(
                          child: ListView.builder(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _pedidosFiltrados.length,
                            itemBuilder: (context, index) {
                              return _buildPedidoCard(_pedidosFiltrados[index]);
                            },
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

  Widget _buildPedidoCard(Pedido pedido) {
    // Filtrar pedidos sin total o con total 0 que no deberían mostrarse
    if (pedido.total <= 0 && pedido.items.isEmpty) {
      print('⚠️ Pedido filtrado - Sin total ni items: ${pedido.id}');
      return SizedBox.shrink(); // No mostrar este pedido
    }

    return Card(
      color: cardBg,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: primary.withOpacity(0.2)),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera del pedido
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mesa ${pedido.mesa}',
                        style: TextStyle(
                          color: textDark,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        pedido.cliente ?? 'Sin cliente',
                        style: TextStyle(color: textLight, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getEstadoColor(pedido.estado).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getEstadoColor(pedido.estado),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _getEstadoTexto(pedido.estado),
                        style: TextStyle(
                          color: _getEstadoColor(pedido.estado),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      formatCurrency(pedido.total),
                      style: TextStyle(
                        color: primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            SizedBox(height: 12),

            // Información del mesero y hora
            Row(
              children: [
                Icon(Icons.person, color: primary, size: 16),
                SizedBox(width: 4),
                Text(
                  'Atendido por: ${pedido.mesero}',
                  style: TextStyle(
                    color: textLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 16),
                Icon(Icons.access_time, color: primary, size: 16),
                SizedBox(width: 4),
                Text(
                  '${pedido.fecha.day}/${pedido.fecha.month}/${pedido.fecha.year} ${pedido.fecha.hour.toString().padLeft(2, '0')}:${pedido.fecha.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(color: textLight, fontSize: 12),
                ),
              ],
            ),

            if (pedido.items.isNotEmpty) ...[
              SizedBox(height: 16),

              // Separador y título de productos
              Container(
                width: double.infinity,
                height: 1,
                color: primary.withOpacity(0.2),
              ),
              SizedBox(height: 12),

              Row(
                children: [
                  Icon(Icons.restaurant_menu, color: primary, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Productos (${pedido.items.length}):',
                    style: TextStyle(
                      color: textDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),

              // Lista de productos
              ...pedido.items
                  .map(
                    (item) => Container(
                      margin: EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: bgDark.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: primary.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Icono del producto
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.restaurant,
                              color: primary,
                              size: 16,
                            ),
                          ),
                          SizedBox(width: 12),

                          // Información del producto
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productoNombre ?? 'Producto',
                                  style: TextStyle(
                                    color: textDark,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (item.notas != null &&
                                    item.notas!.isNotEmpty) ...[
                                  SizedBox(height: 2),
                                  Text(
                                    'Notas: ${item.notas}',
                                    style: TextStyle(
                                      color: AppTheme.warning,
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Cantidad y precio
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'x${item.cantidad}',
                                  style: TextStyle(
                                    color: primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                formatCurrency(item.subtotal),
                                style: TextStyle(
                                  color: textDark,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ],

            // Notas del pedido (si las hay)
            if (pedido.notas != null && pedido.notas!.isNotEmpty) ...[
              SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.warning.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note, color: AppTheme.warning, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notas del pedido:',
                            style: TextStyle(
                              color: AppTheme.warning,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            pedido.notas!,
                            style: TextStyle(color: textLight, fontSize: 12),
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
    );
  }

  // Método auxiliar para construir items de estadísticas
  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: primary, size: 20),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: primary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: textLight,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatearFecha(DateTime fecha) {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final ayer = hoy.subtract(Duration(days: 1));
    final fechaSinHora = DateTime(fecha.year, fecha.month, fecha.day);

    if (fechaSinHora == hoy) {
      return 'hoy ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
    } else if (fechaSinHora == ayer) {
      return 'ayer ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
    } else {
      return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
    }
  }
}

// Delegate para la barra de búsqueda
class _SearchBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _SearchBarDelegate({required this.child});

  @override
  double get minExtent => 60.0;

  @override
  double get maxExtent => 60.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: AppTheme.backgroundDark, child: child);
  }

  @override
  bool shouldRebuild(_SearchBarDelegate oldDelegate) {
    return false;
  }
}

// Delegate para los tabs
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget tabBar;

  _TabBarDelegate({required this.tabBar});

  @override
  double get minExtent => 50.0;

  @override
  double get maxExtent => 50.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: AppTheme.backgroundDark, child: tabBar);
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return false;
  }
}
