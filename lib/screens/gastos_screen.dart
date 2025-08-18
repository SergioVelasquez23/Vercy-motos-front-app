import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/gasto.dart';
import '../models/tipo_gasto.dart';
import '../models/cuadre_caja.dart';
import '../services/gasto_service.dart';
import '../services/cuadre_caja_service.dart';

class GastosScreen extends StatefulWidget {
  final String? cuadreCajaId;

  const GastosScreen({Key? key, this.cuadreCajaId}) : super(key: key);

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

  // Controllers
  final TextEditingController _conceptoController = TextEditingController();
  final TextEditingController _montoController = TextEditingController();
  final TextEditingController _numeroReciboController = TextEditingController();
  final TextEditingController _numeroFacturaController =
      TextEditingController();
  final TextEditingController _proveedorController = TextEditingController();
  final TextEditingController _subtotalController = TextEditingController();
  final TextEditingController _impuestosController = TextEditingController();

  // Estado
  List<Gasto> _gastos = [];
  List<TipoGasto> _tiposGasto = [];
  List<CuadreCaja> _cuadresDisponibles = [];
  bool _isLoading = false;
  bool _showForm = false;

  // Selecciones
  String? _selectedCuadreId;
  String? _selectedTipoGastoId;
  String? _selectedFormaPago;
  DateTime _selectedDate = DateTime.now();
  Gasto? _gastoEditando;

