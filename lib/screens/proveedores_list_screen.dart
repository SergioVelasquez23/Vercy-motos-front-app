import 'package:flutter/material.dart';
import '../models/proveedor.dart';
import '../services/proveedor_service.dart';
import '../theme/app_theme.dart';
import '../widgets/vercy_sidebar_layout.dart';

class ProveedoresListScreen extends StatefulWidget {
  const ProveedoresListScreen({super.key});

  @override
  _ProveedoresListScreenState createState() => _ProveedoresListScreenState();
}

class _ProveedoresListScreenState extends State<ProveedoresListScreen> {
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
    return VercySidebarLayout(
      title: 'Proveedores',
      child: Container(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            Text(
              'Lista proveedores',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 24),

            // Barra de filtros y acciones
            _buildBarraFiltros(),
            SizedBox(height: 16),

            // Tabla de proveedores
            Expanded(child: _buildTabla()),
          ],
        ),
      ),
    );
  }

  Widget _buildBarraFiltros() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Row(
        children: [
          // Campo Nombre Proveedor
          Expanded(
            flex: 2,
            child: _buildCampoFiltro(
              controller: _filtroNombreController,
              hint: 'Nombre Proveedor',
              onChanged: (_) => _aplicarFiltros(),
            ),
          ),
          SizedBox(width: 12),

          // Campo Teléfono
          Expanded(
            child: _buildCampoFiltro(
              controller: _filtroTelefonoController,
              hint: 'Teléfono',
              onChanged: (_) => _aplicarFiltros(),
            ),
          ),
          SizedBox(width: 12),

          // Campo Dirección
          Expanded(
            child: _buildCampoFiltro(
              controller: _filtroDireccionController,
              hint: 'Dirección Proveedor',
              onChanged: (_) => _aplicarFiltros(),
            ),
          ),
          SizedBox(width: 24),

          // Botón Crear Proveedor
          ElevatedButton.icon(
            onPressed: () => _mostrarDialogoProveedor(),
            icon: Icon(Icons.add, color: Colors.white),
            label: Text(
              'Crear Proveedor',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          SizedBox(width: 12),

          // Botón Saldar masivo (placeholder)
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Saldar masivo - Próximamente')),
              );
            },
            child: Text(
              'Saldar masivo',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          SizedBox(width: 12),

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
          SizedBox(width: 8),

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
      style: TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade500),
        filled: true,
        fillColor: AppTheme.surfaceDark,
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
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        children: [
          // Encabezado de la tabla
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
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
                : ListView.builder(
                    itemCount: _proveedoresFiltrados.length,
                    itemBuilder: (context, index) {
                      final proveedor = _proveedoresFiltrados[index];
                      return _buildFilaTabla(proveedor, index);
                    },
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
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildFilaTabla(Proveedor proveedor, int index) {
    final isEven = index % 2 == 0;
    final backgroundColor = isEven ? AppTheme.cardBg : AppTheme.surfaceDark;

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
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),

          // Nombre
          Expanded(
            flex: 4,
            child: Text(
              proveedor.nombre,
              style: TextStyle(color: Colors.white, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Teléfono
          Expanded(
            flex: 2,
            child: Text(
              proveedor.telefono ?? '',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),

          // Dirección
          Expanded(
            flex: 3,
            child: Text(
              proveedor.direccion ?? '',
              style: TextStyle(color: Colors.white, fontSize: 13),
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

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Icon(
                esEdicion ? Icons.edit : Icons.person_add,
                color: AppTheme.primary,
              ),
              SizedBox(width: 12),
              Text(
                esEdicion ? 'Editar Proveedor' : 'Crear Proveedor',
                style: TextStyle(color: Colors.black87, fontSize: 20),
              ),
            ],
          ),
          content: Container(
            width: 800,
            constraints: BoxConstraints(maxHeight: 600),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Fila 1: ID, dv, Nombres, Apellidos
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildCampoDialogoClaro(
                          'ID',
                          documentoController,
                        ),
                      ),
                      SizedBox(width: 12),
                      Container(
                        width: 80,
                        child: _buildCampoDialogoClaro('dv', dvController),
                      ),
                      SizedBox(width: 12),
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

                  // Fila 2: Tipo, Tipo ID
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdownClaro('Tipo', tipo, [
                          'Persona Natural',
                          'Persona Jurídica',
                        ], (value) => setDialogState(() => tipo = value)),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdownClaro(
                          'Tipo ID',
                          tipoId,
                          ['CC', 'NIT', 'Pasaporte', 'CE'],
                          (value) => setDialogState(() => tipoId = value),
                        ),
                      ),
                    ],
                  ),

                  // Fila 3: Departamento, Ciudad
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
                          (value) => setDialogState(() => departamento = value),
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
                          (value) => setDialogState(() => ciudad = value),
                        ),
                      ),
                    ],
                  ),

                  // Fila 4: Teléfono, Dirección
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
                          'Dirección',
                          direccionController,
                        ),
                      ),
                    ],
                  ),

                  // Fila 5: Correo, Actividad Económica
                  Row(
                    children: [
                      Expanded(
                        child: _buildCampoDialogoClaro(
                          'Correo',
                          correoController,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildCampoDialogoClaro(
                          'Act. Económica',
                          actividadEconomicaController,
                        ),
                      ),
                    ],
                  ),

                  // Fila 6: Responsable de IVA, Calidad de agente retenedor
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdownClaro(
                          'Responsable de IVA',
                          responsableIVA,
                          ['SI', 'NO'],
                          (value) =>
                              setDialogState(() => responsableIVA = value),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdownClaro(
                          'Calidad de agente retenedor de impuestos',
                          calidadRetenedor,
                          ['Agente de retención', 'No aplica'],
                          (value) =>
                              setDialogState(() => calidadRetenedor = value),
                        ),
                      ),
                    ],
                  ),

                  // Fila 7: Banco, Tipo cuenta
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
                          (value) => setDialogState(() => banco = value),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildDropdownClaro(
                          'Tipo cuenta',
                          tipoCuenta,
                          ['Ahorros', 'Corriente'],
                          (value) => setDialogState(() => tipoCuenta = value),
                        ),
                      ),
                    ],
                  ),

                  // Fila 8: Número cuenta
                  _buildCampoDialogoClaro(
                    'Numero cuenta',
                    numeroCuentaController,
                  ),

                  // Fila 9: Cuentas por pagar, Cuentas de devolución
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
                backgroundColor: Color(0xFF00BFA5),
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

  Widget _buildCampoDialogo(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade400),
          filled: true,
          fillColor: AppTheme.surfaceDark,
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
      ),
    );
  }

  Widget _buildCampoDialogoClaro(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppTheme.primary, width: 2),
          ),
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
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppTheme.primary, width: 2),
          ),
        ),
        dropdownColor: Colors.white,
        style: TextStyle(color: Colors.black87),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text('--', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ...opciones.map((opcion) {
            return DropdownMenuItem<String>(value: opcion, child: Text(opcion));
          }),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _confirmarEliminar(Proveedor proveedor) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 12),
            Text(
              'Confirmar eliminación',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar el proveedor "${proveedor.nombre}"?',
          style: TextStyle(color: Colors.grey.shade300),
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
}
