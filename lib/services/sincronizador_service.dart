import 'dart:async';
import '../models/mesa.dart';
import '../models/pedido.dart';
import 'mesa_service.dart';
import 'pedido_service.dart';

class SincronizadorService {
  static final SincronizadorService _instance =
      SincronizadorService._internal();
  factory SincronizadorService() => _instance;

  final MesaService _mesaService = MesaService();
  final PedidoService _pedidoService = PedidoService();

  Timer? _sincronizacionPeriodica;

  SincronizadorService._internal() {
    print('🔄 SincronizadorService: Inicializando servicio');
  }

  /// Inicia la sincronización periódica entre mesas y pedidos
  void iniciarSincronizacionPeriodica({
    Duration periodo = const Duration(minutes: 5),
  }) {
    print(
      '🔄 SincronizadorService: Iniciando sincronización periódica cada ${periodo.inMinutes} minutos',
    );

    // Cancelar el timer anterior si existe
    _sincronizacionPeriodica?.cancel();

    // Ejecutar la sincronización inmediatamente una vez
    sincronizarEstadoMesasPedidos();

    // Programar sincronización periódica
    _sincronizacionPeriodica = Timer.periodic(periodo, (_) {
      sincronizarEstadoMesasPedidos();
    });
  }

  /// Detiene la sincronización periódica
  void detenerSincronizacionPeriodica() {
    print('🔄 SincronizadorService: Deteniendo sincronización periódica');
    _sincronizacionPeriodica?.cancel();
    _sincronizacionPeriodica = null;
  }

  /// Sincroniza el estado de todas las mesas con sus pedidos correspondientes
  Future<void> sincronizarEstadoMesasPedidos({
    bool forzarLimpieza = false,
  }) async {
    try {
      print(
        '🔄 SincronizadorService: Iniciando sincronización de mesas y pedidos',
      );

      // Obtener todas las mesas
      final List<Mesa> mesas = await _mesaService.getMesas();
      print('🔄 SincronizadorService: ${mesas.length} mesas encontradas');

      // Procesar cada mesa
      int mesasActualizadas = 0;
      for (final mesa in mesas) {
        final bool fueSincronizada = await sincronizarMesa(
          mesa,
          forzarLimpieza: forzarLimpieza,
        );
        if (fueSincronizada) mesasActualizadas++;
      }

      print(
        '🔄 SincronizadorService: Sincronización completada. $mesasActualizadas mesas actualizadas',
      );
    } catch (e) {
      print('❌ SincronizadorService: Error en sincronización: $e');
    }
  }

  /// Restablece todas las mesas a su estado inicial (vacías y disponibles)
  /// Útil cuando se han eliminado manualmente todos los pedidos de la base de datos
  Future<int> forzarLimpiezaCompletaMesas() async {
    try {
      print(
        '🧹 SincronizadorService: Iniciando limpieza completa de todas las mesas',
      );

      // Obtener todas las mesas
      final List<Mesa> mesas = await _mesaService.getMesas();
      print(
        '🧹 SincronizadorService: ${mesas.length} mesas encontradas para limpiar',
      );

      // Limpiar todas las mesas
      int mesasLimpiadas = 0;
      for (final mesa in mesas) {
        if (mesa.ocupada ||
            mesa.total > 0 ||
            mesa.productos.isNotEmpty ||
            mesa.pedidoActual != null) {
          try {
            print('🧹 Limpiando mesa ${mesa.nombre}');
            mesa.ocupada = false;
            mesa.total = 0;
            mesa.productos = [];
            mesa.pedidoActual = null;
            await _mesaService.updateMesa(mesa);
            mesasLimpiadas++;
          } catch (e) {
            print('❌ Error al limpiar mesa ${mesa.nombre}: $e');
          }
        }
      }

      print(
        '✅ SincronizadorService: Limpieza completa finalizada. $mesasLimpiadas mesas limpiadas',
      );
      return mesasLimpiadas;
    } catch (e) {
      print('❌ SincronizadorService: Error en limpieza completa: $e');
      return 0;
    }
  }

