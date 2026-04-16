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
  bool _isSidebarVisible =
      true; // Variable para controlar la visibilidad del sidebar
  late final GlobalKey<ScaffoldState> _scaffoldKey;

  @override
  void initState() {
    super.initState();
    _scaffoldKey = GlobalKey<ScaffoldState>();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final userName = userProvider.userName?.toUpperCase() ?? 'USUARIO';
    final isMobile = context.isMobile;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.backgroundDark,
      // En móviles, usar Drawer automático en lugar de sidebar fijo
      drawer: isMobile
          ? Drawer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primary.withOpacity(0.06),
                      AppTheme.secondary.withOpacity(0.04),
                      Colors.white,
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
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
            )
          : null,
      body: Row(
        children: [
          // Sidebar (menú lateral) - Solo en desktop, nunca en móvil
          if (!isMobile && _isSidebarVisible)
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              width: 270,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primary.withOpacity(0.06),
                    AppTheme.secondary.withOpacity(0.04),
                    Colors.white,
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
                border: Border(
                  right: BorderSide(
                    color: AppTheme.primary.withOpacity(0.15),
                    width: 2,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.15),
                    blurRadius: 15,
                    offset: Offset(3, 0),
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.5),
                    blurRadius: 8,
                    offset: Offset(-2, 0),
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

          // Área de contenido principal (siempre expande)
          Expanded(
            child: Column(
              children: [
                // Top bar con título, usuario e iconos
                _buildTopBar(context, userName, isMobile),

                // Contenido
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFF5F7FA),
                          Color(0xFFE8EAF6),
                          Color(0xFFF5F7FA),
                        ],
                        stops: [0.0, 0.5, 1.0],
                      ),
                    ),
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
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, AppTheme.secondary],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: AppTheme.secondary.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 200,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.all(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  /// Top bar con título, usuario e iconos
  Widget _buildTopBar(BuildContext context, String userName, bool isMobile) {
    return Container(
      height: 70,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, AppTheme.secondary],
        ),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.2), width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.4),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
          BoxShadow(
            color: AppTheme.secondary.withOpacity(0.2),
            blurRadius: 25,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          // Icono de menú hamburguesa con efecto
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: IconButton(
              icon: Icon(Icons.menu, color: Colors.white, size: 24),
              onPressed: () {
                if (isMobile) {
                  // En móvil, abrir el drawer
                  _scaffoldKey.currentState?.openDrawer();
                } else {
                  // En desktop, desplegar/retraer sidebar
                  setState(() {
                    _isSidebarVisible = !_isSidebarVisible;
                  });
                }
              },
              tooltip: isMobile 
                  ? 'Abrir menú'
                  : (_isSidebarVisible ? 'Ocultar menú' : 'Mostrar menú'),
            ),
          ),
          SizedBox(width: 20),

          // Título con efecto glassmorphism
          if (widget.title != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.25),
                    Colors.white.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Text(
                widget.title!,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: context.screenWidth < 600 ? 16 : 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),

          Spacer(),

          // Usuario con contenedor especial
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.2),
                  Colors.white.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(Icons.person, color: Colors.white, size: 18),
                ),
                SizedBox(width: 10),
                if (!isMobile || context.screenWidth > 500)
                  Text(
                    userName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
              ],
            ),
          ),

          if (!isMobile)
            SizedBox(width: 16),

          // Iconos con efectos mejorados (ocultar en móviles muy pequeños)
          if (!isMobile || context.screenWidth > 500) ...[
            _buildTopBarIcon(Icons.help_outline, 'Ayuda', () {}),
            SizedBox(width: 8),
            _buildTopBarIcon(Icons.home, 'Inicio', () {
              Navigator.pushReplacementNamed(context, '/dashboard');
            }),
            SizedBox(width: 8),
            _buildTopBarIcon(Icons.settings, 'Configuración', () {}),
          ]
        ],
      ),
    );
  }

  /// Widget auxiliar para iconos del top bar
  Widget _buildTopBarIcon(
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }

  /// Items del menú lateral
  Widget _buildMenuItems(BuildContext context, UserProvider userProvider) {
    return ListView(
      padding: EdgeInsets.symmetric(vertical: 8),
      children: [
        // Dashboard - Visible para todos
        _buildMenuItem(
          icon: Icons.dashboard,
          label: 'Dashboard',
          route: '/dashboard',
          isAdmin: false,
        ),

        // Menú para Asesores (si tiene rol ASESOR, sin importar si también es ADMIN)
        if (userProvider.isAsesor) ...[
          _buildMenuItem(
            icon: Icons.shopping_cart,
            label: 'Crear Pedido',
            route: '/asesor-pedidos',
            isAdmin: false,
          ),
          _buildMenuItem(
            icon: Icons.request_quote,
            label: 'Cotización',
            route: '/cotizaciones',
            isAdmin: false,
          ),
          _buildMenuItem(
            icon: Icons.people,
            label: 'Clientes',
            route: '/clientes',
            isAdmin: false,
          ),
          _buildMenuItem(
            icon: Icons.description,
            label: 'Documentos',
            route: '/facturas-lista',
            isAdmin: false,
          ),
          _buildMenuItem(
            icon: Icons.account_balance,
            label: 'Facturas DIAN',
            route: '/facturacion-electronica',
            isAdmin: false,
          ),
        ],

        // Menú para Admins y SuperAdmins (solo si NO es asesor)
        if (!userProvider.isAsesor) ...[
          // Sección Ventas y Facturación
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
          
          // Pedidos (expandible)
          _buildExpandableMenuItem(
            icon: Icons.assignment,
            label: 'Pedidos',
            isAdmin: true,
            subItems: [
              _SubMenuItem(
                icon: Icons.receipt_long,
                label: 'Todos los Pedidos',
                route: '/pedidos',
              ),
              _SubMenuItem(
                icon: Icons.local_shipping,
                label: 'Pedidos RT',
                route: '/pedidos_rt',
              ),
              _SubMenuItem(
                icon: Icons.block,
                label: 'Cancelados',
                route: '/pedidos_cancelados',
              ),
              _SubMenuItem(
                icon: Icons.card_giftcard,
                label: 'Cortesía',
                route: '/pedidos_cortesia',
              ),
              _SubMenuItem(
                icon: Icons.home_work,
                label: 'Internos',
                route: '/pedidos_internos',
              ),
              _SubMenuItem(
                icon: Icons.delete_sweep,
                label: 'Eliminar Pedidos',
                route: '/eliminar-pedidos',
              ),
            ],
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
          _buildMenuItem(
            icon: Icons.account_balance,
            label: 'Facturas DIAN',
            route: '/facturacion-electronica',
            isAdmin: true,
          ),

          // Compras y Gastos
          _buildExpandableMenuItem(
            icon: Icons.shopping_cart,
            label: 'Compras y Gastos',
            isAdmin: true,
            subItems: [
              _SubMenuItem(
                icon: Icons.people_outline,
                label: 'Proveedores',
                route: '/proveedores',
              ),
              _SubMenuItem(
                icon: Icons.list_alt,
                label: 'Lista de Compras',
                route: '/compras',
              ),
              _SubMenuItem(
                icon: Icons.add_shopping_cart,
                label: 'Crear Compra',
                route: '/facturas-compras',
              ),
              _SubMenuItem(
                icon: Icons.receipt_long,
                label: 'Lista de Gastos',
                route: '/gastos-lista',
              ),
              _SubMenuItem(
                icon: Icons.add_circle_outline,
                label: 'Crear Gasto',
                route: '/gastos',
              ),
              _SubMenuItem(
                icon: Icons.category,
                label: 'Tipos de Gasto',
                route: '/tipos-gasto',
              ),
            ],
          ),

          // Cartera
          _buildExpandableMenuItem(
            icon: Icons.account_balance_wallet,
            label: 'Cartera',
            isAdmin: true,
            subItems: [
              _SubMenuItem(
                icon: Icons.receipt_long,
                label: 'Resumen',
                route: '/cartera',
              ),
              _SubMenuItem(
                icon: Icons.account_balance,
                label: 'Cuentas por Cobrar',
                route: '/cuentas-por-cobrar',
              ),
              _SubMenuItem(
                icon: Icons.payment,
                label: 'Cuentas por Pagar',
                route: '/cuentas-por-pagar',
              ),
              _SubMenuItem(
                icon: Icons.schedule,
                label: 'Gastos Programados',
                route: '/gastos-programados',
              ),
            ],
          ),

          // Caja
          _buildExpandableMenuItem(
            icon: Icons.attach_money,
            label: 'Caja',
            isAdmin: true,
            subItems: [
              _SubMenuItem(
                icon: Icons.check_circle,
                label: 'Abrir Caja',
                route: '/abrir_caja',
              ),
              _SubMenuItem(
                icon: Icons.assignment_turned_in,
                label: 'Cuadre Caja',
                route: '/cuadre_caja',
              ),
              _SubMenuItem(
                icon: Icons.close_fullscreen,
                label: 'Cerrar Caja',
                route: '/cerrar_caja',
              ),
              _SubMenuItem(
                icon: Icons.money,
                label: 'Ingresos Caja',
                route: '/ingresos-caja',
              ),
            ],
          ),

          // Inventario
          _buildExpandableMenuItem(
            icon: Icons.inventory,
            label: 'Inventario',
            isAdmin: true,
            subItems: [
              _SubMenuItem(
                icon: Icons.list_alt,
                label: 'Lista Productos',
                route: '/productos-lista',
              ),
              _SubMenuItem(
                icon: Icons.dashboard_customize,
                label: 'Productos',
                route: '/productos',
              ),
              _SubMenuItem(
                icon: Icons.warehouse,
                label: 'Bodegas',
                route: '/bodegas',
              ),
              _SubMenuItem(
                icon: Icons.local_shipping,
                label: 'Traslados',
                route: '/traslados',
              ),
            ],
          ),

          // Reportes y Análisis
          _buildExpandableMenuItem(
            icon: Icons.bar_chart,
            label: 'Reportes',
            isAdmin: true,
            subItems: [
              _SubMenuItem(
                icon: Icons.assessment,
                label: 'Reportes Generales',
                route: '/reportes',
              ),
              _SubMenuItem(
                icon: Icons.trending_up,
                label: 'Ventas',
                route: '/reportes/ventas',
              ),
              _SubMenuItem(
                icon: Icons.inventory_2,
                label: 'Productos',
                route: '/reportes/productos',
              ),
              _SubMenuItem(
                icon: Icons.shopping_cart,
                label: 'Pedidos',
                route: '/reportes/pedidos',
              ),
              _SubMenuItem(
                icon: Icons.people,
                label: 'Clientes',
                route: '/reportes/clientes',
              ),
              _SubMenuItem(
                icon: Icons.analytics,
                label: 'Análisis Ventas',
                route: '/informes/productos',
              ),
            ],
          ),

          // Administración
          _buildExpandableMenuItem(
            icon: Icons.admin_panel_settings,
            label: 'Administración',
            isAdmin: true,
            subItems: [
              _SubMenuItem(
                icon: Icons.business,
                label: 'Mi Negocio',
                route: '/negocio-info',
              ),
              _SubMenuItem(
                icon: Icons.notifications_active,
                label: 'Alertas',
                route: '/alertas',
              ),
              _SubMenuItem(
                icon: Icons.vpn_lock,
                label: 'Autorizaciones',
                route: '/autorizaciones',
              ),
              _SubMenuItem(
                icon: Icons.bug_report,
                label: '🧪 Testing Matias',
                route: '/matias-test',
              ),
            ],
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
    bool isDisabled = false,
  }) {
    final isSelected =
        route != null && ModalRoute.of(context)?.settings.name == route;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primary.withOpacity(0.15),
                  AppTheme.secondary.withOpacity(0.08),
                ],
              )
            : LinearGradient(
                colors: [Colors.white.withOpacity(0.5), Colors.transparent],
              ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected
              ? AppTheme.primary.withOpacity(0.4)
              : Colors.grey.withOpacity(0.15),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.2),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
                BoxShadow(
                  color: AppTheme.secondary.withOpacity(0.1),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isDisabled
              ? Colors.grey.shade600
              : (isSelected ? AppTheme.primary : AppTheme.metal),
          size: 24,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isDisabled
                ? Colors.grey.shade600
                : (isSelected ? AppTheme.primary : AppTheme.textSecondary),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 15,
          ),
        ),
        trailing: isDisabled
            ? Icon(Icons.lock_outline, color: Colors.grey.shade600, size: 16)
            : (isExpandable
                  ? Icon(
                      Icons.keyboard_arrow_down,
                      color: AppTheme.metal,
                      size: 20,
                    )
                  : null),
        onTap: (route != null && !isDisabled)
            ? () {
                setState(() {
                  _selectedRoute = route;
                });
                Navigator.pushReplacementNamed(context, route);
              }
            : (isDisabled
                  ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$label - Próximamente'),
                          duration: Duration(seconds: 1),
                          backgroundColor: Colors.grey.shade700,
                        ),
                      );
                    }
                  : null),
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
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.5),
            AppTheme.metal.withOpacity(0.05),
          ],
        ),
        border: Border(
          top: BorderSide(color: AppTheme.primary.withOpacity(0.2), width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.08),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
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
            onPressed: () async {
              await Provider.of<UserProvider>(context, listen: false).logout();
              Navigator.pushReplacementNamed(context, '/login');
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
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: isExpanded
                  ? LinearGradient(
                      colors: [
                        AppTheme.secondary.withOpacity(0.12),
                        AppTheme.primary.withOpacity(0.06),
                      ],
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.4),
                        Colors.transparent,
                      ],
                    ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isExpanded
                    ? AppTheme.secondary.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.1),
                width: isExpanded ? 1.5 : 1,
              ),
              boxShadow: isExpanded
                  ? [
                      BoxShadow(
                        color: AppTheme.secondary.withOpacity(0.15),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
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
        margin: EdgeInsets.only(left: 20, right: 8, top: 2, bottom: 2),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AppTheme.primary.withOpacity(0.12),
                    AppTheme.secondary.withOpacity(0.06),
                  ],
                )
              : LinearGradient(
                  colors: [Colors.white.withOpacity(0.3), Colors.transparent],
                ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary.withOpacity(0.3)
                : Colors.grey.withOpacity(0.1),
            width: isSelected ? 1.5 : 0.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.12),
                    blurRadius: 5,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
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
