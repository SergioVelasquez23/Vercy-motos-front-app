import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import 'productos_screen.dart';
import 'pedidos_screen_fusion.dart';
import 'cuadre_caja_screen.dart';
import 'facturas_compras_screen.dart';
import 'proveedores_screen.dart';
import 'historial_inventario_screen.dart';
import 'configuracion_screen.dart';
import 'negocio_info_screen.dart';
import 'gastos_screen.dart';
import 'ingresos_caja_screen.dart';
import 'tipos_gasto_screen.dart';
import '../services/reportes_service.dart';
import '../services/pedido_service.dart';
import '../models/dashboard_data.dart';
import '../providers/user_provider.dart';
import '../widgets/admin_key_detector.dart';
import '../widgets/vercy_sidebar_layout.dart';
import '../widgets/dashboard/stat_card.dart';
import '../widgets/dashboard/stats_cards_section.dart';
import '../widgets/dashboard/legend_item.dart';
import '../utils/payment_calculator.dart';
import '../utils/snackbar_helper.dart';
import '../utils/dialogs_helper.dart';

class InfoCardItem {
  final String label;
  final String value;
  final Color color;

  InfoCardItem({required this.label, required this.value, required this.color});
}

class DashboardScreenV2 extends StatefulWidget {
  const DashboardScreenV2({super.key});

  @override
  _DashboardScreenV2State createState() => _DashboardScreenV2State();
}

