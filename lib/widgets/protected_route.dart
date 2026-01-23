import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/permissions_service.dart';
import '../providers/user_provider.dart';

class ProtectedRoute extends StatelessWidget {
  final Widget child;
  final bool requiereFacturacion;
  final bool requiereInventario;
  final bool requiereReportes;
  final bool requiereConfiguracion;

  const ProtectedRoute({
    super.key,
    required this.child,
    this.requiereFacturacion = false,
    this.requiereInventario = false,
    this.requiereReportes = false,
    this.requiereConfiguracion = false,
  });

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    // Obtener el primer rol del usuario (rol principal)
    final rol = userProvider.roles.isNotEmpty ? userProvider.roles.first : null;

    // Verificar permisos según los requisitos
    bool tienePermiso = true;
    String? mensajeError;

    if (requiereFacturacion &&
        !PermissionsService.puedeAccederFacturacion(rol)) {
      tienePermiso = false;
      mensajeError = PermissionsService.getMensajeRestriccion(rol);
    } else if (requiereInventario &&
        !PermissionsService.puedeAccederInventario(rol)) {
      tienePermiso = false;
      mensajeError = 'No tienes permisos para acceder al inventario.';
    } else if (requiereReportes &&
        !PermissionsService.puedeAccederReportes(rol)) {
      tienePermiso = false;
      mensajeError = 'No tienes permisos para acceder a los reportes.';
    } else if (requiereConfiguracion &&
        !PermissionsService.puedeAccederConfiguracion(rol)) {
      tienePermiso = false;
      mensajeError =
          'Solo los administradores pueden acceder a la configuración.';
    }

    // Si no tiene permiso, mostrar diálogo y redirigir
    if (!tienePermiso) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mostrarDialogoRestriccion(context, rol, mensajeError!);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return child;
  }

  void _mostrarDialogoRestriccion(
    BuildContext context,
    String? rol,
    String mensaje,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock, color: Colors.red),
            SizedBox(width: 8),
            Text('Acceso Restringido'),
          ],
        ),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushReplacementNamed(
                context,
                PermissionsService.getRutaInicioPorRol(rol),
              );
            },
            child: Text('Entendido'),
          ),
        ],
      ),
    );
  }
}
