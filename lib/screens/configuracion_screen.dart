import 'package:flutter/material.dart';
import 'users_screen.dart';
import 'roles_screen.dart';
import 'negocio_info_screen.dart';
import '../models/mesa.dart';
import '../services/mesa_service.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Configuración',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF6B00),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[400],
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Usuarios'),
            Tab(icon: Icon(Icons.admin_panel_settings), text: 'Roles'),
            Tab(icon: Icon(Icons.table_restaurant), text: 'Mesas'),
            Tab(icon: Icon(Icons.business), text: 'Negocio'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          UsersScreen(),
          RolesScreen(),
          MesasConfigScreen(),
          NegocioInfoScreen(),
        ],
      ),
    );
  }
}

// Pantalla de configuración de mesas
class MesasConfigScreen extends StatefulWidget {
  const MesasConfigScreen({super.key});

  @override
  State<MesasConfigScreen> createState() => _MesasConfigScreenState();
}

class _MesasConfigScreenState extends State<MesasConfigScreen> {
  final MesaService _mesaService = MesaService();
  List<Mesa> _mesas = [];
  bool _isLoading = true;
  String _searchText = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarMesas();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Mesa> get _filteredMesas {
    if (_searchText.isEmpty) {
      return _mesas;
    }
    return _mesas.where((mesa) {
      return mesa.nombre.toLowerCase().contains(_searchText.toLowerCase());
    }).toList();
  }

  Future<void> _cargarMesas() async {
    setState(() => _isLoading = true);
    try {
      print('🔍 Iniciando carga de mesas...');
      final mesas = await _mesaService.getMesas();
      print('✅ Mesas cargadas: ${mesas.length}');

      setState(() {
        _mesas = mesas;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error cargando mesas: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar mesas: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barra superior con búsqueda y botón agregar
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[900],
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Buscar mesas...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[600]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFFF6B00),
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey[800],
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchText = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  FloatingActionButton(
                    onPressed: () => _mostrarDialogoMesa(),
                    backgroundColor: const Color(0xFFFF6B00),
                    mini: true,
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total: ${_filteredMesas.length} mesas',
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                  TextButton(
                    onPressed: _cargarMesas,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh, color: Colors.grey[400], size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Actualizar',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Lista de mesas
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF6B00)),
                )
              : _filteredMesas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.table_restaurant,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchText.isEmpty
                            ? 'No hay mesas registradas'
                            : 'No se encontraron mesas',
                        style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarMesas,
                  color: const Color(0xFFFF6B00),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredMesas.length,
                    itemBuilder: (context, index) {
                      final mesa = _filteredMesas[index];
                      return _buildMesaCard(mesa);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildMesaCard(Mesa mesa) {
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
                  backgroundColor: mesa.ocupada ? Colors.red : Colors.green,
                  radius: 24,
                  child: Icon(
                    Icons.table_restaurant,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mesa.nombre,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mesa.ocupada ? 'Ocupada' : 'Disponible',
                        style: TextStyle(
                          color: mesa.ocupada ? Colors.red : Colors.green,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
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
                    color: mesa.ocupada ? Colors.red : Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    mesa.ocupada ? 'Ocupada' : 'Libre',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (mesa.ocupada && mesa.total > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total cuenta:',
                      style: TextStyle(color: Colors.grey[300], fontSize: 14),
                    ),
                    Text(
                      '\$${mesa.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFFFF6B00),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () => _mostrarDialogoMesa(mesa: mesa),
                  icon: const Icon(Icons.edit, color: Color(0xFFFF6B00)),
                  tooltip: 'Editar Mesa',
                ),
                IconButton(
                  onPressed: () => _confirmarEliminar(mesa),
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Eliminar Mesa',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoMesa({Mesa? mesa}) {
    final isEditing = mesa != null;
    final nombreController = TextEditingController(text: mesa?.nombre ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          isEditing ? 'Editar Mesa' : 'Nueva Mesa',
          style: const TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nombre de la Mesa *',
                  labelStyle: const TextStyle(color: Colors.grey),
                  hintText: 'Ej: Mesa 1, Mesa VIP, Terraza A...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[600]!),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFFF6B00)),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () => _guardarMesa(
              isEditing: isEditing,
              mesa: mesa,
              nombre: nombreController.text.trim(),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B00),
            ),
            child: Text(
              isEditing ? 'Actualizar' : 'Crear',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _guardarMesa({
    required bool isEditing,
    Mesa? mesa,
    required String nombre,
  }) async {
    // Validaciones
    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El nombre de la mesa es obligatorio'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      Mesa newMesa;

      if (isEditing) {
        // Actualizar mesa existente
        newMesa = mesa!.copyWith(nombre: nombre);
        await _mesaService.updateMesa(newMesa);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mesa actualizada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Crear nueva mesa
        newMesa = Mesa(
          id: '', // Se generará en el backend
          nombre: nombre,
          ocupada: false,
          total: 0.0,
        );
        await _mesaService.createMesa(newMesa);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mesa creada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }

      Navigator.pop(context);
      _cargarMesas();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar mesa: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmarEliminar(Mesa mesa) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Confirmar eliminación',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '¿Está seguro de que desea eliminar la mesa "${mesa.nombre}"?',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[400])),
          ),
          ElevatedButton(
            onPressed: () => _eliminarMesa(mesa),
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

  Future<void> _eliminarMesa(Mesa mesa) async {
    try {
      await _mesaService.deleteMesa(mesa.id);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mesa eliminada correctamente'),
          backgroundColor: Colors.green,
        ),
      );
      _cargarMesas();
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar mesa: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