  /// Sincroniza una mesa específica con su pedido correspondiente
  Future<bool> sincronizarMesa(Mesa mesa, {bool forzarLimpieza = false}) async {
    try {
      print(
        '🔄 SincronizadorService: Sincronizando mesa ${mesa.nombre} (ID: ${mesa.id})',
      );

      bool requiereActualizacion = false;

      // Si se solicita forzar la limpieza, limpiar la mesa sin consultar pedidos
      if (forzarLimpieza &&
          (mesa.ocupada || mesa.total > 0 || mesa.productos.isNotEmpty)) {
        print('🧹 Forzando limpieza de mesa ${mesa.nombre}');
        mesa.ocupada = false;
        mesa.total = 0;
        mesa.productos = [];
        mesa.pedidoActual = null;

        // Actualizar la mesa inmediatamente y retornar
        print('🧹 Actualizando mesa ${mesa.nombre} (limpieza forzada)');
        await _mesaService.updateMesa(mesa);
        return true;
      }

      // 1. Si la mesa está marcada como ocupada, verificar que tenga un pedido activo
      if (mesa.ocupada) {
        print('🔄 Mesa ${mesa.nombre} está ocupada, verificando pedidos');

        // Obtener pedidos para esta mesa
        final pedidos = await _pedidoService.getPedidosByMesa(mesa.nombre);

        // Si no hay pedidos en absoluto (se borraron todos de la BD), liberar la mesa inmediatamente
        if (pedidos.isEmpty) {
          print(
            '⚠️ Mesa ${mesa.nombre} está ocupada pero NO HAY PEDIDOS en el sistema, liberando mesa',
          );
          mesa.ocupada = false;
          mesa.total = 0;
          mesa.productos = [];
          mesa.pedidoActual = null;
          requiereActualizacion = true;
        } else {
          // Buscar un pedido activo
          final pedidoActivo = pedidos
              .where((p) => p.estado == EstadoPedido.activo)
              .toList();

          // Si no hay pedidos activos pero la mesa está ocupada, liberar la mesa
          if (pedidoActivo.isEmpty) {
            print(
              '⚠️ Mesa ${mesa.nombre} está ocupada pero no tiene pedidos activos',
            );

            // Todos los pedidos están pagados o cancelados, liberar la mesa
            print(
              '🔄 Mesa ${mesa.nombre} no tiene pedidos activos, liberando mesa',
            );
            mesa.ocupada = false;
            mesa.total = 0;
            mesa.productos = [];
            mesa.pedidoActual = null;
            requiereActualizacion = true;
          } else if (pedidoActivo.length > 1) {
            // Si hay múltiples pedidos activos, usar el más reciente
            print(
              '⚠️ Mesa ${mesa.nombre} tiene ${pedidoActivo.length} pedidos activos',
            );

            // Ordenar por fecha y tomar el más reciente
            pedidoActivo.sort((a, b) => b.fecha.compareTo(a.fecha));
            mesa.pedidoActual = pedidoActivo.first;
            requiereActualizacion = true;
          }
        }
      }
      // 2. Si la mesa no está ocupada pero tiene productos o total > 0, limpiarla
      else if (!mesa.ocupada && (mesa.productos.isNotEmpty || mesa.total > 0)) {
        print(
          '⚠️ Mesa ${mesa.nombre} no está ocupada pero tiene productos o total > 0',
        );
        mesa.total = 0;
        mesa.productos = [];
        mesa.pedidoActual = null;
        requiereActualizacion = true;
      }

      // 3. Actualizar la mesa si es necesario
      if (requiereActualizacion) {
        print('🔄 Actualizando mesa ${mesa.nombre}');
        await _mesaService.updateMesa(mesa);
        return true;
      } else {
        print('✅ Mesa ${mesa.nombre} sincronizada (sin cambios)');
        return false;
      }
    } catch (e) {
      print('❌ Error sincronizando mesa ${mesa.nombre}: $e');
      return false;
    }
  }

  /// Sincroniza una mesa con un pedido específico
  Future<bool> sincronizarMesaConPedido(Mesa mesa, Pedido pedido) async {
    try {
      print('🔄 Sincronizando mesa ${mesa.nombre} con pedido ${pedido.id}');
      bool requiereActualizacion = false;

      // Si el pedido está pagado/cancelado pero la mesa está ocupada
      if ((pedido.estado == EstadoPedido.pagado ||
              pedido.estado == EstadoPedido.cancelado) &&
          mesa.ocupada) {
        mesa.ocupada = false;
        mesa.total = 0;
        mesa.productos = [];
        mesa.pedidoActual = null;
        requiereActualizacion = true;
      }
      // Si el pedido está activo pero la mesa no está ocupada
      else if (pedido.estado == EstadoPedido.activo && !mesa.ocupada) {
        mesa.ocupada = true;
        mesa.total = pedido.total;
        mesa.pedidoActual = pedido;
        requiereActualizacion = true;
      }

      if (requiereActualizacion) {
        print('🔄 Actualizando estado de mesa ${mesa.nombre}');
        await _mesaService.updateMesa(mesa);
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Error sincronizando mesa con pedido: $e');
      return false;
    }
  }
}
