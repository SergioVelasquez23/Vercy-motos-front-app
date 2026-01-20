import 'package:flutter/material.dart';
import '../models/cliente.dart';
import '../services/cliente_service.dart';
import '../theme/app_theme.dart';
import '../widgets/vercy_sidebar_layout.dart';

class ClientesListScreen extends StatefulWidget {
  @override
  _ClientesListScreenState createState() => _ClientesListScreenState();
}

class _ClientesListScreenState extends State<ClientesListScreen> {
  final ClienteService _clienteService = ClienteService();
  final TextEditingController _searchController = TextEditingController();

  List<Cliente> _clientes = [];
  List<Cliente> _clientesFiltrados = [];
  bool _isLoading = false;
  String _filtroEstado = 'todos'; // todos, activos, bloqueados

  @override
  void initState() {
    super.initState();
    _cargarClientes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarClientes() async {
    setState(() => _isLoading = true);

    try {
      final clientes = await _clienteService.obtenerClientes();
      setState(() {
        _clientes = clientes;
        _aplicarFiltros();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar clientes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _aplicarFiltros() {
    List<Cliente> filtrados = List.from(_clientes);

    // Filtro por estado
    if (_filtroEstado == 'activos') {
      filtrados = filtrados.where((c) => c.estado == 'activo').toList();
    } else if (_filtroEstado == 'bloqueados') {
      filtrados = filtrados.where((c) => c.estado == 'bloqueado').toList();
    }

    // Filtro por búsqueda
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      filtrados = filtrados.where((c) {
        return c.nombreCompleto.toLowerCase().contains(query) ||
            c.numeroIdentificacion.toLowerCase().contains(query) ||
            (c.correo?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    setState(() => _clientesFiltrados = filtrados);
  }

  @override
  Widget build(BuildContext context) {
    return VercySidebarLayout(
      title: 'Clientes',
      child: Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        body: Column(
          children: [
            _buildHeader(),
            _buildFiltros(),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _clientesFiltrados.isEmpty
                  ? _buildEmptyState()
                  : _buildClientesList(),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _navegarAFormulario(null),
          backgroundColor: AppTheme.primary,
          icon: Icon(Icons.person_add),
          label: Text('Nuevo Cliente'),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.people, color: AppTheme.primary, size: 32),
          SizedBox(width: 12),
          Text(
            'Gestión de Clientes',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Spacer(),
          Text(
            '${_clientesFiltrados.length} clientes',
            style: TextStyle(fontSize: 16, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
      ),
      child: Row(
        children: [
          // Buscador
          Expanded(
            flex: 3,
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, documento o correo...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                filled: true,
                fillColor: AppTheme.surfaceDark,
              ),
              onChanged: (value) => _aplicarFiltros(),
            ),
          ),
          SizedBox(width: 16),
          // Filtro por estado
          DropdownButton<String>(
            value: _filtroEstado,
            dropdownColor: AppTheme.cardBg,
            style: TextStyle(color: Colors.white),
            items: [
              DropdownMenuItem(
                value: 'todos',
                child: Text('Todos los estados'),
              ),
              DropdownMenuItem(value: 'activos', child: Text('Activos')),
              DropdownMenuItem(value: 'bloqueados', child: Text('Bloqueados')),
            ],
            onChanged: (value) {
              setState(() => _filtroEstado = value!);
              _aplicarFiltros();
            },
          ),
          SizedBox(width: 16),
          // Botón refrescar
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _cargarClientes,
            tooltip: 'Refrescar',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey[600]),
          SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty
                ? 'No hay clientes registrados'
                : 'No se encontraron clientes',
            style: TextStyle(fontSize: 18, color: Colors.grey[400]),
          ),
          SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _navegarAFormulario(null),
            icon: Icon(Icons.add),
            label: Text('Crear primer cliente'),
          ),
        ],
      ),
    );
  }

  Widget _buildClientesList() {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: ListView.separated(
        itemCount: _clientesFiltrados.length,
        separatorBuilder: (context, index) => Divider(height: 1),
        itemBuilder: (context, index) {
          final cliente = _clientesFiltrados[index];
          return _buildClienteItem(cliente);
        },
      ),
    );
  }

  Widget _buildClienteItem(Cliente cliente) {
    final esEmpresa = cliente.tipoPersona == 'juridica';
    final cupoDisponiblePorcentaje = cliente.cupoCredito > 0
        ? (cliente.cupoDisponible / cliente.cupoCredito * 100)
        : 0.0;

    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leading: CircleAvatar(
        backgroundColor: cliente.estado == 'activo'
            ? Colors.green[100]
            : Colors.red[100],
        child: Icon(
          esEmpresa ? Icons.business : Icons.person,
          color: cliente.estado == 'activo'
              ? Colors.green[700]
              : Colors.red[700],
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              cliente.nombreCompleto,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
          if (cliente.estado == 'bloqueado')
            Chip(
              label: Text(
                'Bloqueado',
                style: TextStyle(fontSize: 12, color: Colors.white),
              ),
              backgroundColor: Colors.red[900],
              padding: EdgeInsets.zero,
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.badge, size: 14, color: Colors.grey[400]),
              SizedBox(width: 4),
              Text(
                '${cliente.tipoIdentificacion}: ${cliente.numeroIdentificacion}',
                style: TextStyle(color: Colors.grey[300]),
              ),
              if (cliente.digitoVerificacion != null)
                Text(
                  '-${cliente.digitoVerificacion}',
                  style: TextStyle(color: Colors.grey[300]),
                ),
            ],
          ),
          if (cliente.correo != null) ...[
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.email, size: 14, color: Colors.grey[400]),
                SizedBox(width: 4),
                Text(
                  cliente.correo!,
                  style: TextStyle(color: Colors.grey[300]),
                ),
              ],
            ),
          ],
          if (cliente.telefono != null) ...[
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.phone, size: 14, color: Colors.grey[400]),
                SizedBox(width: 4),
                Text(
                  cliente.telefono!,
                  style: TextStyle(color: Colors.grey[300]),
                ),
              ],
            ),
          ],
          SizedBox(height: 8),
          Row(
            children: [
              // Saldo
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cliente.saldoActual > 0
                      ? Colors.orange[100]
                      : Colors.green[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Saldo: \$${cliente.saldoActual.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(width: 8),
              // Cupo disponible
              if (cliente.cupoCredito > 0) ...[
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cupoDisponiblePorcentaje > 50
                        ? Colors.blue[100]
                        : cupoDisponiblePorcentaje > 20
                        ? Colors.orange[100]
                        : Colors.red[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Cupo: \$${cliente.cupoDisponible.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.visibility, color: AppTheme.primary),
            onPressed: () => _verDetalle(cliente),
            tooltip: 'Ver detalle',
          ),
          IconButton(
            icon: Icon(Icons.edit, color: Colors.blue),
            onPressed: () => _navegarAFormulario(cliente),
            tooltip: 'Editar',
          ),
          IconButton(
            icon: Icon(
              cliente.estado == 'activo' ? Icons.block : Icons.check_circle,
              color: cliente.estado == 'activo' ? Colors.red : Colors.green,
            ),
            onPressed: () => _toggleEstado(cliente),
            tooltip: cliente.estado == 'activo' ? 'Bloquear' : 'Activar',
          ),
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: () => _confirmarEliminar(cliente),
            tooltip: 'Eliminar',
          ),
        ],
      ),
    );
  }

  void _navegarAFormulario(Cliente? cliente) async {
    final resultado = await Navigator.pushNamed(
      context,
      '/clientes/form',
      arguments: cliente,
    );

    if (resultado == true) {
      _cargarClientes();
    }
  }

  void _verDetalle(Cliente cliente) {
    Navigator.pushNamed(context, '/clientes/detalle', arguments: cliente);
  }

  Future<void> _toggleEstado(Cliente cliente) async {
    try {
      if (cliente.estado == 'activo') {
        // Bloquear
        final motivo = await _mostrarDialogoMotivo();
        if (motivo == null) return;

        await _clienteService.bloquearCliente(cliente.id!, motivo);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cliente bloqueado'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        // Activar
        await _clienteService.activarCliente(cliente.id!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cliente activado'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _cargarClientes();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<String?> _mostrarDialogoMotivo() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Motivo de bloqueo'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Ingrese el motivo...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('Bloquear'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarEliminar(Cliente cliente) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar eliminación'),
        content: Text('¿Está seguro de eliminar a ${cliente.nombreCompleto}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _clienteService.eliminarCliente(cliente.id!);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cliente eliminado'),
            backgroundColor: Colors.green,
          ),
        );
        _cargarClientes();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
