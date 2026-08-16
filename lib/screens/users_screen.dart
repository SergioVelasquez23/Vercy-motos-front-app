import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/role.dart';
import '../models/user_role.dart';
import '../services/user_service.dart';
import '../services/role_service.dart';
import '../services/user_role_service.dart';
import '../theme/app_theme.dart';
import '../utils/api_error.dart';
import '../utils/dialogs_helper.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final UserService _userService = UserService();
  final RoleService _roleService = RoleService();
  final UserRoleService _userRoleService = UserRoleService();

  List<User> _users = [];
  List<Role> _roles = [];
  Map<String, List<Role>> _userRolesMap = {};
  bool _isLoading = true;
  String _searchText = '';
  final TextEditingController _searchController = TextEditingController();

  // Control para evitar sobrescribir roles recién modificados
  Set<String> _usuariosConRolRecienCambiado = {};

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
        

      // Cargar usuarios y roles en paralelo para ahorrar tiempo
      final futures = await Future.wait([
        _userService.getUsers(),
        _roleService.getRoles(),
      ]);

      final usersResult = futures[0] as List<User>;
      final rolesResult = futures[1] as List<Role>;

        
        

      // Actualizar UI inicialmente con los usuarios y roles sin esperar a obtener todos los roles
      setState(() {
        _users = usersResult;
        _roles = rolesResult;
        _isLoading = false;
      });

      // Obtener roles en segundo plano para no bloquear la UI
      _cargarRolesUsuariosEnSegundoPlano(usersResult);

        
    } catch (e, stackTrace) {
        
        

      setState(() => _isLoading = false);
      if (mounted) {
        showErrorDialog(context, 'Error al cargar datos: ${errorMessage(e)}');
      }
    }
  }

  // Método para cargar los roles de los usuarios en segundo plano
  Future<void> _cargarRolesUsuariosEnSegundoPlano(List<User> users) async {
    try {
      Map<String, List<Role>> userRolesMap = {};

      // Crear una lista de futures para obtener los roles de todos los usuarios en paralelo
      final futures = users.where((user) => user.id != null).map((user) async {
        try {
          final roles = await _userService.getRolesByUserId(user.id!);
          return MapEntry(user.id!, roles);
        } catch (e) {
            
          return MapEntry(user.id!, <Role>[]);
        }
      });

      // Ejecutar todas las solicitudes en paralelo
      final results = await Future.wait(futures);

      // Construir el mapa con los resultados
      for (final entry in results) {
        // No sobrescribir si el usuario tuvo un cambio de rol reciente
        if (!_usuariosConRolRecienCambiado.contains(entry.key)) {
          userRolesMap[entry.key] = entry.value;
          // Log detallado de los roles cargados
          if (entry.value.isNotEmpty) {
                         } else {
              
          }
        } else {
                     }
      }

      // Actualizar el estado con los roles cargados
      if (mounted) {
        setState(() {
          _userRolesMap = userRolesMap;
        });
      }

    } catch (e) {
        
    }
  }

  // Método para actualizar roles de un usuario específico
  Future<void> _actualizarRolesUsuarioEspecifico(String userId) async {
    try {
                  
      // Intentar múltiples veces con delay para asegurar sincronización
      List<Role> roles = [];
      int intentos = 0;
      const maxIntentos = 3;

      while (intentos < maxIntentos) {
        try {
          intentos++;
            

          roles = await _userService.getRolesByUserId(userId);
             
          if (roles.isNotEmpty) {
            break; // Éxito, salir del loop
          }

          if (intentos < maxIntentos) {
              
            await Future.delayed(Duration(seconds: 2));
          }
        } catch (e) {
            
          if (intentos < maxIntentos) {
            await Future.delayed(Duration(seconds: 2));
          }
        }
      }

      // Actualizar siempre con la información del servidor (incluso si está vacía)
        
      if (mounted) {
        setState(() {
          _userRolesMap[userId] = roles;
        });
      }

             } catch (e) {
        
    }
  }

  List<User> get _filteredUsers {
    if (_searchText.isEmpty) return _users;
    return _users.where((user) {
      return user.email.toLowerCase().contains(_searchText.toLowerCase()) ||
          (user.nombre?.toLowerCase().contains(_searchText.toLowerCase()) ??
              false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
      
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          // Barra de búsqueda y botón nuevo
          Container(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: context.isMobile ? double.infinity : 360,
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Buscar usuarios...',
                      hintStyle: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4)),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.4),
                      ),
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => _searchText = value);
                    },
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () {
                          _cargarDatos();
                        },
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                  label: const Text(
                    'Refrescar',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    _mostrarDialogoUsuario();
                  },
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'Nuevo',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
              ],
            ),
          ),

          // Lista de usuarios
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF6B00)),
                  )
                : _filteredUsers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchText.isEmpty
                              ? 'No hay usuarios registrados'
                              : 'No se encontraron usuarios',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _cargarDatos,
                    color: AppTheme.primary,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        return _buildUserCard(user);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(User user) {
    // Obtener nombres de roles actuales desde el backend
    final userRoles = _userRolesMap[user.id] ?? [];

    // Ordenar los roles por fecha de actualización (más reciente primero)
    userRoles.sort((a, b) {
      final dateA = a.fechaActualizacion ?? DateTime(1970);
      final dateB = b.fechaActualizacion ?? DateTime(1970);
      return dateB.compareTo(dateA); // Orden descendente
    });

    // Obtener nombres únicos de roles y mostrar solo el más reciente
    final userRoleNames = userRoles.map((role) => role.nombre).toSet().toList();
    final displayedRoles = userRoleNames.isNotEmpty
        ? [userRoleNames.first]
        : [];

    final cs = Theme.of(context).colorScheme;
    final initials = user.displayName.isNotEmpty
        ? user.displayName[0].toUpperCase()
        : '?';
    final nombre = (user.nombre != null && user.nombre!.isNotEmpty)
        ? user.nombre!
        : 'Sin nombre';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primary,
              radius: 22,
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                  if (displayedRoles.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: displayedRoles
                          .map((role) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppTheme.primary
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  role,
                                  style: const TextStyle(
                                    color: Color(0xFFFF6B00),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _mostrarDialogoUsuario(user: user),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  color: AppTheme.primary,
                  tooltip: 'Editar',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: () => _mostrarDialogoRol(user),
                  icon: const Icon(Icons.shield_outlined, size: 20),
                  color: Colors.blue,
                  tooltip: 'Cambiar Rol',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: () => _confirmarEliminar(user),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: Colors.red,
                  tooltip: 'Eliminar',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoUsuario({User? user}) {
    final isEditing = user != null;
    final nombreController = TextEditingController(text: user?.nombre ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            isEditing ? 'Editar Usuario' : 'Nuevo Usuario',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nombre
                TextField(
                  controller: nombreController,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Nombre *',
                    labelStyle: const TextStyle(color: Colors.grey),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[600]!),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFFF6B00)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Email
                TextField(
                  controller: emailController,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Correo electrónico *',
                    labelStyle: const TextStyle(color: Colors.grey),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[600]!),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFFF6B00)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Password (solo para usuarios nuevos o si quiere cambiarla)
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  decoration: InputDecoration(
                    labelText: isEditing
                        ? 'Nueva contraseña (opcional)'
                        : 'Contraseña *',
                    labelStyle: const TextStyle(color: Colors.grey),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[600]!),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFFF6B00)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey[400]),
              ),
            ),
            ElevatedButton(
              onPressed: () => _guardarUsuario(
                isEditing: isEditing,
                user: user,
                nombre: nombreController.text,
                email: emailController.text,
                password: passwordController.text,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
              ),
              child: const Text(
                'Guardar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoRol(User user) {
    String? selectedRoleId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            'Cambiar Rol - ${user.displayName}',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Usuario: ${user.email}',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedRoleId,
                dropdownColor: Colors.grey[800],
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Seleccionar Rol',
                  labelStyle: const TextStyle(color: Colors.grey),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[600]!),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFFF6B00)),
                  ),
                ),
                items: _roles.where((role) => role.id != null).map((role) {
                  return DropdownMenuItem<String>(
                    value: role.id,
                    child: Row(
                      children: [
                        Icon(
                          _getRoleIcon(role.nombre),
                          color: _getRoleColor(role.nombre),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getRoleDisplayName(role.nombre),
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() {
                    selectedRoleId = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey[400]),
              ),
            ),
            ElevatedButton(
              onPressed: selectedRoleId != null
                  ? () => _cambiarRolUsuario(user, selectedRoleId!)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
              ),
              child: const Text(
                'Cambiar Rol',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Funciones auxiliares para roles
  IconData _getRoleIcon(String roleName) {
    final name = roleName.toUpperCase();
    if (name.contains('SUPERADMIN') || name.contains('SUPER ADMIN')) {
      return Icons.admin_panel_settings;
    } else if (name.contains('ADMIN')) {
      return Icons.supervisor_account;
    } else if (name.contains('MESERO')) {
      return Icons.restaurant_menu;
    } else {
      return Icons.person;
    }
  }

  Color _getRoleColor(String roleName) {
    final name = roleName.toUpperCase();
    if (name.contains('SUPERADMIN') || name.contains('SUPER ADMIN')) {
      return Colors.purple;
    } else if (name.contains('ADMIN')) {
      return Colors.orange;
    } else if (name.contains('MESERO')) {
      return Colors.blue;
    } else {
      return Colors.grey;
    }
  }

  String _getRoleDisplayName(String roleName) {
    final name = roleName.toUpperCase();
    if (name.contains('SUPERADMIN') || name.contains('SUPER ADMIN')) {
      return 'Super Administrador';
    } else if (name.contains('ADMIN')) {
      return 'Administrador';
    } else if (name.contains('MESERO')) {
      return 'Mesero';
    } else {
      return roleName;
    }
  }

  // Antes esto tenía sleeps y bucles de reintento/verificación (hasta 3
  // intentos con pausas de 1-1.5s, más una verificación final a los 5s)
  // porque getRolesByUser() nunca lograba encontrar la relación a borrar:
  // pegaba a /api/usersroles/user/{id}, que devuelve el Role (no el
  // UserRole), y el _id igual venía como "_id" mientras el modelo Dart leía
  // "id" — el borrado nunca se ejecutaba (ver getRolesByUser en
  // UserRoleService) y los reintentos solo esperaban algo que no iba a
  // pasar. Ahora que getRolesByUser apunta al endpoint correcto
  // (/relaciones, con el _id real de cada relación), borrar y asignar
  // funciona a la primera — sin necesidad de sleeps ni reintentos.
  Future<void> _cambiarRolUsuario(User user, String roleId) async {
    try {
      final relacionesActuales = await _userRoleService.getRolesByUser(user.id!);
      for (final relacion in relacionesActuales) {
        if (relacion.id != null) {
          final eliminado = await _userRoleService.deleteUserRole(relacion.id!);
          if (!eliminado) {
            throw Exception('No se pudo eliminar el rol anterior (${relacion.id})');
          }
        }
      }

      await _userRoleService.assignRoleToUser(user.id!, roleId);

      final nuevoRol = _roles.firstWhere(
        (role) => role.id == roleId,
        orElse: () => throw Exception('Rol no encontrado en la lista local'),
      );

      if (!mounted) return;

      setState(() {
        _userRolesMap[user.id!] = [nuevoRol];
        // Proteger al usuario de sobrescritura por 30 segundos
        _usuariosConRolRecienCambiado.add(user.id!);
      });

      Timer(Duration(seconds: 30), () {
        if (mounted) {
          setState(() {
            _usuariosConRolRecienCambiado.remove(user.id!);
          });
        }
      });

      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rol cambiado correctamente'),
          backgroundColor: Colors.green,
        ),
      );

      // Confirmar contra el servidor en segundo plano (no bloquea la UI).
      _actualizarRolesUsuarioEspecifico(user.id!);
    } catch (e, stackTrace) {
      debugPrint('💥 [UsersScreen._cambiarRolUsuario] $e');
      debugPrint(stackTrace.toString());
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      if (mounted) {
        showErrorDialog(context, 'Error al cambiar rol: ${errorMessage(e)}');
      }
    }
  }

  Future<void> _guardarUsuario({
    required bool isEditing,
    User? user,
    required String nombre,
    required String email,
    required String password,
  }) async {
    // Validaciones
    if (nombre.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El nombre y email son obligatorios'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!isEditing && password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La contraseña es obligatoria para nuevos usuarios'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Debug: Mostrar datos que se van a enviar
        
        
        
        
         
      // Crear el objeto usuario
      final newUser = User(
        id: user?.id,
        nombre: nombre,
        email: email,
        password: password.isEmpty ? null : password,
        activo: true, // Por defecto activo
      );

        

      if (isEditing) {
        // Actualizar usuario existente
        await _userService.updateUser(newUser);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuario actualizado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Crear nuevo usuario
        await _userService.createUser(newUser);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuario creado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }

      Navigator.pop(context);
      _cargarDatos();
    } catch (e) {
      showErrorDialog(context, 'Error al guardar usuario: ${errorMessage(e)}');
    }
  }

  void _confirmarEliminar(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Confirmar eliminación',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          '¿Está seguro de que desea eliminar al usuario "${user.displayName}"?',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () => _eliminarUsuario(user),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _eliminarUsuario(User user) async {
    try {
      await _userService.deleteUser(user.id!);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usuario eliminado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
      _cargarDatos();
    } catch (e) {
      Navigator.pop(context);
      showErrorDialog(context, 'Error al eliminar usuario: ${errorMessage(e)}');
    }
  }
}
