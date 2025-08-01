import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen_v2.dart';
import 'screens/mesas_screen.dart';
import 'screens/productos_screen.dart';
import 'screens/categorias_screen.dart';
import 'screens/cuadre_caja_screen.dart';
import 'screens/reportes_screen.dart';
import 'screens/pedidos_screen_fusion.dart';
import 'screens/documentos_screen.dart';
import 'screens/inventario_screen.dart';
import 'providers/user_provider.dart';

void main() async {
  // Aseguramos que Flutter esté inicializado
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => UserProvider())],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Initialize user from stored token
    Future.microtask(
      () => Provider.of<UserProvider>(
        context,
        listen: false,
      ).initializeFromStorage(),
    );

    return MaterialApp(
      title: 'Sopa y Carbon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Color(0xFFFF6B00),
        scaffoldBackgroundColor: Color(0xFF1E1E1E),
        fontFamily: 'Roboto',
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: Color(0xFFFF6B00),
          secondary: Color(0xFFFF8800),
          background: Color(0xFF1E1E1E),
          surface: Color(0xFF252525),
        ),
        cardColor: Color(0xFF252525),
        appBarTheme: AppBarTheme(backgroundColor: Color(0xFFFF6B00)),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFE0E0E0)),
          bodyMedium: TextStyle(color: Color(0xFFE0E0E0)),
        ),
      ),
      home: LoginScreen(),
      routes: {
        '/dashboard': (context) => DashboardScreenV2(),
        '/mesas': (context) => MesasScreen(),
        '/productos': (context) => ProductosScreen(),
        '/categorias': (context) => CategoriasScreen(),
        '/cuadre_caja': (context) => CuadreCajaScreen(),
        '/pedidos': (context) =>
            const PedidosScreenFusion(), // Pantalla fusionada
        // '/pedidos_v2': (context) =>
        //     const PedidosScreenV2(), // Nueva pantalla V2
        '/pedidos_rt': (context) => PedidosScreenFusion(),
        '/documentos': (context) => const DocumentosScreen(),
        '/pedidos_cancelados': (context) => PedidosScreenFusion(),
        '/pedidos_cortesia': (context) => PedidosScreenFusion(),
        '/pedidos_internos': (context) =>
            PedidosScreenFusion(), // Cambiado aquí
        // Ruta para detalle de pedido (requiere pasar una mesa como parámetro)
        // Nota: Esta ruta normalmente se usaría con argumentos: Navigator.pushNamed(context, '/pedido', arguments: mesa)

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
