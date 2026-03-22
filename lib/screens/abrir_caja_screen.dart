import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/cuadre_caja.dart';
import '../services/cuadre_caja_service.dart';
import '../theme/app_theme.dart';
import '../widgets/caja/caja_ya_abierta_widget.dart';
import '../widgets/caja/formulario_abrir_caja_widget.dart';

class AbrirCajaScreen extends StatefulWidget {
  const AbrirCajaScreen({super.key});

  @override
  _AbrirCajaScreenState createState() => _AbrirCajaScreenState();
}

class _AbrirCajaScreenState extends State<AbrirCajaScreen> {
  // Controllers
  final TextEditingController _montoInicialController = TextEditingController();
  final TextEditingController _observacionesController = TextEditingController();
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
        Navigator.of(context).pop(true); // true indica que se abrió exitosamente
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

  void _irACerrarCaja() {
    Navigator.of(context).pushReplacementNamed('/cerrar_caja');
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
        backgroundColor: AppTheme.success,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text(
          'Abrir Caja',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título
                  Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        boxShadow: AppTheme.primaryShadow,
                      ),
                      child: Text(
                        'APERTURA DE CAJA',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 24),

                  // Verificación de estado de caja
                  if (_hayCajaAbierta)
                    CajaYaAbiertaWidget(
                      cajaActual: _cajaActual,
                      onIrCerrarCaja: _irACerrarCaja,
                    )
                  else
                    FormularioAbrirCajaWidget(
                      userProvider: userProvider,
                      montoInicialController: _montoInicialController,
                      idMaquinaController: _idMaquinaController,
                      observacionesController: _observacionesController,
                      selectedCaja: _selectedCaja,
                      onCajaChanged: (String? newValue) {
                        setState(() {
                          _selectedCaja = newValue;
                        });
                      },
                      onAbrirCaja: _abrirCaja,
                    ),

                  SizedBox(height: 24),

                  // Botón para actualizar estado
                  Center(
                    child: TextButton.icon(
                      icon: Icon(Icons.refresh, color: AppTheme.primary),
                      label: Text(
                        'Actualizar Estado',
                        style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w500),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
