import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import 'providers/user_provider.dart';
import 'providers/datos_cache_provider.dart';
import 'providers/facturacion_draft_provider.dart';
import 'providers/notificaciones_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'router/app_router.dart';
import 'services/http_502_hard_reset.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Envuelve TODA la app en un cliente HTTP que cuenta 502 por endpoint
  // distinto y hace un hard reset (recarga completa) si se superan 8 — ver
  // Http502TrackingClient. runWithClient hace que hasta las llamadas que usan
  // http.get/post directamente (sin pasar por ningún service base) pasen por
  // este cliente, así que no hace falta tocar cada servicio.
  await http.runWithClient(_runApp, () => Http502TrackingClient(http.Client()));
}

Future<void> _runApp() async {

  // Captura errores de Flutter (build/layout/etc.) con stack trace legible,
  // incluso en builds de release donde el JS minificado no es interpretable.
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('💥 [FlutterError] ${details.exceptionAsString()}');
    debugPrint(details.stack.toString());
    FlutterError.presentError(details);
  };

  // Captura errores asíncronos/no manejados (fuera del árbol de widgets).
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('💥 [PlatformDispatcher] $error');
    debugPrint(stack.toString());
    return true;
  };

  final themeProvider = ThemeProvider();
  await themeProvider.initialize();

  // Inicializar UserProvider antes de runApp para que el token esté disponible
  // desde el primer frame, incluso cuando el usuario recarga la página en una
  // ruta protegida (go_router restaura la URL sin pasar por SplashScreen).
  final userProvider = UserProvider();
  await userProvider.initializeFromStorage();

  final router = buildAppRouter(userProvider);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: userProvider),
        ChangeNotifierProvider(create: (_) => DatosCacheProvider()),
        ChangeNotifierProvider(create: (_) => FacturacionDraftProvider()),
        ChangeNotifierProvider(create: (_) => NotificacionesProvider()),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
      ],
      child: MyApp(router: router),
    ),
  );
}

class MyApp extends StatelessWidget {
  final GoRouter router;
  const MyApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp.router(
      title: 'Vercy Motos',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.mode,
      routerConfig: router,
    );
  }
}
