import 'package:flutter/material.dart';
import '../services/user_management_service.dart';
import '../theme/app_theme.dart';

class AutorizacionesScreen extends StatefulWidget {
  const AutorizacionesScreen({super.key});

  @override
  State<AutorizacionesScreen> createState() => _AutorizacionesScreenState();
}

class _AutorizacionesScreenState extends State<AutorizacionesScreen> {
  final UserManagementService _userService = UserManagementService();
  List<Map<String, dynamic>> _usuariosPendientes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarUsuariosPendientes();
  }

  Future<void> _cargarUsuariosPendientes() async {
    setState(() => _isLoading = true);
    try {
      final usuarios = await _userService.getUsersPendientesAutorizacion();
      setState(() {
        _usuariosPendientes = usuarios;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar usuarios: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _autorizarUsuario(String userId, String nombre) async {
    final resultado = await _userService.autorizarUsuario(userId);

    if (resultado['success']) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $nombre autorizado'),
            backgroundColor: AppTheme.success,
          ),
        );
        await _cargarUsuariosPendientes();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${resultado['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _negarUsuario(String userId, String nombre) async {
    final resultado = await _userService.negarUsuario(userId);

    if (resultado['success']) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $nombre denegado'),
            backgroundColor: Colors.orange,
          ),
        );
        await _cargarUsuariosPendientes();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${resultado['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                isMobile ? 'Pendientes de Autorización' : 'Usuarios Pendientes de Autorización',
                style: TextStyle(
                  fontSize: isMobile ? 18 : 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _cargarUsuariosPendientes,
                icon: Icon(Icons.refresh, color: Colors.white),
                label: Text(
                  'Recargar',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 24),

          // Contenido
          if (_isLoading)
            Center(child: CircularProgressIndicator(color: AppTheme.primary))
          else if (_usuariosPendientes.isEmpty)
            Center(
              child: Container(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 64,
                      color: AppTheme.success,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No hay usuarios pendientes',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                    Text(
                      'Todos los usuarios han sido autorizados',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: _usuariosPendientes.map((usuario) {
                    return _buildTarjetaUsuario(usuario);
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTarjetaUsuario(Map<String, dynamic> usuario) {
    final id = usuario['id'] ?? usuario['_id'] ?? '';
    final email = usuario['email'] ?? 'Sin email';
    final nombre = usuario['nombre'] ?? usuario['username'] ?? 'Sin nombre';
    final fechaCreacion =
        usuario['fechaCreacion'] ?? usuario['createdAt'] ?? '';
    final rol = usuario['roles']?.isNotEmpty == true
        ? usuario['roles'][0]
        : 'No asignado';

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            rol,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Creado: $fechaCreacion',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Divider(color: Colors.grey.shade700),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () => _negarUsuario(id, nombre),
                icon: Icon(Icons.close, color: Colors.white),
                label: Text('Denegar', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                ),
              ),
              SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _autorizarUsuario(id, nombre),
                icon: Icon(Icons.check_circle, color: Colors.white),
                label: Text('Autorizar', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
