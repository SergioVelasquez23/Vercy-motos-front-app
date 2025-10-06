import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/cuadre_caja.dart';
import '../services/cuadre_caja_service.dart';

class AbrirCajaScreen extends StatefulWidget {
  const AbrirCajaScreen({super.key});

  @override
  _AbrirCajaScreenState createState() => _AbrirCajaScreenState();
}

class _AbrirCajaScreenState extends State<AbrirCajaScreen> {
  final Color primary = Color(0xFFFF6B00); // Color naranja fuego
  final Color bgDark = Color(0xFF1E1E1E); // Color de fondo negro
  final Color cardBg = Color(0xFF252525); // Color de tarjetas
  final Color textDark = Color(0xFFE0E0E0); // Color de texto claro
  final Color textLight = Color(0xFFA0A0A0); // Color de texto más suave

  // Controllers
  final TextEditingController _montoInicialController = TextEditingController();
  final TextEditingController _observacionesController =
      TextEditingController();
  final TextEditingController _idMaquinaController = TextEditingController();

  // Services
  final CuadreCajaService _cuadreCajaService = CuadreCajaService();

  // Variables de estado
  bool _isLoading = false;
  String? _selectedCaja = 'Caja Principal';
  bool _hayCajaAbierta = false;
  CuadreCaja? _cajaActual;

  @override
  void initState() {
    super.initState();
    _verificarEstadoCaja();
  }

  @override
  void dispose() {
    _montoInicialController.dispose();
    _observacionesController.dispose();
    _idMaquinaController.dispose();
    super.dispose();
  }

  Future<void> _verificarEstadoCaja() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final cuadres = await _cuadreCajaService.getAllCuadres();
      final cajaAbierta = cuadres.where((c) => !c.cerrada).toList();

