import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../models/proveedor.dart';
import '../services/proveedor_service.dart';
import '../theme/app_theme.dart';
import '../utils/pagination_mixin.dart';
import '../widgets/common/screen_header.dart';

class ProveedoresListScreen extends StatefulWidget {
  const ProveedoresListScreen({super.key});

  @override
  _ProveedoresListScreenState createState() => _ProveedoresListScreenState();
}

class _ProveedoresListScreenState extends State<ProveedoresListScreen>
    with PaginacionMixin<ProveedoresListScreen> {
  final ProveedorService _proveedorService = ProveedorService();

  // Controladores de filtros
  final _filtroNombreController = TextEditingController();
  final _filtroTelefonoController = TextEditingController();
  final _filtroDireccionController = TextEditingController();

  List<Proveedor> _proveedores = [];
  List<Proveedor> _proveedoresFiltrados = [];
  bool _isLoading = false;
  bool _guardandoProveedor = false;

  @override
  void initState() {
    super.initState();
    _cargarProveedores();
  }

  @override
  void dispose() {
    _filtroNombreController.dispose();
    _filtroTelefonoController.dispose();
    _filtroDireccionController.dispose();
    super.dispose();
  }

  Future<void> _cargarProveedores() async {
    setState(() => _isLoading = true);
    try {
      final proveedores = await _proveedorService.getProveedores();
      setState(() {
        _proveedores = proveedores;
        _aplicarFiltros();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar proveedores: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _aplicarFiltros() {
    setState(() {
      _proveedoresFiltrados = _proveedores.where((proveedor) {
        final matchNombre =
            _filtroNombreController.text.isEmpty ||
            proveedor.nombre.toLowerCase().contains(
              _filtroNombreController.text.toLowerCase(),
            );
        final matchTelefono =
            _filtroTelefonoController.text.isEmpty ||
            (proveedor.telefono?.toLowerCase().contains(
                  _filtroTelefonoController.text.toLowerCase(),
                ) ??
                false);
        final matchDireccion =
            _filtroDireccionController.text.isEmpty ||
            (proveedor.direccion?.toLowerCase().contains(
                  _filtroDireccionController.text.toLowerCase(),
                ) ??
                false);
        return matchNombre && matchTelefono && matchDireccion;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScreenHeader(
          icon: Icons.people_outline,
          title: 'Lista proveedores',
          badge: '${_proveedoresFiltrados.length}',
          actions: [
            ScreenHeaderAction.success(
              icon: Icons.file_upload,
              label: 'Carga Masiva',
              mobileLabel: 'Carga',
              onPressed: _mostrarDialogoCargaMasiva,
            ),
            ScreenHeaderAction.primary(
              icon: Icons.add,
              label: 'Crear Proveedor',
              mobileLabel: 'Crear',
              onPressed: _mostrarDialogoProveedor,
            ),
          ],
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(context.isMobile ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildBarraFiltros(),
                const SizedBox(height: 16),
                Expanded(child: _buildTabla()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBarraFiltros() {
    final isMobile = context.isMobile;
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Campo Nombre Proveedor
          SizedBox(
            width: isMobile ? double.infinity : 240,
            child: _buildCampoFiltro(
              controller: _filtroNombreController,
              hint: 'Nombre Proveedor',
              onChanged: (_) => _aplicarFiltros(),
            ),
          ),
          // Campo Teléfono
          SizedBox(
            width: isMobile ? double.infinity : 160,
            child: _buildCampoFiltro(
              controller: _filtroTelefonoController,
              hint: 'Teléfono',
              onChanged: (_) => _aplicarFiltros(),
            ),
          ),
          // Campo Dirección
          SizedBox(
            width: isMobile ? double.infinity : 200,
            child: _buildCampoFiltro(
              controller: _filtroDireccionController,
              hint: 'Dirección Proveedor',
              onChanged: (_) => _aplicarFiltros(),
            ),
          ),
          // Botón Saldar masivo
          if (!isMobile)
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Saldar masivo - Próximamente')),
                );
              },
              child: Text(
                'Saldar masivo',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          // Botón Excel
          Container(
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Exportar Excel - Próximamente')),
                );
              },
              icon: Icon(Icons.file_download, color: Colors.white),
              tooltip: 'Exportar Excel',
            ),
          ),
          // Botón PDF
          Container(
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Exportar PDF - Próximamente')),
                );
              },
              icon: Icon(Icons.picture_as_pdf, color: Colors.white),
              tooltip: 'Exportar PDF',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampoFiltro({
    required TextEditingController controller,
    required String hint,
    required Function(String) onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade500),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          borderSide: BorderSide(color: AppTheme.primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildTabla() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        children: [
          // Encabezado de la tabla
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                _buildEncabezadoColumna('ID', flex: 2),
                _buildEncabezadoColumna('Nombre', flex: 4),
                _buildEncabezadoColumna('Teléfono', flex: 2),
                _buildEncabezadoColumna('Dirección', flex: 3),
                SizedBox(width: 100), // Espacio para acciones
              ],
            ),
          ),

          // Filas de la tabla
          Expanded(
            child: _proveedoresFiltrados.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey.shade600,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No hay proveedores registrados',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          itemCount: paginarLista(_proveedoresFiltrados).length,
                          itemBuilder: (context, index) {
                            final proveedor = paginarLista(
                              _proveedoresFiltrados,
                            )[index];
                            return _buildFilaTabla(proveedor, index);
                          },
                        ),
                      ),
                      buildPaginacion(
                        totalItems: _proveedoresFiltrados.length,
                        accentColor: AppTheme.primary,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEncabezadoColumna(String texto, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        texto,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildFilaTabla(Proveedor proveedor, int index) {
    final isEven = index % 2 == 0;
    final backgroundColor = isEven ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.surface;

    // Mostrar ID corto si es UUID, o el documento si existe
    String idDisplay =
        proveedor.documento ??
        (proveedor.id.length > 8 ? proveedor.id.substring(0, 8) : proveedor.id);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade800, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // ID
          Expanded(
            flex: 2,
            child: Text(
              idDisplay,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
            ),
          ),

          // Nombre
          Expanded(
            flex: 4,
            child: Text(
              proveedor.nombre,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Teléfono
          Expanded(
            flex: 2,
            child: Text(
              proveedor.telefono ?? '',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
            ),
          ),

          // Dirección
          Expanded(
            flex: 3,
            child: Text(
              proveedor.direccion ?? '',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Acciones
          Container(
            width: 100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Botón Editar
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.success,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.build, color: Colors.white, size: 18),
                    onPressed: () =>
                        _mostrarDialogoProveedor(proveedor: proveedor),
                    tooltip: 'Editar',
                  ),
                ),
                SizedBox(width: 8),

                // Botón Eliminar
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.close, color: Colors.white, size: 18),
                    onPressed: () => _confirmarEliminar(proveedor),
                    tooltip: 'Eliminar',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoProveedor({Proveedor? proveedor}) {
    final bool esEdicion = proveedor != null;

    // Controladores
    final documentoController = TextEditingController(
      text: proveedor?.documento ?? '',
    );
    final dvController = TextEditingController(
      text: proveedor?.digitoVerificacion ?? '',
    );
    final nombresController = TextEditingController(
      text: proveedor?.nombre ?? '',
    );
    final apellidosController = TextEditingController(
      text: proveedor?.apellidos ?? '',
    );
    final telefonoController = TextEditingController(
      text: proveedor?.telefono ?? '',
    );
    final direccionController = TextEditingController(
      text: proveedor?.direccion ?? '',
    );
    final correoController = TextEditingController(
      text: proveedor?.email ?? '',
    );
    final actividadEconomicaController = TextEditingController(
      text: proveedor?.actividadEconomica ?? '',
    );
    final numeroCuentaController = TextEditingController(
      text: proveedor?.numeroCuenta ?? '',
    );
    final cuentasPorPagarController = TextEditingController(
      text: proveedor?.cuentasPorPagar ?? '',
    );
    final cuentasDevolucionController = TextEditingController(
      text: proveedor?.cuentasDevolucion ?? '',
    );

    // Variables de estado para dropdowns
    String? tipo = proveedor?.tipo ?? 'Persona Natural';
    String? tipoId = proveedor?.tipoId;
    String? departamento = proveedor?.departamento;
    String? ciudad = proveedor?.ciudad;
    String? responsableIVA = proveedor?.responsableIVA;
    String? calidadRetenedor = proveedor?.calidadRetenedor;
    String? banco = proveedor?.banco;
    String? tipoCuenta = proveedor?.tipoCuenta;
    // Campos DIAN
    String? tipoRegimenTributario = proveedor?.tipoRegimenTributario;
    bool esResidenteColombia = proveedor?.esResidenteColombia ?? true;
    final codigoCiudadDianController = TextEditingController(text: proveedor?.codigoCiudadDian ?? '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Row(
            children: [
              Icon(
                esEdicion ? Icons.edit : Icons.person_add,
                color: AppTheme.primary,
              ),
              SizedBox(width: 12),
              Text(
                esEdicion ? 'Editar Proveedor' : 'Crear Proveedor',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20),
              ),
            ],
          ),
          content: Container(
            width: 800,
            height: 500,
            child: DefaultTabController(
              length: 4,
              child: Column(
                children: [
                  TabBar(
                    indicatorColor: AppTheme.primary,
                    labelColor: AppTheme.primary,
                    unselectedLabelColor: Colors.grey.shade400,
                    tabs: [
                      Tab(text: 'Identificación'),
                      Tab(text: 'Contacto'),
                      Tab(text: 'Tributario'),
                      Tab(text: 'Bancario'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Tab 1: Identificación
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Identificación',
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: _buildCampoDialogoClaro(
                                        'ID *',
                                        documentoController,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: _buildCampoDialogoClaro(
                                        'DV',
                                        dvController,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: _buildCampoDialogoClaro(
                                        'Nombres *',
                                        nombresController,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: _buildCampoDialogoClaro(
                                        'Apellidos',
                                        apellidosController,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDropdownClaro(
                                        'Tipo *',
                                        tipo,
                                        [
                                          'Persona Natural',
                                          'Persona Jurídica',
                                        ],
                                        (value) =>
                                            setDialogState(() => tipo = value),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: _buildDropdownClaro(
                                        'Tipo ID *',
                                        tipoId,
                                        ['CC', 'NIT', 'Pasaporte', 'CE'],
                                        (value) => setDialogState(
                                          () => tipoId = value,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Tab 2: Contacto
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Contacto',
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildCampoDialogoClaro(
                                        'Teléfono',
                                        telefonoController,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: _buildCampoDialogoClaro(
                                        'Correo',
                                        correoController,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                _buildCampoDialogoClaro(
                                  'Dirección',
                                  direccionController,
                                ),
                                SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDropdownClaro(
                                        'Departamento',
                                        departamento,
                                        [
                                          'Cundinamarca',
                                          'Antioquia',
                                          'Valle del Cauca',
                                          'Atlántico',
                                          'Santander',
                                        ],
                                        (value) => setDialogState(
                                          () => departamento = value,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: _buildDropdownClaro(
                                        'Ciudad',
                                        ciudad,
                                        [
                                          'Bogotá',
                                          'Medellín',
                                          'Cali',
                                          'Barranquilla',
                                          'Bucaramanga',
                                        ],
                                        (value) =>
                                            setDialogState(() => ciudad = value),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                _buildCampoDialogoClaro(
                                  'Actividad Económica',
                                  actividadEconomicaController,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Tab 3: Tributario
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tributario',
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDropdownClaro(
                                        'Responsable de IVA',
                                        responsableIVA,
                                        ['SI', 'NO'],
                                        (value) => setDialogState(
                                          () => responsableIVA = value,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: _buildDropdownClaro(
                                        'Agente Retenedor',
                                        calidadRetenedor,
                                        ['Agente de retención', 'No aplica'],
                                        (value) => setDialogState(
                                          () => calidadRetenedor = value,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                // ── Campos DIAN ──
                                Padding(
                                  padding: EdgeInsets.only(top: 8, bottom: 4),
                                  child: Text('DIAN — Documento Soporte',
                                      style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                                _buildDropdownClaro(
                                  'Régimen tributario',
                                  tipoRegimenTributario,
                                  ['Responsable de IVA', 'No Responsable de IVA', 'Gran Contribuyente'],
                                  (value) => setDialogState(() => tipoRegimenTributario = value),
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildCampoDialogoClaro('Código ciudad DIAN', codigoCiudadDianController),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: _buildDropdownClaro(
                                        'Residente Colombia',
                                        esResidenteColombia ? 'Sí' : 'No',
                                        ['Sí', 'No'],
                                        (v) => setDialogState(() => esResidenteColombia = v == 'Sí'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Tab 4: Bancario
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bancario',
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDropdownClaro(
                                        'Banco',
                                        banco,
                                        [
                                          'Bancolombia',
                                          'Davivienda',
                                          'BBVA',
                                          'Banco de Bogotá',
                                          'Nequi',
                                        ],
                                        (value) =>
                                            setDialogState(() => banco = value),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: _buildDropdownClaro(
                                        'Tipo cuenta',
                                        tipoCuenta,
                                        ['Ahorros', 'Corriente'],
                                        (value) => setDialogState(
                                          () => tipoCuenta = value,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                _buildCampoDialogoClaro(
                                  'Número de cuenta',
                                  numeroCuentaController,
                                ),
                                SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildCampoDialogoClaro(
                                        'Cuentas por pagar',
                                        cuentasPorPagarController,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: _buildCampoDialogoClaro(
                                        'Cuentas de devolución',
                                        cuentasDevolucionController,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Text(
                'Volver',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            ElevatedButton(
              onPressed: _guardandoProveedor
                  ? null
                  : () async {
                      if (nombresController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('El nombre es requerido'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => _guardandoProveedor = true);

                      try {
                        final nuevoProveedor = Proveedor(
                          id: proveedor?.id ?? '',
                          nombre: nombresController.text.trim(),
                          apellidos: apellidosController.text.trim().isEmpty
                              ? null
                              : apellidosController.text.trim(),
                          documento: documentoController.text.trim().isEmpty
                              ? null
                              : documentoController.text.trim(),
                          digitoVerificacion: dvController.text.trim().isEmpty
                              ? null
                              : dvController.text.trim(),
                          email: correoController.text.trim().isEmpty
                              ? null
                              : correoController.text.trim(),
                          telefono: telefonoController.text.trim().isEmpty
                              ? null
                              : telefonoController.text.trim(),
                          direccion: direccionController.text.trim().isEmpty
                              ? null
                              : direccionController.text.trim(),
                          tipo: tipo,
                          tipoId: tipoId,
                          departamento: departamento,
                          ciudad: ciudad,
                          actividadEconomica:
                              actividadEconomicaController.text.trim().isEmpty
                              ? null
                              : actividadEconomicaController.text.trim(),
                          responsableIVA: responsableIVA,
                          calidadRetenedor: calidadRetenedor,
                          banco: banco,
                          tipoCuenta: tipoCuenta,
                          tipoRegimenTributario: tipoRegimenTributario,
                          esResidenteColombia: esResidenteColombia,
                          codigoCiudadDian: codigoCiudadDianController.text.trim().isEmpty
                              ? null
                              : codigoCiudadDianController.text.trim(),
                          numeroCuenta:
                              numeroCuentaController.text.trim().isEmpty
                              ? null
                              : numeroCuentaController.text.trim(),
                          cuentasPorPagar:
                              cuentasPorPagarController.text.trim().isEmpty
                              ? null
                              : cuentasPorPagarController.text.trim(),
                          cuentasDevolucion:
                              cuentasDevolucionController.text.trim().isEmpty
                              ? null
                              : cuentasDevolucionController.text.trim(),
                          fechaCreacion:
                              proveedor?.fechaCreacion ?? DateTime.now(),
                          fechaActualizacion: DateTime.now(),
                        );

                        if (esEdicion) {
                          await _proveedorService.actualizarProveedor(
                            nuevoProveedor,
                          );
                        } else {
                          await _proveedorService.crearProveedor(
                            nuevoProveedor,
                          );
                        }

                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              esEdicion
                                  ? 'Proveedor actualizado exitosamente'
                                  : 'Proveedor creado exitosamente',
                            ),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                        await _cargarProveedores();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } finally {
                        setDialogState(() => _guardandoProveedor = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: _guardandoProveedor
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Guardar',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampoDialogoClaro(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(color: cs.onSurface),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: cs.onSurface.withValues(alpha:0.6), fontWeight: FontWeight.w500),
          filled: true,
          fillColor: cs.surfaceContainerHighest,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cs.outline)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cs.outline)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.primary, width: 2)),
        ),
      ),
    );
  }

  Widget _buildDropdownClaro(
    String label,
    String? value,
    List<String> opciones,
    Function(String?) onChanged,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: cs.onSurface.withValues(alpha:0.6), fontWeight: FontWeight.w500),
          filled: true,
          fillColor: cs.surfaceContainerHighest,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cs.outline)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cs.outline)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.primary, width: 2)),
        ),
        dropdownColor: cs.surfaceContainerHighest,
        style: TextStyle(color: cs.onSurface),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text('--', style: TextStyle(color: cs.onSurface.withValues(alpha:0.4))),
          ),
          ...opciones.map((opcion) => DropdownMenuItem<String>(value: opcion, child: Text(opcion))),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _confirmarEliminar(Proveedor proveedor) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 12),
            Text(
              'Confirmar eliminación',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar el proveedor "${proveedor.nombre}"?',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _proveedorService.eliminarProveedor(proveedor.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Proveedor eliminado exitosamente'),
            backgroundColor: AppTheme.success,
          ),
        );
        await _cargarProveedores();
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

  // ============================================
  // 📦 CARGA MASIVA - IGUAL QUE PRODUCTOS
  // ============================================
  void _mostrarDialogoCargaMasiva() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Row(
            children: [
              Icon(Icons.upload_file, color: AppTheme.primary),
              SizedBox(width: 12),
              Text(
                'Carga Masiva de Proveedores',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
            ],
          ),
          content: Container(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selecciona un archivo Excel (.xlsx) con los datos de los proveedores.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                ),
                SizedBox(height: 16),
                Text(
                  'Columnas requeridas:',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.7),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '• nombre\n• documento\n• email\n• telefono\n• direccion',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.7)),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _seleccionarArchivoCargaMasiva();
              },
              icon: Icon(Icons.folder_open),
              label: Text('Elegir archivo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _seleccionarArchivoCargaMasiva() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final bytes = result.files.first.bytes;
        if (bytes == null)
          throw Exception('No se pudo obtener los bytes del archivo');

        await _procesarArchivoExcel(bytes);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al seleccionar archivo: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _procesarArchivoExcel(Uint8List bytes) async {
    try {
      // Mostrar diálogo de progreso
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          content: Row(
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              SizedBox(width: 16),
              Text(
                'Procesando archivo Excel...',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
            ],
          ),
        ),
      );

      // Enviar archivo al backend
      final resultado = await _proveedorService.cargaMasivaProveedores(
        bytes.toList(),
      );

      // Cerrar diálogo de progreso
      if (mounted) Navigator.pop(context);

      // Recargar lista
      await _cargarProveedores();

      // Mostrar resultado
      if (mounted) {
        _mostrarResultadoCarga(resultado);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al procesar archivo: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  void _mostrarResultadoCarga(Map<String, dynamic> resultado) {
    final proveedoresCreados = resultado['proveedoresCreados'] ?? 0;
    final proveedoresActualizados = resultado['proveedoresActualizados'] ?? 0;
    final errores = resultado['errores'] as List? ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Row(
          children: [
            Icon(
              errores.isEmpty ? Icons.check_circle : Icons.warning,
              color: errores.isEmpty ? AppTheme.success : Colors.orange,
            ),
            SizedBox(width: 8),
            Text(
              'Resultado de la carga',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildResumenCarga('Creados', proveedoresCreados),
            SizedBox(height: 8),
            _buildResumenCarga('Actualizados', proveedoresActualizados),
            if (errores.isNotEmpty) ...[
              SizedBox(height: 12),
              Text(
                'Errores (${errores.length}):',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              SizedBox(height: 8),
              Container(
                constraints: BoxConstraints(maxHeight: 150),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    errores.map((e) => '• ${e['mensaje'] ?? e}').join('\n'),
                    style: TextStyle(color: Colors.grey.shade300, fontSize: 11),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenCarga(String label, int cantidad) {
    return Row(
      children: [
        Text(
          '$label:',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.7), fontSize: 12),
        ),
        SizedBox(width: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha:0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            cantidad.toString(),
            style: TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
