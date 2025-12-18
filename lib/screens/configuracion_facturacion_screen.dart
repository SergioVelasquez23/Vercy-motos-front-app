import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/factura_electronica_dian.dart';
import '../services/factura_electronica_service.dart';
import '../config/factura_electronica_config.dart';

/// Pantalla de configuración de facturación electrónica
/// Permite configurar los datos del emisor y autorización DIAN desde la app
class ConfiguracionFacturacionScreen extends StatefulWidget {
  const ConfiguracionFacturacionScreen({Key? key}) : super(key: key);

  @override
  State<ConfiguracionFacturacionScreen> createState() =>
      _ConfiguracionFacturacionScreenState();
}

class _ConfiguracionFacturacionScreenState
    extends State<ConfiguracionFacturacionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKeyEmisor = GlobalKey<FormState>();
  final _formKeyAutorizacion = GlobalKey<FormState>();

  // Controladores para datos del emisor
  final _razonSocialController = TextEditingController();
  final _nitController = TextEditingController();
  final _digitoVerificacionController = TextEditingController();
  final _nombreComercialController = TextEditingController();
  final _direccionController = TextEditingController();
  final _ciudadController = TextEditingController();
  final _codigoCiudadController = TextEditingController();
  final _departamentoController = TextEditingController();
  final _codigoDepartamentoController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();

  // Controladores para autorización DIAN
  final _numeroAutorizacionController = TextEditingController();
  final _prefijoFacturaController = TextEditingController();
  final _rangoDesdeController = TextEditingController();
  final _rangoHastaController = TextEditingController();
  final _softwareIdController = TextEditingController();
  final _softwareSecurityCodeController = TextEditingController();
  final _proveedorSoftwareNitController = TextEditingController();

  DateTime? _fechaInicioAutorizacion;
  DateTime? _fechaFinAutorizacion;

  String _tipoRegimen = 'O-23';
  bool _configuracionGuardada = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarConfiguracionExistente();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _razonSocialController.dispose();
    _nitController.dispose();
    _digitoVerificacionController.dispose();
    _nombreComercialController.dispose();
    _direccionController.dispose();
    _ciudadController.dispose();
    _codigoCiudadController.dispose();
    _departamentoController.dispose();
    _codigoDepartamentoController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _numeroAutorizacionController.dispose();
    _prefijoFacturaController.dispose();
    _rangoDesdeController.dispose();
    _rangoHastaController.dispose();
    _softwareIdController.dispose();
    _softwareSecurityCodeController.dispose();
    _proveedorSoftwareNitController.dispose();
    super.dispose();
  }

  /// Cargar configuración existente si hay
  void _cargarConfiguracionExistente() {
    // TODO: Cargar desde base de datos o SharedPreferences
    // Por ahora cargamos valores de ejemplo
    try {
      final emisor = FacturaElectronicaConfig.obtenerEmisorConfiguracion();
      _razonSocialController.text = emisor.razonSocial;
      _nitController.text = emisor.nit;
      _digitoVerificacionController.text = emisor.digitoVerificacion;
      _nombreComercialController.text = emisor.nombreComercial;
      _direccionController.text = emisor.direccion;
      _ciudadController.text = emisor.ciudad;
      _codigoCiudadController.text = emisor.codigoCiudad;
      _departamentoController.text = emisor.departamento;
      _codigoDepartamentoController.text = emisor.codigoDepartamento;
      _telefonoController.text = emisor.telefono;
      _emailController.text = emisor.email;
      _tipoRegimen = emisor.tipoRegimen;

      final auth = FacturaElectronicaConfig.obtenerAutorizacionDian();
      _numeroAutorizacionController.text = auth['numeroAutorizacion'] ?? '';
      _prefijoFacturaController.text = auth['prefijoFactura'] ?? '';
      _rangoDesdeController.text = auth['rangoDesde'] ?? '';
      _rangoHastaController.text = auth['rangoHasta'] ?? '';
      _softwareIdController.text = auth['softwareId'] ?? '';
      _softwareSecurityCodeController.text = auth['softwareSecurityCode'] ?? '';
      _proveedorSoftwareNitController.text = auth['proveedorSoftwareNit'] ?? '';
      _fechaInicioAutorizacion = auth['fechaInicioAutorizacion'];
      _fechaFinAutorizacion = auth['fechaFinAutorizacion'];
    } catch (e) {
      print('No hay configuración previa: $e');
    }
  }

  Future<void> _guardarConfiguracion() async {
    if (!_formKeyEmisor.currentState!.validate()) {
      _tabController.animateTo(0);
      return;
    }

    if (!_formKeyAutorizacion.currentState!.validate()) {
      _tabController.animateTo(1);
      return;
    }

    try {
      // Crear emisor
      final emisor = EmisorDian(
        razonSocial: _razonSocialController.text,
        nit: _nitController.text,
        digitoVerificacion: _digitoVerificacionController.text,
        tipoDocumento: '31',
        tipoPersona: '1',
        tipoRegimen: _tipoRegimen,
        nombreComercial: _nombreComercialController.text,
        direccion: _direccionController.text,
        ciudad: _ciudadController.text,
        codigoCiudad: _codigoCiudadController.text,
        departamento: _departamentoController.text,
        codigoDepartamento: _codigoDepartamentoController.text,
        pais: 'CO',
        telefono: _telefonoController.text,
        email: _emailController.text,
        responsabilidadesFiscales: _tipoRegimen,
      );

      // Configurar el servicio
      FacturaElectronicaService.configurarEmisor(emisor);
      FacturaElectronicaService.configurarAutorizacionDian(
        numeroAutorizacion: _numeroAutorizacionController.text,
        fechaInicioAutorizacion: _fechaInicioAutorizacion ?? DateTime.now(),
        fechaFinAutorizacion:
            _fechaFinAutorizacion ?? DateTime.now().add(Duration(days: 3650)),
        prefijoFactura: _prefijoFacturaController.text,
        rangoDesde: _rangoDesdeController.text,
        rangoHasta: _rangoHastaController.text,
        softwareId: _softwareIdController.text,
        softwareSecurityCode: _softwareSecurityCodeController.text,
        proveedorSoftwareNit: _proveedorSoftwareNitController.text,
      );

      // TODO: Guardar en base de datos o SharedPreferences para persistencia

      setState(() {
        _configuracionGuardada = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Configuración guardada correctamente'),
          backgroundColor: Colors.green,
        ),
      );

      // Regresar después de 1 segundo
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración Facturación DIAN'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.business), text: 'Datos Empresa'),
            Tab(icon: Icon(Icons.verified_user), text: 'Autorización DIAN'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildFormularioEmisor(), _buildFormularioAutorizacion()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _guardarConfiguracion,
        icon: const Icon(Icons.save),
        label: const Text('Guardar'),
      ),
    );
  }

  Widget _buildFormularioEmisor() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKeyEmisor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSeccionHeader('Información Legal'),
            TextFormField(
              controller: _razonSocialController,
              decoration: const InputDecoration(
                labelText: 'Razón Social *',
                hintText: 'Nombre legal de la empresa',
                prefixIcon: Icon(Icons.business),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _nitController,
                    decoration: const InputDecoration(
                      labelText: 'NIT *',
                      hintText: 'Sin dígito de verificación',
                      prefixIcon: Icon(Icons.badge),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Campo requerido' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _digitoVerificacionController,
                    decoration: const InputDecoration(
                      labelText: 'DV *',
                      hintText: 'DV',
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Requerido' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _tipoRegimen,
              decoration: const InputDecoration(
                labelText: 'Tipo de Régimen *',
                prefixIcon: Icon(Icons.account_balance),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'O-13',
                  child: Text('O-13: Gran contribuyente'),
                ),
                DropdownMenuItem(
                  value: 'O-15',
                  child: Text('O-15: Autoretenedor'),
                ),
                DropdownMenuItem(
                  value: 'O-23',
                  child: Text('O-23: Agente retención IVA'),
                ),
                DropdownMenuItem(
                  value: 'O-47',
                  child: Text('O-47: Régimen simple'),
                ),
                DropdownMenuItem(
                  value: 'O-99',
                  child: Text('O-99: No responsable IVA'),
                ),
              ],
              onChanged: (value) => setState(() => _tipoRegimen = value!),
            ),
            const SizedBox(height: 24),
            _buildSeccionHeader('Datos Comerciales'),
            TextFormField(
              controller: _nombreComercialController,
              decoration: const InputDecoration(
                labelText: 'Nombre Comercial *',
                hintText: 'Nombre del restaurante',
                prefixIcon: Icon(Icons.store),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 24),
            _buildSeccionHeader('Ubicación'),
            TextFormField(
              controller: _direccionController,
              decoration: const InputDecoration(
                labelText: 'Dirección *',
                prefixIcon: Icon(Icons.location_on),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ciudadController,
                    decoration: const InputDecoration(
                      labelText: 'Ciudad *',
                      prefixIcon: Icon(Icons.location_city),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Campo requerido' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _codigoCiudadController,
                    decoration: const InputDecoration(
                      labelText: 'Código DANE *',
                      hintText: 'Ej: 11001',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Requerido' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _departamentoController,
                    decoration: const InputDecoration(
                      labelText: 'Departamento *',
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Campo requerido' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _codigoDepartamentoController,
                    decoration: const InputDecoration(
                      labelText: 'Código Depto *',
                      hintText: 'Ej: 11',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Requerido' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSeccionHeader('Contacto'),
            TextFormField(
              controller: _telefonoController,
              decoration: const InputDecoration(
                labelText: 'Teléfono *',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email *',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Campo requerido';
                if (!RegExp(
                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                ).hasMatch(value!)) {
                  return 'Email inválido';
                }
                return null;
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildFormularioAutorizacion() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKeyAutorizacion,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Estos datos los obtienes después de completar el proceso de habilitación con la DIAN',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSeccionHeader('Autorización'),
            TextFormField(
              controller: _numeroAutorizacionController,
              decoration: const InputDecoration(
                labelText: 'Número de Autorización *',
                hintText: 'Ej: 18760000001',
                prefixIcon: Icon(Icons.verified),
              ),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Fecha Inicio Autorización *'),
              subtitle: Text(
                _fechaInicioAutorizacion != null
                    ? '${_fechaInicioAutorizacion!.day}/${_fechaInicioAutorizacion!.month}/${_fechaInicioAutorizacion!.year}'
                    : 'Seleccionar fecha',
              ),
              leading: const Icon(Icons.calendar_today),
              onTap: () async {
                final fecha = await showDatePicker(
                  context: context,
                  initialDate: _fechaInicioAutorizacion ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2050),
                );
                if (fecha != null) {
                  setState(() => _fechaInicioAutorizacion = fecha);
                }
              },
            ),
            ListTile(
              title: const Text('Fecha Fin Autorización *'),
              subtitle: Text(
                _fechaFinAutorizacion != null
                    ? '${_fechaFinAutorizacion!.day}/${_fechaFinAutorizacion!.month}/${_fechaFinAutorizacion!.year}'
                    : 'Seleccionar fecha',
              ),
              leading: const Icon(Icons.calendar_today),
              onTap: () async {
                final fecha = await showDatePicker(
                  context: context,
                  initialDate:
                      _fechaFinAutorizacion ??
                      DateTime.now().add(Duration(days: 3650)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2050),
                );
                if (fecha != null) {
                  setState(() => _fechaFinAutorizacion = fecha);
                }
              },
            ),
            const SizedBox(height: 24),
            _buildSeccionHeader('Numeración'),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _prefijoFacturaController,
                    decoration: const InputDecoration(
                      labelText: 'Prefijo *',
                      hintText: 'Ej: SOPE',
                      prefixIcon: Icon(Icons.tag),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Requerido' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _rangoDesdeController,
                    decoration: const InputDecoration(
                      labelText: 'Desde *',
                      hintText: '1',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Requerido' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _rangoHastaController,
                    decoration: const InputDecoration(
                      labelText: 'Hasta *',
                      hintText: '5000000',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Requerido' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSeccionHeader('Software'),
            TextFormField(
              controller: _softwareIdController,
              decoration: const InputDecoration(
                labelText: 'Software ID *',
                hintText: 'UUID del software registrado',
                prefixIcon: Icon(Icons.computer),
              ),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _softwareSecurityCodeController,
              decoration: const InputDecoration(
                labelText: 'Código de Seguridad *',
                hintText: 'PIN del software',
                prefixIcon: Icon(Icons.lock),
              ),
              maxLines: 2,
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _proveedorSoftwareNitController,
              decoration: const InputDecoration(
                labelText: 'NIT Proveedor Software *',
                prefixIcon: Icon(Icons.business_center),
              ),
              keyboardType: TextInputType.number,
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionHeader(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        titulo,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}