class _DashboardScreenV2State extends State<DashboardScreenV2>
    with WidgetsBindingObserver {
  late StreamSubscription<bool> _pedidoCompletadoSubscription;
  late StreamSubscription<bool> _pedidoPagadoSubscription;
  late Timer _autoRefreshTimer;
  late Timer _dayChangeDetectorTimer;
  int _selectedIndex = 0;
  bool _isLoading = true;

  // Servicios
  final ReportesService _reportesService = ReportesService();
  final PedidoService _pedidoService = PedidoService();

  // Datos del dashboard
  DashboardData? _dashboardData;

  // Almacenamiento temporal de objetivos modificados
  final Map<String, double> _objetivosTemporales = {};

  // Datos dinámicos para gráficos
  List<Map<String, dynamic>> _ventasPorDia = [];
  List<Map<String, dynamic>> _ingresosVsEgresos = [];
  List<Map<String, dynamic>> _topProductos = [];
  List<Map<String, dynamic>> _topClientes = [];

  // Datos adicionales para nuevos componentes
  List<Map<String, dynamic>> _pedidosPorHora = [];
  List<Map<String, dynamic>> _ultimosPedidos = [];
  List<Map<String, dynamic>> _vendedoresDelMes = [];

  // Variables para el estado de precarga
  bool _productosPrecargados = false;
  bool _ingredientesPrecargados = false;

  // Variables para cálculos corregidos de dashboard
  bool _calculosCorregidos = false;
  Map<String, double> _totalesCorregidos = {};

  // Variables para detectar cambio de día
  late DateTime _ultimaFechaCargada;
  bool _diaActualizado = false;

  // Variables para detectar cambio de semana
  late int _ultimaSemanaCalculada;
  bool _semanaActualizada = false;

  /// Construye un indicador visual para mostrar el progreso de la precarga de datos
  Widget _buildPrecargaIndicator() {
    // Notificación eliminada según solicitud del usuario - siempre retornar widget vacío
    return SizedBox.shrink();
  }

  /// Precarga los productos e ingredientes en segundo plano para mejorar
  /// la experiencia del usuario al navegar por la aplicación.
  Future<void> _precargarDatos() async {
    try {
      // Actualizar la UI para marcar como completado
      if (mounted) {
        setState(() {
          _productosPrecargados = true;
          _ingredientesPrecargados = true;
        });
      }
    } catch (error) {
      // Marcar como completado para que desaparezca el indicador
      if (mounted) {
        setState(() {
          _productosPrecargados = true;
          _ingredientesPrecargados = true;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();

    // Inicializar la fecha de la última carga
    _ultimaFechaCargada = DateTime.now();

    // Inicializar el número de semana cargado
    _ultimaSemanaCalculada = _calcularNumeroDeSemana(DateTime.now());

    // Agregar observer para detectar cambios en el ciclo de vida
    WidgetsBinding.instance.addObserver(this);

    // Verificar roles después de que el context esté disponible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // Cargar datos solo si el usuario es admin
      if (userProvider.isAdmin) {
        _cargarDatos();

        // Precargar productos, imágenes e ingredientes
        _precargarDatos();

        // Suscribirse al stream de eventos de pedidos completados
        _pedidoCompletadoSubscription = _pedidoService.onPedidoCompletado
            .listen(
              (_) {},
            ); // Suscribirse al stream de eventos de pedidos pagados
        _pedidoPagadoSubscription = _pedidoService.onPedidoPagado.listen(
          (_) {},
        );

        // Timer de auto-refresco (cada 5 minutos)
        _autoRefreshTimer = Timer.periodic(Duration(minutes: 5), (timer) {
          _cargarDatos();
          if (mounted) {
            setState(() {});
          }
        });

        // Timer para detectar cambios de día y semana (verifica cada minuto)
        _dayChangeDetectorTimer = Timer.periodic(Duration(minutes: 1), (timer) {
          _verificarYActualizarPorCambioDeDia();
          _verificarYActualizarPorCambioDeSemanA();
        });
      } else if (userProvider.isAsesor) {
        // Para asesores, no cargar datos del dashboard, solo marcar como completado
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Resetear el índice cuando regresamos al dashboard
    if (mounted && _selectedIndex != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedIndex = 0;
          });
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // ⛔ DESHABILITADO: No recargar automáticamente cuando la app vuelve al primer plano
    // Esto causaba que el dashboard se refrescara cada vez que el usuario hacía alt+tab
    // El dashboard ya tiene auto-refresh con timer y listeners de eventos

    // if (state == AppLifecycleState.resumed) {
    //   if (mounted &&
    //       Provider.of<UserProvider>(context, listen: false).isAdmin) {
    //     // Force refresh en caso de que los datos se hayan vuelto stale
    //     _cargarDatos(forceRefresh: true);
    //   }
    // }
  }

  @override
  void dispose() {
    // Remover observer
    WidgetsBinding.instance.removeObserver(this);

    _pedidoCompletadoSubscription.cancel();
    _pedidoPagadoSubscription.cancel();
    _autoRefreshTimer.cancel();
    _dayChangeDetectorTimer.cancel();

    super.dispose();
  }

  Future<void> _cargarDatos({bool forceRefresh = false}) async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      // Los datos se cargarán bajo demanda cuando sea necesario

      // Cargar datos en paralelo pero manejar errores individualmente
      final estadisticasFuture = _cargarEstadisticas(forceRefresh: forceRefresh)
          .catchError((e) {
            return null;
          });
      final ingresosFuture = _cargarIngresosVsEgresos().catchError((e) {
        return null;
      });
      final topProductosFuture = _cargarTopProductos().catchError((e) {
        return null;
      });
      final topClientesFuture = _cargarTopClientes().catchError((e) {
        return null;
      });
      final ventasPorDiaFuture = _reportesService
          .getVentasPorDia(7)
          .then((data) {
            setState(() {
              // Transformar los datos del backend al formato esperado por el frontend
              _ventasPorDia = data.map((item) {
                return {
                  'dia': _formatearFecha(item['fecha'] as String? ?? ''),
                  'ventas': (item['total'] as num?)?.toDouble() ?? 0.0,
                };
              }).toList();
            });
          })
          .catchError((e) {
            setState(() {
              _ventasPorDia = [];
            });
          });

      // Cargar pedidos por hora
      final pedidosPorHoraFuture = _cargarPedidosPorHora().catchError((e) {
        return null;
      });

      // Cargar últimos pedidos
      final ultimosPedidosFuture = _cargarUltimosPedidos().catchError((e) {
        return null;
      });

      // Cargar vendedores del mes
      final vendedoresDelMesFuture = _cargarVendedoresDelMes().catchError((e) {
        return null;
      });

      await Future.wait([
        estadisticasFuture,
        ingresosFuture,
        topProductosFuture,
        topClientesFuture,
        ventasPorDiaFuture,
        pedidosPorHoraFuture,
        ultimosPedidosFuture,
        vendedoresDelMesFuture,
      ]);
    } catch (e) {
      // Error handling
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int _calcularNumeroDeSemana(DateTime fecha) {
    final enero4 = DateTime(fecha.year, 1, 4);
    final primerLunes = enero4.subtract(Duration(days: enero4.weekday - 1));
    final diferenciaDias = fecha.difference(primerLunes).inDays;
    return (diferenciaDias / 7).floor() + 1;
  }

  void _verificarYActualizarPorCambioDeSemanA() {
    final ahora = DateTime.now();
    final numeroSemanaActual = _calcularNumeroDeSemana(ahora);

    if (numeroSemanaActual != _ultimaSemanaCalculada && !_semanaActualizada) {
      if (mounted) {
        _ultimaSemanaCalculada = numeroSemanaActual;
        _semanaActualizada = true;
        _cargarDatos(forceRefresh: true);
      }
    } else if (numeroSemanaActual == _ultimaSemanaCalculada) {
      _semanaActualizada = false;
    }
  }

  void _verificarYActualizarPorCambioDeDia() {
    final ahora = DateTime.now();
    final diaHaCambiado =
        ahora.day != _ultimaFechaCargada.day ||
        ahora.month != _ultimaFechaCargada.month ||
        ahora.year != _ultimaFechaCargada.year;

    if (diaHaCambiado && !_diaActualizado) {
      if (mounted) {
        _ultimaFechaCargada = ahora;
        _diaActualizado = true;
        _cargarDatos(forceRefresh: true);
      }
    } else if (!diaHaCambiado) {
      _diaActualizado = false;
    }
  }

  Future<void> _cargarEstadisticas({bool forceRefresh = false}) async {
    try {
      // Obtener datos del dashboard desde el servicio
      final dashboardData = await _reportesService.getDashboard(
        forceRefresh: forceRefresh,
      );

      if (dashboardData != null && mounted) {
        // Limpiar objetivos temporales ya que tenemos datos frescos del backend
        if (_objetivosTemporales.isNotEmpty) {
          setState(() {
            _dashboardData = dashboardData;
            _objetivosTemporales.clear(); // Limpiar objetivos temporales
          });
        } else {
          setState(() {
            _dashboardData = dashboardData;
          });
        }

        // Calcular totales corregidos después de cargar dashboard data
        await _calcularTotalesCorregidos();
      } else if (mounted) {
        // Mantener los datos existentes o usar null
      }
    } catch (e) {
      // No propagamos el error para evitar que falle toda la UI
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cargarIngresosVsEgresos() async {
    try {
      // Obtener ingresos vs egresos de los últimos 12 meses desde el backend
      final ingresosVsEgresos = await _reportesService.getIngresosVsEgresos(12);

      if (mounted) {
        setState(() {
          _ingresosVsEgresos = ingresosVsEgresos;
        });
      }
    } catch (e) {
      // En caso de error, usar datos vacíos para evitar crashes
      if (mounted) {
        setState(() {
          _ingresosVsEgresos = [];
        });
      }

      // Mostrar mensaje de error al usuario
      if (mounted) {
        showWarningSnackBar(context, 'Error cargando datos de ingresos vs egresos');
      }
    }
  }

  Future<void> _cargarTopProductos() async {
    try {
      // Obtener top 5 productos más vendidos del mes actual desde el backend
      final topProductos = await _reportesService.getTopProductos(5);

      // Transformar datos al formato esperado por la UI
      final List<Map<String, dynamic>> productosTransformados = [];
      final List<Color> colores = [
        AppTheme.primary,
        AppTheme.secondary,
        AppTheme.primaryLight,
        AppTheme.warning,
        AppTheme.secondaryDark,
      ];

      for (int i = 0; i < topProductos.length; i++) {
        final producto = topProductos[i];
        final porcentaje = (producto['porcentaje'] ?? 0.0).toDouble();

        productosTransformados.add({
          'nombre': producto['nombre'],
          'porcentaje': porcentaje,
          'color': colores[i % colores.length],
        });
      }

      if (mounted) {
        setState(() {
          _topProductos = productosTransformados;
        });
      }
    } catch (e) {
      // Error handling
    }
  }

  Future<void> _cargarTopClientes() async {
    try {
      // Obtener top 5 clientes que más compran (excluyendo Consumidor Final)
      final topClientes = await _reportesService.getTopClientes(5);

      // Transformar datos al formato esperado por la UI
      final List<Map<String, dynamic>> clientesTransformados = [];
      final List<Color> colores = [
        Colors.teal,
        Colors.cyan,
        Colors.lightBlue,
        Colors.blueAccent,
        Colors.blue,
      ];

      for (int i = 0; i < topClientes.length; i++) {
        final cliente = topClientes[i];
        final porcentaje = (cliente['porcentaje'] ?? 0.0).toDouble();

        clientesTransformados.add({
          'nombre': cliente['nombre'],
          'porcentaje': porcentaje,
          'color': colores[i % colores.length],
        });
      }

      if (mounted) {
        setState(() {
          _topClientes = clientesTransformados;
        });
      }
    } catch (e) {
      // Error handling
      print('❌ Error al cargar top clientes: $e');
    }
  }

  Future<void> _cargarPedidosPorHora() async {
    try {
      // Obtener pedidos por hora desde el backend
      final pedidosPorHora = await _reportesService.getPedidosPorHora();

      // Validar y limpiar los datos
      final pedidosValidados = pedidosPorHora.map((pedido) {
        return {
          'hora': pedido['hora'] ?? '00:00',
          'cantidad': (pedido['cantidad'] as num?)?.toInt() ?? 0,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _pedidosPorHora = pedidosValidados.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pedidosPorHora = [];
        });
      }
    }
  }

  Future<void> _cargarUltimosPedidos() async {
    try {
      // Opción 1: Obtener desde reportes service (si funciona)
      List<Map<String, dynamic>> ultimosPedidos;
      try {
        ultimosPedidos = await _reportesService.getUltimosPedidos(10);
      } catch (e) {
        // Opción 2: Fallback usando PedidoService directamente
        final pedidos = await _pedidoService.getAllPedidos();
        ultimosPedidos = pedidos
            .take(10)
            .map(
              (pedido) => {
                'pedidoId': pedido.id,
                'mesa': pedido.mesa,
                'producto': pedido.items.isNotEmpty
                    ? pedido.items.first.productoNombre ?? 'Producto N/A'
                    : 'Sin productos',
                'fecha': pedido.fecha.toIso8601String(),
                'cantidad': pedido.items.fold(
                  0,
                  (sum, item) => sum + item.cantidad,
                ),
                'estado': pedido.estadoTexto,
                'vendedor': pedido.mesero,
                'precio': pedido.items.isNotEmpty
                    ? pedido.items.first.precioUnitario
                    : 0.0,
                'subtotal': pedido.total,
                'total': pedido.total,
                'tipo': pedido.tipoTexto,
                'notas': pedido.notas ?? '',
              },
            )
            .toList();
      }

      // Validar y limpiar los datos antes de usarlos
      final pedidosValidados = ultimosPedidos.map((pedido) {
        // Calcular valores si no están presentes o son 0
        final cantidad = (pedido['cantidad'] as num?)?.toInt() ?? 1;
        final precioUnitario = (pedido['precio'] as num?)?.toDouble() ?? 0.0;
        final subtotalOriginal =
            (pedido['subtotal'] as num?)?.toDouble() ?? 0.0;
        final totalOriginal = (pedido['total'] as num?)?.toDouble() ?? 0.0;

        // Usar el mayor valor entre subtotal y total, o calcular si ambos son 0
        double subtotalFinal;
        if (subtotalOriginal > 0) {
          subtotalFinal = subtotalOriginal;
        } else if (totalOriginal > 0) {
          subtotalFinal = totalOriginal;
        } else if (precioUnitario > 0) {
          subtotalFinal = precioUnitario * cantidad;
        } else {
          subtotalFinal = 0.0;
        }

        return {
          'pedidoId': pedido['pedidoId'] ?? 'N/A',
          'mesa': pedido['mesa'] ?? 'N/A',
          'producto': pedido['producto'] ?? 'Producto N/A',
          'fecha': pedido['fecha'] ?? DateTime.now().toString(),
          'cantidad': cantidad,
          'estado': pedido['estado'] ?? 'pendiente',
          'vendedor': pedido['vendedor'] ?? pedido['mesero'] ?? 'N/A',
          'precio': precioUnitario,
          'subtotal': subtotalFinal,
          'tipo': pedido['tipo'] ?? 'Normal',
          'notas': pedido['notas'] ?? '',
        };
      }).toList();

      if (mounted) {
        setState(() {
          _ultimosPedidos = pedidosValidados.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _ultimosPedidos = [];
        });
      }
    }
  }

  Future<void> _cargarVendedoresDelMes() async {
    try {
      // Obtener vendedores del mes desde el backend
      final vendedores = await _reportesService.getVendedoresDelMes(30);

      // Validar y limpiar los datos
      final vendedoresValidados = vendedores.map((vendedor) {
        return {
          'nombre': vendedor['nombre'] ?? 'N/A',
          'totalVentas': (vendedor['totalVentas'] as num?)?.toDouble() ?? 0.0,
          'cantidadPedidos':
              (vendedor['cantidadPedidos'] as num?)?.toInt() ?? 0,
          'promedioVenta':
              (vendedor['promedioVenta'] as num?)?.toDouble() ?? 0.0,
          'puesto': (vendedor['puesto'] as num?)?.toInt() ?? 0,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _vendedoresDelMes = vendedoresValidados.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _vendedoresDelMes = [];
        });
      }
    }
  }

  Future<void> _mostrarDialogoEditarObjetivo(
    String periodo,
    String titulo,
  ) async {
    double objetivoActual = _obtenerObjetivoActual(periodo);
    final TextEditingController controller = TextEditingController(
      text: objetivoActual.toStringAsFixed(0),
    );

    final resultado = await showDialog<double>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: Text(
            'Editar Objetivo - $titulo',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ingrese el nuevo objetivo de ventas:',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Objetivo (\$)',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                  prefixText: '\$',
                  prefixStyle: TextStyle(color: AppTheme.textSecondary),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.textSecondary),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.textSecondary),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primary),
                  ),
                ),
              ),
            ],
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
              onPressed: () {
                final String texto = controller.text
                    .replaceAll(',', '')
                    .replaceAll('.', '');
                final double? nuevoObjetivo = double.tryParse(texto);
                if (nuevoObjetivo != null && nuevoObjetivo > 0) {
                  Navigator.of(context).pop(nuevoObjetivo);
                } else {
                  if (mounted) {
                    showErrorSnackBar(context, 'Por favor ingrese un valor válido');
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (resultado != null) {
      await _actualizarObjetivo(periodo, resultado);
    }
  }

  /// Obtiene el total corregido considerando problemas de descuentos/propinas del backend
  /// Si no hay corrección disponible, retorna el valor original del backend
  double _obtenerTotalCorregido(String periodo, double totalBackend) {
    // Si tenemos correcciones calculadas, usar esas
    if (_calculosCorregidos && _totalesCorregidos.containsKey(periodo)) {
      final totalCorregido = _totalesCorregidos[periodo]!;

      // Solo usar corrección si hay diferencia significativa (más de $100)
      if ((totalCorregido - totalBackend).abs() > 100) {
        return totalCorregido;
      }
    }

    return totalBackend;
  }

  /// Calcula los totales corregidos consultando pedidos reales
  Future<void> _calcularTotalesCorregidos() async {
    try {
      // Por ahora, mantener los valores del backend
      // En el futuro implementar lógica completa para obtener pedidos y recalcular
      // TODO: Obtener pedidos de hoy, 7 días, 30 días y año usando PedidoService
      // TODO: Aplicar PaymentCalculator.calcularTotalReal a cada pedido
      // TODO: Sumar totales corregidos por período

      setState(() {
        _totalesCorregidos = {
          'hoy': _dashboardData?.ventasHoy.total ?? 0.0,
          'semana': _dashboardData?.ventas7Dias.total ?? 0.0,
          'mes': _dashboardData?.ventas30Dias.total ?? 0.0,
          'año': _dashboardData?.ventasAnio.total ?? 0.0,
        };
        _calculosCorregidos = true;
      });
    } catch (e) {
      setState(() {
        _calculosCorregidos = false;
        _totalesCorregidos.clear();
      });
    }
  }

  double _obtenerObjetivoActual(String periodo) {
    // Primero verificar si hay un objetivo temporal
    if (_objetivosTemporales.containsKey(periodo)) {
      return _objetivosTemporales[periodo]!;
    }

    // Si no hay objetivo temporal, usar el del dashboard
    if (_dashboardData == null) return 0.0;

    switch (periodo) {
      case 'hoy':
        return _dashboardData!.ventasHoy.objetivo;
      case 'semana':
        return _dashboardData!.ventas7Dias.objetivo;
      case 'mes':
        return _dashboardData!.ventas30Dias.objetivo;
      case 'año':
        return _dashboardData!.ventasAnio.objetivo;
      default:
        return 0.0;
    }
  }

  Future<void> _actualizarObjetivo(String periodo, double nuevoObjetivo) async {
    try {
      // Guardar objetivo temporal para mostrar cambio inmediato
      setState(() {
        _objetivosTemporales[periodo] = nuevoObjetivo;
      });

      // Llamar al backend para actualizar el objetivo
      final exitoso = await ReportesService().actualizarObjetivo(
        periodo,
        nuevoObjetivo,
      );

      if (exitoso) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Objetivo de $periodo actualizado a \$${_formatNumber(nuevoObjetivo)}',
              ),
              backgroundColor: AppTheme.primary,
            ),
          );
        }

        // IMPORTANTE: Recargar datos del dashboard para obtener los objetivos actualizados
        await _cargarDatos();

        // Calcular totales corregidos después de cargar datos
        await _calcularTotalesCorregidos();
      } else {
        // Si falla, remover el objetivo temporal
        setState(() {
          _objetivosTemporales.remove(periodo);
        });
        throw Exception('Error en el servidor al actualizar objetivo');
      }
    } catch (e) {
      // Remover objetivo temporal si hay error
      setState(() {
        _objetivosTemporales.remove(periodo);
      });
      if (mounted) {
        showErrorSnackBar(context, 'Error al actualizar el objetivo: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    // Resetear el índice seleccionado a Dashboard cuando se construye la pantalla
    // Esto asegura que cuando regreses de otra pantalla, el sidebar muestre Dashboard como activo
    if (_selectedIndex != 0 && ModalRoute.of(context)?.isCurrent == true) {
      // Usar addPostFrameCallback para evitar setState durante el build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedIndex = 0;
          });
        }
      });
    }

    // Los vendedores pueden acceder al dashboard para ver su panel de pedidos
    // (Redirección automática comentada para permitir acceso al dashboard)
    /*
    if (userProvider.isOnlyMesero) {
        
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/mesero');
      });
      return Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
              SizedBox(height: 16),
              Text(
                'Redirigiendo al Panel de Mesero...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }
    */

    return AdminKeySequenceDetector(
      child: VercySidebarLayout(
        title: '¡Hola! Bienvenido a Vercy Motos',
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: BoxDecoration(color: Color(0xFFFAFAFA)),
            child: SafeArea(
              child: Column(
                children: [
                  // Indicador de precarga de datos
                  _buildPrecargaIndicator(),
                  Expanded(
                    child:
                        (userProvider.isAdmin ||
                            userProvider.isSuperAdmin ||
                            userProvider.isAsesor)
                        ? (_isLoading
                              ? Center(
                                  child: Container(
                                    padding: EdgeInsets.all(40),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.primary.withOpacity(
                                            0.1,
                                          ),
                                          blurRadius: 30,
                                          spreadRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppTheme.primary,
                                      ),
                                      strokeWidth: 3,
                                    ),
                                  ),
                                )
                              : RefreshIndicator(
                                  onRefresh: _cargarDatos,
                                  color: AppTheme.primary,
                                  child: SingleChildScrollView(
                                    physics: AlwaysScrollableScrollPhysics(),
                                    padding: EdgeInsets.all(
                                      context.responsivePadding,
                                    ),
                                    child: Column(
                                      children: [
                                        // Solo mostrar datos de admin si es admin
                                        if (userProvider.isAdmin ||
                                            userProvider.isSuperAdmin) ...[
                                          // Cards de estadísticas principales
                                          _dashboardData == null
                                              ? SizedBox(
                                                  height: 200,
                                                  child: Center(
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        CircularProgressIndicator(
                                                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                                                        ),
                                                        SizedBox(height: AppTheme.spacingMedium),
                                                        Text(
                                                          'Cargando estadísticas del dashboard...',
                                                          style: AppTheme.bodyMedium.copyWith(
                                                            color: AppTheme.textSecondary,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                )
                                              : StatsCardsSection(
                                                  cards: [
                                                    StatCardData(
                                                      title: 'Facturado Hoy',
                                                      value: '\$${_formatNumber(_obtenerTotalCorregido('hoy', _dashboardData!.ventasHoy.total))}',
                                                      objective: 'Objetivo: \$${_formatNumber(_obtenerObjetivoActual('hoy'))}',
                                                      percentage: (_obtenerTotalCorregido('hoy', _dashboardData!.ventasHoy.total) / _obtenerObjetivoActual('hoy') * 100).round(),
                                                      color: AppTheme.primary,
                                                      periodo: 'hoy',
                                                    ),
                                                    StatCardData(
                                                      title: 'Últimos 7 días',
                                                      value: '\$${_formatNumber(_obtenerTotalCorregido('semana', _dashboardData!.ventas7Dias.total))}',
                                                      objective: 'Objetivo: \$${_formatNumber(_obtenerObjetivoActual('semana'))}',
                                                      percentage: (_obtenerTotalCorregido('semana', _dashboardData!.ventas7Dias.total) / _obtenerObjetivoActual('semana') * 100).round(),
                                                      color: AppTheme.secondary,
                                                      periodo: 'semana',
                                                    ),
                                                    StatCardData(
                                                      title: 'Últimos 30 días',
                                                      value: '\$${_formatNumber(_obtenerTotalCorregido('mes', _dashboardData!.ventas30Dias.total))}',
                                                      objective: 'Objetivo: \$${_formatNumber(_obtenerObjetivoActual('mes'))}',
                                                      percentage: (_obtenerTotalCorregido('mes', _dashboardData!.ventas30Dias.total) / _obtenerObjetivoActual('mes') * 100).round(),
                                                      color: AppTheme.secondary,
                                                      periodo: 'mes',
                                                    ),
                                                    StatCardData(
                                                      title: 'Año actual',
                                                      value: '\$${_formatNumber(_obtenerTotalCorregido('año', _dashboardData!.ventasAnio.total))}',
                                                      objective: 'Objetivo: \$${_formatNumber(_obtenerObjetivoActual('año'))}',
                                                      percentage: (_obtenerTotalCorregido('año', _dashboardData!.ventasAnio.total) / _obtenerObjetivoActual('año') * 100).round(),
                                                      color: AppTheme.info,
                                                      periodo: 'año',
                                                    ),
                                                  ],
                                                  onEditObjective: _mostrarDialogoEditarObjetivo,
                                                ),
                                          SizedBox(
                                            height: AppTheme.spacingXLarge,
                                          ),

                                          // Gráfico de ventas por día
                                          _buildVentasPorDiaChart(context),
                                          SizedBox(
                                            height: AppTheme.spacingXLarge,
                                          ),

                                          // Gráficos en fila o columna según el dispositivo
                                          context.isMobile
                                              ? Column(
                                                  children: [
                                                    _buildIngresosVsEgresosChart(
                                                      context,
                                                    ),
                                                    SizedBox(
                                                      height:
                                                          AppTheme.spacingLarge,
                                                    ),
                                                    _buildTopProductosChart(
                                                      context,
                                                    ),
                                                  ],
                                                )
                                              : Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child:
                                                          _buildIngresosVsEgresosChart(
                                                            context,
                                                          ),
                                                    ),
                                                    SizedBox(
                                                      width: AppTheme
                                                          .spacingXLarge,
                                                    ),
                                                    Expanded(
                                                      child:
                                                          _buildTopProductosChart(
                                                            context,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                          SizedBox(
                                            height: AppTheme.spacingXLarge,
                                          ),

                                          // Gráficos de clientes en fila o columna según el dispositivo
                                          context.isMobile
                                              ? Column(
                                                  children: [
                                                    _buildTopClientesChart(
                                                      context,
                                                    ),
                                                  ],
                                                )
                                              : Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child:
                                                          _buildTopClientesChart(
                                                            context,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                          SizedBox(
                                            height: AppTheme.spacingXLarge,
                                          ),

                                          // Últimos pedidos y vendedores responsivos
                                          context.isMobile
                                              ? Column(
                                                  children: [
                                                    _buildUltimosPedidos(
                                                      context,
                                                    ),
                                                    SizedBox(
                                                      height:
                                                          AppTheme.spacingLarge,
                                                    ),
                                                    _buildVendedoresDelMes(
                                                      context,
                                                    ),
                                                  ],
                                                )
                                              : Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      flex: 3,
                                                      child:
                                                          _buildUltimosPedidos(
                                                            context,
                                                          ),
                                                    ),
                                                    SizedBox(
                                                      width: AppTheme
                                                          .spacingXLarge,
                                                    ),
                                                    Expanded(
                                                      flex: 2,
                                                      child:
                                                          _buildVendedoresDelMes(
                                                            context,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                          SizedBox(
                                            height: AppTheme.spacingXLarge,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ))
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.security,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Acceso Restringido',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'No tienes permisos para acceder al dashboard.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pushReplacementNamed(
                                      context,
                                      '/mesero',
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 16,
                                    ),
                                  ),
                                  child: Text(
                                    'Ir al Panel de Mesero',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ), // Cierra Scaffold
          ), // Cierra VercySidebarLayout
        ), // Cierra AdminKeySequenceDetector
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.all(16.0),
      color: AppTheme.primary,
      child: Row(
        children: [
          Icon(Icons.restaurant_menu, color: Colors.white, size: 24),
          SizedBox(width: 12),
          Text(
            'Dashboard',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Spacer(),
          // Indicador de estado de conexión
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: !_isLoading
                  ? AppTheme.primary.withOpacity(0.2)
                  : Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: !_isLoading ? AppTheme.primary : Colors.orange,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: !_isLoading ? AppTheme.primary : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  // Mostrar "En vivo" si no está cargando (indica conectividad API)
                  !_isLoading ? 'En vivo' : 'Conectando...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Consumer<UserProvider>(
            builder: (context, userProvider, child) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  userProvider.userName ?? 'Usuario',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              );
            },
          ),
          SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _cargarDatos,
            tooltip: 'Actualizar datos',
          ),
        ],
      ),
    );
  }

  Widget _buildNavBar() {
    final userProvider = Provider.of<UserProvider>(context);

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Scrollbar(
        scrollbarOrientation: ScrollbarOrientation.bottom,
        thumbVisibility: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: _buildNavItems(userProvider)),
        ),
      ),
    );
  }

  List<Widget> _buildNavItems(UserProvider userProvider) {
    List<Widget> navItems = [];

    // 1. Dashboard - Solo para ADMIN y SUPERADMIN
    if (userProvider.isAdmin) {
      navItems.add(_buildNavItem(Icons.dashboard, 'Dashboard', 0, () {}));
    }

    // 2. Pedidos - Disponible para todos los roles
    navItems.add(
      _buildNavItem(Icons.shopping_cart, 'Pedidos', 1, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PedidosScreenFusion()),
        );
      }),
    );

    // Los siguientes módulos solo para ADMIN y SUPERADMIN
    if (userProvider.isAdmin) {
      // 3. Productos
      navItems.add(
        _buildNavItem(Icons.inventory_2, 'Productos', 2, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ProductosScreen()),
          );
        }),
      );

      // 4. Inventario (dropdown)
      navItems.add(
        _buildDropdownNavItem(Icons.inventory_2_outlined, 'Inventario', 3, [
          PopupMenuItem<String>(
            value: 'historial',
            onTap: () {
              Future.delayed(Duration.zero, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HistorialInventarioScreen(),
                  ),
                );
              });
            },
            child: Row(
              children: [
                Icon(Icons.history, color: Colors.blue, size: 18),
                SizedBox(width: 8),
                Text(
                  'Historial',
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'proveedores',
            onTap: () {
              Future.delayed(Duration.zero, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProveedoresScreen()),
                );
              });
            },
            child: Row(
              children: [
                Icon(Icons.local_shipping, color: Colors.purple, size: 18),
                SizedBox(width: 8),
                Text(
                  'Proveedores',
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
              ],
            ),
          ),
        ], tooltip: "Menú de Inventario"),
      );

      // 5. Facturas Compras
      navItems.add(
        _buildNavItem(Icons.receipt_long, 'Facturas Compras', 4, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => FacturasComprasScreen()),
          );
        }),
      );

      // 6. Gestión de Gastos (dropdown)
      navItems.add(
        _buildDropdownNavItem(
          Icons.account_balance_wallet,
          'Gastos',
          5,
          [
            PopupMenuItem<String>(
              value: 'ingresos_caja',
              onTap: () {
                Future.delayed(Duration.zero, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => IngresosCajaScreen(),
                    ),
                  );
                });
              },
              child: Row(
                children: [
                  Icon(Icons.receipt_long, color: Colors.blue, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Ingresos de Caja',
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'tipos_gastos',
              onTap: () {
                Future.delayed(Duration.zero, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TiposGastoScreen()),
                  );
                });
              },
              child: Row(
                children: [
                  Icon(Icons.trending_up, color: Colors.orange, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Tipos de Gastos',
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'gestion_gastos',
              onTap: () {
                Future.delayed(Duration.zero, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => GastosScreen()),
                  );
                });
              },
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    color: AppTheme.secondary,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Gestión de Gastos',
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                ],
              ),
            ),
          ],
          tooltip: "Gestión de Gastos",
          onCanceled: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CuadreCajaScreen()),
            );
          },
        ),
      );

      // 7. Caja
      navItems.add(
        _buildNavItem(Icons.account_balance, 'Caja', 6, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CuadreCajaScreen()),
          );
        }),
      );

      // 9. Configuración
      navItems.add(
        _buildNavItem(Icons.settings, 'Configuración', 8, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ConfiguracionScreen()),
          );
        }),
      );
    }

    // 8. Información del Negocio - Disponible para todos
    navItems.add(
      _buildNavItem(Icons.business, 'Mi Negocio', 7, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const NegocioInfoScreen()),
        );
      }),
    );

    return navItems;
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    int index,
    VoidCallback onTap,
  ) {
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
        onTap();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.grey.withOpacity(0.2),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
              size: 20,
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownNavItem(
    IconData icon,
    String label,
    int index,
    List<PopupMenuItem<String>> items, {
    String? tooltip,
    VoidCallback? onCanceled,
  }) {
    bool isSelected = _selectedIndex == index;
    return PopupMenuButton<String>(
      onSelected: (String value) {
        setState(() {
          _selectedIndex = index;
        });
        // Each menu item handles its own navigation in onTap
      },
      offset: Offset(0, 50),
      itemBuilder: (BuildContext context) => items,
      tooltip: tooltip ?? "Menú de opciones",
      position: PopupMenuPosition.under,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onCanceled: onCanceled,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                  size: 20,
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down,
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                  size: 14,
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards(BuildContext context) {
    if (_dashboardData == null) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
              SizedBox(height: AppTheme.spacingMedium),
              Text(
                'Cargando estadísticas del dashboard...',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Responsivo: En móvil, usar columnas; en escritorio, usar filas
    if (context.isMobile) {
      return Column(
        children: [
          _buildStatCard(
            context,
            title: 'Facturado Hoy',
            value:
                '\$${_formatNumber(_obtenerTotalCorregido('hoy', _dashboardData!.ventasHoy.total))}',
            objective:
                'Objetivo: \$${_formatNumber(_obtenerObjetivoActual('hoy'))}',
            percentage:
                (_obtenerTotalCorregido(
                          'hoy',
                          _dashboardData!.ventasHoy.total,
                        ) /
                        _obtenerObjetivoActual('hoy') *
                        100)
                    .round(),
            color: AppTheme.primary,
            periodo: 'hoy',
          ),
          SizedBox(height: AppTheme.spacingMedium),
          _buildStatCard(
            context,
            title: 'Últimos 7 días',
            value:
                '\$${_formatNumber(_obtenerTotalCorregido('semana', _dashboardData!.ventas7Dias.total))}',
            objective:
                'Objetivo: \$${_formatNumber(_obtenerObjetivoActual('semana'))}',
            percentage:
                (_obtenerTotalCorregido(
                          'semana',
                          _dashboardData!.ventas7Dias.total,
                        ) /
                        _obtenerObjetivoActual('semana') *
                        100)
                    .round(),
            color: AppTheme.secondary,
            periodo: 'semana',
          ),
          SizedBox(height: AppTheme.spacingMedium),
          _buildStatCard(
            context,
            title: 'Últimos 30 días',
            value:
                '\$${_formatNumber(_obtenerTotalCorregido('mes', _dashboardData!.ventas30Dias.total))}',
            objective:
                'Objetivo: \$${_formatNumber(_obtenerObjetivoActual('mes'))}',
            percentage:
                (_obtenerTotalCorregido(
                          'mes',
                          _dashboardData!.ventas30Dias.total,
                        ) /
                        _obtenerObjetivoActual('mes') *
                        100)
                    .round(),
            color: AppTheme.secondary,
            periodo: 'mes',
          ),
          SizedBox(height: AppTheme.spacingMedium),
          _buildStatCard(
            context,
            title: 'Año actual',
            value:
                '\$${_formatNumber(_obtenerTotalCorregido('año', _dashboardData!.ventasAnio.total))}',
            objective:
                'Objetivo: \$${_formatNumber(_obtenerObjetivoActual('año'))}',
            percentage:
                (_obtenerTotalCorregido(
                          'año',
                          _dashboardData!.ventasAnio.total,
                        ) /
                        _obtenerObjetivoActual('año') *
                        100)
                    .round(),
            color: AppTheme.info,
            periodo: 'año',
          ),
        ],
      );
    }

    // Versión tablet/escritorio
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                title: 'Facturado Hoy',
                value:
                    '\$${_formatNumber(_obtenerTotalCorregido('hoy', _dashboardData!.ventasHoy.total))}',
                objective:
                    'Objetivo: \$${_formatNumber(_obtenerObjetivoActual('hoy'))}',
                percentage:
                    (_obtenerTotalCorregido(
                              'hoy',
                              _dashboardData!.ventasHoy.total,
                            ) /
                            _obtenerObjetivoActual('hoy') *
                            100)
                        .round(),
                color: AppTheme.primary,
                periodo: 'hoy',
              ),
            ),
            SizedBox(
              width: context.isTablet
                  ? AppTheme.spacingMedium
                  : AppTheme.spacingLarge,
            ),
            Expanded(
              child: _buildStatCard(
                context,
                title: 'Últimos 7 días',
                value:
                    '\$${_formatNumber(_obtenerTotalCorregido('semana', _dashboardData!.ventas7Dias.total))}',
                objective:
                    'Objetivo: \$${_formatNumber(_obtenerObjetivoActual('semana'))}',
                percentage:
                    (_obtenerTotalCorregido(
                              'semana',
                              _dashboardData!.ventas7Dias.total,
                            ) /
                            _obtenerObjetivoActual('semana') *
                            100)
                        .round(),
                color: AppTheme.secondary,
                periodo: 'semana',
              ),
            ),
          ],
        ),
        SizedBox(height: AppTheme.spacingLarge),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                title: 'Últimos 30 días',
                value:
                    '\$${_formatNumber(_obtenerTotalCorregido('mes', _dashboardData!.ventas30Dias.total))}',
                objective:
                    'Objetivo: \$${_formatNumber(_obtenerObjetivoActual('mes'))}',
                percentage:
                    (_obtenerTotalCorregido(
                              'mes',
                              _dashboardData!.ventas30Dias.total,
                            ) /
                            _obtenerObjetivoActual('mes') *
                            100)
                        .round(),
                color: AppTheme.secondary,
                periodo: 'mes',
              ),
            ),
            SizedBox(
              width: context.isTablet
                  ? AppTheme.spacingMedium
                  : AppTheme.spacingLarge,
            ),
            Expanded(
              child: _buildStatCard(
                context,
                title: 'Año actual',
                value:
                    '\$${_formatNumber(_obtenerTotalCorregido('año', _dashboardData!.ventasAnio.total))}',
                objective:
                    'Objetivo: \$${_formatNumber(_obtenerObjetivoActual('año'))}',
                percentage:
                    (_obtenerTotalCorregido(
                              'año',
                              _dashboardData!.ventasAnio.total,
                            ) /
                            _obtenerObjetivoActual('año') *
                            100)
                        .round(),
                color: AppTheme.info,
                periodo: 'año',
              ),
            ),
          ],
        ),
      ],
    );
  }

  // El método _buildInfoCards ha sido eliminado ya que no se utiliza

  Widget _buildIngresosVsEgresosChart(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(
        context.isMobile ? AppTheme.spacingMedium : AppTheme.spacingLarge,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: AppTheme.primaryLight.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.primaryLight.withOpacity(0.15),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryLight.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'INGRESOS VS EGRESOS',
                  style: TextStyle(
                    color: AppTheme.primaryLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: _ingresosVsEgresos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppTheme.primary),
                        SizedBox(height: 8),
                        Text(
                          'Cargando datos...',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _getMaxIngreso() * 1.2,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          tooltipBgColor: Colors.grey[800],
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final isIngresos = rodIndex == 0;
                            final valor = rod.toY;
                            return BarTooltipItem(
                              '${isIngresos ? "Ingresos" : "Egresos"}\n\$${_formatCurrency(valor)}',
                              TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
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
                              if (value.toInt() >= 0 &&
                                  value.toInt() < _ingresosVsEgresos.length) {
                                return Text(
                                  _ingresosVsEgresos[value.toInt()]['mes'],
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 10,
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
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${(value / 1000).toInt()}K',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 8,
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey.withOpacity(0.3),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: _ingresosVsEgresos.asMap().entries.map((
                        entry,
                      ) {
                        return BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: (entry.value['ingresos'] ?? 0).toDouble(),
                              color: AppTheme.primaryLight,
                              width: 12,
                            ),
                            BarChartRodData(
                              toY: (entry.value['egresos'] ?? 0).toDouble(),
                              color: AppTheme.error,
                              width: 12,
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LegendItem(color: AppTheme.primaryLight, label: 'Ingresos'),
              SizedBox(width: 24),
              LegendItem(color: AppTheme.error, label: 'Egresos'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductosChart(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(
        context.isMobile ? AppTheme.spacingMedium : AppTheme.spacingLarge,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: AppTheme.secondary.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.secondary.withOpacity(0.15),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.secondary.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(Icons.star, color: Colors.white, size: 14),
                ),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOP 5',
                      style: TextStyle(
                        color: AppTheme.secondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'PRODUCTOS MES ACTUAL',
                      style: TextStyle(
                        color: AppTheme.secondary.withOpacity(0.7),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: _topProductos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppTheme.primary),
                        SizedBox(height: 8),
                        Text(
                          'Cargando productos...',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : PieChart(
                    PieChartData(
                      sections: _topProductos.map((producto) {
                        return PieChartSectionData(
                          value: (producto['porcentaje'] ?? 0).toDouble(),
                          color: producto['color'] ?? Colors.grey,
                          title: '${(producto['porcentaje'] ?? 0).toInt()}%',
                          radius: 50,
                          titleStyle: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 25,
                    ),
                  ),
          ),
          SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: _topProductos.isEmpty
                ? Center(
                    child: Text(
                      'No hay datos de productos',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  )
                : ListView(
                    children: _topProductos.map((producto) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: producto['color'] ?? Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                producto['nombre'] ?? 'Producto',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 10,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${(producto['porcentaje'] ?? 0).toInt()}%',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopClientesChart(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(
        context.isMobile ? AppTheme.spacingMedium : AppTheme.spacingXLarge,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.metal.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMedium,
              vertical: AppTheme.spacingSmall,
            ),
            decoration: BoxDecoration(
              color: AppTheme.metal.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                color: AppTheme.metal.withOpacity(0.15),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.metal.withOpacity(0.15),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.metal.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Icon(Icons.people, color: AppTheme.metal, size: 20),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CLIENTES QUE MÁS COMPRAN',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'MES ACTUAL (SIN CONSUMIDOR FINAL)',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: _topClientes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppTheme.primary),
                        SizedBox(height: 8),
                        Text(
                          'Cargando clientes...',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : PieChart(
                    PieChartData(
                      sections: _topClientes.map((cliente) {
                        return PieChartSectionData(
                          value: (cliente['porcentaje'] ?? 0).toDouble(),
                          color: cliente['color'] ?? Colors.grey,
                          title: '${(cliente['porcentaje'] ?? 0).toInt()}%',
                          radius: 50,
                          titleStyle: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 25,
                    ),
                  ),
          ),
          SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: _topClientes.isEmpty
                ? Center(
                    child: Text(
                      'No hay datos de clientes',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  )
                : ListView(
                    children: _topClientes.map((cliente) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: cliente['color'] ?? Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                cliente['nombre'] ?? 'Cliente',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPedidosPorHoraChart(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(
        context.isMobile ? AppTheme.spacingMedium : AppTheme.spacingXLarge,
      ),
      decoration: AppTheme.elevatedCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.access_time,
                color: AppTheme.warning,
                size: 16,
              ), // Ícono más grande
              SizedBox(width: 12),
              Text(
                'PEDIDOS POR HORA',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16, // Título más grande
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: 24), // Más espacio
          SizedBox(
            height: 280, // Gráfico más alto
            child: _pedidosPorHora.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppTheme.primary),
                        SizedBox(height: 8),
                        Text(
                          'Cargando pedidos...',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey.withOpacity(0.3),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= 0 &&
                                  value.toInt() < _pedidosPorHora.length) {
                                // Mostrar solo algunas horas para evitar solapamiento
                                if (value.toInt() % 3 == 0) {
                                  return Text(
                                    _pedidosPorHora[value.toInt()]['hora'] ??
                                        '',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 10,
                                    ),
                                  );
                                }
                              }
                              return Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()}',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 8,
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _pedidosPorHora.asMap().entries.map((entry) {
                            return FlSpot(
                              entry.key.toDouble(),
                              (entry.value['cantidad'] as num?)?.toDouble() ??
                                  0.0,
                            );
                          }).toList(),
                          isCurved: true,
                          color: AppTheme.warning,
                          barWidth: 3,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppTheme.warning.withOpacity(0.2),
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

  Widget _buildVentasPorDiaChart(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(
        context.isMobile ? AppTheme.spacingMedium : AppTheme.spacingXLarge,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.primary.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.primary.withOpacity(0.15),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(Icons.trending_up, color: Colors.white, size: 16),
                ),
                SizedBox(width: 10),
                Text(
                  'VENTAS ÚLTIMOS 7 DÍAS',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          SizedBox(
            height: 280,
            child: _ventasPorDia.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppTheme.primary),
                        SizedBox(height: 8),
                        Text(
                          'Cargando ventas...',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _getMaxVentasDia(),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey.withOpacity(0.3),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < _ventasPorDia.length) {
                                final dia = _ventasPorDia[index]['dia'] ?? '';
                                final ventas =
                                    ((_ventasPorDia[index]['ventas'] as num?)
                                        ?.toDouble() ??
                                    0.0);
                                return Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        dia,
                                        style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '\$${_formatCurrency(ventas)}',
                                        style: TextStyle(
                                          color: AppTheme.primary,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
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
                            reservedSize: 60,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '\$${_formatCurrency(value)}',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 8,
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: _ventasPorDia.asMap().entries.map((entry) {
                        final index = entry.key;
                        final data = entry.value;
                        final ventas =
                            (data['ventas'] as num?)?.toDouble() ?? 0.0;

                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: ventas,
                              color: AppTheme.primaryLight,
                              width: 20,
                              borderRadius: BorderRadius.circular(4),
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

  Widget _buildUltimosPedidos(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(
        context.isMobile ? AppTheme.spacingMedium : AppTheme.spacingXLarge,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.primary.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMedium,
              vertical: AppTheme.spacingSmall,
            ),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                color: AppTheme.primary.withOpacity(0.15),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Icon(Icons.receipt, color: AppTheme.primary, size: 16),
                ),
                SizedBox(width: 12),
                Text(
                  'ÚLTIMOS PEDIDOS',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          SizedBox(
            height: 320, // Lista más alta
            child: _ultimosPedidos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppTheme.primary),
                        SizedBox(height: 12),
                        Text(
                          'Cargando pedidos...',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _ultimosPedidos.length,
                    itemBuilder: (context, index) {
                      final pedido = _ultimosPedidos[index];
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: 12,
                        ), // Más espacio entre elementos
                        child: Container(
                          padding: EdgeInsets.all(16), // Más padding interno
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundDark,
                            borderRadius: BorderRadius.circular(
                              12,
                            ), // Bordes más redondeados
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.2),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Pedido #${pedido['pedidoId']?.toString().substring(0, 8) ?? 'N/A'}',
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 14, // Texto más grande
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    pedido['estado'] ?? 'N/A',
                                    style: TextStyle(
                                      color: _getEstadoColor(pedido['estado']),
                                      fontSize: 12, // Texto más grande
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8), // Más espacio
                              Text(
                                pedido['producto'] ?? 'Producto N/A',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13, // Texto más grande
                                ),
                                maxLines: 2, // Más líneas para producto
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 8), // Más espacio
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _extraerHoraDeFecha(pedido['fecha']),
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12, // Texto más grande
                                    ),
                                  ),
                                  Text(
                                    '\$${_formatCurrency(pedido['subtotal'] ?? 0)}',
                                    style: TextStyle(
                                      color: AppTheme.warning,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendedoresDelMes(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(
        context.isMobile ? AppTheme.spacingMedium : AppTheme.spacingXLarge,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: AppTheme.secondary.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMedium,
              vertical: AppTheme.spacingSmall,
            ),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                color: AppTheme.secondary.withOpacity(0.15),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withOpacity(0.15),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.secondary.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.star,
                    color: AppTheme.secondary,
                    size: context.isMobile ? 16 : 18,
                  ),
                ),
                SizedBox(width: AppTheme.spacingMedium),
                Text(
                  'TOP VENDEDORES',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppTheme.spacingLarge),
          SizedBox(
            height: context.isMobile ? 280 : 320,
            child: _vendedoresDelMes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppTheme.primary),
                        SizedBox(height: AppTheme.spacingMedium),
                        Text(
                          'Cargando vendedores...',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _vendedoresDelMes.length,
                    itemBuilder: (context, index) {
                      final vendedor = _vendedoresDelMes[index];
                      final puesto = index + 1;
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: AppTheme.spacingMedium,
                        ),
                        child: Container(
                          padding: EdgeInsets.all(
                            context.isMobile
                                ? AppTheme.spacingMedium
                                : AppTheme.spacingLarge,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMedium,
                            ),
                            border: Border.all(
                              color: puesto <= 3
                                  ? AppTheme.secondary
                                  : AppTheme.textMuted.withOpacity(0.3),
                              width: puesto <= 3 ? 2 : 1,
                            ),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: context.isMobile ? 26 : 28,
                                    height: context.isMobile ? 26 : 28,
                                    decoration: BoxDecoration(
                                      color: _getPuestoColor(puesto),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$puesto',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: AppTheme.spacingMedium),
                                  Expanded(
                                    child: Text(
                                      vendedor['nombre'] ?? 'N/A',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            color: AppTheme.textPrimary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: AppTheme.spacingSmall),
                              Text(
                                '\$${_formatCurrency(vendedor['totalVentas'] ?? 0)}',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: AppTheme.secondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              SizedBox(height: AppTheme.spacingXSmall),
                              Text(
                                '${vendedor['cantidadPedidos'] ?? 0} pedidos',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Color _getEstadoColor(String? estado) {
    switch (estado?.toLowerCase()) {
      case 'pagada':
        return AppTheme.primary;
      case 'pendiente':
        return Colors.orange;
      case 'cancelado':
        return Colors.red;
      default:
        return AppTheme.textSecondary;
    }
  }

  Color _getPuestoColor(int puesto) {
    switch (puesto) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey[400]!;
      case 3:
        return Colors.orange[700]!;
      default:
        return Colors.blue;
    }
  }

  String _extraerHoraDeFecha(dynamic fecha) {
    if (fecha == null) return 'N/A';

    try {
      String fechaStr = fecha.toString();

      // Si la fecha tiene formato completo (yyyy-MM-dd HH:mm:ss), extraer la hora
      if (fechaStr.length >= 16) {
        return fechaStr.substring(11, 16); // HH:mm
      }

      // Si es solo hora (HH:mm:ss), tomar solo HH:mm
      if (fechaStr.contains(':') && fechaStr.length >= 5) {
        List<String> partes = fechaStr.split(':');
        if (partes.length >= 2) {
          return '${partes[0]}:${partes[1]}';
        }
      }

      return fechaStr.length > 5 ? fechaStr.substring(0, 5) : fechaStr;
    } catch (e) {
      return 'N/A';
    }
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required String objective,
    required int percentage,
    required Color color,
    String? periodo,
  }) {
    return Container(
      padding: EdgeInsets.all(
        context.isMobile ? AppTheme.spacingMedium : AppTheme.spacingLarge,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Botón para editar objetivo
                  if (periodo != null)
                    GestureDetector(
                      onTap: () =>
                          _mostrarDialogoEditarObjetivo(periodo, title),
                      child: Container(
                        padding: EdgeInsets.all(AppTheme.spacingXSmall),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSmall,
                          ),
                          border: Border.all(
                            color: color.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(Icons.edit, size: 14, color: color),
                      ),
                    ),
                  if (periodo != null) SizedBox(width: AppTheme.spacingSmall),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      '$percentage%',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: context.isMobile ? 28 : 32,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: AppTheme.spacingXSmall),
          Text(
            objective,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.textSecondary.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
          SizedBox(height: AppTheme.spacingMedium),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: color.withOpacity(0.15),
                        border: Border.all(
                          color: color.withOpacity(0.2),
                          width: 0.5,
                        ),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (percentage / 100).clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: color,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppTheme.spacingMedium),
              Container(
                width: context.isMobile ? 60 : 70,
                height: context.isMobile ? 60 : 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [color.withOpacity(0.1), Colors.transparent],
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: context.isMobile ? 60 : 70,
                      height: context.isMobile ? 60 : 70,
                      child: CircularProgressIndicator(
                        value: percentage / 100,
                        strokeWidth: context.isMobile ? 5 : 6,
                        backgroundColor: Colors.grey.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Icon(
                      Icons.trending_up,
                      color: color,
                      size: context.isMobile ? 20 : 24,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSales(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(
        context.isMobile ? AppTheme.spacingMedium : AppTheme.spacingLarge,
      ),
      decoration: AppTheme.elevatedCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, color: AppTheme.primary, size: 12),
              SizedBox(width: AppTheme.spacingSmall),
              Text(
                'FACTURADO ÚLTIMOS 7 DÍAS',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingMedium),
          SizedBox(
            height: context.isMobile ? 120 : 150,
            child: _ventasPorDia.isEmpty
                ? Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _getMaxVentasDia() * 1.2,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          tooltipBgColor: Colors.grey[800],
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final diaRaw =
                                _ventasPorDia[group.x.toInt()]['dia'];
                            final dia = (diaRaw is String)
                                ? diaRaw
                                : (diaRaw == null ? '' : diaRaw.toString());
                            // Usar directamente el valor en el BarTooltipItem
                            var ventas =
                                _ventasPorDia[group.x.toInt()]['ventas'];
                            if (ventas != null) {
                              // Forzar uso de la variable
                              ventas = ventas;
                            }
                            return BarTooltipItem(
                              '$dia\n\${_formatCurrency(ventas ?? 0)}',
                              TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= 0 &&
                                  value.toInt() < _ventasPorDia.length) {
                                final diaRaw =
                                    _ventasPorDia[value.toInt()]['dia'];
                                final dia = (diaRaw is String)
                                    ? diaRaw
                                    : (diaRaw == null ? '' : diaRaw.toString());
                                return Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text(
                                    dia,
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
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
                            reservedSize: 60,
                            interval: _getMaxVentasDia() > 0
                                ? _getMaxVentasDia() / 3
                                : 100000,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '\$${_formatCurrency(value)}',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey.withOpacity(0.2),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.withOpacity(0.2),
                            width: 1,
                          ),
                          left: BorderSide(
                            color: Colors.grey.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                      ),
                      barGroups: _ventasPorDia.asMap().entries.map((entry) {
                        final ventasRaw = entry.value['ventas'];
                        final ventas = (ventasRaw is num)
                            ? ventasRaw.toDouble()
                            : (ventasRaw == null
                                  ? 0.0
                                  : double.tryParse(ventasRaw.toString()) ??
                                        0.0);
                        return BarChartGroupData(
                          x: entry.key,
                          barRods: [
                            BarChartRodData(
                              toY: ventas,
                              color: AppTheme.primary,
                              width: 25,
                              borderRadius: BorderRadius.circular(4),
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

  String _formatNumber(double number) {
    return number.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  String _formatCurrency(double amount) {
    // Para pesos colombianos, es mejor mostrar los números completos con separadores
    if (amount >= 1000000000) {
      // Mil millones o más: 1.234.567.890
      return _formatFullNumber(amount);
    } else if (amount >= 100000000) {
      // Cien millones o más: 123.456.789
      return _formatFullNumber(amount);
    } else if (amount >= 1000000) {
      // Un millón o más: 12.345.678
      return _formatFullNumber(amount);
    } else if (amount >= 100000) {
      // Cien mil o más: 123.456
      return _formatFullNumber(amount);
    } else if (amount >= 1000) {
      // Mil o más: 12.345
      return _formatFullNumber(amount);
    } else {
      // Menos de mil: 999
      return amount.toStringAsFixed(0);
    }
  }

  String _formatFullNumber(double amount) {
    // Convertir a entero para evitar decimales innecesarios
    int intAmount = amount.round();
    String numStr = intAmount.toString();

    // Agregar puntos como separadores de miles
    String result = '';
    int counter = 0;

    for (int i = numStr.length - 1; i >= 0; i--) {
      if (counter > 0 && counter % 3 == 0) {
        result = '.' + result;
      }
      result = numStr[i] + result;
      counter++;
    }

    return result;
  }

  double _getMaxVentasDia() {
    if (_ventasPorDia.isEmpty) return 1000000;
    double max = 0;
    for (var venta in _ventasPorDia) {
      final ventasRaw = venta['ventas'];
      final ventas = (ventasRaw is num)
          ? ventasRaw.toDouble()
          : (ventasRaw == null
                ? 0.0
                : double.tryParse(ventasRaw.toString()) ?? 0.0);
      if (ventas > max) max = ventas;
    }
    return max > 0 ? max : 1000000;
  }

  double _getMaxIngreso() {
    if (_ingresosVsEgresos.isEmpty) return 1000000;
    double max = 0;
    for (var item in _ingresosVsEgresos) {
      double ingresos = (item['ingresos'] ?? 0).toDouble();
      double egresos = (item['egresos'] ?? 0).toDouble();
      double maxLocal = ingresos > egresos ? ingresos : egresos;
      if (maxLocal > max) max = maxLocal;
    }
    return max > 0 ? max : 1000000;
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  /// Formatear fecha de "2025-08-07" a "07/08"
  String _formatearFecha(String fecha) {
    try {
      final DateTime fechaDateTime = DateTime.parse(fecha);
      return '${fechaDateTime.day.toString().padLeft(2, '0')}/${fechaDateTime.month.toString().padLeft(2, '0')}';
    } catch (e) {
      return fecha.length > 5 ? fecha.substring(fecha.length - 5) : fecha;
    }
  }
}