      setState(() {
        _hayCajaAbierta = cajaAbierta.isNotEmpty;
        _cajaActual = cajaAbierta.isNotEmpty ? cajaAbierta.first : null;
      });
    } catch (e) {
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _abrirCaja() async {
    if (_montoInicialController.text.isEmpty) {
      _mostrarError('Por favor ingrese el monto inicial');
      return;
    }

    final montoInicial = double.tryParse(_montoInicialController.text);
    if (montoInicial == null || montoInicial < 0) {
      _mostrarError('El monto inicial debe ser un valor válido positivo');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final responsable = userProvider.userName ?? 'Usuario Desconocido';

      final cuadre = await _cuadreCajaService.createCuadre(
        nombre: _selectedCaja ?? 'Caja Principal',
        responsable: responsable,
        fondoInicial: montoInicial,
        efectivoDeclarado: 0,
        efectivoEsperado: 0,
        tolerancia: 5.0,
        observaciones:
            'Caja abierta - ${_observacionesController.text}. ID Máquina: ${_idMaquinaController.text}',
      );

      if (cuadre.id != null) {
        _mostrarExito('Caja abierta exitosamente');
        // Volver a la pantalla anterior
        Navigator.of(
          context,
        ).pop(true); // true indica que se abrió exitosamente
      } else {
        throw Exception('Error al crear el cuadre');
      }
    } catch (e) {
      String errorMessage = 'Error al abrir caja: $e';

      // Verificar si es el error específico de caja ya abierta
      if (e.toString().contains('Ya existe una caja abierta')) {
        errorMessage =
            'Ya existe una caja abierta. Debe cerrar la caja actual antes de abrir una nueva.';
        // Actualizar el estado para mostrar la caja abierta
        await _verificarEstadoCaja();
      }

      _mostrarError(errorMessage);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        title: Text(
          'Abrir Caja',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primary))
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Center(
                    child: Text(
                      'APERTURA DE CAJA',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textDark,
                        shadows: [
                          Shadow(
                            offset: Offset(1, 1),
                            blurRadius: 3,
                            color: Colors.black.withOpacity(0.3),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),

                  // Verificación de estado de caja
                  if (_hayCajaAbierta) ...[
                    Card(
                      color: Colors.red.shade900,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.warning, color: Colors.red.shade300),
                                SizedBox(width: 8),
                                Text(
                                  'CAJA YA ABIERTA',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade100,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            if (_cajaActual != null) ...[
                              Text(
                                'Caja: ${_cajaActual!.nombre}',
                                style: TextStyle(color: Colors.red.shade100),
                              ),
                              Text(
                                'Responsable: ${_cajaActual!.responsable}',
                                style: TextStyle(color: Colors.red.shade100),
                              ),
                              Text(
                                'Fecha apertura: ${_cajaActual!.fechaApertura.day}/${_cajaActual!.fechaApertura.month}/${_cajaActual!.fechaApertura.year} ${_cajaActual!.fechaApertura.hour}:${_cajaActual!.fechaApertura.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(color: Colors.red.shade100),
                              ),
                              Text(
                                'Monto inicial: \$${_cajaActual!.fondoInicial.toStringAsFixed(0)}',
                                style: TextStyle(color: Colors.red.shade100),
                              ),
                            ],
                            SizedBox(height: 12),
                            Text(
                              'Debe cerrar la caja actual antes de abrir una nueva.',
                              style: TextStyle(
                                color: Colors.red.shade100,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Botón para ir a cerrar caja
                    Center(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.lock_clock),
                        label: Text('Ir a Cerrar Caja'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(
                            context,
                          ).pushReplacementNamed('/cerrar_caja');
                        },
                      ),
                    ),
                  ] else ...[
                    // Formulario para abrir caja

                    // Información del usuario
                    Card(
                      elevation: 4,
                      color: cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Responsable',
                              style: TextStyle(fontSize: 16, color: textLight),
                            ),
                            Text(
                              userProvider.userName ??
                                  'Usuario no identificado',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textDark,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Fecha y Hora',
                              style: TextStyle(fontSize: 16, color: textLight),
                            ),
                            Text(
                              '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Selección de caja
                    Card(
                      elevation: 4,
                      color: cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Seleccionar Caja',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textDark,
                              ),
                            ),
                            SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: primary),
                                ),
                              ),
                              style: TextStyle(color: textDark),
                              initialValue: _selectedCaja,
                              items: ['Caja Principal', 'Caja Secundaria']
                                  .map<DropdownMenuItem<String>>((
                                    String value,
                                  ) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    );
                                  })
                                  .toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _selectedCaja = newValue;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Monto inicial
                    Card(
                      elevation: 4,
                      color: cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Monto Inicial *',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textDark,
                              ),
                            ),
                            SizedBox(height: 10),
                            TextFormField(
                              controller: _montoInicialController,
                              keyboardType: TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              style: TextStyle(color: textDark),
                              decoration: InputDecoration(
                                labelText: 'Ingrese el monto inicial',
                                labelStyle: TextStyle(color: textLight),
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(
                                  Icons.attach_money,
                                  color: primary,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: primary),
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Este será el dinero con el que inicia la caja',
                              style: TextStyle(
                                fontSize: 12,
                                color: textLight,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Identificación máquina
                    Card(
                      elevation: 4,
                      color: cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Identificación de Máquina',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textDark,
                              ),
                            ),
                            SizedBox(height: 10),
                            TextFormField(
                              controller: _idMaquinaController,
                              style: TextStyle(color: textDark),
                              decoration: InputDecoration(
                                labelText: 'ID o nombre de la máquina',
                                labelStyle: TextStyle(color: textLight),
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(
                                  Icons.computer,
                                  color: primary,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: primary),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Observaciones
                    Card(
                      elevation: 4,
                      color: cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Observaciones',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textDark,
                              ),
                            ),
                            SizedBox(height: 10),
                            TextFormField(
                              controller: _observacionesController,
                              maxLines: 3,
                              style: TextStyle(color: textDark),
                              decoration: InputDecoration(
                                labelText:
                                    'Observaciones adicionales (opcional)',
                                labelStyle: TextStyle(color: textLight),
                                border: OutlineInputBorder(),
                                alignLabelWithHint: true,
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: primary),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 30),

                    // Botón para abrir caja
                    Center(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.lock_open),
                        label: Text('ABRIR CAJA'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 20,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 4,
                        ),
                        onPressed: _abrirCaja,
                      ),
                    ),
                  ],

                  SizedBox(height: 20),

                  // Botón para actualizar estado
                  Center(
                    child: TextButton.icon(
                      icon: Icon(Icons.refresh, color: primary),
                      label: Text(
                        'Actualizar Estado',
                        style: TextStyle(color: primary),
                      ),
                      onPressed: _verificarEstadoCaja,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
