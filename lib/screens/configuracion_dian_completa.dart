import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/configuracion_dian.dart';
import '../models/factura_electronica_dian.dart';
import '../services/configuracion_facturacion_service.dart';

/// Pantalla completa de configuración DIAN para facturación electrónica
/// Incluye todos los campos necesarios para el envío de facturas electrónicas
class ConfiguracionDianCompleta extends StatefulWidget {
  const ConfiguracionDianCompleta({Key? key}) : super(key: key);

  @override
  State<ConfiguracionDianCompleta> createState() =>
      _ConfiguracionDianCompletaState();
}

class _ConfiguracionDianCompletaState extends State<ConfiguracionDianCompleta>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _formKeyEmisor = GlobalKey<FormState>();
  final _formKeyResolucion = GlobalKey<FormState>();
  final _formKeySoftware = GlobalKey<FormState>();

  final _service = ConfiguracionFacturacionService();

  bool _cargando = false;
  bool _guardando = false;

  // === CONTROLADORES PARA DATOS DEL EMISOR ===
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
  String _tipoRegimen = 'O-23';

  // === CONTROLADORES PARA RESOLUCIÓN DIAN ===
  final _claveTecnicaResolucionController = TextEditingController();
  final _prefijoResolucionController = TextEditingController();
  final _numeroResolucionController = TextEditingController();
  final _rangoNumeracionInicialController = TextEditingController();
  final _rangoNumeracionFinalController = TextEditingController();
  final _resolucionValidaDesdeController = TextEditingController();
  final _resolucionValidaHastaController = TextEditingController();
  final _iniciarNumeroFacturaDesdeController = TextEditingController();

  // === CONTROLADORES PARA MODO DE OPERACIÓN ===
  final _modoOperacionController = TextEditingController();
  final _descripcionModoOperacionController = TextEditingController();
  final _fechaInicioModoOperacionController = TextEditingController();
  final _fechaTerminoModoOperacionController = TextEditingController();

  // === CONTROLADORES PARA RANGO DE NUMERACIÓN ASIGNADO ===
  final _prefijoRangoController = TextEditingController();
  final _numeroResolucionRangoController = TextEditingController();
  final _rangoDesdeController = TextEditingController();
  final _rangoHastaController = TextEditingController();
  final _fechaDesdeRangoController = TextEditingController();
  final _fechaHastaRangoController = TextEditingController();

  // === CONTROLADORES PARA SOFTWARE ===
  final _softwareIdController = TextEditingController();
  final _nombreSoftwareController = TextEditingController();
  final _claveTecnicaSoftwareController = TextEditingController();
  final _pinController = TextEditingController();

  // === CONTROLADORES PARA CERTIFICADO ===
  final _certificadoController = TextEditingController();
  final _certificadoPasswordController = TextEditingController();
  final _certificadoVencimientoController = TextEditingController();

  // === CONTROLADORES PARA AMBIENTE DE PRUEBAS ===
  final _testSetIdController = TextEditingController();
  bool _esModoProduccion = false;

  // === CONTROLADORES PARA PROVEEDOR TECNOLÓGICO ===
  final _proveedorTecnologicoNitController = TextEditingController();
  final _proveedorTecnologicoNombreController = TextEditingController();

  // === CONTROLADORES ADICIONALES ===
  final _urlWebServiceController = TextEditingController();
  final _notasController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _cargarConfiguracion();
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
    _claveTecnicaResolucionController.dispose();
    _prefijoResolucionController.dispose();
    _numeroResolucionController.dispose();
    _rangoNumeracionInicialController.dispose();
    _rangoNumeracionFinalController.dispose();
    _resolucionValidaDesdeController.dispose();
    _resolucionValidaHastaController.dispose();
    _iniciarNumeroFacturaDesdeController.dispose();
    _modoOperacionController.dispose();
    _descripcionModoOperacionController.dispose();
    _fechaInicioModoOperacionController.dispose();
    _fechaTerminoModoOperacionController.dispose();
    _prefijoRangoController.dispose();
    _numeroResolucionRangoController.dispose();
    _rangoDesdeController.dispose();
    _rangoHastaController.dispose();
    _fechaDesdeRangoController.dispose();
    _fechaHastaRangoController.dispose();
    _softwareIdController.dispose();
    _nombreSoftwareController.dispose();
    _claveTecnicaSoftwareController.dispose();
    _pinController.dispose();
    _certificadoController.dispose();
    _certificadoPasswordController.dispose();
    _certificadoVencimientoController.dispose();
    _testSetIdController.dispose();
    _proveedorTecnologicoNitController.dispose();
    _proveedorTecnologicoNombreController.dispose();
    _urlWebServiceController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  Future<void> _cargarConfiguracion() async {
    setState(() => _cargando = true);

    try {
      // Cargar datos del emisor
      final emisor = await _service.obtenerEmisor();
      if (emisor != null) {
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
      }

      // Cargar configuración DIAN completa
      final config = await _service.obtenerConfiguracionDian();
      if (config != null) {
        _claveTecnicaResolucionController.text = config.claveTecnicaResolucion;
        _prefijoResolucionController.text = config.prefijoResolucion;
        _numeroResolucionController.text = config.numeroResolucion;
        _rangoNumeracionInicialController.text = config.rangoNumeracionInicial;
        _rangoNumeracionFinalController.text = config.rangoNumeracionFinal;
        _resolucionValidaDesdeController.text = config.resolucionValidaDesde;
        _resolucionValidaHastaController.text = config.resolucionValidaHasta;
        _iniciarNumeroFacturaDesdeController.text =
            config.iniciarNumeroFacturaDesde;

        _modoOperacionController.text = config.modoOperacion;
        _descripcionModoOperacionController.text =
            config.descripcionModoOperacion ?? '';
        _fechaInicioModoOperacionController.text =
            config.fechaInicioModoOperacion ?? '';
        _fechaTerminoModoOperacionController.text =
            config.fechaTerminoModoOperacion ?? '';

        _prefijoRangoController.text = config.prefijoRango ?? '';
        _numeroResolucionRangoController.text =
            config.numeroResolucionRango ?? '';
        _rangoDesdeController.text = config.rangoDesde ?? '';
        _rangoHastaController.text = config.rangoHasta ?? '';
        _fechaDesdeRangoController.text = config.fechaDesdeRango ?? '';
        _fechaHastaRangoController.text = config.fechaHastaRango ?? '';

        _softwareIdController.text = config.softwareId;
        _nombreSoftwareController.text = config.nombreSoftware ?? '';
        _claveTecnicaSoftwareController.text =
            config.claveTecnicaSoftware ?? '';
        _pinController.text = config.pin;

        _certificadoController.text = config.certificado ?? '';
        _certificadoPasswordController.text = config.certificadoPassword ?? '';
        _certificadoVencimientoController.text =
            config.certificadoVencimiento ?? '';

        _testSetIdController.text = config.testSetId ?? '';
        _esModoProduccion = config.esModoProduccion;

        _proveedorTecnologicoNitController.text =
            config.proveedorTecnologicoNit ?? '';
        _proveedorTecnologicoNombreController.text =
            config.proveedorTecnologicoNombre ?? '';

        _urlWebServiceController.text = config.urlWebService ?? '';
        _notasController.text = config.notas ?? '';
      }
    } catch (e) {
      print('Error cargando configuración: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar configuración: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _guardarConfiguracion() async {
    // Validar todos los formularios
    if (!_formKeyEmisor.currentState!.validate()) {
      _tabController.animateTo(0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor completa los datos del emisor'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_formKeyResolucion.currentState!.validate()) {
      _tabController.animateTo(1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor completa los datos de resolución'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_formKeySoftware.currentState!.validate()) {
      _tabController.animateTo(2);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor completa los datos del software'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      // Guardar datos del emisor
      final emisor = EmisorDian(
        razonSocial: _razonSocialController.text.trim(),
        nit: _nitController.text.trim(),
        digitoVerificacion: _digitoVerificacionController.text.trim(),
        tipoDocumento: '31',
        tipoPersona: '1',
        tipoRegimen: _tipoRegimen,
        nombreComercial: _nombreComercialController.text.trim(),
        direccion: _direccionController.text.trim(),
        ciudad: _ciudadController.text.trim(),
        codigoCiudad: _codigoCiudadController.text.trim(),
        departamento: _departamentoController.text.trim(),
        codigoDepartamento: _codigoDepartamentoController.text.trim(),
        pais: 'CO',
        telefono: _telefonoController.text.trim(),
        email: _emailController.text.trim(),
        responsabilidadesFiscales: _tipoRegimen,
      );

      final emisorGuardado = await _service.guardarEmisor(emisor);

      // Guardar configuración DIAN completa
      final config = ConfiguracionDian(
        claveTecnicaResolucion: _claveTecnicaResolucionController.text.trim(),
        prefijoResolucion: _prefijoResolucionController.text.trim(),
        numeroResolucion: _numeroResolucionController.text.trim(),
        rangoNumeracionInicial: _rangoNumeracionInicialController.text.trim(),
        rangoNumeracionFinal: _rangoNumeracionFinalController.text.trim(),
        resolucionValidaDesde: _resolucionValidaDesdeController.text.trim(),
        resolucionValidaHasta: _resolucionValidaHastaController.text.trim(),
        iniciarNumeroFacturaDesde: _iniciarNumeroFacturaDesdeController.text
            .trim(),
        modoOperacion: _modoOperacionController.text.trim(),
        descripcionModoOperacion:
            _descripcionModoOperacionController.text.trim().isEmpty
            ? null
            : _descripcionModoOperacionController.text.trim(),
        fechaInicioModoOperacion:
            _fechaInicioModoOperacionController.text.trim().isEmpty
            ? null
            : _fechaInicioModoOperacionController.text.trim(),
        fechaTerminoModoOperacion:
            _fechaTerminoModoOperacionController.text.trim().isEmpty
            ? null
            : _fechaTerminoModoOperacionController.text.trim(),
        prefijoRango: _prefijoRangoController.text.trim().isEmpty
            ? null
            : _prefijoRangoController.text.trim(),
        numeroResolucionRango:
            _numeroResolucionRangoController.text.trim().isEmpty
            ? null
            : _numeroResolucionRangoController.text.trim(),
        rangoDesde: _rangoDesdeController.text.trim().isEmpty
            ? null
            : _rangoDesdeController.text.trim(),
        rangoHasta: _rangoHastaController.text.trim().isEmpty
            ? null
            : _rangoHastaController.text.trim(),
        fechaDesdeRango: _fechaDesdeRangoController.text.trim().isEmpty
            ? null
            : _fechaDesdeRangoController.text.trim(),
        fechaHastaRango: _fechaHastaRangoController.text.trim().isEmpty
            ? null
            : _fechaHastaRangoController.text.trim(),
        softwareId: _softwareIdController.text.trim(),
        nombreSoftware: _nombreSoftwareController.text.trim().isEmpty
            ? null
            : _nombreSoftwareController.text.trim(),
        claveTecnicaSoftware:
            _claveTecnicaSoftwareController.text.trim().isEmpty
            ? null
            : _claveTecnicaSoftwareController.text.trim(),
        pin: _pinController.text.trim(),
        certificado: _certificadoController.text.trim().isEmpty
            ? null
            : _certificadoController.text.trim(),
        certificadoPassword: _certificadoPasswordController.text.trim().isEmpty
            ? null
            : _certificadoPasswordController.text.trim(),
        certificadoVencimiento:
            _certificadoVencimientoController.text.trim().isEmpty
            ? null
            : _certificadoVencimientoController.text.trim(),
        testSetId: _testSetIdController.text.trim().isEmpty
            ? null
            : _testSetIdController.text.trim(),
        esModoProduccion: _esModoProduccion,
        proveedorTecnologicoNit:
            _proveedorTecnologicoNitController.text.trim().isEmpty
            ? null
            : _proveedorTecnologicoNitController.text.trim(),
        proveedorTecnologicoNombre:
            _proveedorTecnologicoNombreController.text.trim().isEmpty
            ? null
            : _proveedorTecnologicoNombreController.text.trim(),
        urlWebService: _urlWebServiceController.text.trim().isEmpty
            ? null
            : _urlWebServiceController.text.trim(),
        notas: _notasController.text.trim().isEmpty
            ? null
            : _notasController.text.trim(),
        fechaActualizacion: DateTime.now(),
      );

      final configGuardada = await _service.guardarConfiguracionDian(config);

      if (emisorGuardado && configGuardada) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Configuración guardada correctamente'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          await Future.delayed(const Duration(seconds: 2));
          Navigator.of(context).pop(true);
        }
      } else {
        throw Exception('Error al guardar la configuración');
      }
    } catch (e) {
      print('Error guardando configuración: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Scaffold(
        appBar: AppBar(title: const Text('Configuración DIAN')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración Facturación Electrónica DIAN'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.business), text: 'Empresa'),
            Tab(icon: Icon(Icons.description), text: 'Resolución'),
            Tab(icon: Icon(Icons.computer), text: 'Software'),
            Tab(icon: Icon(Icons.settings), text: 'Adicional'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabEmisor(),
          _buildTabResolucion(),
          _buildTabSoftware(),
          _buildTabAdicional(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _guardando ? null : _guardarConfiguracion,
        icon: _guardando
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save),
        label: Text(_guardando ? 'Guardando...' : 'Guardar'),
      ),
    );
  }

  // ========================================
  // TAB 1: DATOS DEL EMISOR (EMPRESA)
  // ========================================
  Widget _buildTabEmisor() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKeyEmisor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Información Legal'),
            _buildTextField(
              controller: _razonSocialController,
              label: 'Razón Social *',
              hint: 'Nombre legal de la empresa',
              icon: Icons.business,
              required: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildTextField(
                    controller: _nitController,
                    label: 'NIT *',
                    hint: 'Sin dígito de verificación',
                    icon: Icons.badge,
                    required: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTextField(
                    controller: _digitoVerificacionController,
                    label: 'DV *',
                    hint: 'DV',
                    required: true,
                    maxLength: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _nombreComercialController,
              label: 'Nombre Comercial *',
              hint: 'Nombre con el que se conoce el negocio',
              icon: Icons.store,
              required: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _tipoRegimen,
              decoration: const InputDecoration(
                labelText: 'Tipo de Régimen *',
                prefixIcon: Icon(Icons.account_balance),
                border: OutlineInputBorder(),
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
            _buildSectionTitle('Ubicación'),
            _buildTextField(
              controller: _direccionController,
              label: 'Dirección *',
              hint: 'Calle 123 # 45-67',
              icon: Icons.location_on,
              required: true,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildTextField(
                    controller: _ciudadController,
                    label: 'Ciudad *',
                    hint: 'Bogotá D.C.',
                    required: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTextField(
                    controller: _codigoCiudadController,
                    label: 'Código *',
                    hint: '11001',
                    required: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildTextField(
                    controller: _departamentoController,
                    label: 'Departamento *',
                    hint: 'Cundinamarca',
                    required: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTextField(
                    controller: _codigoDepartamentoController,
                    label: 'Código *',
                    hint: '11',
                    required: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Contacto'),
            _buildTextField(
              controller: _telefonoController,
              label: 'Teléfono *',
              hint: '3001234567',
              icon: Icons.phone,
              required: true,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _emailController,
              label: 'Email *',
              hint: 'facturacion@empresa.com',
              icon: Icons.email,
              required: true,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // ========================================
  // TAB 2: RESOLUCIÓN DIAN
  // ========================================
  Widget _buildTabResolucion() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKeyResolucion,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Datos de la Resolución DIAN'),
            _buildInfoCard(
              'Esta información la encuentras en la resolución de habilitación '
              'que te proporcionó la DIAN',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _claveTecnicaResolucionController,
              label: 'Clave Técnica Resolución *',
              hint:
                  'd075145f255e7513efdeb638238fdd1765f8f4d179d038c290abdd8d10245770',
              icon: Icons.vpn_key,
              required: true,
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _prefijoResolucionController,
                    label: 'Prefijo Resolución *',
                    hint: 'SC',
                    required: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _buildTextField(
                    controller: _numeroResolucionController,
                    label: 'Número Resolución *',
                    hint: '18764101895165',
                    required: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _rangoNumeracionInicialController,
                    label: 'Rango Inicial *',
                    hint: '1',
                    required: true,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTextField(
                    controller: _rangoNumeracionFinalController,
                    label: 'Rango Final *',
                    hint: '10000',
                    required: true,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDateField(
              controller: _resolucionValidaDesdeController,
              label: 'Resolución Válida Desde *',
              hint: '2025-11-21',
            ),
            const SizedBox(height: 16),
            _buildDateField(
              controller: _resolucionValidaHastaController,
              label: 'Resolución Válida Hasta *',
              hint: '2027-11-21',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _iniciarNumeroFacturaDesdeController,
              label: 'Iniciar Número de Factura Desde *',
              hint: '1',
              icon: Icons.tag,
              required: true,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Modo de Operación'),
            _buildTextField(
              controller: _modoOperacionController,
              label: 'Modo de Operación *',
              hint: 'Software propio',
              icon: Icons.computer,
              required: true,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _descripcionModoOperacionController,
              label: 'Descripción',
              hint: 'Set SW Propio',
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDateField(
                    controller: _fechaInicioModoOperacionController,
                    label: 'Fecha Inicio',
                    hint: '2019-03-14',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDateField(
                    controller: _fechaTerminoModoOperacionController,
                    label: 'Fecha Término',
                    hint: '2019-06-14',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Rango de Numeración Asignado (Opcional)'),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _prefijoRangoController,
                    label: 'Prefijo',
                    hint: 'SETP',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _buildTextField(
                    controller: _numeroResolucionRangoController,
                    label: 'Número Resolución',
                    hint: '18760000001',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _rangoDesdeController,
                    label: 'Rango Desde',
                    hint: '990000000',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTextField(
                    controller: _rangoHastaController,
                    label: 'Rango Hasta',
                    hint: '995000000',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDateField(
                    controller: _fechaDesdeRangoController,
                    label: 'Fecha Desde',
                    hint: '2019-01-19',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDateField(
                    controller: _fechaHastaRangoController,
                    label: 'Fecha Hasta',
                    hint: '2030-01-19',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // ========================================
  // TAB 3: SOFTWARE Y CERTIFICADO
  // ========================================
  Widget _buildTabSoftware() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKeySoftware,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Información del Software'),
            _buildTextField(
              controller: _softwareIdController,
              label: 'Software ID *',
              hint: '66f373d2-a05a-407d-a079-fb2c',
              icon: Icons.computer,
              required: true,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _nombreSoftwareController,
              label: 'Nombre del Software',
              hint: 'Vercy Motos',
              icon: Icons.apps,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _claveTecnicaSoftwareController,
              label: 'Clave Técnica del Software',
              hint: 'fc8eac422eba16e22ffd8c6f94b',
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _pinController,
              label: 'PIN del Software *',
              hint: '77777',
              icon: Icons.lock,
              required: true,
              obscureText: false,
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Certificado Digital'),
            _buildInfoCard(
              'El certificado digital es necesario para firmar las facturas electrónicas. '
              'Puedes cargar el certificado en formato base64 o la ruta del archivo.',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _certificadoController,
              label: 'Certificado',
              hint: 'Ruta al archivo o contenido en base64',
              icon: Icons.security,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _certificadoPasswordController,
              label: 'Contraseña del Certificado',
              hint: 'Contraseña',
              icon: Icons.password,
              obscureText: true,
            ),
            const SizedBox(height: 16),
            _buildDateField(
              controller: _certificadoVencimientoController,
              label: 'Fecha de Vencimiento',
              hint: '2026-12-31',
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Ambiente de Pruebas / Producción'),
            _buildInfoCard(
              '⚠️ IMPORTANTE: Durante el proceso de habilitación debes usar el TestSetId '
              'que te proporciona la DIAN. Una vez aprobado, cambia a modo producción.',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _testSetIdController,
              label: 'TestSetId (Para ambiente de pruebas)',
              hint: '03966238-b459-4231-baeb-95e4991c0784',
              icon: Icons.science,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Modo Producción'),
              subtitle: Text(
                _esModoProduccion
                    ? 'Las facturas se enviarán a producción'
                    : 'Las facturas se enviarán a pruebas',
              ),
              value: _esModoProduccion,
              onChanged: (value) => setState(() => _esModoProduccion = value),
              secondary: Icon(
                _esModoProduccion ? Icons.check_circle : Icons.construction,
                color: _esModoProduccion ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // ========================================
  // TAB 4: INFORMACIÓN ADICIONAL
  // ========================================
  Widget _buildTabAdicional() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Proveedor Tecnológico (Opcional)'),
          _buildInfoCard(
            'Si usas un proveedor tecnológico para el envío de facturas, '
            'completa estos datos.',
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _proveedorTecnologicoNitController,
            label: 'NIT del Proveedor',
            hint: '900123456',
            icon: Icons.business_center,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _proveedorTecnologicoNombreController,
            label: 'Nombre del Proveedor',
            hint: 'Nombre de la empresa proveedora',
            icon: Icons.corporate_fare,
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Web Service'),
          _buildTextField(
            controller: _urlWebServiceController,
            label: 'URL del Web Service',
            hint: 'https://api.dian.gov.co/...',
            icon: Icons.cloud,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Notas Adicionales'),
          _buildTextField(
            controller: _notasController,
            label: 'Notas',
            hint: 'Información adicional o recordatorios',
            icon: Icons.note,
            maxLines: 4,
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // ========================================
  // WIDGETS AUXILIARES
  // ========================================

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildInfoCard(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    bool required = false,
    bool obscureText = false,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: const OutlineInputBorder(),
        counterText: '',
      ),
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      validator: required
          ? (value) => (value == null || value.trim().isEmpty)
                ? 'Campo requerido'
                : null
          : null,
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint ?? 'yyyy-MM-dd',
        prefixIcon: const Icon(Icons.calendar_today),
        border: const OutlineInputBorder(),
      ),
      readOnly: true,
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2050),
        );
        if (date != null) {
          controller.text = DateFormat('yyyy-MM-dd').format(date);
        }
      },
    );
  }
}
