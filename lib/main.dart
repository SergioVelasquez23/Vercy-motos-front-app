import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen_v2.dart';
import 'screens/facturacion_screen.dart';
import 'screens/clientes_list_screen.dart';
import 'screens/cliente_form_screen.dart';
import 'screens/cotizaciones_list_screen.dart';
import 'screens/cotizacion_form_screen.dart';
import 'screens/productos_screen.dart';
import 'screens/categorias_screen.dart';
import 'screens/cuadre_caja_screen.dart';
import 'screens/abrir_caja_screen.dart';
import 'screens/cerrar_caja_screen.dart';
import 'screens/reportes_screen.dart';
import 'screens/pedidos_screen_fusion.dart';
import 'screens/configuracion_facturacion_screen.dart';
import 'screens/gastos_screen.dart';
import 'models/cliente.dart';
import 'models/cotizacion.dart';
import 'providers/user_provider.dart';
import 'providers/datos_cache_provider.dart';

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
        print('🔥 WARMUP: Iniciando precarga de datos...');
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
        scaffoldBackgroundColor: Color(0xFF000000), // Negro
        fontFamily: 'Roboto',
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: Color(0xFF2196F3), // Azul
          secondary: Color(0xFF9C27B0), // Morado
          surface: Color(0xFF212121), // Gris oscuro
        ),
        cardColor: Color(0xFF212121),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF2196F3), // Azul
          foregroundColor: Color(0xFFFFFFFF), // Blanco
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFFFFFFF)),
          bodyMedium: TextStyle(color: Color(0xFFE0E0E0)),
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
        '/dashboard': (context) => DashboardScreenV2(),
        '/facturar': (context) => FacturacionScreen(),
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
        '/productos': (context) => ProductosScreen(),
        '/categorias': (context) => CategoriasScreen(),
        '/cuadre_caja': (context) => CuadreCajaScreen(),
        '/abrir_caja': (context) => AbrirCajaScreen(),
        '/cerrar_caja': (context) => CerrarCajaScreen(),
        '/gastos': (context) => GastosScreen(),
        '/pedidos': (context) =>
            const PedidosScreenFusion(), // Pantalla fusionada
        // '/pedidos_v2': (context) =>
        //     const PedidosScreenV2(), // Nueva pantalla V2
        '/pedidos_rt': (context) => PedidosScreenFusion(),
        '/pedidos_cancelados': (context) => PedidosScreenFusion(),
        '/pedidos_cortesia': (context) => PedidosScreenFusion(),
        '/pedidos_internos': (context) =>
            PedidosScreenFusion(), // Cambiado aquí
        '/facturacion/config': (context) =>
            const ConfiguracionFacturacionScreen(),

        // Rutas para la pantalla de reportes
        '/reportes': (context) => ReportesScreen(),
        '/reportes/ventas': (context) => ReportesScreen(initialReportIndex: 1),
        '/reportes/productos': (context) =>
            ReportesScreen(initialReportIndex: 2),
        '/reportes/pedidos': (context) => ReportesScreen(initialReportIndex: 3),
        '/reportes/clientes': (context) =>
            ReportesScreen(initialReportIndex: 4),
      },
    );
  }
}
