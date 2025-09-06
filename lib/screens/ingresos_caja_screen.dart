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
      appBar: AppBar(title: Text('Ingresos de Caja')),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarIngresos,
              child: ListView.builder(
                itemCount: _ingresos.length,
                itemBuilder: (context, i) {
                  final ingreso = _ingresos[i];
                  return ListTile(
                    title: Text(ingreso.concepto),
                    subtitle: Text(
                      'Monto: ${ingreso.monto} | Forma: ${ingreso.formaPago}\n${ingreso.fechaIngreso.toLocal()}',
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _eliminarIngreso(ingreso.id!),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarDialogoNuevoIngreso,
        tooltip: 'Nuevo ingreso',
        child: Icon(Icons.add),
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Nuevo Ingreso',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Concepto'),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                onSaved: (v) => concepto = v!,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Monto'),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || double.tryParse(v) == null
                    ? 'Monto válido'
                    : null,
                onSaved: (v) => monto = double.parse(v!),
              ),
              DropdownButtonFormField<String>(
                initialValue: formaPago,
                items: ['Efectivo', 'Transferencia', 'Otro']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => formaPago = v!),
                decoration: InputDecoration(labelText: 'Forma de pago'),
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Responsable'),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                onSaved: (v) => responsable = v!,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Observaciones'),
                onSaved: (v) => observaciones = v ?? '',
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancelar'),
                  ),
                  ElevatedButton(
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
