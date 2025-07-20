import 'package:flutter/material.dart';
import 'cuadre_caja_screen.dart';
import 'documentos_screen.dart';
import 'pedidos_screen_fusion.dart';

class VentasScreen extends StatefulWidget {
  final int initialIndex;

  // Constructor que acepta un parámetro opcional para la pestaña inicial
  const VentasScreen({Key? key, this.initialIndex = 0}) : super(key: key);

  _VentasScreenState createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  final Color primary = Color(0xFFFF6B00); // Color naranja fuego
  final Color bgDark = Color(0xFF1E1E1E); // Color de fondo negro
  final Color cardBg = Color(0xFF252525); // Color de tarjetas
  final Color textLight = Color(0xFFE0E0E0); // Color de texto claro
  final Color accentOrange = Color(0xFFFF8800); // Naranja más brillante

  // Estado para rastrear qué pantalla estamos mostrando
  late String _currentScreen;

  @override
  void initState() {
    super.initState();
    // Inicializar _currentScreen según el initialIndex
    switch (widget.initialIndex) {
      case 0:
        _currentScreen = 'cuadre_caja';
        break;
      case 1:
        _currentScreen = 'pedidos';
        break;
      case 2:
        _currentScreen = 'pantalla_digital';
        break;
      case 3:
        _currentScreen = 'pedidos_rt';
        break;
      case 4:
        _currentScreen = 'documentos';
        break;
      case 5:
        _currentScreen = 'pedidos_cancelados';
        break;
      case 6:
        _currentScreen = 'pedidos_cortesia';
        break;
      case 7:
        _currentScreen = 'pedidos_internos';
        break;
      default:
        _currentScreen = 'cuadre_caja';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        title: Text('Ventas', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primary,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Sergio', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, color: primary),
                ),
              ],
            ),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: bgDark,
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [primary, accentOrange],
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.point_of_sale, color: Colors.white, size: 30),
                    SizedBox(width: 10),
                    Text(
                      'Ventas',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: Offset(1, 1),
                            blurRadius: 3,
                            color: Colors.black.withOpacity(0.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildDrawerItem(
              icon: Icons.assessment,
              text: 'Cuadre de caja',
              iconColor: primary,
              onTap: () => _changeScreen('cuadre_caja'),
              trailingIcon: null,
            ),
            _buildDrawerItem(
              icon: Icons.shopping_cart,
              text: 'Pedidos',
              iconColor: primary,
              onTap: () => _changeScreen('pedidos'),
              trailingIcon: null,
            ),
            _buildDrawerItem(
              icon: Icons.computer,
              text: 'Pantalla Digital de Comandas',
              iconColor: primary,
              onTap: () => _changeScreen('pantalla_comandas'),
              trailingIcon: Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Nuevo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            _buildDrawerItem(
              icon: Icons.fastfood,
              text: 'Pedidos RT',
              iconColor: primary,
              onTap: () => _changeScreen('pedidos_rt'),
              trailingIcon: null,
            ),
            _buildDrawerItem(
              icon: Icons.description,
              text: 'Documentos',
              iconColor: primary,
              onTap: () => _changeScreen('documentos'),
              trailingIcon: null,
            ),
            _buildDrawerItem(
              icon: Icons.cancel,
              text: 'Pedidos cancelados',
              iconColor: primary,
              onTap: () => _changeScreen('pedidos_cancelados'),
              trailingIcon: null,
            ),
            _buildDrawerItem(
              icon: Icons.card_giftcard,
              text: 'Pedidos de cortesía',
              iconColor: primary,
              onTap: () => _changeScreen('pedidos_cortesia'),
              trailingIcon: null,
            ),
            _buildDrawerItem(
              icon: Icons.business,
              text: 'Pedidos Internos',
              iconColor: primary,
              onTap: () => _changeScreen('pedidos_internos'),
              trailingIcon: null,
            ),
            Spacer(),
            Divider(color: Colors.grey.withOpacity(0.3)),
            _buildDrawerItem(
              icon: Icons.home,
              text: 'Dashboard',
              iconColor: primary,
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacementNamed('/dashboard');
              },
              trailingIcon: null,
            ),
          ],
        ),
      ),
      body: _getScreenWidget(),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String text,
    required Color iconColor,
    required VoidCallback onTap,
    required Widget? trailingIcon,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(text, style: TextStyle(color: textLight)),
      trailing: trailingIcon,
      onTap: onTap,
    );
  }

  void _changeScreen(String screenName) {
    setState(() {
      _currentScreen = screenName;
    });
    Navigator.of(context).pop(); // Cerrar drawer
  }

  Widget _getScreenWidget() {
    switch (_currentScreen) {
      case 'cuadre_caja':
        return _buildCuadreCajaScreen();
      case 'pedidos':
        return _buildPedidosScreen();
      case 'pantalla_comandas':
        return _buildPantallaCommandasScreen();
      case 'pedidos_rt':
        return _buildPedidosRTScreen();
      case 'documentos':
        return _buildDocumentosScreen();
      case 'pedidos_cancelados':
        return _buildPedidosCanceladosScreen();
      case 'pedidos_cortesia':
        return _buildPedidosCortesiaScreen();
      case 'pedidos_internos':
        return _buildPedidosInternosScreen();
      default:
        return _buildVentasDashboard();
    }
  }

  // Construir cada pantalla
  Widget _buildVentasDashboard() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.point_of_sale, size: 100, color: primary.withOpacity(0.8)),
          SizedBox(height: 20),
          Text(
            'Panel de Ventas',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textLight,
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Selecciona una opción del menú lateral',
            style: TextStyle(fontSize: 16, color: textLight.withOpacity(0.7)),
          ),
          SizedBox(height: 30),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              _buildQuickAccessCard(
                'Cuadre de Caja',
                Icons.assessment,
                () => _changeScreen('cuadre_caja'),
              ),
              _buildQuickAccessCard(
                'Pedidos',
                Icons.shopping_cart,
                () => _changeScreen('pedidos'),
              ),
              _buildQuickAccessCard(
                'Comandas',
                Icons.computer,
                () => _changeScreen('pantalla_comandas'),
              ),
              _buildQuickAccessCard(
                'Documentos',
                Icons.description,
                () => _changeScreen('documentos'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessCard(
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 150,
        height: 100,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 3,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: primary, size: 40),
            SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(color: textLight, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCuadreCajaScreen() {
    return CuadreCajaScreen();
  }

  Widget _buildPedidosScreen() {
    // Aquí directamente devolvemos el PedidosScreenFusion para evitar problemas de navegación
    return const PedidosScreenFusion();
  }

  Widget _buildPantallaCommandasScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              Icon(Icons.computer, size: 100, color: primary.withOpacity(0.8)),
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'NUEVO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Text(
            'Pantalla Digital de Comandas',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textLight,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Funcionalidad en desarrollo',
            style: TextStyle(color: textLight.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildPedidosRTScreen() {
    return PedidosScreenFusion();
  }

  Widget _buildDocumentosScreen() {
    return const DocumentosScreen();
  }

  Widget _buildPedidosCanceladosScreen() {
    return PedidosScreenFusion();
  }

  Widget _buildPedidosCortesiaScreen() {
    return PedidosScreenFusion();
  }

  Widget _buildPedidosInternosScreen() {
    return PedidosScreenFusion();
  }
}
