import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/gasto.dart';
import '../models/tipo_gasto.dart';
import '../models/cuadre_caja.dart';
import '../models/proveedor.dart';
import '../services/gasto_service.dart';
import '../services/cuadre_caja_service.dart';
import '../services/proveedor_service.dart';
import '../theme/app_theme.dart';

class GastosScreen extends StatefulWidget {
  final String? cuadreCajaId;
  final bool mostrarFormulario;

  const GastosScreen({
    super.key,
    this.cuadreCajaId,
    this.mostrarFormulario = false,
  });

  @override
  _GastosScreenState createState() => _GastosScreenState();
}

class _GastosScreenState extends State<GastosScreen> {
  // Services
  final GastoService _gastoService = GastoService();
  final CuadreCajaService _cuadreCajaService = CuadreCajaService();
  final ProveedorService _proveedorService = ProveedorService();

  // Controllers
  final TextEditingController _conceptoController = TextEditingController();
  final TextEditingController _montoController = TextEditingController();
  final TextEditingController _numeroReciboController = TextEditingController();
  final TextEditingController _numeroFacturaController =
      TextEditingController();
  final TextEditingController _subtotalController = TextEditingController();
  final TextEditingController _impuestosController = TextEditingController();

  // Estado
  List<Gasto> _gastos = [];
  List<TipoGasto> _tiposGasto = [];
  List<CuadreCaja> _cuadresDisponibles = [];
  List<Proveedor> _proveedores = [];
  bool _isLoading = false;
  bool _showForm = false;
  bool _pagadoDesdeCaja = false; // ✅ Campo para checkbox

  // Variable para controlar el timeout del botón guardar gasto
  bool _guardandoGasto = false;

  // Selecciones
  String? _selectedCuadreId;
  String? _selectedTipoGastoId;
  String? _selectedProveedorId;
  int _proveedorResetKey = 0;
  String? _selectedFormaPago;
  DateTime _selectedDate = DateTime.now();
  Gasto? _gastoEditando;

  // Opciones de forma de pago
  final List<String> _formasPago = ['Efectivo', 'Transferencia', 'Cheque'];

  // Variables para filtros de búsqueda
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  String? _filtroConcepto;
  final TextEditingController _conceptoBusquedaController =
      TextEditingController();

  // Variables para el nuevo formulario de gastos
  DateTime? _fechaVencimiento;
  String? _selectedTipoGastoIdNuevo;
  bool _documentoSoporte = false;
  bool _mostrarRetenciones = false;
  List<Map<String, dynamic>> _conceptosGasto = [];

  // Controladores para nuevo concepto
  final TextEditingController _nuevoConceptoController =
      TextEditingController();
  final TextEditingController _nuevoValorController = TextEditingController();
  String _nuevoImpuestoTipo = 'Impuesto';

  // Controladores para retenciones
  final TextEditingController _retencionController = TextEditingController();
  final TextEditingController _reteivaController = TextEditingController();
  final TextEditingController _reteicaController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();

  // Totales calculados
  double _subtotalGasto = 0;
  double _descuentoGasto = 0;
  double _impuestosGasto = 0;
  double _totalGasto = 0;

  @override
  void initState() {
    super.initState();
    _selectedCuadreId = widget.cuadreCajaId;
    _showForm = widget.mostrarFormulario;
    _initializeData();
  }

