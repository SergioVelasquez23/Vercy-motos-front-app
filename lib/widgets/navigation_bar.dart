import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppNavigationBar extends StatelessWidget {
  final String currentRoute;

  const AppNavigationBar({Key? key, required this.currentRoute})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      color: AppTheme.cardBg,
      child: Scrollbar(
        scrollbarOrientation: ScrollbarOrientation.bottom,
        thumbVisibility: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildNavItem(
                context,
                icon: Icons.dashboard,
                label: 'Dashboard',
                route: '/dashboard',
              ),
              _buildNavItem(
                context,
                icon: Icons.receipt,
                label: 'Facturación',
                route: '/facturacion',
              ),
              _buildNavItem(
                context,
                icon: Icons.receipt_long,
                label: 'Pedidos',
                route: '/pedidos',
              ),
              _buildNavItem(
                context,
                icon: Icons.two_wheeler,
                label: 'Productos',
                route: '/productos',
              ),
              _buildNavItem(
                context,
                icon: Icons.inventory,
                label: 'Inventario',
                route: '/inventario',
              ),
              _buildNavItem(
                context,
                icon: Icons.shopping_bag,
                label: 'Facturas Compras',
                route: '/facturas_compras',
              ),
              _buildNavItem(
                context,
                icon: Icons.attach_money,
                label: 'Gastos',
                route: '/gastos',
              ),
              _buildNavItem(
                context,
                icon: Icons.people,
                label: 'Clientes',
                route: '/clientes',
              ),
              _buildNavItem(
                context,
                icon: Icons.description,
                label: 'Cotizaciones',
                route: '/cotizaciones',
              ),
              _buildNavItem(
                context,
                icon: Icons.account_balance,
                label: 'Caja',
                route: '/cuadre_caja',
              ),
              _buildNavItem(
                context,
                icon: Icons.settings,
                label: 'Configuración',
                route: '/configuracion',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
  }) {
    final isActive = currentRoute == route;

    return GestureDetector(
      onTap: () {
        if (!isActive) {
          Navigator.pushNamed(context, route);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primary.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? AppTheme.primary : AppTheme.textSecondary,
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? AppTheme.primary : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
