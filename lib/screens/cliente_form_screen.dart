import 'package:flutter/material.dart';
import '../models/cliente.dart';
import '../services/cliente_service.dart';
import '../theme/app_theme.dart';

class ClienteFormScreen extends StatefulWidget {
  final Cliente? cliente;

  const ClienteFormScreen({Key? key, this.cliente}) : super(key: key);

  @override
  _ClienteFormScreenState createState() => _ClienteFormScreenState();
}

class _ClienteFormScreenState extends State<ClienteFormScreen> {
  final ClienteService _clienteService = ClienteService();
  final _formKey = GlobalKey<FormState>();

  // Controladores - Identificación
  final _tipoPersonaController = TextEditingController();
  final _tipoIdentificacionController = TextEditingController();
  final _numeroIdentificacionController = TextEditingController();
  final _digitoVerificacionController = TextEditingController();

  // Controladores - Contacto
  final _nombresController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _razonSocialController = TextEditingController();
  final _nombreComercialController = TextEditingController();
  final _correoController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _celularController = TextEditingController();
  final _direccionController = TextEditingController();
  final _ciudadController = TextEditingController();
  final _departamentoController = TextEditingController();
  final _paisController = TextEditingController(text: 'Colombia');
  final _codigoPostalController = TextEditingController();

  // Controladores - Tributario
  String _responsableIVA = 'no';
  String _calidadAgenteRetencion = 'no';
  String? _regimenTributario = 'simplificado';
  final _actividadEconomicaController = TextEditingController();

  // Controladores - Comercial
  String? _condicionPago = 'contado';
  final _diasCreditoController = TextEditingController(text: '0');
  final _cupoCreditoController = TextEditingController(text: '0');

  bool _isLoading = false;
  bool _esEdicion = false;

  @override
  void initState() {
    super.initState();
    _esEdicion = widget.cliente != null;

    if (_esEdicion) {
      _cargarDatosCliente();
    }
  }

  void _cargarDatosCliente() {
    final c = widget.cliente!;

    // Identificación
    _tipoPersonaController.text = c.tipoPersona;
    _tipoIdentificacionController.text = c.tipoIdentificacion;
    _numeroIdentificacionController.text = c.numeroIdentificacion;
    _digitoVerificacionController.text = c.digitoVerificacion ?? '';

    // Contacto
    _nombresController.text = c.nombres ?? '';
    _apellidosController.text = c.apellidos ?? '';
    _razonSocialController.text = c.razonSocial ?? '';
    _correoController.text = c.correo ?? '';
    _telefonoController.text = c.telefono ?? '';
    _direccionController.text = c.direccion ?? '';
    _ciudadController.text = c.ciudad ?? '';
    _departamentoController.text = c.departamento ?? '';
    _codigoPostalController.text = c.codigoPostal ?? '';

    // Tributario
    _responsableIVA = c.responsableIVA;
    _calidadAgenteRetencion = c.calidadAgenteRetencion;
    _regimenTributario = c.regimenTributario;

    // Comercial
    _condicionPago = c.condicionPago;
    _diasCreditoController.text = c.diasCredito.toString();
    _cupoCreditoController.text = c.cupoCredito.toString();
  }

