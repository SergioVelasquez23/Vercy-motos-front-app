import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../models/ingreso_caja.dart';
import '../services/ingreso_caja_service.dart';
import '../utils/datetime_utils.dart';
import '../utils/api_error.dart';
import '../utils/dialogs_helper.dart';

class IngresosCajaScreen extends StatefulWidget {
  const IngresosCajaScreen({super.key});

  @override
  _IngresosCajaScreenState createState() => _IngresosCajaScreenState();
}

class _IngresosCajaScreenState extends State<IngresosCajaScreen> {
  final IngresoCajaService _service = IngresoCajaService();
  List<IngresoCaja> _ingresos = [];
  List<IngresoCaja> _ingresosFiltrados = [];
  bool _loading = true;

  // Filtros
  final TextEditingController _searchController = TextEditingController();
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  String _cuadreCajaId = ''; // Corregido de _cuadreId a _cuadreCajaId
  bool _mostrarFiltros = false;

  // Colores estilo GastosScreen

  @override
  void initState() {
    super.initState();
    _cargarIngresos();
    _searchController.addListener(_filtrarIngresos);
  }

  Future<void> _cargarIngresos() async {
    setState(() => _loading = true);
    try {
      _ingresos = await _service.obtenerTodos();
      if (!mounted) return;
      _filtrarIngresos(); // Aplicar filtros al cargar
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar ingresos: ${errorMessage(e)}')));
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filtrarIngresos);
    _searchController.dispose();
    super.dispose();
  }

  void _filtrarIngresos() {
    final String busqueda = _searchController.text.toLowerCase();

    setState(() {
      _ingresosFiltrados = _ingresos.where((ingreso) {
        // Filtro por texto (concepto, responsable, observaciones)
        final bool coincideTexto =
            busqueda.isEmpty ||
            ingreso.concepto.toLowerCase().contains(busqueda) ||
            ingreso.responsable.toLowerCase().contains(busqueda) ||
            ingreso.observaciones.toLowerCase().contains(busqueda) ||
            ingreso.formaPago.toLowerCase().contains(busqueda) ||
            ingreso.monto.toString().contains(busqueda);

        // Filtro por fecha
        final bool coincideFecha =
            (_fechaInicio == null ||
                !ingreso.fechaIngreso.isBefore(_fechaInicio!)) &&
            (_fechaFin == null ||
                !ingreso.fechaIngreso.isAfter(
                  _fechaFin!.add(Duration(days: 1)),
                ));

        // Filtro por ID de cuadre
        final bool coincideCuadre =
            _cuadreCajaId.isEmpty ||
            (ingreso.cuadreCajaId != null &&
                ingreso.cuadreCajaId!.contains(_cuadreCajaId));

        return coincideTexto && coincideFecha && coincideCuadre;
      }).toList();
    });
  }