  // Opciones de forma de pago
  final List<String> _formasPago = ['Efectivo', 'Transferencia', 'Cheque'];

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
    _proveedorController.dispose();
    _subtotalController.dispose();
    _impuestosController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadTiposGasto(),
        _loadCuadresDisponibles(),
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
      setState(() => _tiposGasto = tipos);
    } catch (e) {
      print('Error loading tipos gasto: $e');
    }
  }

  Future<void> _loadCuadresDisponibles() async {
    try {
      // Obtener solo cuadres abiertos (no cerrados)
      final allCuadres = await _cuadreCajaService.getAllCuadres();
      setState(() {
        _cuadresDisponibles = allCuadres.where((c) => !c.cerrada).toList();
      });
    } catch (e) {
      print('Error loading cuadres: $e');
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

  void _showFormDialog({Gasto? gasto}) {
    setState(() {
      _gastoEditando = gasto;
      _showForm = true;
    });

    if (gasto != null) {
      // Editar gasto existente
      _conceptoController.text = gasto.concepto;
      _montoController.text = gasto.monto.toString();
      _numeroReciboController.text = gasto.numeroRecibo ?? '';
      _numeroFacturaController.text = gasto.numeroFactura ?? '';
      _proveedorController.text = gasto.proveedor ?? '';
      _subtotalController.text = gasto.subtotal.toString();
      _impuestosController.text = gasto.impuestos.toString();
      _selectedTipoGastoId = gasto.tipoGastoId;
      _selectedFormaPago = gasto.formaPago;
      _selectedDate = gasto.fechaGasto;
      _selectedCuadreId = gasto.cuadreCajaId;
    } else {
      // Nuevo gasto
      _clearForm();
    }
  }

  void _clearForm() {
    _conceptoController.clear();
    _montoController.clear();
    _numeroReciboController.clear();
    _numeroFacturaController.clear();
    _proveedorController.clear();
    _subtotalController.clear();
    _impuestosController.clear();
    _selectedTipoGastoId = null;
    _selectedFormaPago = null;
    _selectedDate = DateTime.now();
    if (widget.cuadreCajaId != null) {
      _selectedCuadreId = widget.cuadreCajaId;
    }
  }

  Future<void> _saveGasto() async {
    if (!_validateForm()) return;

    setState(() => _isLoading = true);
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final responsable = userProvider.userName ?? 'Usuario Desconocido';

      if (_gastoEditando != null) {
        // Actualizar gasto existente
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
          proveedor: _proveedorController.text.isEmpty
              ? null
              : _proveedorController.text,
          formaPago: _selectedFormaPago,
          subtotal: double.tryParse(_subtotalController.text),
          impuestos: double.tryParse(_impuestosController.text),
        );
        _showSuccess('Gasto actualizado exitosamente');
      } else {
        // Crear nuevo gasto
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
          proveedor: _proveedorController.text.isEmpty
              ? null
              : _proveedorController.text,
          formaPago: _selectedFormaPago,
          subtotal: double.tryParse(_subtotalController.text),
          impuestos: double.tryParse(_impuestosController.text),
        );
        _showSuccess('Gasto creado exitosamente');
      }

      setState(() => _showForm = false);
      await _loadGastos();
    } catch (e) {
      _showError('Error al guardar gasto: $e');
    } finally {
      setState(() => _isLoading = false);
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
    if (_montoController.text.trim().isEmpty ||
        double.tryParse(_montoController.text) == null) {
      _showError('El monto debe ser un número válido');
      return false;
    }
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
        final success = await _gastoService.deleteGasto(gasto.id!);
        if (success) {
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: primary,
        title: Text('Gestión de Gastos', style: TextStyle(color: Colors.white)),
        actions: [
          if (!_showForm)
            IconButton(
              icon: Icon(Icons.add, color: Colors.white),
              onPressed: () => _showFormDialog(),
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primary))
          : _showForm
          ? _buildForm()
          : _buildGastosList(),
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
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // Cuadre de caja
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Cuadre de Caja',
                      labelStyle: TextStyle(color: textLight),
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedCuadreId,
                    dropdownColor: cardBg,
                    style: TextStyle(color: textDark),
                    items: _cuadresDisponibles.map((cuadre) {
                      return DropdownMenuItem(
                        value: cuadre.id,
                        child: Text('${cuadre.nombre} - ${cuadre.responsable}'),
                      );
                    }).toList(),
                    onChanged: widget.cuadreCajaId == null
                        ? (value) {
                            setState(() => _selectedCuadreId = value);
                          }
                        : null,
                  ),
                  SizedBox(height: 16),

                  // Tipo de gasto
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Tipo de Gasto',
                      labelStyle: TextStyle(color: textLight),
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedTipoGastoId,
                    dropdownColor: cardBg,
                    style: TextStyle(color: textDark),
                    items: _tiposGasto.map((tipo) {
                      return DropdownMenuItem(
                        value: tipo.id,
                        child: Text(tipo.nombre),
                      );
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => _selectedTipoGastoId = value),
                  ),
                  SizedBox(height: 16),

                  // Concepto
                  TextFormField(
                    controller: _conceptoController,
                    decoration: InputDecoration(
                      labelText: 'Concepto',
                      labelStyle: TextStyle(color: textLight),
                      border: OutlineInputBorder(),
                    ),
                    style: TextStyle(color: textDark),
                  ),
                  SizedBox(height: 16),

                  // Monto
                  TextFormField(
                    controller: _montoController,
                    decoration: InputDecoration(
                      labelText: 'Monto',
                      labelStyle: TextStyle(color: textLight),
                      border: OutlineInputBorder(),
                      prefixText: '\$ ',
                    ),
                    style: TextStyle(color: textDark),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 16),

                  // Forma de pago
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Forma de Pago',
                      labelStyle: TextStyle(color: textLight),
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedFormaPago,
                    dropdownColor: cardBg,
                    style: TextStyle(color: textDark),
                    items: _formasPago.map((forma) {
                      return DropdownMenuItem(value: forma, child: Text(forma));
                    }).toList(),
                    onChanged: (value) =>
                        setState(() => _selectedFormaPago = value),
                  ),
                  SizedBox(height: 16),

                  // Número de recibo
                  TextFormField(
                    controller: _numeroReciboController,
                    decoration: InputDecoration(
                      labelText: 'Número de Recibo (Opcional)',
                      labelStyle: TextStyle(color: textLight),
                      border: OutlineInputBorder(),
                    ),
                    style: TextStyle(color: textDark),
                  ),
                  SizedBox(height: 16),

                  // Número de factura
                  TextFormField(
                    controller: _numeroFacturaController,
                    decoration: InputDecoration(
                      labelText: 'Número de Factura (Opcional)',
                      labelStyle: TextStyle(color: textLight),
                      border: OutlineInputBorder(),
                    ),
                    style: TextStyle(color: textDark),
                  ),
                  SizedBox(height: 16),

                  // Proveedor
                  TextFormField(
                    controller: _proveedorController,
                    decoration: InputDecoration(
                      labelText: 'Proveedor (Opcional)',
                      labelStyle: TextStyle(color: textLight),
                      border: OutlineInputBorder(),
                    ),
                    style: TextStyle(color: textDark),
                  ),
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
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: _saveGasto,
                          child: Text('Guardar'),
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
    return Column(
      children: [
        // Filtros
        if (widget.cuadreCajaId == null)
          Card(
            color: cardBg,
            margin: EdgeInsets.all(16),
            child: Padding(
              padding: EdgeInsets.all(16),
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
                      child: Text('${cuadre.nombre} - ${cuadre.responsable}'),
                    );
                  }).toList(),
                ],
                onChanged: (value) {
                  setState(() => _selectedCuadreId = value);
                  _loadGastos();
                },
              ),
            ),
          ),

        // Lista de gastos
        Expanded(
          child: _gastos.isEmpty
              ? Center(
                  child: Text(
                    'No hay gastos registrados',
                    style: TextStyle(color: textLight, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _gastos.length,
                  itemBuilder: (context, index) {
                    final gasto = _gastos[index];
                    return Card(
                      color: cardBg,
                      margin: EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          gasto.concepto,
                          style: TextStyle(
                            color: textDark,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${gasto.tipoGastoNombre} • ${gasto.fechaFormateada}',
                              style: TextStyle(color: textLight),
                            ),
                            if (gasto.proveedor != null)
                              Text(
                                'Proveedor: ${gasto.proveedor}',
                                style: TextStyle(color: textLight),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              gasto.montoFormateado,
                              style: TextStyle(
                                color: primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            PopupMenuButton(
                              color: cardBg,
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text(
                                    'Editar',
                                    style: TextStyle(color: textDark),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    'Eliminar',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showFormDialog(gasto: gasto);
                                } else if (value == 'delete') {
                                  _deleteGasto(gasto);
                                }
                              },
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