  @override
  void dispose() {
    _tipoPersonaController.dispose();
    _tipoIdentificacionController.dispose();
    _numeroIdentificacionController.dispose();
    _digitoVerificacionController.dispose();
    _nombresController.dispose();
    _apellidosController.dispose();
    _razonSocialController.dispose();
    _nombreComercialController.dispose();
    _correoController.dispose();
    _telefonoController.dispose();
    _celularController.dispose();
    _direccionController.dispose();
    _ciudadController.dispose();
    _departamentoController.dispose();
    _paisController.dispose();
    _codigoPostalController.dispose();
    _actividadEconomicaController.dispose();
    _diasCreditoController.dispose();
    _cupoCreditoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppTheme.surfaceDark,
          labelStyle: TextStyle(color: Colors.grey.shade400),
          hintStyle: TextStyle(color: Colors.grey.shade500),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade700),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade700),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppTheme.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.red, width: 1),
          ),
          prefixIconColor: Colors.grey.shade400,
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: AppTheme.primary,
        ),
        dropdownMenuTheme: DropdownMenuThemeData(
          textStyle: TextStyle(color: Colors.white),
        ),
      ),
      child: Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        appBar: AppBar(
          title: Text(_esEdicion ? 'Editar Cliente' : 'Nuevo Cliente'),
          backgroundColor: AppTheme.cardBg,
          foregroundColor: Colors.white,
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSeccionIdentificacion(),
                SizedBox(height: 24),
                _buildSeccionContacto(),
                SizedBox(height: 24),
                _buildSeccionTributario(),
                SizedBox(height: 24),
                _buildSeccionComercial(),
                SizedBox(height: 100), // Espacio para el botón flotante
              ],
            ),
          ),
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildSeccionCard({
    required String titulo,
    required IconData icono,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(icono, color: AppTheme.primary),
                SizedBox(width: 12),
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionIdentificacion() {
    return _buildSeccionCard(
      titulo: 'Identificación',
      icono: Icons.badge,
      children: [
        DropdownButtonFormField<String>(
          value: _tipoPersonaController.text.isEmpty
              ? 'natural'
              : _tipoPersonaController.text,
          decoration: InputDecoration(
            labelText: 'Tipo de Persona *',
            border: OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(value: 'natural', child: Text('Persona Natural')),
            DropdownMenuItem(
              value: 'juridica',
              child: Text('Persona Jurídica'),
            ),
          ],
          onChanged: (value) =>
              setState(() => _tipoPersonaController.text = value!),
          validator: (value) => value == null ? 'Campo requerido' : null,
        ),
        SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _tipoIdentificacionController.text.isEmpty
              ? 'CC'
              : _tipoIdentificacionController.text,
          decoration: InputDecoration(
            labelText: 'Tipo de Identificación *',
            border: OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(value: 'CC', child: Text('Cédula de Ciudadanía')),
            DropdownMenuItem(value: 'CE', child: Text('Cédula de Extranjería')),
            DropdownMenuItem(value: 'NIT', child: Text('NIT')),
            DropdownMenuItem(value: 'TI', child: Text('Tarjeta de Identidad')),
            DropdownMenuItem(value: 'PAS', child: Text('Pasaporte')),
          ],
          onChanged: (value) =>
              setState(() => _tipoIdentificacionController.text = value!),
          validator: (value) => value == null ? 'Campo requerido' : null,
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _numeroIdentificacionController,
                decoration: InputDecoration(
                  labelText: 'Número de Identificación *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Campo requerido' : null,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: TextFormField(
                controller: _digitoVerificacionController,
                decoration: InputDecoration(
                  labelText: 'DV',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                maxLength: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSeccionContacto() {
    final esJuridica = _tipoPersonaController.text == 'juridica';

    return _buildSeccionCard(
      titulo: 'Contacto',
      icono: Icons.contact_mail,
      children: [
        if (!esJuridica) ...[
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _nombresController,
                  decoration: InputDecoration(
                    labelText: 'Nombres *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Campo requerido' : null,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _apellidosController,
                  decoration: InputDecoration(
                    labelText: 'Apellidos *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Campo requerido' : null,
                ),
              ),
            ],
          ),
        ] else ...[
          TextFormField(
            controller: _razonSocialController,
            decoration: InputDecoration(
              labelText: 'Razón Social *',
              border: OutlineInputBorder(),
            ),
            validator: (value) =>
                value?.isEmpty ?? true ? 'Campo requerido' : null,
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: _nombreComercialController,
            decoration: InputDecoration(
              labelText: 'Nombre Comercial',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _correoController,
                decoration: InputDecoration(
                  labelText: 'Correo Electrónico',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _telefonoController,
                decoration: InputDecoration(
                  labelText: 'Teléfono',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        TextFormField(
          controller: _direccionController,
          decoration: InputDecoration(
            labelText: 'Dirección',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_on),
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _ciudadController,
                decoration: InputDecoration(
                  labelText: 'Ciudad',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _departamentoController,
                decoration: InputDecoration(
                  labelText: 'Departamento',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSeccionTributario() {
    return _buildSeccionCard(
      titulo: 'Tributario',
      icono: Icons.account_balance,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _responsableIVA,
                decoration: InputDecoration(
                  labelText: 'Responsable de IVA',
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: 'si', child: Text('Sí')),
                  DropdownMenuItem(value: 'no', child: Text('No')),
                ],
                onChanged: (value) => setState(() => _responsableIVA = value!),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _calidadAgenteRetencion,
                decoration: InputDecoration(
                  labelText: 'Agente Retenedor',
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: 'si', child: Text('Sí')),
                  DropdownMenuItem(value: 'no', child: Text('No')),
                ],
                onChanged: (value) =>
                    setState(() => _calidadAgenteRetencion = value!),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _regimenTributario,
          decoration: InputDecoration(
            labelText: 'Régimen Tributario',
            border: OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(
              value: 'simplificado',
              child: Text('Régimen Simplificado'),
            ),
            DropdownMenuItem(value: 'comun', child: Text('Régimen Común')),
            DropdownMenuItem(
              value: 'gran_contribuyente',
              child: Text('Gran Contribuyente'),
            ),
          ],
          onChanged: (value) => setState(() => _regimenTributario = value),
        ),
      ],
    );
  }

  Widget _buildSeccionComercial() {
    return _buildSeccionCard(
      titulo: 'Comercial',
      icono: Icons.credit_card,
      children: [
        DropdownButtonFormField<String>(
          value: _condicionPago,
          decoration: InputDecoration(
            labelText: 'Condición de Pago',
            border: OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(value: 'contado', child: Text('Contado')),
            DropdownMenuItem(value: 'credito', child: Text('Crédito')),
          ],
          onChanged: (value) => setState(() => _condicionPago = value!),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _diasCreditoController,
                decoration: InputDecoration(
                  labelText: 'Días de Crédito',
                  border: OutlineInputBorder(),
                  suffixText: 'días',
                ),
                keyboardType: TextInputType.number,
                enabled: _condicionPago == 'credito',
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _cupoCreditoController,
                decoration: InputDecoration(
                  labelText: 'Cupo de Crédito',
                  border: OutlineInputBorder(),
                  prefixText: '\$ ',
                ),
                keyboardType: TextInputType.number,
                enabled: _condicionPago == 'credito',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        border: Border(top: BorderSide(color: Colors.grey.shade800, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.grey.shade600),
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _guardarCliente,
              child: _isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _esEdicion ? 'Actualizar Cliente' : 'Crear Cliente',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _guardarCliente() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Complete todos los campos requeridos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final cliente = Cliente(
        id: widget.cliente?.id,
        tipoPersona: _tipoPersonaController.text,
        tipoIdentificacion: _tipoIdentificacionController.text,
        numeroIdentificacion: _numeroIdentificacionController.text,
        digitoVerificacion: _digitoVerificacionController.text.isEmpty
            ? null
            : _digitoVerificacionController.text,
        nombres: _nombresController.text.isEmpty
            ? null
            : _nombresController.text,
        apellidos: _apellidosController.text.isEmpty
            ? null
            : _apellidosController.text,
        razonSocial: _razonSocialController.text.isEmpty
            ? null
            : _razonSocialController.text,
        correo: _correoController.text.isEmpty ? null : _correoController.text,
        telefono: _telefonoController.text.isEmpty
            ? null
            : _telefonoController.text,
        direccion: _direccionController.text.isEmpty
            ? null
            : _direccionController.text,
        ciudad: _ciudadController.text.isEmpty ? null : _ciudadController.text,
        departamento: _departamentoController.text.isEmpty
            ? null
            : _departamentoController.text,
        codigoPostal: _codigoPostalController.text.isEmpty
            ? null
            : _codigoPostalController.text,
        responsableIVA: _responsableIVA,
        calidadAgenteRetencion: _calidadAgenteRetencion,
        regimenTributario: _regimenTributario,
        condicionPago: _condicionPago,
        diasCredito: int.tryParse(_diasCreditoController.text) ?? 0,
        cupoCredito: double.tryParse(_cupoCreditoController.text) ?? 0,
        saldoActual: widget.cliente?.saldoActual ?? 0,
        estado: widget.cliente?.estado ?? 'activo',
        fechaCreacion: widget.cliente?.fechaCreacion ?? DateTime.now(),
      );

      if (_esEdicion) {
        await _clienteService.actualizarCliente(widget.cliente!.id!, cliente);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cliente actualizado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        await _clienteService.crearCliente(cliente);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cliente creado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }

      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar cliente: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
