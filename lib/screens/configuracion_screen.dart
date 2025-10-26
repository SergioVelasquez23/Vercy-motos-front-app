import 'package:flutter/material.dart';
import 'users_screen.dart';
import 'negocio_info_screen.dart';
import 'exportar_mensual_screen.dart';
import '../models/mesa.dart';
import '../models/tipo_mesa.dart';
import '../services/mesa_service.dart';
import '../theme/app_theme.dart';

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
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Configuración', style: AppTheme.headlineMedium),
      ),
      body: Column(
        children: [
          // Tabs movidos del AppBar al body (ahora scrolleable)
          Container(
            decoration: BoxDecoration(
              color: AppTheme.backgroundDark,
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primary,
              labelColor: AppTheme.textDark,
              unselectedLabelColor: AppTheme.textLight,
              tabs: const [
                Tab(icon: Icon(Icons.people), text: 'Usuarios'),
                Tab(icon: Icon(Icons.table_restaurant), text: 'Mesas'),
                Tab(icon: Icon(Icons.business), text: 'Negocio'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                UsersScreen(),
                MesasConfigScreen(),
                NegocioInfoScreen(),
              ],
            ),
          ),
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
    print(
      '🏗️ CONSTRUYENDO MESAS CONFIG SCREEN - Mesas: ${_mesas.length}, Loading: $_isLoading',
    );
    return Column(
      children: [
        // Barra superior con búsqueda y botón agregar
        Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.cardBg,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: AppTheme.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Buscar mesas...',
                        hintStyle: AppTheme.bodySmall,
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppTheme.textLight,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppTheme.textLight),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppTheme.primary),
                        ),
                        filled: true,
                        fillColor: AppTheme.backgroundDark,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchText = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      print('INFO: BOTÓN NUEVO MESAS PRESIONADO!');
                      _mostrarDialogoMesa();
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
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total: ${_filteredMesas.length} mesas',
                    style: AppTheme.bodySmall,
                  ),
                  TextButton(
                    onPressed: _cargarMesas,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh,
                          color: AppTheme.textLight,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text('Actualizar', style: AppTheme.bodySmall),
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
              ? Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                )
              : _filteredMesas.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.table_restaurant,
                        size: 64,
                        color: AppTheme.textLight,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchText.isEmpty
                            ? 'No hay mesas registradas'
                            : 'No se encontraron mesas',
                        style: AppTheme.bodyLarge,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarMesas,
                  color: AppTheme.primary,
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
      color: AppTheme.cardBg,
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
                        style: AppTheme.headlineSmall.copyWith(
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
                  color: AppTheme.backgroundDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total cuenta:', style: AppTheme.bodySmall),
                    Text(
                      '\$${mesa.total.toStringAsFixed(2)}',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.primary,
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
                  icon: Icon(Icons.edit, color: AppTheme.primary),
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
    TipoMesa tipoSeleccionado = mesa?.tipo ?? TipoMesa.normal;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: Text(
            isEditing ? 'Editar Mesa' : 'Nueva Mesa',
            style: AppTheme.headlineMedium,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreController,
                  style: AppTheme.bodyMedium,
                  decoration: InputDecoration(
                    labelText: 'Nombre de la Mesa *',
                    labelStyle: AppTheme.bodySmall,
                    hintText: 'Ej: Mesa 1, Mesa VIP, Terraza A...',
                    hintStyle: AppTheme.bodySmall,
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.textLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tipo de Mesa *',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.textLight),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<TipoMesa>(
                          value: tipoSeleccionado,
                          isExpanded: true,
                          style: AppTheme.bodyMedium,
                          dropdownColor: AppTheme.cardBg,
                          onChanged: (TipoMesa? newValue) {
                            if (newValue != null) {
                              setState(() {
                                tipoSeleccionado = newValue;
                              });
                            }
                          },
                          items: TipoMesa.values.map((TipoMesa tipo) {
                            return DropdownMenuItem<TipoMesa>(
                              value: tipo,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tipo.nombre,
                                    style: AppTheme.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    tipo.descripcion,
                                    style: AppTheme.bodySmall.copyWith(
                                      color: AppTheme.textLight,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tipoSeleccionado == TipoMesa.especial
                            ? AppTheme.primary.withOpacity(0.1)
                            : AppTheme.surfaceDark.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: tipoSeleccionado == TipoMesa.especial
                              ? AppTheme.primary.withOpacity(0.3)
                              : AppTheme.textLight.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            tipoSeleccionado == TipoMesa.especial
                                ? Icons.star
                                : Icons.table_restaurant,
                            color: tipoSeleccionado == TipoMesa.especial
                                ? AppTheme.primary
                                : AppTheme.textLight,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tipoSeleccionado == TipoMesa.especial
                                  ? 'Esta mesa tendrá características especiales'
                                  : 'Mesa estándar para servicio regular',
                              style: AppTheme.bodySmall.copyWith(
                                color: tipoSeleccionado == TipoMesa.especial
                                    ? AppTheme.primary
                                    : AppTheme.textLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: AppTheme.secondaryButtonStyle,
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => _guardarMesa(
                isEditing: isEditing,
                mesa: mesa,
                nombre: nombreController.text.trim(),
                tipo: tipoSeleccionado,
              ),
              style: AppTheme.primaryButtonStyle,
              child: Text(
                isEditing ? 'Actualizar' : 'Crear',
                style: AppTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _guardarMesa({
    required bool isEditing,
    Mesa? mesa,
    required String nombre,
    required TipoMesa tipo,
  }) async {
    // Validaciones
    if (nombre.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El nombre de la mesa es obligatorio'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    try {
      Mesa newMesa;

      if (isEditing) {
        // Actualizar mesa existente
        newMesa = mesa!.copyWith(nombre: nombre, tipo: tipo);
        await _mesaService.updateMesa(newMesa);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mesa actualizada correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Crear nueva mesa
        newMesa = Mesa(
          id: '', // Se generará en el backend
          nombre: nombre,
          tipo: tipo,
          ocupada: false,
          total: 0.0,
        );
        await _mesaService.createMesa(newMesa);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mesa creada correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
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
        backgroundColor: AppTheme.cardBg,
        title: Text('Confirmar eliminación', style: AppTheme.headlineMedium),
        content: Text(
          '¿Está seguro de que desea eliminar la mesa "${mesa.nombre}"?',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: AppTheme.secondaryButtonStyle,
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => _eliminarMesa(mesa),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: Text('Eliminar', style: AppTheme.bodyMedium),
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
