import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'users_screen.dart';
import '../theme/app_theme.dart';
import '../providers/theme_provider.dart';
import '../models/negocio_info.dart';
import '../services/negocio_info_service.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Configuración'),
      ),
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primary,
              isScrollable: true,
              tabs: const [
                Tab(icon: Icon(Icons.people), text: 'Usuarios'),
                Tab(icon: Icon(Icons.palette), text: 'Apariencia'),
                Tab(icon: Icon(Icons.store_outlined), text: 'Mi Negocio'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                UsersScreen(),
                _AparienciaTab(),
              ] + const [_NegocioTab()],
            ),
          ),
        ],
      ),
    );
  }
}

class _AparienciaTab extends StatelessWidget {
  const _AparienciaTab();

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingLarge),
      children: [
        Text('Tema de la aplicación', style: AppTheme.headlineSmall),
        const SizedBox(height: AppTheme.spacingSmall),
        Text(
          'Elige cómo se ve la aplicación. El modo oscuro reduce la fatiga visual en ambientes con poca luz.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
        ),
        const SizedBox(height: AppTheme.spacingLarge),
        _ThemeOption(
          icon: Icons.light_mode,
          title: 'Claro',
          subtitle: 'Fondos suaves, ideal para uso diurno.',
          selected: themeProvider.mode == ThemeMode.light,
          onTap: () => themeProvider.setMode(ThemeMode.light),
        ),
        _ThemeOption(
          icon: Icons.dark_mode,
          title: 'Oscuro',
          subtitle: 'Bajo contraste, menos cansador de noche.',
          selected: themeProvider.mode == ThemeMode.dark,
          onTap: () => themeProvider.setMode(ThemeMode.dark),
        ),
        _ThemeOption(
          icon: Icons.brightness_auto,
          title: 'Automático (sistema)',
          subtitle: 'Sigue la configuración del dispositivo.',
          selected: themeProvider.mode == ThemeMode.system,
          onTap: () => themeProvider.setMode(ThemeMode.system),
        ),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      child: Material(
        color: selected ? color.primary.withOpacity(0.08) : color.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacingMedium),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                color: selected ? color.primary : color.onSurface.withOpacity(0.12),
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: selected ? color.primary : color.onSurface.withOpacity(0.6)),
                const SizedBox(width: AppTheme.spacingMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: color.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: color.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected) Icon(Icons.check_circle, color: color.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
