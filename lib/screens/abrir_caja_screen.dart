import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/cuadre_caja.dart';
import '../services/cuadre_caja_service.dart';
import '../theme/app_theme.dart';

class AbrirCajaScreen extends StatefulWidget {
  const AbrirCajaScreen({super.key});

  @override
  _AbrirCajaScreenState createState() => _AbrirCajaScreenState();
}

class _AbrirCajaScreenState extends State<AbrirCajaScreen> {
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

    // 🔍 LOGGING: Debug para valor introducido por usuario
    print('💰 Usuario abriendo caja:');
    print('  - Caja seleccionada: ${_selectedCaja}');
    print('  - Texto introducido: "${_montoInicialController.text}"');
    print('  - Monto parseado: \$${montoInicial.toStringAsFixed(0)}');

    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final responsable = userProvider.userName ?? 'Usuario Desconocido';

      print(
        '🔄 Llamando createCuadre con fondoInicial: \$${montoInicial.toStringAsFixed(0)}',
      );

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

      print(
        '✅ Cuadre recibido - fondoInicial: \$${cuadre.fondoInicial.toStringAsFixed(0)}',
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
                  if (_hayCajaAbierta) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.error.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        border: Border.all(color: AppTheme.error.withOpacity(0.5)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.error.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 24),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'CAJA YA ABIERTA',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.error,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            if (_cajaActual != null) ...[
                              _buildInfoRow(Icons.point_of_sale, 'Caja', _cajaActual!.nombre),
                              SizedBox(height: 8),
                              _buildInfoRow(Icons.person, 'Responsable', _cajaActual!.responsable),
                              SizedBox(height: 8),
                              _buildInfoRow(
                                Icons.access_time,
                                'Apertura',
                                '${_cajaActual!.fechaApertura.day}/${_cajaActual!.fechaApertura.month}/${_cajaActual!.fechaApertura.year} ${_cajaActual!.fechaApertura.hour}:${_cajaActual!.fechaApertura.minute.toString().padLeft(2, '0')}',
                              ),
                              SizedBox(height: 8),
                              _buildInfoRow(
                                Icons.attach_money,
                                'Monto inicial',
                                '\$${_cajaActual!.fondoInicial.toStringAsFixed(0)}',
                              ),
                            ],
                            SizedBox(height: 16),
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.warning.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, color: AppTheme.warning, size: 20),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Debe cerrar la caja actual antes de abrir una nueva.',
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24),

                    // Botón para ir a cerrar caja
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.warning, AppTheme.warning.withOpacity(0.8)],
                          ),
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.warning.withOpacity(0.3),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.lock_clock, size: 22),
                          label: Text(
                            'Ir a Cerrar Caja',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).pushReplacementNamed('/cerrar_caja');
                          },
                        ),
                      ),
                    ),
                  ] else ...[
                    // Formulario para abrir caja

                    // Información del usuario
                    _buildCard(
                      icon: Icons.person_outline,
                      title: 'Información del Turno',
                      child: Column(
                        children: [
                          _buildInfoTile(
                            'Responsable',
                            userProvider.userName ?? 'Usuario no identificado',
                            Icons.badge,
                          ),
                          Divider(color: AppTheme.textMuted.withOpacity(0.2)),
                          _buildInfoTile(
                            'Fecha y Hora',
                            '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                            Icons.schedule,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),

                    // Selección de caja
                    _buildCard(
                      icon: Icons.point_of_sale,
                      title: 'Seleccionar Caja',
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            borderSide: BorderSide(color: AppTheme.textMuted),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            borderSide: BorderSide(color: AppTheme.textMuted),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            borderSide: BorderSide(color: AppTheme.primary, width: 2),
                          ),
                          filled: true,
                          fillColor: AppTheme.surfaceDark,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        dropdownColor: AppTheme.cardBg,
                        style: TextStyle(color: AppTheme.textPrimary),
                        value: _selectedCaja,
                        items: ['Caja Principal', 'Caja Secundaria']
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedCaja = newValue;
                          });
                        },
                      ),
                    ),
                    SizedBox(height: 16),

                    // Monto inicial
                    _buildCard(
                      icon: Icons.attach_money,
                      title: 'Monto Inicial *',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _montoInicialController,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(color: AppTheme.textPrimary, fontSize: 18),
                            decoration: InputDecoration(
                              hintText: 'Ingrese el monto inicial',
                              hintStyle: TextStyle(color: AppTheme.textMuted),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                borderSide: BorderSide(color: AppTheme.textMuted),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                borderSide: BorderSide(color: AppTheme.primary, width: 2),
                              ),
                              filled: true,
                              fillColor: AppTheme.surfaceDark,
                              prefixIcon: Container(
                                margin: EdgeInsets.all(8),
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.attach_money, color: AppTheme.primary),
                              ),
                            ),
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.info_outline, size: 14, color: AppTheme.textMuted),
                              SizedBox(width: 6),
                              Text(
                                'Este será el dinero con el que inicia la caja',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),

                    // Identificación máquina
                    _buildCard(
                      icon: Icons.computer,
                      title: 'Identificación de Máquina',
                      child: TextFormField(
                        controller: _idMaquinaController,
                        style: TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'ID o nombre de la máquina',
                          hintStyle: TextStyle(color: AppTheme.textMuted),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            borderSide: BorderSide(color: AppTheme.textMuted),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            borderSide: BorderSide(color: AppTheme.primary, width: 2),
                          ),
                          filled: true,
                          fillColor: AppTheme.surfaceDark,
                          prefixIcon: Container(
                            margin: EdgeInsets.all(8),
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.secondary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.computer, color: AppTheme.secondary),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Observaciones
                    _buildCard(
                      icon: Icons.notes,
                      title: 'Observaciones',
                      child: TextFormField(
                        controller: _observacionesController,
                        maxLines: 3,
                        style: TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Observaciones adicionales (opcional)',
                          hintStyle: TextStyle(color: AppTheme.textMuted),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            borderSide: BorderSide(color: AppTheme.textMuted),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                            borderSide: BorderSide(color: AppTheme.primary, width: 2),
                          ),
                          filled: true,
                          fillColor: AppTheme.surfaceDark,
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),
                    SizedBox(height: 32),

                    // Botón para abrir caja
                    Center(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          boxShadow: AppTheme.primaryShadow,
                        ),
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.lock_open, size: 24),
                          label: Text(
                            'ABRIR CAJA',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            ),
                          ),
                          onPressed: _abrirCaja,
                        ),
                      ),
                    ),
                  ],

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

  Widget _buildCard({required IconData icon, required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.textMuted.withOpacity(0.1)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 18),
        SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
