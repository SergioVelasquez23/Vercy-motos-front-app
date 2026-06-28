import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../utils/html_stub.dart' if (dart.library.html) 'dart:html' as html;
import '../models/cliente.dart';
import '../services/cliente_service.dart';
import '../theme/app_theme.dart';
import '../utils/pagination_mixin.dart';
import '../widgets/common/screen_header.dart';

class ClientesListScreen extends StatefulWidget {
  @override
  _ClientesListScreenState createState() => _ClientesListScreenState();
}

class _ClientesListScreenState extends State<ClientesListScreen> with PaginacionMixin<ClientesListScreen> {
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
      if (!mounted) return;
      setState(() {
        _clientes = clientes;
        _aplicarFiltros();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
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

    setState(() {
      _clientesFiltrados = filtrados;
      resetPagina();
      resetPagina();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScreenHeader(
          icon: Icons.people,
          title: 'Lista de Clientes',
          badge: '${_clientesFiltrados.length}',
          actions: [
            ScreenHeaderAction.success(
              icon: Icons.upload_file,
              label: 'Carga Masiva',
              mobileLabel: 'Carga',
              onPressed: _mostrarDialogoCargaMasiva,
            ),
            ScreenHeaderAction.primary(
              icon: Icons.person_add,
              label: 'Nuevo Cliente',
              mobileLabel: 'Nuevo',
              onPressed: () => _navegarAFormulario(null),
            ),
          ],
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(context.isMobile ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFiltros(),
                const SizedBox(height: 16),
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(color: AppTheme.primary),
                        )
                      : _clientesFiltrados.isEmpty
                          ? _buildEmptyState()
                          : _buildClientesList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFiltros() {
    final isMobile = context.isMobile;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Buscador — full width móvil
          SizedBox(
            width: isMobile ? double.infinity : 360,
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: onSurface),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, documento o correo...',
                hintStyle: TextStyle(color: onSurface.withOpacity(0.6)),
                prefixIcon: Icon(Icons.search, color: onSurface.withOpacity(0.7)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.primary, width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              onChanged: (value) => _aplicarFiltros(),
            ),
          ),
          // Filtro por estado
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filtroEstado,
                dropdownColor: Theme.of(context).colorScheme.surface,
                style: TextStyle(color: onSurface),
                icon: Icon(Icons.arrow_drop_down, color: onSurface),
                items: [
                  DropdownMenuItem(value: 'todos', child: Text('Todos los estados')),
                  DropdownMenuItem(value: 'activos', child: Text('Activos')),
                  DropdownMenuItem(value: 'bloqueados', child: Text('Bloqueados')),
                ],
                onChanged: (value) {
                  setState(() => _filtroEstado = value!);
                  _aplicarFiltros();
                },
              ),
            ),
          ),
          // Botón refrescar
          Container(
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(Icons.refresh, color: Colors.white),
              onPressed: _cargarClientes,
              tooltip: 'Refrescar',
            ),
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
          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty
                ? 'No hay clientes registrados'
                : 'No se encontraron clientes',
            style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface),
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _navegarAFormulario(null),
            icon: Icon(Icons.add, color: Colors.white),
            label: Text(
              'Crear primer cliente',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientesList() {
    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              itemCount: paginarLista(_clientesFiltrados).length,
              separatorBuilder: (context, index) => Divider(height: 1),
              itemBuilder: (context, index) {
                final cliente = paginarLista(_clientesFiltrados)[index];
                return _buildClienteItem(cliente);
              },
            ),
          ),
          buildPaginacion(
            totalItems: _clientesFiltrados.length,
            accentColor: AppTheme.primary,
          ),
        ],
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
                color: Theme.of(context).colorScheme.onSurface,
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
      subtitle: Builder(builder: (context) {
        final onSurface = Theme.of(context).colorScheme.onSurface;
        final muted = onSurface.withOpacity(0.7);
        final saldoColor = cliente.saldoActual > 0 ? AppTheme.warning : AppTheme.success;
        final cupoColor = cupoDisponiblePorcentaje > 50
            ? AppTheme.primary
            : cupoDisponiblePorcentaje > 20
            ? AppTheme.warning
            : AppTheme.error;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.badge, size: 14, color: muted),
                SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${cliente.tipoIdentificacion}: ${cliente.numeroIdentificacion}'
                    '${cliente.digitoVerificacion != null ? '-${cliente.digitoVerificacion}' : ''}',
                    style: TextStyle(color: onSurface),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (cliente.correo != null) ...[
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.email, size: 14, color: muted),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      cliente.correo!,
                      style: TextStyle(color: onSurface),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (cliente.telefono != null) ...[
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.phone, size: 14, color: muted),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      cliente.telefono!,
                      style: TextStyle(color: onSurface),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: saldoColor.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: saldoColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    'Saldo: \$${cliente.saldoActual.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: saldoColor,
                    ),
                  ),
                ),
                if (cliente.cupoCredito > 0)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cupoColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: cupoColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      'Cupo: \$${cliente.cupoDisponible.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: cupoColor,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      }),
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
    final resultado = await context.push(
      '/clientes/form',
      extra: cliente,
    );

    if (resultado == true) {
      _cargarClientes();
    }
  }

  void _verDetalle(Cliente cliente) {
    context.push('/clientes/detalle', extra: cliente);
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
        title: Text('Confirmar deshabilitación'),
        content: Text(
          '¿Está seguro de deshabilitar a ${cliente.nombreCompleto}? El cliente quedará inactivo pero no se eliminará de la base de datos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Deshabilitar'),
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
            content: Text('Cliente deshabilitado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        _cargarClientes();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al deshabilitar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============================================
  // CARGA MASIVA DESDE EXCEL
  // ============================================

  void _mostrarDialogoCargaMasiva() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.upload_file, color: Colors.green, size: 24),
              ),
              SizedBox(width: 12),
              Text(
                'Carga Masiva de Clientes',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18),
              ),
            ],
          ),
          content: Container(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sube un archivo Excel (.xlsx o .xls) con los clientes a cargar.',
                  style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                ),
                SizedBox(height: 20),
                Text(
                  'Columnas requeridas:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    '• TIPOCLIENTE* (Persona Natural / Persona Jurídica)\n'
                    '• TIPDOCUMENTO* (Cédula de ciudadanía, NIT, CE, etc.)\n'
                    '• CEDULA* (Número de documento)\n'
                    '• DIGITO VERIFICACION (Para NIT)\n'
                    '• NOMBRE*\n'
                    '• DPTO (Departamento)\n'
                    '• CIUDAD\n'
                    '• DIRECCION\n'
                    '• TELEFONO\n'
                    '• CORREO',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      height: 1.6,
                    ),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Columnas opcionales:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    '• MES CUMPLEAÑOS, DIA CUMPLEAÑOS\n'
                    '• RESPONSABLE IVA (Sí/No)\n'
                    '• ZONA, PLAZO, CUPO\n'
                    '• VENDEDOR, OBSERVACIONES\n'
                    '• BLOQUEADO (SI/NO)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      height: 1.6,
                    ),
                  ),
                ),
                SizedBox(height: 16),
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
                          'Los campos marcados con * son obligatorios',
                          style: TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _seleccionarYCargarArchivo();
              },
              icon: Icon(Icons.folder_open, color: Colors.white),
              label: Text(
                'Seleccionar Archivo',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _seleccionarYCargarArchivo() async {
    try {
        
        

      if (kIsWeb) {
        await _seleccionarArchivoWeb();
      } else {
        await _seleccionarArchivoDesktop();
      }
    } catch (e, stackTrace) {
        
        

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _seleccionarArchivoWeb() async {
      

    final html.FileUploadInputElement uploadInput =
        html.FileUploadInputElement();
    uploadInput.accept =
        '.xlsx,.xls,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,application/vnd.ms-excel';
    uploadInput.click();

    await uploadInput.onChange.first;

    final files = uploadInput.files;
    if (files == null || files.isEmpty) {
        
      return;
    }

    final file = files[0];
      
      

    _mostrarDialogoCarga();

    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;

    final bytes = reader.result as Uint8List;
      

    await _cargarArchivoExcelBytes(bytes, file.name);
  }

  Future<void> _seleccionarArchivoDesktop() async {
      

    FilePickerResult? result;

    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
        withReadStream: true,
      );
    } catch (pickerError) {
        
      throw Exception('Error al abrir selector de archivos: $pickerError');
    }

    if (result == null) {
        
      return;
    }

    if (result.files.isEmpty) {
        
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se seleccionó ningún archivo'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    PlatformFile file = result.files.first;
      
      
      

    if (file.path == null || file.path!.isEmpty) {
      throw Exception('No se pudo obtener la ruta del archivo');
    }

    _mostrarDialogoCarga();

      
    await _cargarArchivoExcelPath(file.path!);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _mostrarDialogoCarga() {
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: Center(
            child: Card(
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppTheme.primary),
                    SizedBox(height: 20),
                    Text(
                      'Cargando clientes...',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Por favor espera, esto puede tardar unos segundos',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  Future<void> _cargarArchivoExcelBytes(
    List<int> bytes,
    String fileName,
  ) async {
    try {
      final resultado = await _clienteService.cargarClientesMasivosBytes(
        bytes,
        fileName,
      );

      if (mounted) {
        // Cerrar el diálogo de carga primero
        Navigator.of(context).pop();

        // Mostrar resultado
        _mostrarResultadoCarga(resultado);
        await _cargarClientes();
      }
    } catch (e) {
        
      if (mounted) {
        // Cerrar el diálogo de carga en caso de error
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar clientes: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _cargarArchivoExcelPath(String filePath) async {
    try {
      final resultado = await _clienteService.cargarClientesMasivosPath(
        filePath,
      );

      if (mounted) {
        // Cerrar el diálogo de carga primero
        Navigator.of(context).pop();

        // Mostrar resultado
        _mostrarResultadoCarga(resultado);
        await _cargarClientes();
      }
    } catch (e) {
        
      if (mounted) {
        // Cerrar el diálogo de carga en caso de error
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar clientes: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _mostrarResultadoCarga(Map<String, dynamic> resultado) {
    final clientesCargados = resultado['clientesCargados'] ?? 0;
    final errores = resultado['errores'] as List? ?? [];
    final mensaje = resultado['message'] ?? 'Proceso completado';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              errores.isEmpty ? Icons.check_circle : Icons.warning_amber,
              color: errores.isEmpty ? Colors.green : Colors.orange,
              size: 28,
            ),
            SizedBox(width: 12),
            Text(
              'Resultado de la Carga',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Container(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.people, color: Colors.green, size: 32),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$clientesCargados',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          'clientes cargados exitosamente',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (errores.isNotEmpty) ...[
                SizedBox(height: 16),
                Text(
                  'Errores encontrados (${errores.length}):',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  height: 150,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: ListView.builder(
                    itemCount: errores.length > 10 ? 10 : errores.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• ${errores[index]}',
                          style: TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                      );
                    },
                  ),
                ),
                if (errores.length > 10)
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      '... y ${errores.length - 10} errores más',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                    ),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('Aceptar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
