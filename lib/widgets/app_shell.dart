import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/user_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/notificaciones_provider.dart';

/// Shell persistente: sidebar a la izquierda + topbar minimal + área de contenido.
/// Las rutas envueltas por ShellRoute se renderizan en [child] sin perder el sidebar.
class AppShell extends StatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final Set<String> _expandedMenus = {};
  bool _isSidebarVisible = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String get _currentRoute => GoRouterState.of(context).matchedLocation;

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final userName = userProvider.userName?.toUpperCase() ?? 'USUARIO';
    final isMobile = context.isMobile;

    return Scaffold(
      key: _scaffoldKey,
      drawer: isMobile ? _buildMobileDrawer(context, userProvider, userName) : null,
      body: Row(
        children: [
          if (!isMobile && _isSidebarVisible) _buildSidebar(context, userProvider, userName),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(context, userName, isMobile),
                Expanded(
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDrawer(BuildContext context, UserProvider userProvider, String userName) {
    return Drawer(
      child: Container(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(child: _buildMenuItems(context, userProvider)),
            _buildFooter(context, userName),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, UserProvider userProvider, String userName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 270,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
          ),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(2, 0),
                ),
              ],
      ),
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(child: _buildMenuItems(context, userProvider)),
          _buildFooter(context, userName),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    // Aspect ratio del logo (738x527 ≈ 1.4) — el contenedor adopta esa proporción
    // para que el logo ocupe todo el ancho sin recortes y sin fondo visible.
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
      clipBehavior: Clip.hardEdge,
      child: AspectRatio(
        aspectRatio: 738 / 527,
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, String userName, bool isMobile) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu),
            tooltip: isMobile ? 'Abrir menú' : (_isSidebarVisible ? 'Ocultar menú' : 'Mostrar menú'),
            onPressed: () {
              if (isMobile) {
                _scaffoldKey.currentState?.openDrawer();
              } else {
                setState(() => _isSidebarVisible = !_isSidebarVisible);
              }
            },
          ),
          const Spacer(),
          const _NotificacionesBell(),
          IconButton(
            icon: Icon(
              Provider.of<ThemeProvider>(context).isDark ? Icons.light_mode : Icons.dark_mode,
            ),
            tooltip: 'Cambiar tema',
            onPressed: () => Provider.of<ThemeProvider>(context, listen: false).toggle(),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Configuración',
            onPressed: () => context.push('/configuracion'),
          ),
          if (!isMobile || context.screenWidth > 500) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.secondary,
              child: Text(
                userName.isNotEmpty ? userName[0] : 'U',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              userName,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuItems(BuildContext context, UserProvider userProvider) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _MenuItem(
          icon: Icons.dashboard,
          label: 'Dashboard',
          route: '/dashboard',
          currentRoute: _currentRoute,
        ),
        if (userProvider.isAsesor) ...[
          _MenuItem(icon: Icons.shopping_cart, label: 'Crear Pedido', route: '/asesor-pedidos', currentRoute: _currentRoute),
          _MenuItem(icon: Icons.request_quote, label: 'Cotización', route: '/cotizaciones', currentRoute: _currentRoute),
          _MenuItem(icon: Icons.people, label: 'Clientes', route: '/clientes', currentRoute: _currentRoute),
          _MenuItem(icon: Icons.description, label: 'Documentos', route: '/facturas-lista', currentRoute: _currentRoute),
          _MenuItem(icon: Icons.account_balance, label: 'Facturas DIAN', route: '/facturacion-electronica', currentRoute: _currentRoute),
        ],
        if (!userProvider.isAsesor) ...[
          _MenuItem(icon: Icons.receipt, label: 'Facturar', route: '/facturar', currentRoute: _currentRoute),
          _MenuItem(icon: Icons.list_alt, label: 'Pedidos Asesores', route: '/admin-pedidos-asesor', currentRoute: _currentRoute),
          _ExpandableMenuItem(
            icon: Icons.assignment,
            label: 'Pedidos',
            expanded: _expandedMenus.contains('Pedidos'),
            onToggle: () => _toggleMenu('Pedidos'),
            currentRoute: _currentRoute,
            subItems: const [
              _SubMenuItem(icon: Icons.delete_sweep, label: 'Eliminar Pedidos', route: '/eliminar-pedidos'),
            ],
          ),
          _MenuItem(icon: Icons.request_quote, label: 'Cotización', route: '/cotizaciones', currentRoute: _currentRoute),
          _MenuItem(icon: Icons.people, label: 'Clientes', route: '/clientes', currentRoute: _currentRoute),
          _MenuItem(icon: Icons.description, label: 'Documentos', route: '/facturas-lista', currentRoute: _currentRoute),
          _MenuItem(icon: Icons.account_balance, label: 'Facturas DIAN', route: '/facturacion-electronica', currentRoute: _currentRoute),
          _ExpandableMenuItem(
            icon: Icons.shopping_cart,
            label: 'Compras y Gastos',
            expanded: _expandedMenus.contains('Compras y Gastos'),
            onToggle: () => _toggleMenu('Compras y Gastos'),
            currentRoute: _currentRoute,
            subItems: const [
              _SubMenuItem(icon: Icons.people_outline, label: 'Proveedores', route: '/proveedores'),
              _SubMenuItem(icon: Icons.list_alt, label: 'Lista de Compras', route: '/compras'),
              _SubMenuItem(icon: Icons.add_shopping_cart, label: 'Crear Compra', route: '/facturas-compras'),
              _SubMenuItem(icon: Icons.receipt_long, label: 'Lista de Gastos', route: '/gastos-lista'),
              _SubMenuItem(icon: Icons.add_circle_outline, label: 'Crear Gasto', route: '/gastos'),
            ],
          ),
          _ExpandableMenuItem(
            icon: Icons.account_balance_wallet,
            label: 'Cartera',
            expanded: _expandedMenus.contains('Cartera'),
            onToggle: () => _toggleMenu('Cartera'),
            currentRoute: _currentRoute,
            subItems: const [
              _SubMenuItem(icon: Icons.receipt_long, label: 'Resumen', route: '/cartera'),
              _SubMenuItem(icon: Icons.account_balance_wallet, label: 'Deudas', route: '/deudas'),
              _SubMenuItem(icon: Icons.account_balance, label: 'Cuentas por Cobrar', route: '/cuentas-por-cobrar'),
              _SubMenuItem(icon: Icons.payment, label: 'Cuentas por Pagar', route: '/cuentas-por-pagar'),
            ],
          ),
          _MenuItem(
            icon: Icons.attach_money,
            label: 'Caja',
            route: '/cuadre_caja',
            currentRoute: _currentRoute,
          ),
          _ExpandableMenuItem(
            icon: Icons.inventory,
            label: 'Inventario',
            expanded: _expandedMenus.contains('Inventario'),
            onToggle: () => _toggleMenu('Inventario'),
            currentRoute: _currentRoute,
            subItems: const [
              _SubMenuItem(icon: Icons.list_alt, label: 'Lista Productos', route: '/productos-lista'),
              _SubMenuItem(icon: Icons.swap_horiz, label: 'Traslados', route: '/traslados'),
            ],
          ),
          _ExpandableMenuItem(
            icon: Icons.bar_chart,
            label: 'Reportes',
            expanded: _expandedMenus.contains('Reportes'),
            onToggle: () => _toggleMenu('Reportes'),
            currentRoute: _currentRoute,
            subItems: const [
              _SubMenuItem(icon: Icons.analytics, label: 'Análisis Ventas', route: '/informes/productos'),
            ],
          ),
        ],
      ],
    );
  }

  void _toggleMenu(String label) {
    setState(() {
      if (_expandedMenus.contains(label)) {
        _expandedMenus.remove(label);
      } else {
        _expandedMenus.add(label);
      }
    });
  }

  Widget _buildFooter(BuildContext context, String userName) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.secondary,
            child: Text(
              userName.isNotEmpty ? userName[0] : 'U',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  userName,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  Provider.of<UserProvider>(context).isAdmin ? 'Admin' : 'Usuario',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            color: AppTheme.error,
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await Provider.of<UserProvider>(context, listen: false).logout();
              if (!mounted) return;
              context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final String currentRoute;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = currentRoute == route;
    final color = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected ? color.primary.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: ListTile(
          leading: Icon(
            icon,
            color: isSelected ? color.primary : color.onSurface.withOpacity(0.7),
            size: 22,
          ),
          title: Text(
            label,
            style: TextStyle(
              color: isSelected ? color.primary : color.onSurface,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
          onTap: () => context.go(route),
          dense: true,
          visualDensity: const VisualDensity(vertical: -2),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
        ),
      ),
    );
  }
}

