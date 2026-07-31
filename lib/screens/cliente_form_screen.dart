import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../models/cliente.dart';
import '../services/cliente_service.dart';
import '../utils/submit_guard.dart';
import '../services/colombia_location_service.dart';
import '../theme/app_theme.dart';
import '../utils/api_error.dart';
import '../utils/dialogs_helper.dart';
import '../utils/legal_texts.dart';

class ClienteFormScreen extends StatefulWidget {
  final Cliente? cliente;

  const ClienteFormScreen({Key? key, this.cliente}) : super(key: key);

  @override
  _ClienteFormScreenState createState() => _ClienteFormScreenState();
}

class _ClienteFormScreenState extends State<ClienteFormScreen> with SubmitGuard {
  final ClienteService _clienteService = ClienteService();
  final ColombiaLocationService _locationService = ColombiaLocationService();
  final _formKey = GlobalKey<FormState>();

  // Datos de ubicación Colombia
  List<Departamento> _departamentos = [];
  List<Municipio> _municipios = [];
  Departamento? _selectedDepartamento;
  Municipio? _selectedMunicipio;
  bool _loadingDepartamentos = true;
  bool _loadingMunicipios = false;

  // 🔒 Aviso visual de tratamiento de datos personales (Ley 1581/2012). Por
  // ahora solo informativo: no bloquea la creación/edición ni se guarda en
  // el backend todavía.
  bool _autorizaTratamientoDatos = false;

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

    // Inicializar tipo de persona como "natural" por defecto
    _tipoPersonaController.text = 'natural';

    _cargarDepartamentos();

