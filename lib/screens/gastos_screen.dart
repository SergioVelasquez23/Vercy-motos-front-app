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

class GastosScreen extends StatefulWidget {
  final String? cuadreCajaId;

  const GastosScreen({super.key, this.cuadreCajaId});

  @override
  _GastosScreenState createState() => _GastosScreenState();
}

class _GastosScreenState extends State<GastosScreen> {
  final Color primary = Color(0xFFFF6B00); // Color naranja fuego
  final Color bgDark = Color(0xFF1E1E1E); // Color de fondo negro
  final Color cardBg = Color(0xFF252525); // Color de tarjetas
  final Color textDark = Color(0xFFE0E0E0); // Color de texto claro
  final Color textLight = Color(0xFFA0A0A0); // Color de texto más suave

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

  @override
  void initState() {
    super.initState();
    _selectedCuadreId = widget.cuadreCajaId;
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
        setState(() => _tiposGasto = tipos);
      }
    } catch (e) {
      print('Error loading tipos gasto: $e');
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
      print('Error loading cuadres: $e');
    }
  }

  Future<void> _loadProveedores() async {
    try {
      final proveedores = await _proveedorService.getProveedores();
      if (mounted) {
        setState(() => _proveedores = proveedores);
      }
    } catch (e) {
      print('Error loading proveedores: $e');
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
      print('DEBUG: Cargando gasto para editar: ${gasto.proveedor}'); // DEBUG

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

      // Buscar el proveedor por nombre para seleccionarlo
      if (gasto.proveedor != null && gasto.proveedor!.isNotEmpty) {
        final proveedor = _proveedores
            .where((p) => p.nombre == gasto.proveedor)
            .firstOrNull;
        _selectedProveedorId = proveedor?.id;
      }

      print('DEBUG: Proveedor seleccionado: $_selectedProveedorId'); // DEBUG
    } else {
      // Nuevo gasto
      _clearForm();
      _generateInvoiceNumber(); // Generar número de factura automáticamente
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
        backgroundColor: cardBg,
        title: Text('Confirmar eliminación', style: TextStyle(color: textDark)),
        content: Text(
          '¿Está seguro de eliminar este gasto?',
          style: TextStyle(color: textLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar', style: TextStyle(color: textLight)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: primary,
        title: Text('Gestión de Gastos', style: TextStyle(color: Colors.white)),
        actions: [],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primary))
          : _showForm
          ? _buildForm()
          : _buildGastosList(),
      floatingActionButton: !_showForm
          ? FloatingActionButton(
              onPressed: () => _showFormDialog(),
              backgroundColor: primary,
              child: Icon(Icons.add, color: Colors.white),
              tooltip: 'Agregar Nuevo Gasto',
            )
          : null,
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: textDark),
                onPressed: () => setState(() => _showForm = false),
              ),
              Text(
                _gastoEditando != null ? 'Editar Gasto' : 'Nuevo Gasto',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Formulario
          Card(
            color: cardBg,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  // Cuadre de caja (solo si no viene predefinido)
                  if (widget.cuadreCajaId == null) ...[
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Cuadre de Caja*',
                        labelStyle: TextStyle(color: textLight, fontSize: 14),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      initialValue: _selectedCuadreId,
                      dropdownColor: cardBg,
                      style: TextStyle(color: textDark, fontSize: 14),
                      items: _cuadresDisponibles.map((cuadre) {
                        return DropdownMenuItem(
                          value: cuadre.id,
                          child: Text(
                            '${cuadre.nombre} - ${cuadre.responsable}',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedCuadreId = value);
                      },
                    ),
                    SizedBox(height: 12),
                  ],

                  // Fecha
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (date != null) {
                        setState(() => _selectedDate = date);
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: textLight,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Text(
                            '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                            style: TextStyle(color: textDark, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 12),

                  // Tipo de gasto y Proveedor en la misma fila
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Tipo de gasto*',
                            labelStyle: TextStyle(
                              color: textLight,
                              fontSize: 14,
                            ),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          initialValue: _selectedTipoGastoId,
                          dropdownColor: cardBg,
                          style: TextStyle(color: textDark, fontSize: 14),
                          items: _tiposGasto.map((tipo) {
                            return DropdownMenuItem(
                              value: tipo.id,
                              child: Text(tipo.nombre),
                            );
                          }).toList(),
                          onChanged: (value) =>
                              setState(() => _selectedTipoGastoId = value),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Proveedor',
                            labelStyle: TextStyle(
                              color: textLight,
                              fontSize: 14,
                            ),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          value: _selectedProveedorId,
                          dropdownColor: cardBg,
                          style: TextStyle(color: textDark, fontSize: 14),
                          items: [
                            DropdownMenuItem<String>(
                              value: null,
                              child: Text(
                                'Sin proveedor',
                                style: TextStyle(color: textLight),
                              ),
                            ),
                            ..._proveedores.map((proveedor) {
                              return DropdownMenuItem<String>(
                                value: proveedor.id,
                                child: Text(proveedor.nombre),
                              );
                            }),
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedProveedorId = value),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),

                  // Número de factura
                  TextFormField(
                    controller: _numeroFacturaController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'N° Factura (Generado automáticamente)',
                      labelStyle: TextStyle(color: textLight, fontSize: 14),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.refresh, color: primary, size: 20),
                        onPressed: _generateInvoiceNumber,
                        tooltip: 'Regenerar número',
                      ),
                    ),
                    style: TextStyle(color: textDark, fontSize: 14),
                  ),
                  SizedBox(height: 12),

                  // Forma de pago
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Forma de Pago',
                      labelStyle: TextStyle(color: textLight, fontSize: 14),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    initialValue: _selectedFormaPago,
                    dropdownColor: cardBg,
                    style: TextStyle(color: textDark, fontSize: 14),
                    items: _formasPago.map((forma) {
                      return DropdownMenuItem(value: forma, child: Text(forma));
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => _selectedFormaPago = value),
                  ),
                  SizedBox(height: 12),

                  // Concepto del gasto
                  TextFormField(
                    controller: _conceptoController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Concepto del Gasto*',
                      labelStyle: TextStyle(color: textLight, fontSize: 14),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    style: TextStyle(color: textDark, fontSize: 14),
                  ),
                  SizedBox(height: 12),

                  // Subtotal e Impuestos en la misma fila
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _subtotalController,
                          decoration: InputDecoration(
                            labelText: 'Subtotal*',
                            labelStyle: TextStyle(
                              color: textLight,
                              fontSize: 14,
                            ),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          style: TextStyle(color: textDark, fontSize: 14),
                          keyboardType: TextInputType.number,
                          onChanged: _calculateTotal,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _impuestosController,
                          decoration: InputDecoration(
                            labelText: 'Impuestos',
                            labelStyle: TextStyle(
                              color: textLight,
                              fontSize: 14,
                            ),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          style: TextStyle(color: textDark, fontSize: 14),
                          keyboardType: TextInputType.number,
                          onChanged: _calculateTotal,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),

                  // Total
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.1),
                      border: Border.all(color: primary),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(
                            color: textDark,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _montoController.text.isEmpty
                              ? '0,00'
                              : _montoController.text,
                          style: TextStyle(
                            color: primary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),

                  // Checkbox para pago desde caja
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          color: primary,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Pagar desde caja (descontar del efectivo)',
                            style: TextStyle(
                              color: textDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Switch(
                          value: _pagadoDesdeCaja,
                          onChanged: (value) {
                            setState(() {
                              _pagadoDesdeCaja = value;
                            });
                            // Recalcular total cuando cambia el switch
                            _calculateTotal();
                          },
                          activeColor: primary,
                        ),
                      ],
                    ),
                  ),

                  // Mostrar información de efectivo disponible si está activado el switch
                  if (_pagadoDesdeCaja && _selectedCuadreId != null) ...[
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Se descontará del efectivo disponible en caja. Asegúrate de que hay suficiente efectivo.',
                              style: TextStyle(color: textDark, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 20),

                  // Botones
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () => setState(() => _showForm = false),
                          child: Text('Cancelar'),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: _guardandoGasto ? null : _saveGasto,
                          child: Text(
                            _guardandoGasto ? 'Guardando...' : 'Guardar',
                          ),
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
    );
  }

  Widget _buildGastosList() {
    final gastosMostrar = _gastosFiltrados;

    return Column(
      children: [
        // Panel de filtros expandido
        Card(
          color: cardBg,
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
                        color: textDark,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: _limpiarFiltros,
                      child: Text('Limpiar', style: TextStyle(color: primary)),
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
                          decoration: InputDecoration(
                            labelText: 'Filtrar por Cuadre',
                            labelStyle: TextStyle(color: textLight),
                            border: OutlineInputBorder(),
                          ),
                          value: _selectedCuadreId,
                          dropdownColor: cardBg,
                          style: TextStyle(color: textDark),
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
                        style: TextStyle(color: textDark),
                        decoration: InputDecoration(
                          labelText: 'Buscar por concepto',
                          labelStyle: TextStyle(color: textLight),
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search, color: textLight),
                          suffixIcon:
                              _conceptoBusquedaController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, color: textLight),
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
                            lastDate: DateTime.now(),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.dark(
                                    primary: primary,
                                    surface: cardBg,
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
                            border: Border.all(color: textLight),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, color: textLight),
                              SizedBox(width: 8),
                              Text(
                                _fechaInicio != null
                                    ? '${_fechaInicio!.day}/${_fechaInicio!.month}/${_fechaInicio!.year}'
                                    : 'Fecha inicio',
                                style: TextStyle(color: textDark),
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
                            lastDate: DateTime.now(),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.dark(
                                    primary: primary,
                                    surface: cardBg,
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
                            border: Border.all(color: textLight),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, color: textLight),
                              SizedBox(width: 8),
                              Text(
                                _fechaFin != null
                                    ? '${_fechaFin!.day}/${_fechaFin!.month}/${_fechaFin!.year}'
                                    : 'Fecha fin',
                                style: TextStyle(color: textDark),
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
                      style: TextStyle(color: textLight, fontSize: 14),
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
                      Icon(Icons.search_off, size: 64, color: textLight),
                      SizedBox(height: 16),
                      Text(
                        _gastos.isEmpty
                            ? 'No hay gastos registrados'
                            : 'No se encontraron gastos con los filtros aplicados',
                        style: TextStyle(color: textLight, fontSize: 16),
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
                      color: cardBg,
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
                                      color: textDark,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Text(
                                  gasto.montoFormateado,
                                  style: TextStyle(
                                    color: primary,
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
                                  color: textLight,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  gasto.tipoGastoNombre,
                                  style: TextStyle(
                                    color: textLight,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Icon(
                                  Icons.calendar_today,
                                  size: 16,
                                  color: textLight,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  gasto.fechaFormateada,
                                  style: TextStyle(
                                    color: textLight,
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
                                    color: textLight,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    gasto.proveedor!,
                                    style: TextStyle(
                                      color: textLight,
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
                                    color: textLight,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Factura: ${gasto.numeroFactura}',
                                    style: TextStyle(
                                      color: textLight,
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
