import 'package:flutter/material.dart';
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

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => DatosCacheProvider()),
        ChangeNotifierProvider(create: (_) => FacturacionDraftProvider()),
        ChangeNotifierProvider(create: (_) => NotificacionesProvider()),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    Future.microtask(() async {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.initializeFromStorage();
      if (!context.mounted) return;
      if (userProvider.isAuthenticated) {
        final cacheProvider = Provider.of<DatosCacheProvider>(context, listen: false);
        await cacheProvider.initialize();
        cacheProvider.warmupProductos();
        final notifProvider = Provider.of<NotificacionesProvider>(context, listen: false);
        notifProvider.refresh();
        notifProvider.startAutoRefresh();
      }
    });

    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp.router(
      title: 'Vercy Motos',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.mode,
      routerConfig: appRouter,
    );
  }
}