class _ExpandableMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool expanded;
  final VoidCallback onToggle;
  final List<_SubMenuItem> subItems;
  final String currentRoute;

  const _ExpandableMenuItem({
    required this.icon,
    required this.label,
    required this.expanded,
    required this.onToggle,
    required this.subItems,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final hasActiveChild = subItems.any((s) => s.route == currentRoute);
    final highlight = expanded || hasActiveChild;

    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: highlight ? color.secondary.withOpacity(0.10) : Colors.transparent,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Row(
              children: [
                Icon(icon, color: color.onSurface.withOpacity(0.7), size: 20),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: color.onSurface.withOpacity(0.6),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          ...subItems.map((sub) => _SubMenuTile(item: sub, isSelected: sub.route == currentRoute)),
      ],
    );
  }
}

class _SubMenuItem {
  final IconData icon;
  final String label;
  final String route;

  const _SubMenuItem({required this.icon, required this.label, required this.route});
}

class _SubMenuTile extends StatelessWidget {
  final _SubMenuItem item;
  final bool isSelected;

  const _SubMenuTile({required this.item, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => context.go(item.route),
      child: Container(
        margin: const EdgeInsets.only(left: 20, right: 8, top: 1, bottom: 1),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.primary.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Row(
          children: [
            Icon(
              item.icon,
              color: isSelected ? color.primary : color.onSurface.withOpacity(0.65),
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(
              item.label,
              style: TextStyle(
                color: isSelected ? color.primary : color.onSurface.withOpacity(0.85),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificacionesBell extends StatelessWidget {
  const _NotificacionesBell();

  @override
  Widget build(BuildContext context) {
    final notif = context.watch<NotificacionesProvider>();
    final color = Theme.of(context).colorScheme;
    final count = notif.totalNotificaciones;

    return Tooltip(
      message: 'Notificaciones',
      child: InkResponse(
        onTap: () => _openCentro(context),
        radius: 22,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.notifications_outlined, color: color.onSurface),
              if (count > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    decoration: BoxDecoration(
                      color: AppTheme.error,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.surface, width: 1.5),
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCentro(BuildContext context) async {
    final notif = context.read<NotificacionesProvider>();
    await showDialog<void>(
      context: context,
      barrierColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.15),
      builder: (dialogContext) {
        return Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 64, right: 16),
            child: Material(
              color: Colors.transparent,
              child: _NotificacionesPanel(
                onClose: () => Navigator.of(dialogContext).pop(),
              ),
            ),
          ),
        );
      },
    );
    // Refresh on close in case the user actioned something
    notif.refresh();
  }
}

class _NotificacionesPanel extends StatelessWidget {
  final VoidCallback onClose;
  const _NotificacionesPanel({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final notif = context.watch<NotificacionesProvider>();
    final color = Theme.of(context).colorScheme;
    final items = notif.items;

    return Container(
      width: 360,
      constraints: const BoxConstraints(maxHeight: 480),
      decoration: BoxDecoration(
        color: color.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.elevatedShadow,
        border: Border.all(color: color.onSurface.withOpacity(0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Icon(Icons.notifications, color: color.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Notificaciones',
                  style: TextStyle(
                    color: color.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: 'Actualizar',
                  onPressed: notif.isLoading ? null : () => notif.refresh(),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Cerrar',
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: color.onSurface.withOpacity(0.08)),
          Flexible(
            child: _buildBody(context, notif, items),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    NotificacionesProvider notif,
    List<NotificacionItem> items,
  ) {
    final color = Theme.of(context).colorScheme;

    if (notif.isLoading && items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (notif.error != null && items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: AppTheme.error),
            const SizedBox(height: 8),
            Text(
              notif.error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: color.onSurface.withOpacity(0.7), fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, color: AppTheme.success, size: 32),
            const SizedBox(height: 8),
            Text(
              'Sin notificaciones pendientes',
              style: TextStyle(color: color.onSurface.withOpacity(0.7), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: color.onSurface.withOpacity(0.06),
      ),
      itemBuilder: (_, i) => _NotificacionTile(
        item: items[i],
        onTap: () {
          onClose();
          context.push(items[i].ruta);
        },
      ),
    );
  }
}

class _NotificacionTile extends StatelessWidget {
  final NotificacionItem item;
  final VoidCallback onTap;
  const _NotificacionTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final (icon, tone) = _decoration(item.tipo);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: tone.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: tone, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.titulo,
                    style: TextStyle(
                      color: color.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    item.descripcion,
                    style: TextStyle(
                      color: color.onSurface.withOpacity(0.7),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.onSurface.withOpacity(0.4), size: 18),
          ],
        ),
      ),
    );
  }

  (IconData, Color) _decoration(TipoNotificacion tipo) {
    switch (tipo) {
      case TipoNotificacion.cuentaVencida:
        return (Icons.error_outline, AppTheme.error);
      case TipoNotificacion.cuentaProximaVencer:
        return (Icons.schedule, AppTheme.warning);
      case TipoNotificacion.gastoProgramadoProximo:
        return (Icons.event_note, AppTheme.primary);
      case TipoNotificacion.descuentoEnRiesgo:
        return (Icons.local_offer_outlined, AppTheme.secondary);
    }
  }
}