  @override
  void dispose() {
    _conceptoController.dispose();
    _montoController.dispose();
    _numeroReciboController.dispose();
    _numeroFacturaController.dispose();
    _subtotalController.dispose();
    _impuestosController.dispose();
    _conceptoBusquedaController.dispose();
    _nuevoConceptoController.dispose();
    _nuevoValorController.dispose();
    _retencionController.dispose();
    _reteivaController.dispose();
    _reteicaController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadTiposGasto(),
        _loadCuadresDisponibles(),
        _loadProveedores(),
        _loadGastos(),
      ]);
    } catch (e) {
      _showError('Error al cargar datos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTiposGasto() async {
    try {
      final tipos = await _gastoService.getAllTiposGasto();
        
      if (mounted) {
        setState(() => _tiposGasto = tipos.where((t) => t.activo).toList());
      }
    } catch (e) {
        
    }
  }

  Future<void> _loadCuadresDisponibles() async {
    try {
      // Obtener solo cuadres abiertos (no cerrados)
      final allCuadres = await _cuadreCajaService.getAllCuadres();
      if (mounted) {
        setState(() {
          _cuadresDisponibles = allCuadres.where((c) => !c.cerrada).toList();
        });
      }
    } catch (e) {
        
    }
  }

  Future<void> _loadProveedores() async {
    try {
      final proveedores = await _proveedorService.getProveedores();
      if (mounted) {
        setState(() => _proveedores = proveedores);
      }
    } catch (e) {
        
    }
  }

  Future<void> _loadGastos() async {
    try {
      List<Gasto> gastos;
      if (_selectedCuadreId != null) {
        gastos = await _gastoService.getGastosByCuadre(_selectedCuadreId!);
      } else {
        gastos = await _gastoService.getAllGastos();
      }

      // Ordenar gastos por fecha descendente (más recientes primero)
      gastos.sort((a, b) => b.fechaGasto.compareTo(a.fechaGasto));

      setState(() => _gastos = gastos);
    } catch (e) {
      _showError('Error al cargar gastos: $e');
    }
  }

  List<Gasto> get _gastosFiltrados {
    List<Gasto> gastosFiltrados = List.from(_gastos);

    // Filtrar por concepto
    if (_filtroConcepto != null && _filtroConcepto!.isNotEmpty) {
      gastosFiltrados = gastosFiltrados
          .where(
            (gasto) => gasto.concepto.toLowerCase().contains(
              _filtroConcepto!.toLowerCase(),
            ),
          )
          .toList();
    }

    // Filtrar por rango de fechas
    if (_fechaInicio != null && _fechaFin != null) {
      gastosFiltrados = gastosFiltrados.where((gasto) {
        final fechaGasto = DateTime(
          gasto.fechaGasto.year,
          gasto.fechaGasto.month,
          gasto.fechaGasto.day,
        );
        final inicio = DateTime(
          _fechaInicio!.year,
          _fechaInicio!.month,
          _fechaInicio!.day,
        );
        final fin = DateTime(_fechaFin!.year, _fechaFin!.month, _fechaFin!.day);
        return fechaGasto.isAfter(inicio.subtract(Duration(days: 1))) &&
            fechaGasto.isBefore(fin.add(Duration(days: 1)));
      }).toList();
    }

    return gastosFiltrados;
  }

  void _limpiarFiltros() {
    setState(() {
      _fechaInicio = null;
      _fechaFin = null;
      _filtroConcepto = null;
      _conceptoBusquedaController.clear();
    });
  }

  void _showFormDialog({Gasto? gasto}) {
    _gastoEditando = gasto;

    if (gasto != null) {
      // Editar gasto existente - cargar datos en los controladores
      // DEBUG

      _conceptoController.text = gasto.concepto;
      _montoController.text = gasto.monto.toString();
      _numeroReciboController.text = gasto.numeroRecibo ?? '';
      _numeroFacturaController.text = gasto.numeroFactura ?? '';
      _subtotalController.text = gasto.subtotal.toString();
      _impuestosController.text = gasto.impuestos.toString();
      _selectedTipoGastoId = gasto.tipoGastoId;
      _selectedFormaPago = gasto.formaPago;
      _selectedDate = gasto.fechaGasto;
      _selectedCuadreId = gasto.cuadreCajaId;
      _pagadoDesdeCaja = gasto.pagadoDesdeCaja;

      // Para el nuevo formulario
      _selectedTipoGastoIdNuevo = gasto.tipoGastoId;
      _conceptosGasto = [
        {
          'concepto': gasto.concepto,
          'valor': gasto.subtotal,
          'descuento': 0.0,
          'tasa': gasto.impuestos > 0 ? 19.0 : 0.0,
          'impuesto': gasto.impuestos,
          'total': gasto.monto,
        },
      ];
      _subtotalGasto = gasto.subtotal;
      _impuestosGasto = gasto.impuestos;
      _totalGasto = gasto.monto;

      // Buscar el proveedor por nombre para seleccionarlo
      if (gasto.proveedor != null && gasto.proveedor!.isNotEmpty) {
        final proveedor = _proveedores
            .where((p) => p.nombre == gasto.proveedor)
            .firstOrNull;
        _selectedProveedorId = proveedor?.id;
      } else {
        _selectedProveedorId = null;
      }
      _proveedorResetKey++;

      // DEBUG
    } else {
      // Nuevo gasto - limpiar todo
      _clearForm();
      _generateInvoiceNumber();

      // Limpiar nuevo formulario
      _fechaVencimiento = null;
      _selectedTipoGastoIdNuevo = null;
      _documentoSoporte = false;
      _mostrarRetenciones = false;
      _conceptosGasto = [];
      _nuevoConceptoController.clear();
      _nuevoValorController.clear();
      _nuevoImpuestoTipo = 'Impuesto';
      _retencionController.clear();
      _reteivaController.clear();
      _reteicaController.clear();
      _descripcionController.clear();
      _subtotalGasto = 0;
      _descuentoGasto = 0;
      _impuestosGasto = 0;
      _totalGasto = 0;
    }

    setState(() {
      _showForm = true;
    });
  }

  void _generateInvoiceNumber() {
    // Generar número de factura basado en la fecha y hora actual
    final now = DateTime.now();
    final timestamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    _numeroFacturaController.text = 'FACT-$timestamp';
  }

  void _clearForm() {
    _conceptoController.clear();
    _montoController.clear();
    _numeroReciboController.clear();
    _numeroFacturaController.clear();
    _subtotalController.clear();
    _impuestosController.clear();
    _selectedTipoGastoId = null;
    _selectedProveedorId = null;
    _proveedorResetKey++;
    _selectedFormaPago = null;
    _selectedDate = DateTime.now();
    _pagadoDesdeCaja = false; // ✅ Reset checkbox
    if (widget.cuadreCajaId != null) {
      _selectedCuadreId = widget.cuadreCajaId;
    }
  }

  Future<void> _saveGasto() async {
    if (!_validateForm()) return;

    // 🚀 TIMEOUT: Verificar si ya está guardando
    if (_guardandoGasto) return;

    setState(() {
      _isLoading = true;
      _guardandoGasto = true;
    });
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final responsable = userProvider.userName ?? 'Usuario Desconocido';

      if (_gastoEditando != null) {
        // Actualizar gasto existente
        // Obtener nombre del proveedor seleccionado
        String? proveedorNombre;
        if (_selectedProveedorId != null) {
          final proveedor = _proveedores
              .where((p) => p.id == _selectedProveedorId)
              .firstOrNull;
          proveedorNombre = proveedor?.nombre;
        }

        await _gastoService.updateGasto(
          _gastoEditando!.id!,
          cuadreCajaId: _selectedCuadreId,
          tipoGastoId: _selectedTipoGastoId,
          concepto: _conceptoController.text,
          monto: double.parse(_montoController.text),
          responsable: responsable,
          fechaGasto: _selectedDate,
          numeroRecibo: _numeroReciboController.text.isEmpty
              ? null
              : _numeroReciboController.text,
          numeroFactura: _numeroFacturaController.text.isEmpty
              ? null
              : _numeroFacturaController.text,
          proveedor: proveedorNombre,
          formaPago: _selectedFormaPago,
          subtotal: double.tryParse(_subtotalController.text),
          impuestos: double.tryParse(_impuestosController.text),
          pagadoDesdeCaja: _pagadoDesdeCaja,
        );
        _showSuccess('Gasto actualizado exitosamente');
      } else {
        // Crear nuevo gasto
        // Obtener nombre del proveedor seleccionado
        String? proveedorNombre;
        if (_selectedProveedorId != null) {
          final proveedor = _proveedores
              .where((p) => p.id == _selectedProveedorId)
              .firstOrNull;
          proveedorNombre = proveedor?.nombre;
        }

        await _gastoService.createGasto(
          cuadreCajaId: _selectedCuadreId!,
          tipoGastoId: _selectedTipoGastoId!,
          concepto: _conceptoController.text,
          monto: double.parse(_montoController.text),
          responsable: responsable,
          fechaGasto: _selectedDate,
          numeroRecibo: _numeroReciboController.text.isEmpty
              ? null
              : _numeroReciboController.text,
          numeroFactura: _numeroFacturaController.text.isEmpty
              ? null
              : _numeroFacturaController.text,
          proveedor: proveedorNombre,
          formaPago: _selectedFormaPago,
          subtotal: double.tryParse(_subtotalController.text),
          impuestos: double.tryParse(_impuestosController.text),
          pagadoDesdeCaja: _pagadoDesdeCaja,
        );
        _showSuccess('Gasto creado exitosamente');
      }

      // Si vino con mostrarFormulario=true (desde menú), navegar a la lista
      if (widget.mostrarFormulario && mounted) {
        Navigator.pushReplacementNamed(context, '/gastos-lista');
        return;
      }

      setState(() => _showForm = false);
      await _loadGastos();
    } catch (e) {
      _showError('Error al guardar gasto: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _guardandoGasto = false;
      });
    }
  }

  bool _validateForm() {
    if (_selectedCuadreId == null) {
      _showError('Debe seleccionar un cuadre de caja');
      return false;
    }
    if (_selectedTipoGastoId == null) {
      _showError('Debe seleccionar un tipo de gasto');
      return false;
    }
    if (_conceptoController.text.trim().isEmpty) {
      _showError('El concepto es requerido');
      return false;
    }
    if (_subtotalController.text.trim().isEmpty ||
        double.tryParse(_subtotalController.text) == null) {
      _showError('El subtotal debe ser un número válido');
      return false;
    }

    // Calcular total automáticamente si no está calculado
    _calculateTotal();

    return true;
  }

  Future<void> _deleteGasto(Gasto gasto) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text(
          'Confirmar eliminación',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          '¿Está seguro de eliminar este gasto?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        setState(() => _isLoading = true);
        final response = await _gastoService.deleteGasto(gasto.id!);
        if (response['success'] == true) {
          _showSuccess('Gasto eliminado exitosamente');
          await _loadGastos();
        } else {
          _showError('Error al eliminar el gasto');
        }
      } catch (e) {
        _showError('Error al eliminar gasto: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _calculateTotal([String? value]) {
    final subtotal = double.tryParse(_subtotalController.text) ?? 0.0;
    final impuestos = double.tryParse(_impuestosController.text) ?? 0.0;
    final total = subtotal + impuestos;
    _montoController.text = total.toStringAsFixed(2);
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }

  // Método para mostrar diálogo de crear tipo de gasto
  Future<void> _mostrarDialogoCrearTipoGasto() async {
    final nombreController = TextEditingController();
    final descripcionController = TextEditingController();
    bool guardando = false;

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
                child: Icon(Icons.category, color: AppTheme.primary, size: 24),
              ),
              SizedBox(width: 12),
              Text(
                'Nuevo Tipo de Gasto',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Container(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nombreController,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Nombre *',
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                    hintText: 'Ej: Servicios Públicos, Nómina...',
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
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: descripcionController,
                  style: TextStyle(color: AppTheme.textPrimary),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Descripción (opcional)',
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                    hintText: 'Descripción del tipo de gasto',
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
                  ),
                ),
              ],
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
                        final nuevoTipo = await _gastoService.createTipoGasto(
                          nombre: nombreController.text.trim(),
                          descripcion: descripcionController.text.trim().isEmpty
                              ? null
                              : descripcionController.text.trim(),
                          activo: true,
                        );

                        // Recargar tipos de gasto
                        await _loadTiposGasto();

                        // Seleccionar el nuevo tipo creado
                        setState(() {
                          _selectedTipoGastoIdNuevo = nuevoTipo.id;
                        });

                        Navigator.pop(context);
                        _showSuccess(
                          'Tipo de gasto "${nuevoTipo.nombre}" creado',
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
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
                  : Text('Crear', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: Text('Gestión de Gastos', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () =>
              Navigator.pushReplacementNamed(context, '/dashboard'),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.category, color: Colors.white),
            tooltip: 'Tipos de Gasto',
            onPressed: () => Navigator.pushNamed(context, '/tipos-gasto'),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _showForm
          ? _buildForm()
          : _buildGastosList(),
      floatingActionButton: !_showForm
          ? FloatingActionButton(
              onPressed: () => _showFormDialog(),
              backgroundColor: AppTheme.primary,
              child: Icon(Icons.add, color: Colors.white),
              tooltip: 'Agregar Nuevo Gasto',
            )
          : null,
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con título
          Text(
            'Crear Gastos',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: 24),

          // Fila superior: Proveedor, Fecha, Vencimiento, Tipo de Gasto, Documento Soporte
          _buildHeaderRow(),
          SizedBox(height: 24),

          // Tabla de conceptos
          _buildConceptosTable(),
          SizedBox(height: 32),

          // Sección inferior: Descripción, Retenciones, Resumen
          _buildBottomSection(),
          SizedBox(height: 24),

          // Botón Pagar
          _buildPayButton(),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Proveedor con botón +
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Proveedor',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Autocomplete<Proveedor>(
                      key: ValueKey(
                        'proveedor_autocomplete_$_proveedorResetKey',
                      ),
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return _proveedores.take(10);
                        }
                        final query = textEditingValue.text.toLowerCase();
                        return _proveedores
                            .where(
                              (p) => p.nombre.toLowerCase().contains(query),
                            )
                            .take(15);
                      },
                      displayStringForOption: (Proveedor p) => p.nombre,
                      initialValue: _selectedProveedorId != null
                          ? TextEditingValue(
                              text:
                                  _proveedores
                                      .where(
                                        (p) => p.id == _selectedProveedorId,
                                      )
                                      .map((p) => p.nombre)
                                      .firstOrNull ??
                                  '',
                            )
                          : null,
                      onSelected: (Proveedor proveedor) {
                        _selectedProveedorId = proveedor.id;
                      },
                      fieldViewBuilder:
                          (
                            BuildContext context,
                            TextEditingController textEditingController,
                            FocusNode focusNode,
                            VoidCallback onFieldSubmitted,
                          ) {
                            return Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceDark,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.textSecondary.withOpacity(
                                    0.3,
                                  ),
                                ),
                              ),
                              child: TextField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 15,
                                ),
                                onChanged: (text) {
                                  // Si el usuario escribe manualmente algo distinto
                                  // al proveedor seleccionado, limpiar la selección
                                  if (_selectedProveedorId != null) {
                                    final selectedProveedor = _proveedores
                                        .where(
                                          (p) => p.id == _selectedProveedorId,
                                        )
                                        .firstOrNull;
                                    if (selectedProveedor?.nombre != text) {
                                      _selectedProveedorId = null;
                                    }
                                  }
                                },
                                decoration: InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  border: InputBorder.none,
                                  hintText: 'Buscar proveedor...',
                                  hintStyle: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 15,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search,
                                    color: AppTheme.textSecondary,
                                    size: 20,
                                  ),
                                  suffixIcon:
                                      textEditingController.text.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(
                                            Icons.clear,
                                            color: AppTheme.textSecondary,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            textEditingController.clear();
                                            setState(() {
                                              _selectedProveedorId = null;
                                              _proveedorResetKey++;
                                            });
                                          },
                                        )
                                      : Icon(
                                          Icons.arrow_drop_down,
                                          color: AppTheme.textSecondary,
                                        ),
                                ),
                              ),
                            );
                          },
                      optionsViewBuilder:
                          (
                            BuildContext context,
                            AutocompleteOnSelected<Proveedor> onSelected,
                            Iterable<Proveedor> options,
                          ) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4.0,
                                color: AppTheme.cardBg,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxHeight: 250,
                                    maxWidth: 350,
                                  ),
                                  child: ListView.builder(
                                    padding: EdgeInsets.all(8.0),
                                    itemCount: options.length,
                                    shrinkWrap: true,
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                          final Proveedor proveedor = options
                                              .elementAt(index);
                                          return InkWell(
                                            onTap: () => onSelected(proveedor),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10,
                                              ),
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  bottom: BorderSide(
                                                    color: AppTheme
                                                        .textSecondary
                                                        .withOpacity(0.15),
                                                    width: 1,
                                                  ),
                                                ),
                                              ),
                                              child: Text(
                                                proveedor.nombre,
                                                style: TextStyle(
                                                  color: AppTheme.textPrimary,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                  ),
                                ),
                              ),
                            );
                          },
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.textSecondary.withOpacity(0.3),
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.add,
                        color: AppTheme.textSecondary,
                        size: 24,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        // TODO: Abrir diálogo para crear proveedor
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(width: 20),

        // Fecha
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fecha:',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) setState(() => _selectedDate = date);
                },
                child: Container(
                  height: 48,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.textSecondary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: AppTheme.textSecondary,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.close,
                        color: AppTheme.textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 20),

        // Vencimiento
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vencimiento:',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate:
                        _fechaVencimiento ??
                        DateTime.now().add(Duration(days: 30)),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) setState(() => _fechaVencimiento = date);
                },
                child: Container(
                  height: 48,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.textSecondary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: AppTheme.textSecondary,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _fechaVencimiento != null
                              ? '${_fechaVencimiento!.day.toString().padLeft(2, '0')}/${_fechaVencimiento!.month.toString().padLeft(2, '0')}/${_fechaVencimiento!.year}'
                              : 'Fecha',
                          style: TextStyle(
                            color: _fechaVencimiento != null
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.close,
                        color: AppTheme.textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 20),

        // Tipo de Gasto con botón +
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tipo de Gasto:',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.textSecondary.withOpacity(0.3),
                        ),
                      ),
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('tipoGasto_$_selectedTipoGastoIdNuevo'),
                        value: _selectedTipoGastoIdNuevo,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: InputBorder.none,
                          hintText: 'Tipo de Gasto',
                          hintStyle: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 15,
                          ),
                        ),
                        dropdownColor: AppTheme.cardBg,
                        isExpanded: true,
                        items: [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Text(
                              'Tipo de Gasto',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ),
                          ..._tiposGasto.map(
                            (t) => DropdownMenuItem<String>(
                              value: t.id,
                              child: Text(t.nombre),
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedTipoGastoIdNuevo = v),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.textSecondary.withOpacity(0.3),
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.add,
                        color: AppTheme.textSecondary,
                        size: 24,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () => _mostrarDialogoCrearTipoGasto(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(width: 20),

        // Documento Soporte con toggle
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Documento Soporte',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 6),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.info_outline,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Container(
              height: 48,
              child: Row(
                children: [
                  Transform.scale(
                    scale: 1.2,
                    child: Switch(
                      value: _documentoSoporte,
                      onChanged: (v) => setState(() => _documentoSoporte = v),
                      activeColor: AppTheme.primary,
                      activeTrackColor: AppTheme.primary.withOpacity(0.3),
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    _documentoSoporte ? 'Sí' : 'No',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConceptosTable() {
    return Column(
      children: [
        // Header de la tabla
        Container(
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
          child: Row(
            children: [
              _buildTableHeader('Concepto', flex: 5),
              _buildTableHeaderButton('Valor', width: 280),
              _buildTableHeaderButton('Impuesto', width: 180),
              _buildTableHeaderButton('Total', width: 160),
              SizedBox(width: 80), // Espacio para columna eliminar/agregar
            ],
          ),
        ),
        // Filas de conceptos
        ..._conceptosGasto.asMap().entries.map((entry) {
          final index = entry.key;
          final concepto = entry.value;
          return _buildConceptoRow(index, concepto);
        }),
        // Fila para agregar nuevo concepto
        _buildNuevoConceptoRow(),
      ],
    );
  }

  Widget _buildTableHeader(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeaderButton(String text, {double width = 140}) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: AppTheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildConceptoRow(int index, Map<String, dynamic> concepto) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: AppTheme.textSecondary.withOpacity(0.3)),
          right: BorderSide(color: AppTheme.textSecondary.withOpacity(0.3)),
          bottom: BorderSide(color: AppTheme.textSecondary.withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Text(
                concepto['concepto'] ?? '',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
              ),
            ),
          ),
          _buildTableCell(
            '\$${(concepto['valor'] ?? 0).toStringAsFixed(0)}',
            width: 280,
          ),
          _buildTableCell(
            '\$${(concepto['impuesto'] ?? 0).toStringAsFixed(0)}',
            width: 180,
          ),
          _buildTableCell(
            '\$${(concepto['total'] ?? 0).toStringAsFixed(0)}',
            width: 160,
          ),
          Container(
            width: 80,
            child: IconButton(
              icon: Icon(Icons.delete_outline, color: AppTheme.error, size: 26),
              onPressed: () {
                setState(() {
                  _conceptosGasto.removeAt(index);
                  _calcularTotalesGasto();
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCell(String text, {double width = 140}) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Text(
        text,
        style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildNuevoConceptoRow() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: AppTheme.textSecondary.withOpacity(0.3)),
          right: BorderSide(color: AppTheme.textSecondary.withOpacity(0.3)),
          bottom: BorderSide(color: AppTheme.textSecondary.withOpacity(0.3)),
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          // Campo concepto
          Expanded(
            flex: 5,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: TextField(
                controller: _nuevoConceptoController,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                decoration: InputDecoration(
                  isDense: false,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  hintText: 'Ingrese el concepto...',
                  hintStyle: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          // Tipo de valor (Valor/%) y campo de valor
          Container(
            width: 280,
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 80,
                  child: DropdownButtonFormField<String>(
                    value: 'Valor',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    dropdownColor: AppTheme.cardBg,
                    items: [
                      DropdownMenuItem(
                        value: 'Valor',
                        child: Text('Valor', style: TextStyle(fontSize: 14)),
                      ),
                      DropdownMenuItem(
                        value: '%',
                        child: Text('%', style: TextStyle(fontSize: 14)),
                      ),
                    ],
                    onChanged: (v) {},
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _nuevoValorController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
                    decoration: InputDecoration(
                      isDense: false,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      hintText: '0,00',
                      hintStyle: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 16,
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Impuesto dropdown
          Container(
            width: 180,
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: DropdownButtonFormField<String>(
              key: ValueKey('impuesto_$_nuevoImpuestoTipo'),
              value: _nuevoImpuestoTipo,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                isDense: false,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                filled: true,
                fillColor: AppTheme.surfaceDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              dropdownColor: AppTheme.cardBg,
              items: [
                DropdownMenuItem(
                  value: 'Impuesto',
                  child: Text('Impuesto', style: TextStyle(fontSize: 15)),
                ),
                DropdownMenuItem(
                  value: 'IVA 19%',
                  child: Text('IVA 19%', style: TextStyle(fontSize: 15)),
                ),
                DropdownMenuItem(
                  value: 'IVA 5%',
                  child: Text('IVA 5%', style: TextStyle(fontSize: 15)),
                ),
                DropdownMenuItem(
                  value: 'Exento',
                  child: Text('Exento', style: TextStyle(fontSize: 15)),
                ),
              ],
              onChanged: (v) =>
                  setState(() => _nuevoImpuestoTipo = v ?? 'Impuesto'),
            ),
          ),
          // Total (calculado)
          Container(
            width: 160,
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _calcularTotalNuevoConcepto(),
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          // Botón agregar
          Container(
            width: 80,
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.add, color: Colors.white, size: 28),
                padding: EdgeInsets.zero,
                onPressed: _agregarConcepto,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Descripción
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Descripción',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _descripcionController,
                maxLines: 5,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: '',
                  hintStyle: TextStyle(color: AppTheme.textSecondary),
                  filled: true,
                  fillColor: AppTheme.surfaceDark,
                  contentPadding: EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 32),

        // Link Agregar Retenciones
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 32),
              TextButton(
                onPressed: () {
                  setState(() => _mostrarRetenciones = !_mostrarRetenciones);
                },
                child: Text(
                  'Agregar Retenciones',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (_mostrarRetenciones) ...[
                SizedBox(height: 16),
                _buildRetencionField('Retención', _retencionController),
                SizedBox(height: 12),
                _buildRetencionField('Reteiva', _reteivaController),
                SizedBox(height: 12),
                _buildRetencionField('Reteica', _reteicaController),
              ],
            ],
          ),
        ),
        SizedBox(width: 32),

        // Panel de resumen
        Container(
          width: 320,
          child: Column(
            children: [
              _buildResumenRow('Subtotal', _subtotalGasto),
              _buildResumenRow('Descuento', _descuentoGasto),
              _buildResumenRow('Impuestos', _impuestosGasto),
              SizedBox(height: 12),
              Divider(color: AppTheme.textSecondary.withOpacity(0.3)),
              _buildResumenRow('Total', _totalGasto, isTotal: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRetencionField(String label, TextEditingController controller) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              suffixText: '%',
              suffixStyle: TextStyle(color: AppTheme.textSecondary),
              filled: true,
              fillColor: AppTheme.surfaceDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => _calcularTotalesGasto(),
          ),
        ),
      ],
    );
  }

  Widget _buildResumenRow(String label, double valor, {bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isTotal ? AppTheme.textPrimary : AppTheme.textSecondary,
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Container(
            width: 140,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '\$${valor.toStringAsFixed(0)}',
              style: TextStyle(
                color: isTotal ? AppTheme.primary : AppTheme.textPrimary,
                fontSize: isTotal ? 18 : 16,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 320,
        child: ElevatedButton(
          onPressed: _guardandoGasto ? null : _saveGastoNuevo,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            padding: EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            _guardandoGasto ? 'Guardando...' : 'Pagar',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  String _calcularTotalNuevoConcepto() {
    final valor = double.tryParse(_nuevoValorController.text) ?? 0;
    double impuesto = 0;
    if (_nuevoImpuestoTipo == 'IVA 19%') {
      impuesto = valor * 0.19;
    } else if (_nuevoImpuestoTipo == 'IVA 5%') {
      impuesto = valor * 0.05;
    }
    return '\$${(valor + impuesto).toStringAsFixed(0)}';
  }

  void _agregarConcepto() {
    if (_nuevoConceptoController.text.isEmpty) return;

    final valor = double.tryParse(_nuevoValorController.text) ?? 0;
    double tasa = 0;
    double impuesto = 0;

    if (_nuevoImpuestoTipo == 'IVA 19%') {
      tasa = 19;
      impuesto = valor * 0.19;
    } else if (_nuevoImpuestoTipo == 'IVA 5%') {
      tasa = 5;
      impuesto = valor * 0.05;
    }

    setState(() {
      _conceptosGasto.add({
        'concepto': _nuevoConceptoController.text,
        'valor': valor,
        'descuento': 0.0,
        'tasa': tasa,
        'impuesto': impuesto,
        'total': valor + impuesto,
      });

      _nuevoConceptoController.clear();
      _nuevoValorController.clear();
      _nuevoImpuestoTipo = 'Impuesto';

      _calcularTotalesGasto();
    });
  }

  void _calcularTotalesGasto() {
    double subtotal = 0;
    double descuento = 0;
    double impuestos = 0;

    for (var concepto in _conceptosGasto) {
      subtotal += concepto['valor'] ?? 0;
      descuento += concepto['descuento'] ?? 0;
      impuestos += concepto['impuesto'] ?? 0;
    }

    setState(() {
      _subtotalGasto = subtotal;
      _descuentoGasto = descuento;
      _impuestosGasto = impuestos;
      _totalGasto = subtotal - descuento + impuestos;
    });
  }

  Future<void> _saveGastoNuevo() async {
    if (_conceptosGasto.isEmpty) {
      _showError('Debe agregar al menos un concepto');
      return;
    }

    if (_selectedTipoGastoIdNuevo == null) {
      _showError('Debe seleccionar un tipo de gasto');
      return;
    }

    // Verificar cuadre de caja
    if (_selectedCuadreId == null && _cuadresDisponibles.isNotEmpty) {
      _selectedCuadreId = _cuadresDisponibles.first.id;
    }

    if (_selectedCuadreId == null) {
      _showError('No hay cuadre de caja disponible');
      return;
    }

    if (_guardandoGasto) return;

    setState(() {
      _isLoading = true;
      _guardandoGasto = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final responsable = userProvider.userName ?? 'Usuario Desconocido';

      // Obtener nombre del proveedor
      String? proveedorNombre;
      if (_selectedProveedorId != null) {
        final proveedor = _proveedores
            .where((p) => p.id == _selectedProveedorId)
            .firstOrNull;
        proveedorNombre = proveedor?.nombre;
      }

      // Crear el concepto combinando todos los conceptos
      final conceptoCombinado = _conceptosGasto
          .map((c) => c['concepto'])
          .join(', ');

      if (_gastoEditando != null) {
        // Actualizar gasto existente
        await _gastoService.updateGasto(
          _gastoEditando!.id!,
          cuadreCajaId: _selectedCuadreId,
          tipoGastoId: _selectedTipoGastoIdNuevo,
          concepto: conceptoCombinado,
          monto: _totalGasto,
          responsable: responsable,
          fechaGasto: _selectedDate,
          proveedor: proveedorNombre,
          formaPago: _selectedFormaPago ?? 'Efectivo',
          subtotal: _subtotalGasto,
          impuestos: _impuestosGasto,
          pagadoDesdeCaja: _pagadoDesdeCaja,
        );
        _gastoEditando = null;
        _showSuccess('Gasto actualizado exitosamente');
      } else {
        // Crear nuevo gasto
        await _gastoService.createGasto(
          cuadreCajaId: _selectedCuadreId!,
          tipoGastoId: _selectedTipoGastoIdNuevo!,
          concepto: conceptoCombinado,
          monto: _totalGasto,
          responsable: responsable,
          fechaGasto: _selectedDate,
          numeroRecibo: null,
          numeroFactura: null,
          proveedor: proveedorNombre,
          formaPago: _selectedFormaPago ?? 'Efectivo',
          subtotal: _subtotalGasto,
          impuestos: _impuestosGasto,
          pagadoDesdeCaja: true,
        );
        _showSuccess('Gasto creado exitosamente');
      }

      setState(() => _showForm = false);
      await _loadGastos();
    } catch (e) {
      _showError('Error al guardar gasto: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _guardandoGasto = false;
      });
    }
  }

  Widget _buildGastosList() {
    final gastosMostrar = _gastosFiltrados;

    return Column(
      children: [
        // Panel de filtros expandido
        Card(
          color: AppTheme.cardBg,
          margin: EdgeInsets.all(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título de filtros
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filtros de Búsqueda',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: _limpiarFiltros,
                      child: Text(
                        'Limpiar',
                        style: TextStyle(color: AppTheme.primary),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Fila 1: Cuadre y concepto
                Row(
                  children: [
                    // Filtro por cuadre
                    if (widget.cuadreCajaId == null)
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          key: ValueKey('cuadre_$_selectedCuadreId'),
                          decoration: InputDecoration(
                            labelText: 'Filtrar por Cuadre',
                            labelStyle: TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                            border: OutlineInputBorder(),
                          ),
                          value: _selectedCuadreId,
                          dropdownColor: AppTheme.cardBg,
                          style: TextStyle(color: AppTheme.textPrimary),
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text('Todos los cuadres'),
                            ),
                            ..._cuadresDisponibles.map((cuadre) {
                              return DropdownMenuItem(
                                value: cuadre.id,
                                child: Text(
                                  '${cuadre.nombre} - ${cuadre.responsable}',
                                ),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedCuadreId = value);
                            _loadGastos();
                          },
                        ),
                      ),

                    if (widget.cuadreCajaId == null) SizedBox(width: 16),

                    // Filtro por concepto
                    Expanded(
                      child: TextFormField(
                        controller: _conceptoBusquedaController,
                        style: TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Buscar por concepto',
                          labelStyle: TextStyle(color: AppTheme.textSecondary),
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(
                            Icons.search,
                            color: AppTheme.textSecondary,
                          ),
                          suffixIcon:
                              _conceptoBusquedaController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: AppTheme.textSecondary,
                                  ),
                                  onPressed: () {
                                    _conceptoBusquedaController.clear();
                                    setState(() => _filtroConcepto = null);
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _filtroConcepto = value.isEmpty ? null : value;
                          });
                        },
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 16),

                // Fila 2: Filtros de fecha
                Row(
                  children: [
                    // Fecha inicio
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final fecha = await showDatePicker(
                            context: context,
                            initialDate: _fechaInicio ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.dark(
                                    primary: AppTheme.primary,
                                    surface: AppTheme.cardBg,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (fecha != null) {
                            setState(() => _fechaInicio = fecha);
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.textSecondary),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: AppTheme.textSecondary,
                              ),
                              SizedBox(width: 8),
                              Text(
                                _fechaInicio != null
                                    ? '${_fechaInicio!.day}/${_fechaInicio!.month}/${_fechaInicio!.year}'
                                    : 'Fecha inicio',
                                style: TextStyle(color: AppTheme.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(width: 16),

                    // Fecha fin
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final fecha = await showDatePicker(
                            context: context,
                            initialDate: _fechaFin ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.dark(
                                    primary: AppTheme.primary,
                                    surface: AppTheme.cardBg,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (fecha != null) {
                            setState(() => _fechaFin = fecha);
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.textSecondary),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: AppTheme.textSecondary,
                              ),
                              SizedBox(width: 8),
                              Text(
                                _fechaFin != null
                                    ? '${_fechaFin!.day}/${_fechaFin!.month}/${_fechaFin!.year}'
                                    : 'Fecha fin',
                                style: TextStyle(color: AppTheme.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Información de resultados
                if (gastosMostrar.length != _gastos.length)
                  Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(
                      'Mostrando ${gastosMostrar.length} de ${_gastos.length} gastos',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Lista de gastos
        Expanded(
          child: gastosMostrar.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: AppTheme.textSecondary,
                      ),
                      SizedBox(height: 16),
                      Text(
                        _gastos.isEmpty
                            ? 'No hay gastos registrados'
                            : 'No se encontraron gastos con los filtros aplicados',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: gastosMostrar.length,
                  itemBuilder: (context, index) {
                    final gasto = gastosMostrar[index];
                    return Card(
                      color: AppTheme.cardBg,
                      margin: EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    gasto.concepto,
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Text(
                                  gasto.montoFormateado,
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.category,
                                  size: 16,
                                  color: AppTheme.textSecondary,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  gasto.tipoGastoNombre,
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: AppTheme.textSecondary,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  gasto.fechaFormateada,
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            if (gasto.proveedor != null) ...[
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.business,
                                    size: 16,
                                    color: AppTheme.textSecondary,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    gasto.proveedor!,
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (gasto.numeroFactura != null) ...[
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.receipt,
                                    size: 16,
                                    color: AppTheme.textSecondary,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Factura: ${gasto.numeroFactura}',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      _showFormDialog(gasto: gasto),
                                  icon: Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    'Editar',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    minimumSize: Size(0, 32),
                                  ),
                                ),
                                SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () => _deleteGasto(gasto),
                                  icon: Icon(
                                    Icons.delete,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    'Eliminar',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    minimumSize: Size(0, 32),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
