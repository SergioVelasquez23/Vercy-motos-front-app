import 'package:flutter/material.dart';
import '../models/bodega.dart';
import '../services/bodega_service.dart';
import '../theme/app_theme.dart';
import '../widgets/vercy_sidebar_layout.dart';

/// Pantalla para gestionar bodegas/almacenes/ubicaciones de inventario
class BodegasScreen extends StatefulWidget {
  const BodegasScreen({super.key});

  @override
  _BodegasScreenState createState() => _BodegasScreenState();
}

class _BodegasScreenState extends State<BodegasScreen> {
  final BodegaService _bodegaService = BodegaService();
  final TextEditingController _searchController = TextEditingController();

  List<Bodega> _bodegas = [];
  List<Bodega> _bodegasFiltradas = [];
  bool _isLoading = false;
  String _filtroEstado = 'todas'; // todas, activas, inactivas

  @override
  void initState() {
    super.initState();
    _cargarBodegas();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarBodegas() async {
    setState(() => _isLoading = true);
    try {
      final bodegas = await _bodegaService.obtenerBodegas();
      setState(() {
        _bodegas = bodegas;
        _aplicarFiltros();
      });
    } catch (e) {
      _mostrarError('Error al cargar ubicaciones: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _aplicarFiltros() {
    List<Bodega> filtradas = List.from(_bodegas);

    // Filtro por estado
    if (_filtroEstado == 'activas') {
      filtradas = filtradas.where((b) => b.activa).toList();
    } else if (_filtroEstado == 'inactivas') {
      filtradas = filtradas.where((b) => !b.activa).toList();
    }

    // Filtro por búsqueda
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      filtradas = filtradas.where((b) {
        return b.nombre.toLowerCase().contains(query) ||
            (b.codigo?.toLowerCase().contains(query) ?? false) ||
            (b.tipo?.toLowerCase().contains(query) ?? false) ||
            (b.responsable?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    setState(() => _bodegasFiltradas = filtradas);
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: AppTheme.success),
    );
  }

  Future<void> _mostrarDialogoBodega({Bodega? bodega}) async {
    final esEdicion = bodega != null;
    final nombreController = TextEditingController(text: bodega?.nombre ?? '');
    final codigoController = TextEditingController(text: bodega?.codigo ?? '');
    final descripcionController = TextEditingController(
      text: bodega?.descripcion ?? '',
    );
    final direccionController = TextEditingController(
      text: bodega?.direccion ?? '',
    );
    final telefonoController = TextEditingController(
      text: bodega?.telefono ?? '',
    );
    final responsableController = TextEditingController(
      text: bodega?.responsable ?? '',
    );
    String tipoSeleccionado = bodega?.tipo ?? 'BODEGA';
    bool activa = bodega?.activa ?? true;
    bool guardando = false;

    final tipos = _bodegaService.getTiposBodega();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  esEdicion ? Icons.edit_location : Icons.add_location,
                  color: AppTheme.primary,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Text(
                esEdicion
                    ? 'Editar Ubicación de Inventario'
                    : 'Nueva Ubicación de Inventario',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Container(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fila: Nombre y Código
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildCampoTexto(
                          controller: nombreController,
                          label: 'Nombre *',
                          hint: 'Ej: Bodega Principal, Almacén Norte...',
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildCampoTexto(
                          controller: codigoController,
                          label: 'Código',
                          hint: 'BOD01',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Tipo de ubicación
                  Text(
                    'Tipo de Ubicación',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 6),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.textSecondary.withOpacity(0.3),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: tipoSeleccionado,
                        isExpanded: true,
                        dropdownColor: AppTheme.cardBg,
                        style: TextStyle(color: AppTheme.textPrimary),
                        items: tipos.map((tipo) {
                          return DropdownMenuItem(
                            value: tipo,
                            child: Row(
                              children: [
                                Icon(
                                  _getIconoTipo(tipo),
                                  color: AppTheme.primary,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(tipo.replaceAll('_', ' ')),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() => tipoSeleccionado = value!);
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Descripción
                  _buildCampoTexto(
                    controller: descripcionController,
                    label: 'Descripción',
                    hint: 'Descripción de la ubicación...',
                    maxLines: 2,
                  ),
                  SizedBox(height: 16),

                  // Fila: Dirección y Teléfono
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildCampoTexto(
                          controller: direccionController,
                          label: 'Dirección',
                          hint: 'Calle 123 #45-67',
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildCampoTexto(
                          controller: telefonoController,
                          label: 'Teléfono',
                          hint: '300 123 4567',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Responsable
                  _buildCampoTexto(
                    controller: responsableController,
                    label: 'Responsable',
                    hint: 'Nombre del encargado',
                  ),
                  SizedBox(height: 16),

                  // Switch Activa
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              activa ? Icons.check_circle : Icons.cancel,
                              color: activa ? AppTheme.success : Colors.grey,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Ubicación Activa',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: activa,
                          onChanged: (value) {
                            setDialogState(() => activa = value);
                          },
                          activeColor: AppTheme.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: guardando ? null : () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: guardando
                  ? null
                  : () async {
                      if (nombreController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('El nombre es requerido'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => guardando = true);

                      try {
                        if (esEdicion) {
                          await _bodegaService.actualizarBodega(
                            bodega!.id!,
                            nombre: nombreController.text.trim(),
                            codigo: codigoController.text.trim(),
                            tipo: tipoSeleccionado,
                            descripcion: descripcionController.text.trim(),
                            direccion: direccionController.text.trim(),
                            telefono: telefonoController.text.trim(),
                            responsable: responsableController.text.trim(),
                            activa: activa,
                          );
                          _mostrarExito('Ubicación actualizada');
                        } else {
                          await _bodegaService.crearBodega(
                            nombre: nombreController.text.trim(),
                            codigo: codigoController.text.trim(),
                            tipo: tipoSeleccionado,
                            descripcion: descripcionController.text.trim(),
                            direccion: direccionController.text.trim(),
                            telefono: telefonoController.text.trim(),
                            responsable: responsableController.text.trim(),
                            activa: activa,
                          );
                          _mostrarExito('Ubicación creada');
                        }
                        Navigator.pop(context);
                        await _cargarBodegas();
                      } catch (e) {
                        _mostrarError('Error: $e');
                      } finally {
                        setDialogState(() => guardando = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: guardando
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      esEdicion ? 'Actualizar' : 'Crear',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampoTexto({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        SizedBox(height: 6),
        TextField(
          controller: controller,
          style: TextStyle(color: AppTheme.textPrimary),
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppTheme.textSecondary.withOpacity(0.5),
            ),
            filled: true,
            fillColor: AppTheme.surfaceDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: AppTheme.textSecondary.withOpacity(0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: AppTheme.textSecondary.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.primary),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  IconData _getIconoTipo(String tipo) {
    switch (tipo) {
      case 'BODEGA':
        return Icons.warehouse;
      case 'ALMACEN':
        return Icons.store;
      case 'PUNTO_VENTA':
        return Icons.storefront;
      case 'TALLER':
        return Icons.build;
      case 'DEPOSITO':
        return Icons.inventory;
      default:
        return Icons.location_on;
    }
  }

  Future<void> _confirmarEliminar(Bodega bodega) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text(
              'Eliminar Ubicación',
              style: TextStyle(color: AppTheme.textPrimary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Estás seguro de que deseas eliminar "${bodega.nombre}"?',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Si hay productos asociados a esta ubicación, no podrá ser eliminada.',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      try {
        await _bodegaService.eliminarBodega(bodega.id!);
        _mostrarExito('Ubicación eliminada');
        await _cargarBodegas();
      } catch (e) {
        _mostrarError('Error al eliminar: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return VercySidebarLayout(
      title: 'Ubicaciones de Inventario',
      child: Container(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ubicaciones de Inventario',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Gestiona las bodegas, almacenes y puntos de inventario',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _mostrarDialogoBodega(),
                  icon: Icon(Icons.add_location, color: Colors.white),
                  label: Text(
                    'Nueva Ubicación',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),

            // Filtros
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade800),
              ),
              child: Row(
                children: [
                  // Buscador
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => _aplicarFiltros(),
                      style: TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre, código, tipo...',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                        filled: true,
                        fillColor: AppTheme.surfaceDark,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade700),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade700),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: AppTheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),

                  // Filtro por estado
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade700),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _filtroEstado,
                        dropdownColor: AppTheme.cardBg,
                        style: TextStyle(color: Colors.white),
                        icon: Icon(Icons.arrow_drop_down, color: Colors.grey),
                        items: [
                          DropdownMenuItem(
                            value: 'todas',
                            child: Text('Todas'),
                          ),
                          DropdownMenuItem(
                            value: 'activas',
                            child: Text('Activas'),
                          ),
                          DropdownMenuItem(
                            value: 'inactivas',
                            child: Text('Inactivas'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _filtroEstado = value!);
                          _aplicarFiltros();
                        },
                      ),
                    ),
                  ),
                  SizedBox(width: 16),

                  // Botón refrescar
                  IconButton(
                    onPressed: _cargarBodegas,
                    icon: Icon(Icons.refresh, color: AppTheme.primary),
                    tooltip: 'Recargar',
                  ),

                  SizedBox(width: 8),
                  Text(
                    '${_bodegasFiltradas.length} ubicaciones',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // Lista de bodegas
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    )
                  : _bodegasFiltradas.isEmpty
                  ? _buildEmptyState()
                  : _buildListaBodegas(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warehouse_outlined, size: 80, color: Colors.grey.shade600),
          SizedBox(height: 16),
          Text(
            _searchController.text.isNotEmpty
                ? 'No se encontraron resultados'
                : 'No hay ubicaciones de inventario',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            _searchController.text.isNotEmpty
                ? 'Intenta con otro término de búsqueda'
                : 'Crea tu primera ubicación para comenzar',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
          if (_searchController.text.isEmpty) ...[
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _mostrarDialogoBodega(),
              icon: Icon(Icons.add_location, color: Colors.white),
              label: Text(
                'Crear Ubicación',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildListaBodegas() {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _bodegasFiltradas.length,
      itemBuilder: (context, index) {
        final bodega = _bodegasFiltradas[index];
        return _buildBodegaCard(bodega);
      },
    );
  }

  Widget _buildBodegaCard(Bodega bodega) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: bodega.activa
              ? AppTheme.primary.withOpacity(0.3)
              : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de la tarjeta
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bodega.activa
                  ? AppTheme.primary.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: bodega.activa
                        ? AppTheme.primary.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getIconoTipo(bodega.tipo ?? 'BODEGA'),
                    color: bodega.activa ? AppTheme.primary : Colors.grey,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bodega.nombre,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (bodega.codigo != null && bodega.codigo!.isNotEmpty)
                        Text(
                          bodega.codigo!,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                // Badge de estado
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: bodega.activa
                        ? AppTheme.success.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    bodega.activa ? 'Activa' : 'Inactiva',
                    style: TextStyle(
                      color: bodega.activa ? AppTheme.success : Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Contenido
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (bodega.tipo != null)
                    _buildInfoRow(
                      Icons.category,
                      bodega.tipo!.replaceAll('_', ' '),
                    ),
                  if (bodega.responsable != null &&
                      bodega.responsable!.isNotEmpty)
                    _buildInfoRow(Icons.person, bodega.responsable!),
                  if (bodega.direccion != null && bodega.direccion!.isNotEmpty)
                    _buildInfoRow(Icons.location_on, bodega.direccion!),
                  if (bodega.descripcion != null &&
                      bodega.descripcion!.isNotEmpty)
                    Expanded(
                      child: Text(
                        bodega.descripcion!,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Acciones
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark.withOpacity(0.5),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Editar
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: Icon(Icons.edit, color: AppTheme.primary, size: 20),
                  onPressed: () => _mostrarDialogoBodega(bodega: bodega),
                  tooltip: 'Editar',
                ),
                SizedBox(width: 8),
                // Toggle activa
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: Icon(
                    bodega.activa ? Icons.toggle_on : Icons.toggle_off,
                    color: bodega.activa ? AppTheme.success : Colors.grey,
                    size: 28,
                  ),
                  onPressed: () async {
                    try {
                      await _bodegaService.toggleActivaBodega(
                        bodega.id!,
                        !bodega.activa,
                      );
                      _mostrarExito(
                        bodega.activa
                            ? 'Ubicación desactivada'
                            : 'Ubicación activada',
                      );
                      await _cargarBodegas();
                    } catch (e) {
                      _mostrarError('Error: $e');
                    }
                  },
                  tooltip: bodega.activa ? 'Desactivar' : 'Activar',
                ),
                SizedBox(width: 8),
                // Eliminar
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () => _confirmarEliminar(bodega),
                  tooltip: 'Eliminar',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
