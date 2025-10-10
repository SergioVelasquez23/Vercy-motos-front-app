import 'package:flutter/material.dart';
import '../models/role.dart';
import '../services/role_service.dart';

class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  final RoleService _roleService = RoleService();

  List<Role> _roles = [];
  bool _isLoading = true;
  String _searchText = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarRoles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarRoles() async {
    setState(() => _isLoading = true);
    try {
      final roles = await _roleService.getRoles();
      setState(() {
        _roles = roles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar roles: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Role> get _filteredRoles {
    if (_searchText.isEmpty) return _roles;
    return _roles.where((role) {
      return role.nombre.toLowerCase().contains(_searchText.toLowerCase()) ||
          (role.descripcion?.toLowerCase().contains(
                _searchText.toLowerCase(),
              ) ??
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
                      hintText: 'Buscar roles...',
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
              ],
            ),
          ),

          // Lista de roles
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF6B00)),
                  )
                : _filteredRoles.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.admin_panel_settings_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchText.isEmpty
                              ? 'No hay roles registrados'
                              : 'No se encontraron roles',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _cargarRoles,
                    color: const Color(0xFFFF6B00),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredRoles.length,
                      itemBuilder: (context, index) {
                        final role = _filteredRoles[index];
                        return _buildRoleCard(role);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(Role role) {
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B00).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings,
                    color: Color(0xFFFF6B00),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role.nombre,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (role.descripcion != null &&
                          role.descripcion!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          role.descripcion!,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: role.activo ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    role.activo ? 'Activo' : 'Inactivo',
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
                if (role.fechaCreacion != null)
                  Text(
                    'Creado: ${_formatDate(role.fechaCreacion!)}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  )
                else
                  const SizedBox(),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _mostrarDialogoRol(role: role),
                      icon: const Icon(Icons.edit, color: Color(0xFFFF6B00)),
                      tooltip: 'Editar',
                    ),
                    IconButton(
                      onPressed: () => _confirmarEliminar(role),
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _mostrarDialogoRol({Role? role}) {
    final isEditing = role != null;
    final nombreController = TextEditingController(text: role?.nombre ?? '');
    final descripcionController = TextEditingController(
      text: role?.descripcion ?? '',
    );
    bool activo = role?.activo ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            isEditing ? 'Editar Rol' : 'Nuevo Rol',
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nombre del rol *',
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
              TextField(
                controller: descripcionController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Descripción',
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
              Row(
                children: [
                  Checkbox(
                    value: activo,
                    onChanged: (value) {
                      setDialogState(() => activo = value ?? true);
                    },
                    activeColor: const Color(0xFFFF6B00),
                  ),
                  const Text(
                    'Rol activo',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
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
              onPressed: () => _guardarRol(
                isEditing: isEditing,
                role: role,
                nombre: nombreController.text,
                descripcion: descripcionController.text,
                activo: activo,
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

  Future<void> _guardarRol({
    required bool isEditing,
    Role? role,
    required String nombre,
    required String descripcion,
    required bool activo,
  }) async {
    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El nombre del rol es obligatorio'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final newRole = Role(
        id: role?.id,
        nombre: nombre,
        descripcion: descripcion.isEmpty ? null : descripcion,
        activo: activo,
      );

      if (isEditing) {
        await _roleService.updateRole(newRole);
        // Reload roles immediately after update
        await _cargarRoles();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rol actualizado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        await _roleService.createRole(newRole);
        // Reload roles immediately after create
        await _cargarRoles();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rol creado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }

      Navigator.pop(context);
      _cargarRoles();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar rol: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmarEliminar(Role role) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Confirmar eliminación',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '¿Está seguro de que desea eliminar el rol "${role.nombre}"?',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () => _eliminarRol(role),
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

  Future<void> _eliminarRol(Role role) async {
    try {
      await _roleService.deleteRole(role.id!);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rol eliminado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
      _cargarRoles();
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar rol: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