    if (_esEdicion) {
      _cargarDatosCliente();
    }
  }

  Future<void> _cargarDepartamentos() async {
    try {
      final departamentos = await _locationService.getDepartamentos();
      if (mounted) {
        setState(() {
          _departamentos = departamentos;
          _loadingDepartamentos = false;
        });

        // Si estamos editando, buscar el departamento por nombre
        if (_esEdicion && widget.cliente?.departamento != null) {
          final depName = widget.cliente!.departamento!.toLowerCase();
          final match = _departamentos.where(
            (d) => d.name.toLowerCase() == depName,
          );
          if (match.isNotEmpty) {
            _selectedDepartamento = match.first;
            await _cargarMunicipios(match.first.id);
            // Buscar el municipio por nombre
            if (widget.cliente?.ciudad != null) {
              final cityName = widget.cliente!.ciudad!.toLowerCase();
              final cityMatch = _municipios.where(
                (m) => m.name.toLowerCase() == cityName,
              );
              if (cityMatch.isNotEmpty && mounted) {
                setState(() => _selectedMunicipio = cityMatch.first);
              }
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingDepartamentos = false);
      }
    }
  }

  Future<void> _cargarMunicipios(int departamentoId) async {
    setState(() {
      _loadingMunicipios = true;
      _selectedMunicipio = null;
      _municipios = [];
    });

    try {
      final municipios = await _locationService.getMunicipios(departamentoId);
      if (mounted) {
        setState(() {
          _municipios = municipios;
          _loadingMunicipios = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingMunicipios = false);
      }
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
    _codigoPostalController.text = c.codigoPostal ?? '';
    // Departamento y ciudad se cargan asíncronamente en _cargarDepartamentos()

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
          fillColor: Theme.of(context).colorScheme.surface,
          labelStyle: TextStyle(color: Colors.grey.shade400),
          hintStyle: TextStyle(color: const Color.fromARGB(255, 247, 247, 247)),
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
          prefixIconColor: const Color.fromARGB(255, 255, 255, 255),
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: const Color.fromARGB(255, 0, 0, 0),
        ),
        dropdownMenuTheme: DropdownMenuThemeData(
          textStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(_esEdicion ? 'Editar Cliente' : 'Nuevo Cliente'),
          backgroundColor: Theme.of(context).colorScheme.surface,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
        ),
        body: Form(
          key: _formKey,
          child: DefaultTabController(
            length: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TabBar(
                  indicatorColor: AppTheme.primary,
                  labelColor: AppTheme.primary,
                  unselectedLabelColor: Colors.grey.shade800,
                  tabs: [
                    Tab(text: 'Identificación'),
                    Tab(text: 'Contacto'),
                    Tab(text: 'Tributario'),
                    Tab(text: 'Comercial'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Tab 1: Identificación
                      _buildTabIdentificacion(),
                      // Tab 2: Contacto
                      _buildTabContacto(),
                      // Tab 3: Tributario
                      _buildTabTributario(),
                      // Tab 4: Comercial
                      _buildTabComercial(),
                    ],
                  ),
                ),
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color.fromARGB(255, 11, 11, 11),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.3),
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

  Widget _buildTabIdentificacion() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Datos de Identificación', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value:
                  _tipoPersonaController.text.isEmpty ||
                      _tipoPersonaController.text == 'Persona Natural'
                  ? 'natural'
                  : (_tipoPersonaController.text == 'Persona Jurídica'
                        ? 'juridica'
                        : _tipoPersonaController.text),
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
              onChanged: (value) {
                if (value != null) {
                  setState(() => _tipoPersonaController.text = value);
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Campo requerido';
                }
                return null;
              },
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
              onChanged: (value) {
                if (value != null) {
                  setState(() => _tipoIdentificacionController.text = value);
                }
              },
              validator: (value) =>
                  value == null || value.isEmpty ? 'Campo requerido' : null,
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
        ),
      ),
    );
  }

  Widget _buildTabContacto() {
    final esJuridica = _tipoPersonaController.text == 'juridica';

    return Padding(
      padding: EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
        // Departamento - Dropdown con buscador
        _buildDepartamentoDropdown(),
        SizedBox(height: 16),
        // Ciudad/Municipio - Dropdown con buscador
        _buildMunicipioDropdown(),
            SizedBox(height: 16),
            _buildDepartamentoDropdown(),
            SizedBox(height: 16),
            _buildMunicipioDropdown(),
          ],
        ),
      ),
    );
  }

  /// Dropdown con buscador para Departamento
  Widget _buildDepartamentoDropdown() {
    if (_loadingDepartamentos) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: 'Departamento',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.map),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primary,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Cargando departamentos...',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    return Autocomplete<Departamento>(
      displayStringForOption: (dep) => dep.name,
      initialValue: _selectedDepartamento != null
          ? TextEditingValue(text: _selectedDepartamento!.name)
          : null,
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return _departamentos;
        }
        return _departamentos.where(
          (dep) => dep.name.toLowerCase().contains(
            textEditingValue.text.toLowerCase(),
          ),
        );
      },
      onSelected: (Departamento departamento) {
        setState(() {
          _selectedDepartamento = departamento;
        });
        _cargarMunicipios(departamento.id);
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            labelText: 'Departamento',
            hintText: 'Buscar departamento...',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.map),
            suffixIcon: textController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      size: 18,
                      color: Colors.grey.shade400,
                    ),
                    onPressed: () {
                      textController.clear();
                      setState(() {
                        _selectedDepartamento = null;
                        _selectedMunicipio = null;
                        _municipios = [];
                      });
                    },
                  )
                : Icon(Icons.arrow_drop_down, color: Colors.grey.shade400),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 250,
                maxWidth: MediaQuery.of(context).size.width - 80,
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final dep = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(
                      dep.name,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    ),
                    leading: Icon(
                      Icons.location_city,
                      size: 18,
                      color: AppTheme.primary,
                    ),
                    hoverColor: AppTheme.primary.withOpacity(0.3),
                    onTap: () => onSelected(dep),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// Dropdown con buscador para Municipio/Ciudad
  Widget _buildMunicipioDropdown() {
    if (_loadingMunicipios) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: 'Ciudad / Municipio',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.location_city),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primary,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Cargando municipios...',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    if (_selectedDepartamento == null) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: 'Ciudad / Municipio',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.location_city),
        ),
        child: Text(
          'Seleccione primero un departamento',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    return Autocomplete<Municipio>(
      displayStringForOption: (mun) => mun.name,
      initialValue: _selectedMunicipio != null
          ? TextEditingValue(text: _selectedMunicipio!.name)
          : null,
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return _municipios;
        }
        return _municipios.where(
          (mun) => mun.name.toLowerCase().contains(
            textEditingValue.text.toLowerCase(),
          ),
        );
      },
      onSelected: (Municipio municipio) {
        setState(() {
          _selectedMunicipio = municipio;
        });
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            labelText: 'Ciudad / Municipio',
            hintText: 'Buscar municipio...',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_city),
            suffixIcon: textController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      size: 18,
                      color: Colors.grey.shade400,
                    ),
                    onPressed: () {
                      textController.clear();
                      setState(() {
                        _selectedMunicipio = null;
                      });
                    },
                  )
                : Icon(Icons.arrow_drop_down, color: Colors.grey.shade400),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 250,
                maxWidth: MediaQuery.of(context).size.width - 80,
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final mun = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(
                      mun.name,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    ),
                    leading: Icon(
                      Icons.place,
                      size: 18,
                      color: AppTheme.primary,
                    ),
                    hoverColor: AppTheme.primary.withOpacity(0.3),
                    onTap: () => onSelected(mun),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabTributario() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Información Tributaria', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 16),
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
        ),
      ),
    );
  }

  Widget _buildTabComercial() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Condiciones Comerciales', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 16),
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
        ),
      ),
    );
  }

  Future<void> _mostrarTextoLegal(String titulo, String texto) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: SizedBox(
          width: dialogWidth(context, 480),
          child: SingleChildScrollView(
            child: Text(
              texto.trim(),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12, height: 1.4),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Colors.grey.shade800, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_esEdicion)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              value: _autorizaTratamientoDatos,
              onChanged: (value) => setState(() => _autorizaTratamientoDatos = value ?? false),
              title: RichText(
                text: TextSpan(
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                    fontSize: 12,
                  ),
                  children: [
                    const TextSpan(text: 'El cliente autorizó el tratamiento de sus datos personales según la '),
                    TextSpan(
                      text: 'Política de Tratamiento de Datos',
                      style: const TextStyle(color: AppTheme.primary, decoration: TextDecoration.underline),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () =>
                            _mostrarTextoLegal('Política de Tratamiento de Datos', politicaTratamientoDatosTexto),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),
          Row(
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
              onPressed: _isLoading ? null : () => runGuarded(_guardarCliente),
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
        ciudad: _selectedMunicipio?.name,
        departamento: _selectedDepartamento?.name,
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

      Cliente clienteGuardado;
      
      if (_esEdicion) {
        clienteGuardado = await _clienteService.actualizarCliente(
          widget.cliente!.id!,
          cliente,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cliente actualizado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        clienteGuardado = await _clienteService.crearCliente(cliente);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cliente creado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }

      Navigator.pop(context, clienteGuardado);
    } catch (e) {
      setState(() => _isLoading = false);
      showErrorDialog(context, errorMessage(e), title: 'No se pudo guardar el cliente');
    }
  }
}