  // Método para seleccionar fechas
  Future<void> _seleccionarFecha(bool esInicio) async {
    final DateTime? fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: esInicio
          ? (_fechaInicio ?? DateTime.now())
          : (_fechaFin ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
            primary: AppTheme.primary,
              onPrimary: Colors.white,
              surface: Theme.of(context).colorScheme.surface,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (fechaSeleccionada != null) {
      setState(() {
        if (esInicio) {
          _fechaInicio = fechaSeleccionada;
        } else {
          _fechaFin = fechaSeleccionada;
        }
      });
      _filtrarIngresos();
    }
  }

  // Método para limpiar los filtros
  void _limpiarFiltros() {
    setState(() {
      _searchController.clear();
      _fechaInicio = null;
      _fechaFin = null;
      _cuadreCajaId = '';
    });
    _filtrarIngresos();
  }

  void _mostrarDialogoNuevoIngreso() async {
    final result = await showDialog<IngresoCaja>(
      context: context,
      builder: (context) => Dialog(child: _IngresoCajaForm()),
    );
    if (result != null) {
      try {
        await _service.registrarIngreso(result);
        _cargarIngresos();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ingreso registrado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        showErrorDialog(context, 'Error al registrar ingreso: ${errorMessage(e)}');
      }
    }
  }

  void _eliminarIngreso(String id) async {
    await _service.eliminarIngreso(id);
    _cargarIngresos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Ingresos de Caja', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : Column(
              children: [
                // Barra de búsqueda
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText:
                              'Buscar por concepto, monto, responsable...',
                          hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                          prefixIcon: Icon(Icons.search, color: AppTheme.primary),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _mostrarFiltros
                                  ? Icons.filter_list_off
                                  : Icons.filter_list,
                              color: AppTheme.primary,
                            ),
                            onPressed: () {
                              setState(() {
                                _mostrarFiltros = !_mostrarFiltros;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                      ),

                      // Panel de filtros expandible
                      if (_mostrarFiltros) ...[
                        SizedBox(height: 16),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Filtros avanzados',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),

                              // Filtro de fechas
                              Row(
                                children: [
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: () => _seleccionarFecha(true),
                                      icon: Icon(
                                        Icons.date_range,
                                        color: AppTheme.primary,
                                      ),
                                      label: Text(
                                        _fechaInicio == null
                                            ? 'Desde'
                                            : 'Desde: ${_fechaInicio!.day}/${_fechaInicio!.month}/${_fechaInicio!.year}',
                                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                      ),
                                      style: TextButton.styleFrom(
                                        backgroundColor: Colors.grey[800],
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: () => _seleccionarFecha(false),
                                      icon: Icon(
                                        Icons.date_range,
                                        color: AppTheme.primary,
                                      ),
                                      label: Text(
                                        _fechaFin == null
                                            ? 'Hasta'
                                            : 'Hasta: ${_fechaFin!.day}/${_fechaFin!.month}/${_fechaFin!.year}',
                                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                      ),
                                      style: TextButton.styleFrom(
                                        backgroundColor: Colors.grey[800],
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(height: 8),

                              // Filtro por cuadre
                              TextField(
                                decoration: InputDecoration(
                                  hintText: 'ID de Cuadre',
                                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                                  prefixIcon: Icon(
                                    Icons.receipt_long,
                                    color: AppTheme.primary,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[800],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                onChanged: (value) {
                                  setState(() {
                                    _cuadreCajaId = value;
                                  });
                                  _filtrarIngresos();
                                },
                              ),

                              SizedBox(height: 8),

                              // Botón para limpiar filtros
                              Center(
                                child: TextButton.icon(
                                  onPressed: _limpiarFiltros,
                                  icon: Icon(
                                    Icons.clear_all,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    'Limpiar filtros',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.red[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Lista de ingresos filtrados
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _cargarIngresos,
                    child: _ingresosFiltrados.isEmpty
                        ? Center(
                            child: Text(
                              _ingresos.isEmpty
                                  ? 'No hay ingresos registrados'
                                  : 'No se encontraron resultados',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 16),
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _ingresosFiltrados.length,
                            itemBuilder: (context, i) {
                              final ingreso = _ingresosFiltrados[i];
                              return Card(
                                color: Theme.of(context).colorScheme.surface,
                                margin: EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  title: Text(
                                    ingreso.concepto,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Monto: ${ingreso.monto} | Forma: ${ingreso.formaPago}',
                                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                                      ),
                                      Text(
                                        'Fecha: ${ingreso.fechaIngreso.toLocal()}',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (ingreso.responsable.isNotEmpty)
                                        Text(
                                          'Responsable: ${ingreso.responsable}',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                            fontSize: 12,
                                          ),
                                        ),
                                      if (ingreso.observaciones.isNotEmpty)
                                        Text(
                                          'Obs: ${ingreso.observaciones}',
                                          style: TextStyle(
                                            color: Colors.orange,
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    onPressed: () =>
                                        _eliminarIngreso(ingreso.id!),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        onPressed: _mostrarDialogoNuevoIngreso,
        tooltip: 'Nuevo ingreso',
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _IngresoCajaForm extends StatefulWidget {
  @override
  State<_IngresoCajaForm> createState() => _IngresoCajaFormState();
}

class _IngresoCajaFormState extends State<_IngresoCajaForm> {
  final _formKey = GlobalKey<FormState>();
  String concepto = '';
  double monto = 0;
  String formaPago = 'Efectivo';
  String responsable = '';
  String observaciones = '';

  @override
  Widget build(BuildContext context) {
            return SingleChildScrollView(
      child: Card(
        color: Theme.of(context).colorScheme.surface,
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.attach_money, color: AppTheme.primary),
                    SizedBox(width: 8),
                    Text(
                      'Nuevo Ingreso',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Concepto',
                    labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                    border: OutlineInputBorder(),
                  ),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                  onSaved: (v) => concepto = v!,
                ),
                SizedBox(height: 16),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Monto',
                    labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                    border: OutlineInputBorder(),
                  ),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || double.tryParse(v) == null
                      ? 'Monto válido'
                      : null,
                  onSaved: (v) => monto = double.parse(v!),
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: formaPago,
                  items: ['Efectivo', 'Transferencia', 'Tarjeta', 'Sistecredito', 'Datafono', 'Otro']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => formaPago = v!),
                  decoration: InputDecoration(
                    labelText: 'Forma de pago',
                    labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                    border: OutlineInputBorder(),
                  ),
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                ),
                SizedBox(height: 16),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Responsable',
                    labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                    border: OutlineInputBorder(),
                  ),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                  onSaved: (v) => responsable = v!,
                ),
                SizedBox(height: 16),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Observaciones',
                    labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                    border: OutlineInputBorder(),
                  ),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  onSaved: (v) => observaciones = v ?? '',
                ),
                SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancelar'),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors
                              .green, // ✅ CORREGIDO: Cambio de naranja a verde
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            _formKey.currentState!.save();
                            Navigator.pop(
                              context,
                              IngresoCaja(
                                concepto: concepto,
                                monto: monto,
                                formaPago: formaPago,
                                fechaIngreso: DateTimeUtils.nowColombia(),
                                responsable: responsable,
                                observaciones: observaciones,
                              ),
                            );
                          }
                        },
                        child: Text('Guardar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

