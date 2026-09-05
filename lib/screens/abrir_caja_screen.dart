import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/cuadre_caja.dart';
import '../services/cuadre_caja_service.dart';
import '../theme/app_theme.dart';
import '../widgets/caja/caja_ya_abierta_widget.dart';
import '../widgets/caja/formulario_abrir_caja_widget.dart';
import '../widgets/caja/caja_ui_helpers.dart';
import '../utils/api_error.dart';
import '../utils/dialogs_helper.dart';
import '../utils/submit_guard.dart';

class AbrirCajaScreen extends StatefulWidget {
  /// Inyectable solo para tests de secuencia (doble-tap, etc.) - en la app
  /// real siempre se usa el CuadreCajaService real.
  @visibleForTesting
  final ICuadreCajaService? cuadreCajaService;

  const AbrirCajaScreen({super.key, this.cuadreCajaService});

  @override
  _AbrirCajaScreenState createState() => _AbrirCajaScreenState();
}

class _AbrirCajaScreenState extends State<AbrirCajaScreen> with SubmitGuard {
  // Controllers
  final TextEditingController _montoInicialController = TextEditingController();
  final TextEditingController _observacionesController = TextEditingController();
  final TextEditingController _idMaquinaController = TextEditingController();

  // Services
  late final ICuadreCajaService _cuadreCajaService =
      widget.cuadreCajaService ?? CuadreCajaService();

  // Variables de estado
  bool _isLoading = false;
  List<CuadreCaja> _cajasAbiertas = [];
  String _tipoCajaSeleccionado = 'LOCAL';

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
      final cajasAbiertas = cuadres.where((c) => !c.cerrada).toList();

      setState(() {
        _cajasAbiertas = cajasAbiertas;
        // Por defecto se selecciona el tipo que todavía no está abierto (para
        // invitar a abrirlo); si ambos o ninguno lo está, se deja LOCAL.
        final localAbierta = cajasAbiertas.any((c) => c.tipoCaja == 'LOCAL');
        final enviosAbierta = cajasAbiertas.any((c) => c.tipoCaja == 'ENVIOS');
        if (localAbierta && !enviosAbierta) {
          _tipoCajaSeleccionado = 'ENVIOS';
        } else if (!localAbierta) {
          _tipoCajaSeleccionado = 'LOCAL';
        }
      });
    } catch (e) {
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  CuadreCaja? get _cajaAbiertaDelTipoSeleccionado {
    for (final c in _cajasAbiertas) {
      if (c.tipoCaja == _tipoCajaSeleccionado) return c;
    }
    return null;
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
        nombre: _tipoCajaSeleccionado == 'ENVIOS' ? 'Caja Envíos' : 'Caja Local',
        responsable: responsable,
        fondoInicial: montoInicial,
        efectivoDeclarado: 0,
        efectivoEsperado: 0,
        tolerancia: 5.0,
        observaciones:
            'Caja abierta - ${_observacionesController.text}. ID Máquina: ${_idMaquinaController.text}',
        tipoCaja: _tipoCajaSeleccionado,
      );

      if (cuadre.id != null) {
        if (!mounted) return;
        _mostrarExito('Caja abierta exitosamente');
        Navigator.of(context).pop(true);
      } else {
        throw Exception('Error al crear el cuadre');
      }
    } catch (e) {
      String mensajeError = errorMessage(e);

      if (e.toString().contains('Ya existe una caja')) {
        final nombreTipo = _tipoCajaSeleccionado == 'ENVIOS' ? 'Envíos' : 'Local';
        mensajeError =
            'Ya existe una caja $nombreTipo abierta. Debe cerrar esa caja antes de abrir otra del mismo tipo.';
        await _verificarEstadoCaja();
      }

      if (!mounted) return;
      _mostrarError(mensajeError);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _irACerrarCaja() {
    context.go('/cerrar_caja');
  }

  void _mostrarError(String mensaje) {
    showErrorDialog(context, mensaje);
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Abrir Caja',
          style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
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

                  // Selector de tipo de caja (Local / Envíos)
                  CajaUiHelpers.buildCard(
                    context: context,
                    icon: Icons.storefront,
                    title: 'Tipo de Caja',
                    child: Row(
                      children: [
                        Expanded(
                          child: _TipoCajaButton(
                            label: 'Local',
                            icon: Icons.storefront,
                            seleccionado: _tipoCajaSeleccionado == 'LOCAL',
                            onTap: () => setState(() => _tipoCajaSeleccionado = 'LOCAL'),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _TipoCajaButton(
                            label: 'Envíos',
                            icon: Icons.local_shipping,
                            seleccionado: _tipoCajaSeleccionado == 'ENVIOS',
                            onTap: () => setState(() => _tipoCajaSeleccionado = 'ENVIOS'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  // Verificación de estado de caja
                  if (_cajaAbiertaDelTipoSeleccionado != null)
                    CajaYaAbiertaWidget(
                      cajaActual: _cajaAbiertaDelTipoSeleccionado,
                      onIrCerrarCaja: _irACerrarCaja,
                    )
                  else
                    FormularioAbrirCajaWidget(
                      userProvider: userProvider,
                      montoInicialController: _montoInicialController,
                      idMaquinaController: _idMaquinaController,
                      observacionesController: _observacionesController,
                      // runGuarded: el boton "ABRIR CAJA" no tenia ningun
                      // guard, ni siquiera el de _isLoading (ver
                      // FormularioAbrirCajaWidget.onPressed) - un doble-tap
                      // real podia disparar dos createCuadre() concurrentes
                      // antes de que el primer setState desactivara el form.
                      onAbrirCaja: () => runGuarded(_abrirCaja),
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

class _TipoCajaButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool seleccionado;
  final VoidCallback onTap;

  const _TipoCajaButton({
    required this.label,
    required this.icon,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: seleccionado ? AppTheme.primaryGradient : null,
          color: seleccionado ? null : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(
            color: seleccionado
                ? Colors.transparent
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: seleccionado ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: seleccionado ? Colors.white : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
