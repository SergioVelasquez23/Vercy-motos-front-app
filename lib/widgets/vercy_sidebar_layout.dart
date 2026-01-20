import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/user_provider.dart';

/// Widget de layout principal con menú lateral estilo Vercy Motos
/// Similar a la interfaz de contoda
class VercySidebarLayout extends StatefulWidget {
  final Widget child;
  final String? title;

  const VercySidebarLayout({super.key, required this.child, this.title});

  @override
  State<VercySidebarLayout> createState() => _VercySidebarLayoutState();
}

class _VercySidebarLayoutState extends State<VercySidebarLayout> {
  String? _selectedRoute;
  Set<String> _expandedMenus = {}; // Para controlar qué menús están expandidos

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final userName = userProvider.userName?.toUpperCase() ?? 'USUARIO';

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Row(
        children: [
          // Sidebar (menú lateral)
          Container(
            width: 270,
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Logo y header
                _buildHeader(context),

                // Menú de navegación
                Expanded(child: _buildMenuItems(context, userProvider)),

                // Usuario y logout
                _buildFooter(context, userName),
              ],
            ),
          ),

          // Área de contenido principal
          Expanded(
            child: Column(
              children: [
                // Top bar con título, usuario e iconos
                _buildTopBar(context, userName),

                // Contenido
                Expanded(
                  child: Container(
                    color: AppTheme.backgroundDark,
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

  /// Header con logo Vercy Motos
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
      child: Row(
        children: [
          // Logo o icono
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.two_wheeler, color: AppTheme.primary, size: 32),
          ),
          SizedBox(width: 12),
          // Texto del logo
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VERCY',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              Text(
                'MOTOS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Top bar con título, usuario e iconos
  Widget _buildTopBar(BuildContext context, String userName) {
    return Container(
      height: 70,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icono de menú hamburguesa (opcional para responsive)
          IconButton(
            icon: Icon(Icons.menu, color: Colors.white),
            onPressed: () {
              // Podría abrir un drawer en versión móvil
            },
          ),
          SizedBox(width: 16),

          // Título
          if (widget.title != null)
            Text(
              widget.title!,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

          Spacer(),

          // Usuario
          Row(
            children: [
              Icon(Icons.person, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                userName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          SizedBox(width: 16),

          // Iconos de ayuda, home, configuración
          IconButton(
            icon: Icon(Icons.help_outline, color: Colors.white),
            onPressed: () {
              // Mostrar ayuda
            },
            tooltip: 'Ayuda',
          ),
          IconButton(
            icon: Icon(Icons.home, color: Colors.white),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/dashboard');
            },
            tooltip: 'Inicio',
          ),
          IconButton(
            icon: Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              // Ir a configuración
            },
            tooltip: 'Configuración',
          ),
        ],
      ),
    );
  }

  /// Items del menú lateral
  Widget _buildMenuItems(BuildContext context, UserProvider userProvider) {
    return ListView(
      padding: EdgeInsets.symmetric(vertical: 8),
      children: [
        // Menú para Asesores (solo pueden crear pedidos)
        if (userProvider.isOnlyAsesor) ...[
          _buildMenuItem(
            icon: Icons.shopping_cart,
            label: 'Crear Pedido',
            route: '/asesor-pedidos',
            isAdmin: false,
          ),
        ],

        // Menú para Admins y SuperAdmins
        if (!userProvider.isOnlyAsesor) ...[
          _buildMenuItem(
            icon: Icons.receipt,
            label: 'Facturar',
            route: '/facturar',
            isAdmin: true,
          ),
          _buildMenuItem(
            icon: Icons.list_alt,
            label: 'Pedidos Asesores',
            route: '/admin-pedidos-asesor',
            isAdmin: true,
          ),
          _buildMenuItem(
            icon: Icons.request_quote,
            label: 'Cotización',
            route: '/cotizaciones',
            isAdmin: true,
          ),
          _buildMenuItem(
            icon: Icons.people,
            label: 'Clientes',
            route: '/clientes',
            isAdmin: true,
          ),
          _buildMenuItem(
            icon: Icons.description,
            label: 'Documentos',
            route: '/facturas-lista',
            isAdmin: true,
          ),
          _buildExpandableMenuItem(
            icon: Icons.shopping_cart,
            label: 'Compras y Gastos',
            isAdmin: true,
            subItems: [
              _SubMenuItem(
                icon: Icons.receipt_long,
                label: 'Facturas de Compras',
                route: '/facturas-compras',
              ),
              _SubMenuItem(
                icon: Icons.money_off,
                label: 'Gestión de Gastos',
                route: '/gastos',
              ),
              _SubMenuItem(
                icon: Icons.money,
                label: 'Ingresos Caja',
                route: '/ingresos-caja',
              ),
            ],
          ),
          _buildMenuItem(
            icon: Icons.account_balance_wallet,
            label: 'Cartera',
            route: null,
            isAdmin: true,
          ),
          _buildExpandableMenuItem(
            icon: Icons.inventory,
            label: 'Inventario',
            isAdmin: true,
            subItems: [
              _SubMenuItem(
                icon: Icons.history,
                label: 'Historial',
                route: '/historial-inventario',
              ),
              _SubMenuItem(
                icon: Icons.inventory_2,
                label: 'Productos',
                route: '/productos',
              ),
            ],
          ),
          _buildMenuItem(
            icon: Icons.local_shipping,
            label: 'Traslados',
            route: '/traslados',
            isAdmin: true,
          ),
          _buildMenuItem(
            icon: Icons.tune,
            label: 'Ajuste',
            route: '/reportes',
            isAdmin: true,
            isExpandable: true,
          ),
          _buildMenuItem(
            icon: Icons.attach_money,
            label: 'Caja',
            route: '/cuadre_caja',
            isAdmin: true,
          ),
        ],
      ],
    );
  }

  /// Widget de item de menú
  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    String? route,
    required bool isAdmin,
    bool isExpandable = false,
  }) {
    final isSelected =
        route != null && ModalRoute.of(context)?.settings.name == route;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primary.withOpacity(0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isSelected
            ? Border.all(color: AppTheme.primary, width: 2)
            : null,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? AppTheme.primary : AppTheme.metal,
          size: 24,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 15,
          ),
        ),
        trailing: isExpandable
            ? Icon(Icons.keyboard_arrow_down, color: AppTheme.metal, size: 20)
            : null,
        onTap: route != null
            ? () {
                setState(() {
                  _selectedRoute = route;
                });
                Navigator.pushReplacementNamed(context, route);
              }
            : null,
        dense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  /// Footer con usuario y logout
  Widget _buildFooter(BuildContext context, String userName) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.metal.withOpacity(0.3), width: 1),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.secondary,
            child: Text(
              userName.isNotEmpty ? userName[0] : 'U',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  userName,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Admin',
                  style: TextStyle(color: AppTheme.metal, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.logout, color: AppTheme.error, size: 20),
            onPressed: () {
              Provider.of<UserProvider>(context, listen: false).logout();
              Navigator.pushReplacementNamed(context, '/');
            },
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
    );
  }

  /// Construir item de menú expandible con subitems
  Widget _buildExpandableMenuItem({
    required IconData icon,
    required String label,
    required bool isAdmin,
    required List<_SubMenuItem> subItems,
  }) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (isAdmin && !userProvider.isAdmin) return SizedBox.shrink();

    final isExpanded = _expandedMenus.contains(label);

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedMenus.remove(label);
              } else {
                _expandedMenus.add(label);
              }
            });
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.textSecondary, size: 20),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          ...subItems.map((subItem) => _buildSubMenuItem(subItem)),
      ],
    );
  }

  /// Construir subitem de menú
  Widget _buildSubMenuItem(_SubMenuItem subItem) {
    final isSelected = _selectedRoute == subItem.route;

    return InkWell(
      onTap: () {
        setState(() => _selectedRoute = subItem.route);
        Navigator.pushReplacementNamed(context, subItem.route);
      },
      child: Container(
        margin: EdgeInsets.only(left: 20),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              subItem.icon,
              color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              size: 18,
            ),
            SizedBox(width: 12),
            Text(
              subItem.label,
              style: TextStyle(
                color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
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

/// Clase auxiliar para subitems de menú
class _SubMenuItem {
  final IconData icon;
  final String label;
  final String route;

  _SubMenuItem({required this.icon, required this.label, required this.route});
}
