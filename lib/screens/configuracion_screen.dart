import 'package:flutter/material.dart';
import 'users_screen.dart';
import 'negocio_info_screen.dart';
import 'exportar_mensual_screen.dart';
import 'configuracion_facturacion_screen.dart';
import '../theme/app_theme.dart';

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
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Configuración', style: AppTheme.headlineMedium),
      ),
      body: Column(
        children: [
          // Tabs movidos del AppBar al body (ahora scrolleable)
          Container(
            decoration: BoxDecoration(
              color: AppTheme.backgroundDark,
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
              labelColor: AppTheme.textDark,
              unselectedLabelColor: AppTheme.textLight,
              isScrollable: true,
              tabs: const [
                Tab(icon: Icon(Icons.people), text: 'Usuarios'),
                Tab(icon: Icon(Icons.business), text: 'Negocio'),
                Tab(icon: Icon(Icons.receipt_long), text: 'Facturación DIAN'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                UsersScreen(),
                NegocioInfoScreen(),
                const ConfiguracionFacturacionScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
