import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen_v2.dart';
import 'screens/facturacion_screen.dart';
import 'screens/facturas_list_screen.dart';
import 'screens/facturas_compras_screen.dart';
import 'screens/clientes_list_screen.dart';
import 'screens/cliente_form_screen.dart';
import 'screens/cotizaciones_list_screen.dart';
import 'screens/cotizacion_form_screen.dart';
import 'screens/categorias_screen.dart';
import 'screens/cuadre_caja_screen.dart';
import 'screens/abrir_caja_screen.dart';
import 'screens/cerrar_caja_screen.dart';
import 'screens/reportes_screen.dart';
import 'screens/informes_productos_screen.dart';
import 'screens/pedidos_screen_fusion.dart';

import 'screens/gastos_screen.dart';
import 'screens/tipos_gasto_screen.dart';
import 'screens/ingresos_caja_screen.dart';
import 'screens/traslados_screen.dart';
import 'screens/bodegas_screen.dart';
import 'screens/asesor_pedidos_screen.dart';
import 'screens/admin_pedidos_asesor_screen.dart';
import 'screens/proveedores_list_screen.dart';
import 'screens/compras_list_screen.dart';
import 'screens/gastos_list_screen.dart';
import 'screens/productos_list_screen.dart';
import 'screens/productos_screen.dart';
import 'screens/cartera_screen.dart';
import 'screens/cuentas_por_cobrar_screen.dart';
import 'screens/cuentas_por_pagar_screen.dart';
import 'screens/gastos_programados_screen.dart';
import 'screens/alertas_screen.dart';
import 'screens/autorizaciones_screen.dart';
import 'screens/eliminar_pedidos_screen.dart';
import 'screens/negocio_info_screen.dart';
import 'models/cliente.dart';
import 'models/cotizacion.dart';
import 'providers/user_provider.dart';
import 'providers/datos_cache_provider.dart';
import 'providers/facturacion_draft_provider.dart';

void main() async {
  // Aseguramos que Flutter esté inicializado
  WidgetsFlutterBinding.ensureInitialized();

  // NO inicializar Intl.defaultLocale para evitar corrupción de formateo
  // El formateo de números ahora es completamente independiente en format_utils.dart
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => DatosCacheProvider()),
        ChangeNotifierProvider(create: (_) => FacturacionDraftProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize user from stored token and cache data
    Future.microtask(() async {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.initializeFromStorage();

      // Si el usuario está autenticado, inicializar el cache Y PRECARGAR PRODUCTOS
      if (userProvider.isAuthenticated) {
        final cacheProvider = Provider.of<DatosCacheProvider>(
          context,
          listen: false,
        );
        // 🔥 WARMUP: Inicializar cache y precargar productos en background
        await cacheProvider.initialize();
        // Precargar productos en background sin bloquear la UI
        cacheProvider.warmupProductos();
      }
    });

    return MaterialApp(
      title: 'Vercy Motos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Color(0xFF2196F3), // Azul Vercy Motos
        scaffoldBackgroundColor: Color(0xFFFFFFFF), // Blanco
        fontFamily: 'Roboto',
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          primary: Color(0xFF2196F3), // Azul
          secondary: Color(0xFF9C27B0), // Morado
          surface: Color(0xFFF5F5F5), // Gris muy claro
        ),
        cardColor: Color(0xFFFFFFFF),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF2196F3), // Azul
          foregroundColor: Color(0xFFFFFFFF), // Blanco
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF212121)),
          bodyMedium: TextStyle(color: Color(0xFF424242)),
        ),
        // Estilo global para inputs con labels negros (para fondos claros)
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: TextStyle(color: Colors.black54),
          floatingLabelStyle: TextStyle(
            color: Color(0xFF2196F3),
            fontWeight: FontWeight.w600,
          ),
          border: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF2196F3), width: 2),
          ),
        ),
        // Estilo para dropdowns
        dropdownMenuTheme: DropdownMenuThemeData(
          textStyle: TextStyle(color: Colors.black87),
        ),
      ),
      home: LoginScreen(),
      routes: {
        '/login': (context) => LoginScreen(),
        '/dashboard': (context) => DashboardScreenV2(),
        '/facturar': (context) => FacturacionScreen(),
        '/asesor-pedidos': (context) => AsesorPedidosScreen(),
        '/admin-pedidos-asesor': (context) => AdminPedidosAsesorScreen(),
        '/clientes': (context) => ClientesListScreen(),
        '/clientes/form': (context) {
          final cliente =
              ModalRoute.of(context)?.settings.arguments as Cliente?;
          return ClienteFormScreen(cliente: cliente);
        },
        '/cotizaciones': (context) => CotizacionesListScreen(),
        '/cotizaciones/form': (context) {
          final cotizacion =
              ModalRoute.of(context)?.settings.arguments as Cotizacion?;
          return CotizacionFormScreen(cotizacion: cotizacion);
        },
        '/productos-lista': (context) => ProductosListScreen(),
        '/productos': (context) => ProductosScreen(),
        '/traslados': (context) => TrasladosScreen(),
        '/bodegas': (context) => BodegasScreen(),
        '/cuadre_caja': (context) => CuadreCajaScreen(),
        '/negocio-info': (context) => const NegocioInfoScreen(),
        '/abrir_caja': (context) => AbrirCajaScreen(),
        '/cerrar_caja': (context) => CerrarCajaScreen(),
        '/compras': (context) => ComprasListScreen(),
        '/facturas-compras': (context) => CrearFacturaCompraScreen(),
        '/gastos': (context) => GastosScreen(mostrarFormulario: true),
        '/tipos-gasto': (context) => TiposGastoScreen(),
        '/gastos-lista': (context) => GastosListScreen(),
        '/proveedores': (context) => ProveedoresListScreen(),
        '/cartera': (context) => const CarteraScreen(),
        '/cuentas-por-cobrar': (context) => const CuentasPorCobrarScreen(),
        '/cuentas-por-pagar': (context) => const CuentasPorPagarScreen(),
        '/gastos-programados': (context) => const GastosProgramadosScreen(),
        '/alertas': (context) => const AlertasScreen(),
        '/autorizaciones': (context) => const AutorizacionesScreen(),
        '/ingresos-caja': (context) => IngresosCajaScreen(),
        '/pedidos': (context) =>
            const PedidosScreenFusion(), // Pantalla fusionada
        // '/pedidos_v2': (context) =>
        //     const PedidosScreenV2(), // Nueva pantalla V2
        '/pedidos_rt': (context) => PedidosScreenFusion(),
        '/pedidos_cancelados': (context) => PedidosScreenFusion(),
        '/pedidos_cortesia': (context) => PedidosScreenFusion(),
        '/pedidos_internos': (context) =>
            PedidosScreenFusion(), // Cambiado aquí
        '/facturas-lista': (context) => FacturasListScreen(),
        '/eliminar-pedidos': (context) => const EliminarPedidosScreen(),
        // Rutas para la pantalla de reportes
        '/reportes': (context) => ReportesScreen(),
        '/reportes/ventas': (context) => ReportesScreen(initialReportIndex: 1),
        '/reportes/productos': (context) =>
            ReportesScreen(initialReportIndex: 2),
        '/reportes/pedidos': (context) => ReportesScreen(initialReportIndex: 3),
        '/reportes/clientes': (context) =>
            ReportesScreen(initialReportIndex: 4),
        // Ruta para informes de productos
        '/informes/productos': (context) => const InformesProductosScreen(),
      },
    );
  }
}
