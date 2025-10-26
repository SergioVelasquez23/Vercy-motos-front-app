import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/role.dart';
import '../models/user_role.dart';
import '../services/user_service.dart';
import '../services/role_service.dart';
import '../services/user_role_service.dart';

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

      // Cargar usuarios y roles en paralelo para ahorrar tiempo
      final futures = await Future.wait([
        _userService.getUsers(),
        _roleService.getRoles(),
      ]);

      final usersResult = futures[0] as List<User>;
      final rolesResult = futures[1] as List<Role>;

      print('✅ Usuarios cargados: ${usersResult.length}');
      print('✅ Roles cargados: ${rolesResult.length}');

      // Actualizar UI inicialmente con los usuarios y roles sin esperar a obtener todos los roles
      setState(() {
        _users = usersResult;
        _roles = rolesResult;
        _isLoading = false;
      });

      // Obtener roles en segundo plano para no bloquear la UI
      _cargarRolesUsuariosEnSegundoPlano(usersResult);

      print('🎉 Datos básicos cargados exitosamente');
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
          print('Error obteniendo roles para usuario ${user.id}: $e');
          return MapEntry(user.id!, <Role>[]);
        }
      });

      // Ejecutar todas las solicitudes en paralelo
      final results = await Future.wait(futures);

      // Construir el mapa con los resultados
      for (final entry in results) {
        userRolesMap[entry.key] = entry.value;
        // Log detallado de los roles cargados
        if (entry.value.isNotEmpty) {
          print(
            '📋 Usuario ${entry.key}: roles = ${entry.value.map((r) => r.nombre).join(", ")}',
          );
        } else {
          print('📋 Usuario ${entry.key}: sin roles asignados');
        }
      }

      // Actualizar el estado con los roles cargados
      if (mounted) {
        setState(() {
          _userRolesMap = userRolesMap;
        });
      }

      print(
        '✅ Roles de usuarios cargados en segundo plano - Total usuarios: ${userRolesMap.length}',
      );
    } catch (e) {
      print('💥 Error al cargar roles en segundo plano: $e');
    }
  }

  // Método para actualizar roles de un usuario específico
  Future<void> _actualizarRolesUsuarioEspecifico(String userId) async {
    try {
      print(
        '🔄 Actualizando roles específicamente para usuario $userId desde servidor',
      );
      print(
        '   • Roles actuales en memoria: ${_userRolesMap[userId]?.map((r) => r.nombre).join(", ") ?? "ninguno"}',
      );

      // Intentar múltiples veces con delay para asegurar sincronización
      List<Role> roles = [];
      int intentos = 0;
      const maxIntentos = 3;

      while (intentos < maxIntentos) {
        try {
          intentos++;
          print('   • Intento $intentos de $maxIntentos...');

          roles = await _userService.getRolesByUserId(userId);
          print(
            '   • Roles obtenidos del servidor: ${roles.map((r) => r.nombre).join(", ")}',
          );

          if (roles.isNotEmpty) {
            break; // Éxito, salir del loop
          }

          if (intentos < maxIntentos) {
            print('   • No se obtuvieron roles, esperando 2 segundos...');
            await Future.delayed(Duration(seconds: 2));
          }
        } catch (e) {
          print('   • Error en intento $intentos: $e');
          if (intentos < maxIntentos) {
            await Future.delayed(Duration(seconds: 2));
          }
        }
      }

      // Actualizar siempre con la información del servidor (incluso si está vacía)
      print('   • Actualizando roles en memoria con información del servidor');
      if (mounted) {
        setState(() {
          _userRolesMap[userId] = roles;
        });
      }

      print(
        '✅ Roles finales para usuario $userId: ${_userRolesMap[userId]?.map((r) => r.nombre).join(", ")}',
      );
    } catch (e) {
      print('💥 Error al actualizar roles del usuario $userId: $e');
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
    print('🏗️ CONSTRUYENDO USERS SCREEN - Usuarios: ${_users.length}');
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
                const SizedBox(width: 12),
                // Botón Refrescar
                ElevatedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () {
                          print('INFO: BOTÓN REFRESCAR PRESIONADO!');
                          _cargarDatos();
                        },
                  icon: const Icon(
                    Icons.refresh,
                    color: Colors.white,
                    size: 20,
                  ),
                  label: const Text(
                    'Refrescar',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Botón Nuevo
                ElevatedButton.icon(
                  onPressed: () {
                    print('INFO: BOTÓN NUEVO USUARIOS PRESIONADO!');
                    _mostrarDialogoUsuario();
                  },
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
                        user.nombre != null && user.nombre!.isNotEmpty
                            ? user.nombre!
                            : 'Sin nombre',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      Text(
                        user.email,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: displayedRoles
                            .map(
                              (role) => Chip(
                                label: Text(role),
                                backgroundColor: Colors.blueGrey[700],
                                labelStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Email: ${user.email}',
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 14,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () =>
                                    _mostrarDialogoUsuario(user: user),
                                icon: const Icon(
                                  Icons.edit,
                                  color: Color(0xFFFF6B00),
                                ),
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
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                tooltip: 'Eliminar',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
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
                initialValue: selectedRoleId,
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

      // Eliminar todos los roles previos antes de asignar el nuevo
      final relacionesActuales = await _userRoleService.getRolesByUser(
        user.id!,
      );
      print('📋 Roles actuales encontrados: ${relacionesActuales.length}');

      // ✅ NUEVA LÓGICA: Eliminar roles uno por uno y verificar cada eliminación
      for (final relacion in relacionesActuales) {
        if (relacion.id != null) {
          print('🗑️ Eliminando rol ${relacion.id}');
          final eliminado = await _userRoleService.deleteUserRole(relacion.id!);
          print(
            eliminado
                ? '✅ Rol eliminado correctamente'
                : '❌ Error al eliminar rol',
          );

          if (!eliminado) {
            throw Exception('No se pudo eliminar el rol ${relacion.id}');
          }
        }
      }

      // Esperar más tiempo para asegurar la sincronización con la base de datos
      print('⏳ Esperando sincronización de la base de datos...');
      await Future.delayed(Duration(milliseconds: 1500));

      // Verificar que los roles fueron eliminados - intentar hasta 3 veces
      int intentos = 0;
      List<UserRole> verificacion;

      do {
        intentos++;
        verificacion = await _userRoleService.getRolesByUser(user.id!);
        print(
          '🔍 Verificación post-eliminación (intento $intentos): ${verificacion.length} roles restantes',
        );

        if (verificacion.isNotEmpty && intentos < 3) {
          print('⏳ Roles aún presentes, esperando más tiempo...');
          await Future.delayed(Duration(milliseconds: 1000));
        }
      } while (verificacion.isNotEmpty && intentos < 3);

      if (verificacion.isNotEmpty) {
        print(
          '⚠️ ADVERTENCIA: No se pudieron eliminar todos los roles después de 3 intentos',
        );
        print(
          '   • Roles restantes: ${verificacion.map((r) => r.id ?? "sin-id").join(", ")}',
        );
        // Continuar de todas maneras para asignar el nuevo rol
      }

      print('➕ Asignando nuevo rol $roleId al usuario ${user.id}');
      final resultado = await _userRoleService.assignRoleToUser(
        user.id!,
        roleId,
      );
      print('✅ Rol asignado, resultado: $resultado');

      // Esperar para que se procese la asignación
      await Future.delayed(Duration(milliseconds: 500));

      // Verificar que el nuevo rol se asignó correctamente
      final rolesFinales = await _userRoleService.getRolesByUser(user.id!);
      print(
        '🔍 Verificación post-asignación: ${rolesFinales.length} roles encontrados',
      );

      if (rolesFinales.length != 1) {
        print(
          '⚠️ PROBLEMA: Se esperaba 1 rol pero se encontraron ${rolesFinales.length}',
        );
        for (var r in rolesFinales) {
          print('   • Rol encontrado: ${r.id}');
        }
      }

      // Actualizar inmediatamente el mapa de roles en memoria
      final nuevoRol = _roles.firstWhere(
        (role) => role.id == roleId,
        orElse: () {
          print('❌ No se encontró el rol con ID $roleId en la lista de roles');
          throw Exception('Rol no encontrado en la lista local');
        },
      );

      setState(() {
        _userRolesMap[user.id!] = [nuevoRol];
      });

      print(
        '✅ Rol actualizado en memoria: ${nuevoRol.nombre} para usuario ${user.email}',
      );

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rol cambiado correctamente'),
          backgroundColor: Colors.green,
        ),
      );

      // Esperar más tiempo antes de verificar desde el servidor para mejor sincronización
      Future.delayed(Duration(milliseconds: 5000), () {
        // Actualizar roles específico del usuario desde el servidor para confirmar
        _actualizarRolesUsuarioEspecifico(user.id!);
      });

      // También hacer una verificación inmediata para debug
      print('🔍 Rol actualizado localmente. Estado actual en _userRolesMap:');
      print(
        '   • Usuario ${user.email}: ${_userRolesMap[user.id!]?.map((r) => r.nombre).join(", ")}',
      );
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

      print('INFO: Objeto User creado: ${newUser.toJsonCreate()}');

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
