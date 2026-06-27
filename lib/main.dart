import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'providers/user_provider.dart';
import 'providers/datos_cache_provider.dart';
import 'providers/facturacion_draft_provider.dart';
import 'providers/notificaciones_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
