import 'package:flutter/material.dart';
import '../services/user_management_service.dart';
import '../services/role_service.dart';
import '../services/user_role_service.dart';
import '../models/role.dart';
import '../theme/app_theme.dart';
import '../utils/api_error.dart';
import '../utils/dialogs_helper.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final UserManagementService _userService = UserManagementService();
  final RoleService _roleService = RoleService();
  final UserRoleService _userRoleService = UserRoleService();
  List<Map<String, dynamic>> _users = [];
  List<Role> _roles = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadRoles();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final users = await _userService.getAllUsers();
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar usuarios: ${errorMessage(e)}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRoles() async {
    try {
      final roles = await _roleService.getRoles();
      if (mounted) setState(() => _roles = roles);
    } catch (e) {
      // El diálogo de cambio de rol valida _roles.isEmpty antes de guardar.
    }
  }

  Future<void> _showEditRoleDialog(Map<String, dynamic> user) async {
    final roles = user['roles'] as List<dynamic>? ?? ['asesor'];
    String selectedRole = roles.isNotEmpty ? roles.first.toString() : 'asesor';
    final availableRoles = ['admin', 'gerente', 'cajero', 'asesor'];

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            'Cambiar Rol de ${user['name'] ?? user['nombre'] ?? 'Usuario'}',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Email: ${user['email']}',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 14),
              ),
              SizedBox(height: 8),
              Text(
                'Rol actual: ${_formatRoleName(selectedRole)}',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 14),
              ),
              SizedBox(height: 24),
              Text(
                'Seleccionar nuevo rol:',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              ...availableRoles.map((role) {
                final isSelected = selectedRole.toLowerCase() == role;
                return RadioListTile<String>(
                  title: Text(
                    _formatRoleName(role),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  ),
                  subtitle: Text(
                    _getRoleDescription(role),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                  value: role,
                  groupValue: selectedRole,
                  activeColor: AppTheme.primary,
                  onChanged: (value) {
                    setDialogState(() {
                      selectedRole = value!;
                    });
                  },
                );
              }).toList(),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, selectedRole),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result != selectedRole) {
      final userId = user['_id'] ?? user['id'];
      if (userId != null) {
        await _updateUserRole(userId.toString(), result);
      }
    }
  }

  // Antes esto llamaba a UserManagementService.updateUserRole(), que le pega
  // a PUT /users/{id}/role — un endpoint que no existe en el backend
  // (UsersControllers solo tiene PUT /api/users/{id} para datos básicos, y ni
  // siquiera con el prefijo /api correcto). El cambio de rol nunca se
  // guardaba: el usuario se quedaba con el rol que ya tenía (normalmente
  // "asesor", el que se asigna por defecto al crear la cuenta). Ahora usa el
  // mismo mecanismo real que ya funciona en UsersScreen: los roles viven en
  // una colección UserRole aparte (User <-> Role), así que hay que borrar la
  // relación vieja y crear la nueva por roleId, no mandar el nombre del rol
  // como si fuera un campo del usuario.
  Future<void> _updateUserRole(String userId, String newRoleName) async {
    final nuevoRol = _roles.firstWhere(
      (r) => r.nombre.toLowerCase() == newRoleName.toLowerCase(),
      orElse: () => Role(nombre: ''),
    );
    if (nuevoRol.id == null) {
      showErrorDialog(
        context,
        'No se encontró el rol "$newRoleName" en el servidor. Refresca la pantalla e intenta de nuevo.',
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
        ),
      ),
    );

    try {
      final relacionesActuales = await _userRoleService.getRolesByUser(userId);
      for (final relacion in relacionesActuales) {
        if (relacion.id != null) {
          await _userRoleService.deleteUserRole(relacion.id!);
        }
      }

      await _userRoleService.assignRoleToUser(userId, nuevoRol.id!);

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rol actualizado a "${_formatRoleName(newRoleName)}" correctamente'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadUsers();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      showErrorDialog(context, 'Error al actualizar el rol: ${errorMessage(e)}');
    }
  }

  Future<void> _toggleUserStatus(Map<String, dynamic> user) async {
    final newStatus = !(user['activo'] ?? true);
    final nombre = user['name'] ?? user['nombre'] ?? 'este usuario';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          newStatus ? 'Activar Usuario' : 'Desactivar Usuario',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          newStatus
              ? '¿Deseas activar a $nombre?'
              : '¿Deseas desactivar a $nombre? No podrá acceder al sistema.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus ? Colors.green : Colors.red,
            ),
            child: Text(newStatus ? 'Activar' : 'Desactivar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final userId = user['_id'] ?? user['id'];
      if (userId == null) return;

      final result = await _userService.toggleUserStatus(
        userId.toString(),
        newStatus,
      );
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.green,
          ),
        );
        await _loadUsers();
      } else {
        showErrorDialog(context, result['message']);
      }
    }
  }

  String _formatRoleName(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Administrador';
      case 'gerente':
        return 'Gerente';
      case 'cajero':
        return 'Cajero';
      case 'asesor':
        return 'Asesor';
      default:
        return role;
    }
  }

  String _getRoleDescription(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Acceso completo a todas las funciones';
      case 'gerente':
        return 'Acceso a inventario, reportes y facturación';
      case 'cajero':
        return 'Acceso a facturación y caja';
      case 'asesor':
        return 'Solo puede crear pedidos';
      default:
        return '';
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.purple;
      case 'gerente':
        return Colors.blue;
      case 'cajero':
        return Colors.orange;
      case 'asesor':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                ),
              )
            : _errorMessage != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red),
                    SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadUsers,
                      child: Text('Reintentar'),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadUsers,
                child: _users.isEmpty
                    ? Center(
                        child: Text(
                          'No hay usuarios registrados',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          return _buildUserCard(user);
                        },
                      ),
              ),
      );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final nombre = user['name'] ?? user['nombre'] ?? 'Sin nombre';
    final email = user['email'] ?? 'Sin email';
    final roles = user['roles'] as List<dynamic>? ?? ['asesor'];
    final rol = roles.isNotEmpty ? roles.first.toString() : 'asesor';
    final activo = user['activo'] ?? true;
    final fechaCreacion = user['createdAt'] != null
        ? DateTime.tryParse(user['createdAt'])
        : null;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      color: Theme.of(context).colorScheme.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getRoleColor(rol),
                  radius: 24,
                  child: Text(
                    nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: activo
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: activo ? Colors.green : Colors.red,
                    ),
                  ),
                  child: Text(
                    activo ? 'Activo' : 'Inactivo',
                    style: TextStyle(
                      color: activo ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getRoleColor(rol).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _getRoleColor(rol)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.security, size: 16, color: _getRoleColor(rol)),
                      SizedBox(width: 4),
                      Text(
                        _formatRoleName(rol),
                        style: TextStyle(
                          color: _getRoleColor(rol),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.edit, color: AppTheme.primary),
                  onPressed: () => _showEditRoleDialog(user),
                  tooltip: 'Cambiar rol',
                ),
                IconButton(
                  icon: Icon(
                    activo ? Icons.block : Icons.check_circle,
                    color: activo ? Colors.red : Colors.green,
                  ),
                  onPressed: () => _toggleUserStatus(user),
                  tooltip: activo ? 'Desactivar' : 'Activar',
                ),
              ],
            ),
            if (fechaCreacion != null) ...[
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Registrado: ${_formatDate(fechaCreacion)}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Hoy';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
