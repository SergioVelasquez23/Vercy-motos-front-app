import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Widget base para mantener consistencia en las pantallas de pedidos
abstract class BasePedidosScreen extends StatefulWidget {
  final String title;
  final Color themeColor;
  final IconData titleIcon;

  const BasePedidosScreen({
    super.key,
    required this.title,
    required this.themeColor,
    required this.titleIcon,
  });
}

abstract class BasePedidosScreenState<T extends BasePedidosScreen>
    extends State<T> {
  // Colores base consistentes (redirigen a AppTheme)
  Color get primary => AppTheme.primary;
  Color get bgDark => Theme.of(context).scaffoldBackgroundColor;
  Color get cardBg => Theme.of(context).colorScheme.surface;
  Color get textDark => Theme.of(context).colorScheme.onSurface;
  Color get textLight => Theme.of(context).colorScheme.onSurface.withOpacity(0.6);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(widget.titleIcon, color: Colors.white),
            SizedBox(width: 8),
            Text(widget.title, style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: widget.themeColor,
        elevation: 0,
        actions: buildAppBarActions(),
      ),
      body: buildBody(),
      floatingActionButton: buildFloatingActionButton(),
    );
  }

  /// Construye el cuerpo principal de la pantalla
  Widget buildBody();

  /// Construye las acciones del AppBar (opcional)
  List<Widget>? buildAppBarActions() => null;

  /// Construye el FloatingActionButton (opcional)
  Widget? buildFloatingActionButton() => null;

  /// Formatea números como moneda
  String formatearMoneda(double valor) {
    return '\$${valor.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  /// Formatea fechas de manera consistente
  String formatearFecha(DateTime fecha) {
    return '${fecha.day}/${fecha.month}/${fecha.year} ${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}';
  }

  /// Widget para mostrar estado vacío
  Widget buildEstadoVacio({
    required IconData icono,
    required String mensaje,
    String? submensaje,
    VoidCallback? onAccion,
    String? textoAccion,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 64, color: textLight),
          SizedBox(height: 16),
          Text(
            mensaje,
            style: TextStyle(
              color: textLight,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (submensaje != null) ...[
            SizedBox(height: 8),
            Text(
              submensaje,
              style: TextStyle(color: textLight.withOpacity(0.7), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
          if (onAccion != null && textoAccion != null) ...[
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAccion,
              icon: Icon(Icons.add),
              label: Text(textoAccion),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.themeColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
