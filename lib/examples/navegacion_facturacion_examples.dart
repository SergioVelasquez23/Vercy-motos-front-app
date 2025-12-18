import 'package:flutter/material.dart';
import '../screens/configuracion_facturacion_screen.dart';
import '../screens/prueba_facturacion_screen.dart';

/// Widget de ejemplo para agregar al menú de administración
///
/// Puedes usar esto como referencia para agregar las pantallas
/// de facturación a tu sistema de navegación existente.
class MenuFacturacionElectronica extends StatelessWidget {
  const MenuFacturacionElectronica({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.receipt_long, color: Colors.blue),
            title: const Text('Facturación Electrónica'),
            subtitle: const Text('Configuración y pruebas DIAN'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              _mostrarMenuFacturacion(context);
            },
          ),
        ],
      ),
    );
  }

  void _mostrarMenuFacturacion(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.blue),
              title: const Text('Configuración'),
              subtitle: const Text('Datos de la empresa y autorización DIAN'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const ConfiguracionFacturacionScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.science, color: Colors.orange),
              title: const Text('Pruebas'),
              subtitle: const Text('Generar facturas de prueba'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PruebaFacturacionScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Ejemplo de cómo agregar al drawer/menú lateral
class EjemploDrawerConFacturacion extends StatelessWidget {
  const EjemploDrawerConFacturacion({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Text(
              'Menú',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),

          // ... otros items del menú ...
          const Divider(),

          // Sección de Facturación
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Facturación Electrónica'),
            trailing: const Icon(Icons.arrow_drop_down),
            onTap: () {
              // Abrir submenu o navegar
            },
          ),

          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.settings, size: 20),
                  title: const Text('Configuración'),
                  onTap: () {
                    Navigator.pop(context); // Cerrar drawer
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const ConfiguracionFacturacionScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.science, size: 20),
                  title: const Text('Pruebas'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PruebaFacturacionScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const Divider(),

          // ... más items del menú ...
        ],
      ),
    );
  }
}

/// Ejemplo de botones en AppBar
class EjemploAppBarConFacturacion extends StatelessWidget
    implements PreferredSizeWidget {
  const EjemploAppBarConFacturacion({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Mi Restaurante'),
      actions: [
        // Botón de pruebas (solo en desarrollo)
        if (const bool.fromEnvironment('dart.vm.product') == false)
          IconButton(
            icon: const Icon(Icons.science),
            tooltip: 'Pruebas de Facturación',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PruebaFacturacionScreen(),
                ),
              );
            },
          ),

        // Botón de configuración
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'config_facturacion') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ConfiguracionFacturacionScreen(),
                ),
              );
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'config_facturacion',
              child: ListTile(
                leading: Icon(Icons.receipt_long),
                title: Text('Facturación Electrónica'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Ejemplo de navegación directa desde un botón
class EjemploBotonDirecto extends StatelessWidget {
  const EjemploBotonDirecto({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Botón para configuración
        ElevatedButton.icon(
          icon: const Icon(Icons.settings),
          label: const Text('Configurar Facturación'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ConfiguracionFacturacionScreen(),
              ),
            );
          },
        ),

        const SizedBox(width: 8),

        // Botón para pruebas
        OutlinedButton.icon(
          icon: const Icon(Icons.science),
          label: const Text('Probar'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PruebaFacturacionScreen(),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Ejemplo de navegación con named routes
///
/// Primero define las rutas en tu MaterialApp:
///
/// ```dart
/// MaterialApp(
///   routes: {
///     '/facturacion/config': (context) => ConfiguracionFacturacionScreen(),
///     '/facturacion/pruebas': (context) => PruebaFacturacionScreen(),
///   },
/// )
/// ```
///
/// Luego navega así:
class EjemploNamedRoutes extends StatelessWidget {
  const EjemploNamedRoutes({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            Navigator.pushNamed(context, '/facturacion/config');
          },
          child: const Text('Configuración'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pushNamed(context, '/facturacion/pruebas');
          },
          child: const Text('Pruebas'),
        ),
      ],
    );
  }
}
