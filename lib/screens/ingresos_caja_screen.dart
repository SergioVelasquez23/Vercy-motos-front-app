import 'package:flutter/material.dart';
import '../models/ingreso_caja.dart';
import '../services/ingreso_caja_service.dart';

class IngresosCajaScreen extends StatefulWidget {
  const IngresosCajaScreen({super.key});

  @override
  _IngresosCajaScreenState createState() => _IngresosCajaScreenState();
}

class _IngresosCajaScreenState extends State<IngresosCajaScreen> {
  final IngresoCajaService _service = IngresoCajaService();
  List<IngresoCaja> _ingresos = [];
  bool _loading = true;

  // Colores estilo GastosScreen
  final Color primary = Color(0xFFFF6B00); // Naranja fuego
  final Color bgDark = Color(0xFF1E1E1E); // Fondo oscuro
  final Color cardBg = Color(0xFF252525); // Tarjetas
  final Color textDark = Color(0xFFE0E0E0); // Texto claro
  final Color textLight = Color(0xFFA0A0A0); // Texto suave

  @override
  void initState() {
    super.initState();
    _cargarIngresos();
  }

  Future<void> _cargarIngresos() async {
    setState(() => _loading = true);
    try {
      _ingresos = await _service.obtenerTodos();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al cargar ingresos: $e')));
    }
    setState(() => _loading = false);
  }

  void _mostrarDialogoNuevoIngreso() async {
    final result = await showDialog<IngresoCaja>(
      context: context,
      builder: (context) => Dialog(child: _IngresoCajaForm()),
    );
    if (result != null) {
      await _service.registrarIngreso(result);
      _cargarIngresos();
    }
  }

  void _eliminarIngreso(String id) async {
    await _service.eliminarIngreso(id);
    _cargarIngresos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: primary,
        title: Text('Ingresos de Caja', style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primary))
          : RefreshIndicator(
              onRefresh: _cargarIngresos,
              child: _ingresos.isEmpty
                  ? Center(
                      child: Text(
                        'No hay ingresos registrados',
                        style: TextStyle(color: textLight, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: _ingresos.length,
                      itemBuilder: (context, i) {
                        final ingreso = _ingresos[i];
                        return Card(
                          color: cardBg,
                          margin: EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(
                              ingreso.concepto,
                              style: TextStyle(
                                color: textDark,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Monto: ${ingreso.monto} | Forma: ${ingreso.formaPago}',
                                  style: TextStyle(color: textLight),
                                ),
                                Text(
                                  'Fecha: ${ingreso.fechaIngreso.toLocal()}',
                                  style: TextStyle(
                                    color: textLight,
                                    fontSize: 12,
                                  ),
                                ),
                                if (ingreso.responsable.isNotEmpty)
                                  Text(
                                    'Responsable: ${ingreso.responsable}',
                                    style: TextStyle(
                                      color: textLight,
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
                              onPressed: () => _eliminarIngreso(ingreso.id!),
                            ),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primary,
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
    final Color primary = Color(0xFFFF6B00);
    final Color cardBg = Color(0xFF252525);
    final Color textDark = Color(0xFFE0E0E0);
    final Color textLight = Color(0xFFA0A0A0);
    return SingleChildScrollView(
      child: Card(
        color: cardBg,
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
                    Icon(Icons.attach_money, color: primary),
                    SizedBox(width: 8),
                    Text(
                      'Nuevo Ingreso',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: textDark,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Concepto',
                    labelStyle: TextStyle(color: textLight),
                    border: OutlineInputBorder(),
                  ),
                  style: TextStyle(color: textDark),
                  validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                  onSaved: (v) => concepto = v!,
                ),
                SizedBox(height: 16),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Monto',
                    labelStyle: TextStyle(color: textLight),
                    border: OutlineInputBorder(),
                  ),
                  style: TextStyle(color: textDark),
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || double.tryParse(v) == null
                      ? 'Monto válido'
                      : null,
                  onSaved: (v) => monto = double.parse(v!),
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: formaPago,
                  items: ['Efectivo', 'Transferencia', 'Otro']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => formaPago = v!),
                  decoration: InputDecoration(
                    labelText: 'Forma de pago',
                    labelStyle: TextStyle(color: textLight),
                    border: OutlineInputBorder(),
                  ),
                  dropdownColor: cardBg,
                  style: TextStyle(color: textDark),
                ),
                SizedBox(height: 16),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Responsable',
                    labelStyle: TextStyle(color: textLight),
                    border: OutlineInputBorder(),
                  ),
                  style: TextStyle(color: textDark),
                  validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                  onSaved: (v) => responsable = v!,
                ),
                SizedBox(height: 16),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Observaciones',
                    labelStyle: TextStyle(color: textLight),
                    border: OutlineInputBorder(),
                  ),
                  style: TextStyle(color: textDark),
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
                          backgroundColor: primary,
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
                                fechaIngreso: DateTime.now(),
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
