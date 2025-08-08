import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'productos_screen.dart';
import 'reportes_screen.dart';
import 'categorias_screen.dart';
import 'mesas_screen.dart';
import 'pedidos_screen_fusion.dart';
import 'cuadre_caja_screen.dart';
import 'documentos_screen.dart';
import 'inventario_screen.dart';
import 'ingredientes_screen.dart';
import 'recetas_screen.dart';
import 'proveedores_screen.dart';
import 'unidades_screen.dart';
import 'historial_inventario_screen.dart';
import '../config/constants.dart';
import '../services/reportes_service.dart';
import '../services/pedido_service.dart';
import '../models/dashboard_data.dart';
import '../providers/user_provider.dart';

class InfoCardItem {
  final String label;
  final String value;
  final Color color;

  InfoCardItem({required this.label, required this.value, required this.color});
}

class DashboardScreenV2 extends StatefulWidget {
  @override
  _DashboardScreenV2State createState() => _DashboardScreenV2State();
}

class _DashboardScreenV2State extends State<DashboardScreenV2>
    with WidgetsBindingObserver {
  final Color primary = Color(kPrimaryColor);
  final Color bgDark = Color(kBackgroundDark);
  final Color cardBg = Color(kCardBackgroundDark);
  final Color textDark = Color(kTextDark);
  final Color textLight = Color(kTextLight);
  final Color accentOrange = Color(0xFFFF8800);

  late StreamSubscription<bool> _pedidoCompletadoSubscription;
  late StreamSubscription<bool> _pedidoPagadoSubscription;
  late Timer _autoRefreshTimer;
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

  @override
  void initState() {
    super.initState();

    // Agregar observer para detectar cambios en el ciclo de vida
    WidgetsBinding.instance.addObserver(this);

    // Verificar roles después de que el context esté disponible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // Solo cargar datos si el usuario es admin
      if (userProvider.isAdmin) {
        _cargarDatos();

        // Suscribirse al stream de eventos de pedidos completados
        _pedidoCompletadoSubscription = _pedidoService.onPedidoCompletado
            .listen((_) {
              _cargarDatos();
            });

        // Suscribirse al stream de eventos de pedidos pagados
        _pedidoPagadoSubscription = _pedidoService.onPedidoPagado.listen((_) {
          _cargarDatos();
        });

        // Timer para actualizar automáticamente cada 30 segundos
        _autoRefreshTimer = Timer.periodic(Duration(seconds: 30), (timer) {
          _cargarDatos();
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

    // Solo recargar datos cuando la app vuelve a estar activa
    if (state == AppLifecycleState.resumed && mounted) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (userProvider.isAdmin) {
        _cargarDatos();
      }
    }
  }

  @override
  void dispose() {
    // Remover observer
    WidgetsBinding.instance.removeObserver(this);

    _pedidoCompletadoSubscription.cancel();
    _pedidoPagadoSubscription.cancel();
    _autoRefreshTimer.cancel();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      // Cargar datos en paralelo pero manejar errores individualmente
      final estadisticasFuture = _cargarEstadisticas().catchError((e) {
        return null;
      });
      final ingresosFuture = _cargarIngresosVsEgresos().catchError((e) {
        return null;
      });
      final topProductosFuture = _cargarTopProductos().catchError((e) {
        return null;
      });
      final ventasPorDiaFuture = _reportesService
          .getVentasPorDia(7)
          .then((data) {
            setState(() {
              _ventasPorDia = data;
            });
          })
          .catchError((e) {
            setState(() {
              _ventasPorDia = [];
            });
          });

      await Future.wait([
        estadisticasFuture,
        ingresosFuture,
        topProductosFuture,
        ventasPorDiaFuture,
      ]);
    } catch (e) {
      // Error handling
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cargarEstadisticas() async {
    try {
      // Obtener datos del dashboard desde el servicio
      final dashboardData = await _reportesService.getDashboard();

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
    }
  }

  Future<void> _cargarTopProductos() async {
    try {
      // Obtener top 5 productos más vendidos del mes actual desde el backend
      final topProductos = await _reportesService.getTopProductos(5);

      // Transformar datos al formato esperado por la UI
      final List<Map<String, dynamic>> productosTransformados = [];
      final List<Color> colores = [
        Colors.red,
        Colors.blue,
        Colors.green,
        Colors.orange,
        Colors.purple,
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
          backgroundColor: cardBg,
          title: Text(
            'Editar Objetivo - $titulo',
            style: TextStyle(color: textDark),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ingrese el nuevo objetivo de ventas:',
                style: TextStyle(color: textLight),
              ),
              SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textDark),
                decoration: InputDecoration(
                  labelText: 'Objetivo (\$)',
                  labelStyle: TextStyle(color: textLight),
                  prefixText: '\$',
                  prefixStyle: TextStyle(color: textLight),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: textLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: textLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: primary),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar', style: TextStyle(color: textLight)),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Por favor ingrese un valor válido'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Objetivo de $periodo actualizado a \$${_formatNumber(nuevoObjetivo)}',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // IMPORTANTE: Recargar datos del dashboard para obtener los objetivos actualizados
        await _cargarDatos();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar el objetivo: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
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

    // Si el usuario es mesero sin permisos de admin, redirigir a la pantalla de mesas
    if (userProvider.isMesero && !userProvider.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/mesas');
      });
      return Scaffold(
        backgroundColor: bgDark,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primary),
              ),
              SizedBox(height: 16),
              Text(
                'Redirigiendo a Mesas...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildNavBar(),
            Expanded(
              child: userProvider.isAdmin
                  ? (_isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                primary,
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _cargarDatos,
                            child: SingleChildScrollView(
                              physics: AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  _buildStatsCards(),
                                  SizedBox(height: 20),
                                  _buildInfoCards(),
                                  SizedBox(height: 20),
                                  _buildRecentSales(),
                                  SizedBox(height: 20),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildIngresosVsEgresosChart(),
                                      ),
                                      SizedBox(width: 20),
                                      Expanded(
                                        child: _buildTopProductosChart(),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ))
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.security, size: 64, color: Colors.grey),
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
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pushReplacementNamed(context, '/mesas');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              padding: EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                            ),
                            child: Text(
                              'Ir a Mesas',
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
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.all(16.0),
      color: primary,
      child: Row(
        children: [
          Icon(Icons.restaurant_menu, color: Colors.white, size: 24),
          SizedBox(width: 12),
          Text(
            'Dashboard Asados',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Sergio',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
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
      color: cardBg,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: _buildNavItems(userProvider)),
      ),
    );
  }

  List<Widget> _buildNavItems(UserProvider userProvider) {
    List<Widget> navItems = [];

    // Dashboard - Solo para ADMIN y SUPERADMIN
    if (userProvider.isAdmin) {
      navItems.add(_buildNavItem(Icons.dashboard, 'Dashboard', 0, () {}));
    }

    // Mesas - Disponible para todos los roles
    navItems.add(
      _buildNavItem(Icons.table_restaurant, 'Mesas', 4, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MesasScreen()),
        );
      }),
    );

    // Pedidos - Disponible para todos los roles
    navItems.add(
      _buildNavItem(Icons.shopping_cart, 'Pedidos', 5, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PedidosScreenFusion()),
        );
      }),
    );

    // Los siguientes módulos solo para ADMIN y SUPERADMIN
    if (userProvider.isAdmin) {
      navItems.add(
        _buildNavItem(Icons.inventory_2, 'Productos', 1, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ProductosScreen()),
          );
        }),
      );

      navItems.add(
        _buildDropdownNavItem(Icons.inventory_2_outlined, 'Inventario', 2, [
          PopupMenuItem<String>(
            value: 'inventario',
            onTap: () {
              Future.delayed(Duration.zero, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => InventarioScreen()),
                );
              });
            },
            child: Row(
              children: [
                Icon(Icons.inventory, color: primary, size: 18),
                SizedBox(width: 8),
                Text('General', style: TextStyle(color: textDark)),
              ],
            ),
          ),
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
                Text('Historial', style: TextStyle(color: textDark)),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'ingredientes',
            onTap: () {
              Future.delayed(Duration.zero, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => IngredientesScreen()),
                );
              });
            },
            child: Row(
              children: [
                Icon(Icons.restaurant_menu, color: Colors.green, size: 18),
                SizedBox(width: 8),
                Text('Ingredientes', style: TextStyle(color: textDark)),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'recetas',
            onTap: () {
              Future.delayed(Duration.zero, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RecetasScreen()),
                );
              });
            },
            child: Row(
              children: [
                Icon(Icons.menu_book, color: Colors.orange, size: 18),
                SizedBox(width: 8),
                Text('Recetas', style: TextStyle(color: textDark)),
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
                Text('Proveedores', style: TextStyle(color: textDark)),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'unidades',
            onTap: () {
              Future.delayed(Duration.zero, () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => UnidadesScreen()),
                );
              });
            },
            child: Row(
              children: [
                Icon(Icons.straighten, color: Colors.teal, size: 18),
                SizedBox(width: 8),
                Text('Unidades', style: TextStyle(color: textDark)),
              ],
            ),
          ),
        ]),
      );

      navItems.add(
        _buildNavItem(Icons.category, 'Categorías', 3, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CategoriasScreen()),
          );
        }),
      );

      navItems.add(
        _buildNavItem(Icons.bar_chart, 'Reportes', 6, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ReportesScreen()),
          );
        }),
      );

      navItems.add(
        _buildNavItem(Icons.description, 'Documentos', 7, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DocumentosScreen()),
          );
        }),
      );

      navItems.add(
        _buildNavItem(Icons.account_balance, 'Caja', 8, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CuadreCajaScreen()),
          );
        }),
      );
    }

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
          color: isSelected ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.white : textLight, size: 20),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : textLight,
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
    List<PopupMenuItem<String>> items,
  ) {
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
      tooltip: "Menú de Inventario",
      position: PopupMenuPosition.under,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      // Direct access to main inventory screen via icon
      onCanceled: () {
        // Navigate to Inventory main screen if menu is opened and then canceled
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => InventarioScreen()),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? primary : Colors.transparent,
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
                  color: isSelected ? Colors.white : textLight,
                  size: 20,
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down,
                  color: isSelected ? Colors.white : textLight,
                  size: 14,
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : textLight,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    if (_dashboardData == null) {
      return Container(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primary),
              ),
              SizedBox(height: 16),
              Text(
                'Cargando estadísticas del dashboard...',
                style: TextStyle(color: textLight, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Facturado Hoy',
                value: '\$${_formatNumber(_dashboardData!.ventasHoy.total)}',
                objective:
                    'Objetivo: \$${_formatNumber(_obtenerObjetivoActual('hoy'))}',
                percentage:
                    (_dashboardData!.ventasHoy.total /
                            _obtenerObjetivoActual('hoy') *
                            100)
                        .round(),
                color: primary,
                periodo: 'hoy',
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                title: 'Últimos 7 días',
                value: '\$${_formatNumber(_dashboardData!.ventas7Dias.total)}',
                objective:
                    'Objetivo: \$${_formatNumber(_obtenerObjetivoActual('semana'))}',
                percentage:
                    (_dashboardData!.ventas7Dias.total /
                            _obtenerObjetivoActual('semana') *
                            100)
                        .round(),
                color: accentOrange,
                periodo: 'semana',
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Últimos 30 días',
                value: '\$${_formatNumber(_dashboardData!.ventas30Dias.total)}',
                objective:
                    'Objetivo: \$${_formatNumber(_obtenerObjetivoActual('mes'))}',
                percentage:
                    (_dashboardData!.ventas30Dias.total /
                            _obtenerObjetivoActual('mes') *
                            100)
                        .round(),
                color: Colors.green,
                periodo: 'mes',
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                title: 'Año actual',
                value: '\$${_formatNumber(_dashboardData!.ventasAnio.total)}',
                objective:
                    'Objetivo: \$${_formatNumber(_obtenerObjetivoActual('año'))}',
                percentage:
                    (_dashboardData!.ventasAnio.total /
                            _obtenerObjetivoActual('año') *
                            100)
                        .round(),
                color: Colors.blue,
                periodo: 'año',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCards() {
    if (_dashboardData == null) {
      return Container(
        height: 150,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primary),
              ),
              SizedBox(height: 16),
              Text(
                'Cargando información adicional...',
                style: TextStyle(color: textLight, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Primera fila: Pedidos y Facturación
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                title: 'Pedidos Hoy',
                icon: Icons.shopping_cart,
                mainValue: '${_dashboardData!.pedidosHoy.total}',
                items: [
                  InfoCardItem(
                    label: 'Completados',
                    value: '${_dashboardData!.pedidosHoy.completados}',
                    color: Colors.green,
                  ),
                  InfoCardItem(
                    label: 'Pendientes',
                    value: '${_dashboardData!.pedidosHoy.pendientes}',
                    color: Colors.orange,
                  ),
                ],
                color: primary,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildInfoCard(
                title: 'Facturación',
                icon: Icons.account_balance_wallet,
                mainValue: _dashboardData!.facturacion.montoPendiente > 0
                    ? '\$${_formatNumber(_dashboardData!.facturacion.montoPendiente)}'
                    : 'Al día',
                items: [
                  InfoCardItem(
                    label: 'Pendientes',
                    value: '${_dashboardData!.facturacion.pendientesPago}',
                    color: _dashboardData!.facturacion.pendientesPago > 0
                        ? Colors.red
                        : Colors.green,
                  ),
                ],
                color: accentOrange,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        // Segunda fila: Inventario y Ventas Hoy
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                title: 'Inventario',
                icon: Icons.inventory,
                mainValue: '${_dashboardData!.inventario.alertas} Alertas',
                items: [
                  InfoCardItem(
                    label: 'Stock Bajo',
                    value: '${_dashboardData!.inventario.stockBajo}',
                    color: Colors.yellow,
                  ),
                  InfoCardItem(
                    label: 'Agotados',
                    value: '${_dashboardData!.inventario.agotados}',
                    color: Colors.red,
                  ),
                ],
                color: Colors.purple,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildInfoCard(
                title: 'Detalles Hoy',
                icon: Icons.today,
                mainValue: '${_dashboardData!.ventasHoy.cantidad} Items',
                items: [
                  InfoCardItem(
                    label: 'Facturas',
                    value: '${_dashboardData!.ventasHoy.facturas}',
                    color: Colors.blue,
                  ),
                  InfoCardItem(
                    label: 'Pagados',
                    value: '${_dashboardData!.ventasHoy.pedidosPagados}',
                    color: Colors.green,
                  ),
                ],
                color: Colors.teal,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIngresosVsEgresosChart() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, color: Color(0xFF00E5FF), size: 12),
              SizedBox(width: 8),
              Text(
                'INGRESOS VS EGRESOS',
                style: TextStyle(
                  color: textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            height: 200,
            child: _ingresosVsEgresos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: primary),
                        SizedBox(height: 8),
                        Text(
                          'Cargando datos...',
                          style: TextStyle(color: textLight, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _getMaxIngreso() * 1.2,
                      barTouchData: BarTouchData(enabled: false),
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
                                    color: textLight,
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
                                style: TextStyle(color: textLight, fontSize: 8),
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
                              color: Color(0xFF00E5FF),
                              width: 12,
                            ),
                            BarChartRodData(
                              toY: (entry.value['egresos'] ?? 0).toDouble(),
                              color: Color(0xFFFF5252),
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
              _buildLegendItem(Color(0xFF00E5FF), 'Ingresos'),
              SizedBox(width: 24),
              _buildLegendItem(Color(0xFFFF5252), 'Egresos'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductosChart() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, color: Colors.red, size: 12),
              SizedBox(width: 8),
              Text(
                'TOP 5',
                style: TextStyle(
                  color: textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            'PRODUCTOS MES ACTUAL',
            style: TextStyle(color: textLight, fontSize: 12),
          ),
          SizedBox(height: 20),
          Container(
            height: 160,
            child: _topProductos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: primary),
                        SizedBox(height: 8),
                        Text(
                          'Cargando productos...',
                          style: TextStyle(color: textLight, fontSize: 12),
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
          Container(
            height: 100,
            child: _topProductos.isEmpty
                ? Center(
                    child: Text(
                      'No hay datos de productos',
                      style: TextStyle(color: textLight, fontSize: 12),
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
                                  color: textLight,
                                  fontSize: 10,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${(producto['porcentaje'] ?? 0).toInt()}%',
                              style: TextStyle(
                                color: textDark,
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

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 8),
        Text(label, style: TextStyle(color: textLight, fontSize: 12)),
      ],
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required String mainValue,
    required List<InfoCardItem> items,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: textLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            mainValue,
            style: TextStyle(
              color: textDark,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          ...items
              .map(
                (item) => Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.label,
                        style: TextStyle(color: textLight, fontSize: 12),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: item.color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.value,
                          style: TextStyle(
                            color: item.color,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String objective,
    required int percentage,
    required Color color,
    String? periodo, // Nuevo parámetro para identificar el período
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
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
                  style: TextStyle(
                    color: textLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.edit, size: 14, color: color),
                      ),
                    ),
                  if (periodo != null) SizedBox(width: 6),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${percentage}%',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: textDark,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(objective, style: TextStyle(color: textLight, fontSize: 10)),
          SizedBox(height: 8),
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: percentage / 100,
              strokeWidth: 8,
              backgroundColor: Colors.grey.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSales() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, color: primary, size: 12),
              SizedBox(width: 8),
              Text(
                'FACTURADO ÚLTIMOS 7 DÍAS',
                style: TextStyle(
                  color: textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            height: 150,
            child: _ventasPorDia.isEmpty
                ? Center(child: CircularProgressIndicator(color: primary))
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
                                      color: textLight,
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
                                  color: textLight,
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
                              color: primary,
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
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    } else {
      return amount.toStringAsFixed(0);
    }
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
}
