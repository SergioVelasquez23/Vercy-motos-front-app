import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/role.dart';
import '../services/user_service.dart';
import '../services/role_service.dart';
import '../services/user_role_service.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({Key? key}) : super(key: key);

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final UserService _userService = UserService();
  final RoleService _roleService = RoleService();
  final UserRoleService _userRoleService = UserRoleService();

  List<User> _users = [];
  List<Role> _roles = [];
  bool _isLoading = true;
  String _searchText = '';
  final TextEditingController _searchController = TextEditingController();

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
      print('🔍 Iniciando carga de datos de usuarios y roles...');

      final usersResult = await _userService.getUsers();
      final rolesResult = await _roleService.getRoles();

      print('✅ Usuarios cargados: ${usersResult.length}');
      print('✅ Roles cargados: ${rolesResult.length}');

      setState(() {
        _users = usersResult;
        _roles = rolesResult;
        _isLoading = false;
      });

      print('🎉 Datos cargados exitosamente');
    } catch (e, stackTrace) {
      print('💥 Error al cargar datos: $e');
      print('📍 Stack trace: $stackTrace');

      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
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
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Buscar usuarios...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey[800],
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
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _mostrarDialogoUsuario(),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'Nuevo',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B00),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
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
                    color: const Color(0xFFFF6B00),
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
    return Card(
      color: Colors.grey[850],
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFFF6B00),
                  radius: 24,
                  child: Text(
                    user.displayName.isNotEmpty
                        ? user.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: user.activo ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user.activo ? 'Activo' : 'Inactivo',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Email: ${user.email}',
                  style: TextStyle(color: Colors.grey[300], fontSize: 14),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _mostrarDialogoUsuario(user: user),
                      icon: const Icon(Icons.edit, color: Color(0xFFFF6B00)),
                      tooltip: 'Editar Usuario',
                    ),
                    IconButton(
                      onPressed: () => _mostrarDialogoRol(user),
                      icon: const Icon(
                        Icons.admin_panel_settings,
                        color: Colors.blue,
                      ),
                      tooltip: 'Cambiar Rol',
                    ),
                    IconButton(
                      onPressed: () => _confirmarEliminar(user),
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Eliminar',
                    ),
                  ],
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
          backgroundColor: Colors.grey[900],
          title: Text(
            isEditing ? 'Editar Usuario' : 'Nuevo Usuario',
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nombre
                TextField(
                  controller: nombreController,
                  style: const TextStyle(color: Colors.white),
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
                  style: const TextStyle(color: Colors.white),
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
                  style: const TextStyle(color: Colors.white),
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
                backgroundColor: const Color(0xFFFF6B00),
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
          backgroundColor: Colors.grey[900],
          title: Text(
            'Cambiar Rol - ${user.displayName}',
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Usuario: ${user.email}',
                style: TextStyle(color: Colors.grey[400]),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedRoleId,
                dropdownColor: Colors.grey[800],
                style: const TextStyle(color: Colors.white),
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
                items: _roles.map((role) {
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
                          style: const TextStyle(color: Colors.white),
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
                backgroundColor: const Color(0xFFFF6B00),
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

  Future<void> _cambiarRolUsuario(User user, String roleId) async {
    try {
      print('🔄 Cambiando rol del usuario ${user.email} al rol $roleId');

      await _userRoleService.assignRoleToUser(user.id!, roleId);

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rol cambiado correctamente'),
          backgroundColor: Colors.green,
        ),
      );

      // Recargar datos para mostrar los cambios
      _cargarDatos();
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cambiar rol: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
      print('🔧 DEBUG - Datos a enviar:');
      print('  - isEditing: $isEditing');
      print('  - nombre: "$nombre"');
      print('  - email: "$email"');
      print(
        '  - password: "${password.isEmpty ? "(vacío)" : "(tiene valor)"}"',
      );

      // Crear el objeto usuario
      final newUser = User(
        id: user?.id,
        nombre: nombre,
        email: email,
        password: password.isEmpty ? null : password,
        activo: true, // Por defecto activo
      );

      print('🚀 Objeto User creado: ${newUser.toJsonCreate()}');

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar usuario: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmarEliminar(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Confirmar eliminación',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '¿Está seguro de que desea eliminar al usuario "${user.displayName}"?',
          style: const TextStyle(color: Colors.white),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar usuario: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
