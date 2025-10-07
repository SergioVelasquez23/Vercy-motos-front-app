import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/negocio_info.dart';
import '../services/negocio_info_service.dart';

class NegocioInfoScreen extends StatefulWidget {
  const NegocioInfoScreen({super.key});

  @override
  State<NegocioInfoScreen> createState() => _NegocioInfoScreenState();
}

class _NegocioInfoScreenState extends State<NegocioInfoScreen> {
  final NegocioInfoService _negocioInfoService = NegocioInfoService();
  final _formKey = GlobalKey<FormState>();

  // Controladores de texto
  final _nombreController = TextEditingController();
  final _nitController = TextEditingController();
  final _contactoController = TextEditingController();
  final _emailController = TextEditingController();
  final _direccionController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _paginaWebController = TextEditingController();
  final _costosEnvioController = TextEditingController();
  final _prefijoController = TextEditingController(); // Keep this
  final _numeroInicioController = TextEditingController(); // Keep this
  final _porcentajePropinaController = TextEditingController(); // Keep this
  final _nombreDocumentoController = TextEditingController(); // Keep this
  final _nota1Controller = TextEditingController(); // Keep this
  final _nota2Controller = TextEditingController(); // Keep this

  // Variables de estado
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  NegocioInfo? _currentInfo;
  XFile? _selectedLogo;

  // Valores de dropdown
  String _selectedPais = 'Colombia';
  String _selectedDepartamento = 'Caldas';
  String _selectedTipoDocumento = 'Factura';

  // Switches
  bool _productosConIngredientes = false;
  bool _utilizoMesas = false;
  bool _envioADomicilio = false;

  // Constantes de diseño
  static const Color _primary = Color(0xFFFF6B00);
  static const Color _cardBg = Color(0xFF1E1E1E);
  static const Color _bgDark = Color(0xFF121212);
  static const Color _textLight = Color(0xFFE0E0E0);

  @override
  void initState() {
    super.initState();
    _cargarInformacion();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _contactoController.dispose();
    _emailController.dispose();
    _direccionController.dispose();
    _nitController.dispose();
    _telefonoController.dispose();
    _paginaWebController.dispose();
    _costosEnvioController.dispose();
    _prefijoController.dispose();
    _numeroInicioController.dispose();
    _porcentajePropinaController.dispose();
    _nombreDocumentoController.dispose();
    _nota1Controller.dispose();
    _nota2Controller.dispose();
    super.dispose();
  }

  Future<void> _cargarInformacion() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final info = await _negocioInfoService.getNegocioInfo();

      if (info != null) {
        _currentInfo = info;
        _llenarFormulario(info);
      } else {
        // Si no hay información, usar valores por defecto
        _numeroInicioController.text = '1';
        _prefijoController.text = 'F';
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _llenarFormulario(NegocioInfo info) {
    final paises = _negocioInfoService.getPaises();
    final departamentos = _negocioInfoService.getDepartamentos();
    final tiposDocumento = _negocioInfoService.getTiposDocumento();

    _nombreController.text = info.nombre;
    _nitController.text = info.nit ?? '';
    _contactoController.text = info.contacto ?? '';
    _emailController.text = info.email ?? '';
    _direccionController.text = info.direccion ?? '';
    _telefonoController.text = info.telefono ?? '';
    _paginaWebController.text = info.paginaWeb ?? '';
    _costosEnvioController.text = info.costosEnvio?.toString() ?? '';
    _prefijoController.text = info.prefijo ?? '';
    _numeroInicioController.text = info.numeroInicio?.toString() ?? '';
    _porcentajePropinaController.text =
        info.porcentajePropinaSugerida?.toString() ?? '';
    _nombreDocumentoController.text = info.nombreDocumento ?? '';
    _nota1Controller.text = info.nota1 ?? '';
    _nota2Controller.text = info.nota2 ?? '';

    _selectedPais =
        paises.contains(info.pais) && (info.pais.isNotEmpty ?? false)
        ? info.pais
        : paises.first;
    _selectedDepartamento =
        departamentos.contains(info.departamento) &&
            (info.departamento.isNotEmpty ?? false)
        ? info.departamento
        : departamentos.first;
    _selectedTipoDocumento =
        tiposDocumento.contains(info.tipoDocumento) &&
            (info.tipoDocumento.isNotEmpty ?? false)
        ? info.tipoDocumento
        : tiposDocumento.first;

    _productosConIngredientes = info.productosConIngredientes ?? false;
    _utilizoMesas = info.utilizoMesas ?? false;
    _envioADomicilio = info.envioADomicilio ?? false;
  }

  Future<void> _seleccionarLogo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedLogo = image;
        });
      }
    } catch (e) {
      _mostrarMensajeError('Error al seleccionar imagen: $e');
    }
  }

  Future<void> _guardarInformacion() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      String? logoUrl = _currentInfo?.logoUrl;

      // Subir logo si se seleccionó uno nuevo
      if (_selectedLogo != null) {
        logoUrl = await _negocioInfoService.uploadLogo(_selectedLogo!);
      }

      // Crear objeto con la información
      final negocioInfo = NegocioInfo(
        id: _currentInfo?.id,
        nombre: _nombreController.text.trim(),
        nitDoc: _nitController.text.trim(),
        contacto: _contactoController.text.trim().isEmpty
            ? ''
            : _contactoController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? ''
            : _emailController.text.trim(),
        direccion: _direccionController.text.trim().isEmpty
            ? ''
            : _direccionController.text.trim(),
        pais: _selectedPais,
        departamento: _selectedDepartamento,
        ciudad: '',
        tieneProductosConIngredientes: _productosConIngredientes,
        utilizaMesas: _utilizoMesas,
        realizaDomicilios: _envioADomicilio ?? false,
        telefono: _telefonoController.text.trim().isEmpty
            ? null
            : _telefonoController.text.trim(),
        paginaWeb: _paginaWebController.text.trim().isEmpty
            ? null
            : _paginaWebController.text.trim(),
        productosConIngredientes: _productosConIngredientes,
        utilizoMesas: _utilizoMesas,
        envioADomicilio: _envioADomicilio,
        costosEnvio: double.tryParse(_costosEnvioController.text.trim()),
        tipoDocumento: _selectedTipoDocumento,
        prefijoDocumento: _prefijoController.text.trim(),
        numeroInicialDocumento:
            int.tryParse(_numeroInicioController.text.trim()) ?? 0,
        prefijo: _prefijoController.text.trim().isEmpty
            ? null
            : _prefijoController.text.trim(),
        numeroInicio: int.tryParse(_numeroInicioController.text.trim()),
        porcentajePropinaSugerida: double.tryParse(
          _porcentajePropinaController.text.trim(),
        ),
        nombreDocumento: _nombreDocumentoController.text.trim().isEmpty
            ? null
            : _nombreDocumentoController.text.trim(),
        nota1: _nota1Controller.text.trim().isEmpty
            ? null
            : _nota1Controller.text.trim(),
        nota2: _nota2Controller.text.trim().isEmpty
            ? null
            : _nota2Controller.text.trim(),
        logoUrl: logoUrl,
        fechaCreacion: _currentInfo?.fechaCreacion ?? DateTime.now(),
        fechaActualizacion: DateTime.now(),
      );

      final savedInfo = await _negocioInfoService.saveNegocioInfo(negocioInfo);

      setState(() {
        _currentInfo = savedInfo;
        _selectedLogo = null;
        _isSaving = false;
      });

      _mostrarMensajeExito('Información guardada correctamente');
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      _mostrarMensajeError('Error al guardar: $e');
    }
  }

  void _mostrarMensajeExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _mostrarMensajeError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        title: Text(
          'Información del Negocio',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _primary,
        elevation: 0,
        actions: [
          if (!_isLoading)
            IconButton(
              icon: Icon(Icons.save, color: Colors.white),
              onPressed: _isSaving ? null : _guardarInformacion,
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primary))
          : _error != null
          ? _buildErrorWidget()
          : _buildFormulario(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, color: Colors.red, size: 64),
          SizedBox(height: 16),
          Text(
            'Error al cargar información',
            style: TextStyle(color: _textLight, fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            _error ?? '',
            style: TextStyle(color: Colors.red, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: _cargarInformacion,
            style: ElevatedButton.styleFrom(backgroundColor: _primary),
            child: Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulario() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSeccionInformacionBasica(),
            SizedBox(height: 24),
            _buildSeccionUbicacion(),
            SizedBox(height: 24),
            _buildSeccionCaracteristicas(),
            SizedBox(height: 24),
            _buildSeccionDocumentacion(),
            SizedBox(height: 24),
            _buildSeccionNotas(),
            SizedBox(height: 32),
            _buildBotonGuardar(),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionInformacionBasica() {
    return Card(
      color: _cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Información Básica',
              style: TextStyle(
                color: _primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),

            // Logo
            _buildCampoLogo(),
            SizedBox(height: 16),

            // Nombre
            _buildCampoTexto(
              controller: _nombreController,
              label: 'Nombre',
              hint: '',
              icon: Icons.business,
              validator: (value) =>
                  value?.isEmpty == true ? 'Nombre requerido' : null,
            ),
            SizedBox(height: 16),

            // NIT/Documento
            _buildCampoTexto(
              controller: _nitController,
              label: 'NIT / Doc *',
              hint: '',
              icon: Icons.assignment_ind,
              validator: (value) =>
                  value?.isEmpty == true ? 'NIT/Documento requerido' : null,
            ),
            SizedBox(height: 16),

            // Contacto
            _buildCampoTexto(
              controller: _contactoController,
              label: 'Contacto',
              hint: '',
              icon: Icons.person,
              validator: (value) =>
                  value?.isEmpty == true ? 'Contacto requerido' : null,
            ),
            SizedBox(height: 16),

            // Email
            _buildCampoTexto(
              controller: _emailController,
              label: 'Email',
              hint: '',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value?.isEmpty == true) return 'Email requerido';
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value!)) {
                  return 'Email inválido';
                }
                return null;
              },
            ),
            SizedBox(height: 16),

            // Teléfono
            _buildCampoTexto(
              controller: _telefonoController,
              label: 'Teléfono',
              hint: '',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              validator: (value) => null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampoLogo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Logo',
          style: TextStyle(
            color: _textLight,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: _seleccionarLogo,
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[600]!),
            ),
            child: _selectedLogo != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: kIsWeb
                        ? Image.network(_selectedLogo!.path, fit: BoxFit.cover)
                        : Image.file(
                            File(_selectedLogo!.path),
                            fit: BoxFit.cover,
                          ),
                  )
                : _currentInfo?.logoUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _currentInfo!.logoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildLogoPlaceholder(),
                    ),
                  )
                : _buildLogoPlaceholder(),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate, color: Colors.grey[400], size: 40),
        SizedBox(height: 8),
        Text(
          'Seleccionar Logo',
          style: TextStyle(color: Colors.grey[400], fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildSeccionUbicacion() {
    return Card(
      color: _cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ubicación',
              style: TextStyle(
                color: _primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),

            // Dirección
            _buildCampoTexto(
              controller: _direccionController,
              label: 'Dirección',
              hint: 'calle 7 # 9a - 27',
              icon: Icons.location_on,
              validator: (value) =>
                  value?.isEmpty == true ? 'Dirección requerida' : null,
            ),
            SizedBox(height: 16),

            // País
            _buildDropdown(
              label: 'País',
              value: _selectedPais,
              items: _negocioInfoService.getPaises(),
              onChanged: (value) => setState(() => _selectedPais = value!),
              icon: Icons.public,
            ),
            SizedBox(height: 16),

            // Departamento
            _buildDropdown(
              label: 'Departamento',
              value: _selectedDepartamento,
              items: _negocioInfoService.getDepartamentos(),
              onChanged: (value) =>
                  setState(() => _selectedDepartamento = value!),
              icon: Icons.map,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionCaracteristicas() {
    return Card(
      color: _cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Características del Negocio',
              style: TextStyle(
                color: _primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),

            _buildSwitch(
              title: 'Productos con ingredientes',
              subtitle: 'Los productos tienen recetas con ingredientes',
              value: _productosConIngredientes,
              onChanged: (value) =>
                  setState(() => _productosConIngredientes = value),
              icon: Icons.restaurant_menu,
            ),

            _buildSwitch(
              title: 'Utiliza mesas',
              subtitle: 'El negocio maneja sistema de mesas',
              value: _utilizoMesas,
              onChanged: (value) => setState(() => _utilizoMesas = value),
              icon: Icons.table_restaurant,
            ),

            _buildSwitch(
              title: 'Realiza domicilios',
              subtitle: 'El negocio ofrece servicio a domicilio',
              value: _envioADomicilio,
              onChanged: (value) => setState(() => _envioADomicilio = value),
              icon: Icons.delivery_dining,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionDocumentacion() {
    return Card(
      color: _cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configuración de Documentos',
              style: TextStyle(
                color: _primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),

            // Tipo de documento
            _buildDropdown(
              label: 'Tipo de Documento',
              value: _selectedTipoDocumento,
              items: _negocioInfoService.getTiposDocumento(),
              onChanged: (value) =>
                  setState(() => _selectedTipoDocumento = value!),
              icon: Icons.description,
            ),
            SizedBox(height: 16),

            // Prefijo
            _buildCampoTexto(
              controller: _prefijoController,
              label: 'Prefijo de Documento',
              hint: 'F',
              icon: Icons.tag,
              validator: (value) =>
                  value?.isEmpty == true ? 'Prefijo requerido' : null,
            ),
            SizedBox(height: 16),

            // Número inicial
            _buildCampoTexto(
              controller: _numeroInicioController,
              label: 'Número Inicial',
              hint: '1',
              icon: Icons.numbers,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value?.isEmpty == true) return 'Número inicial requerido';
                if (int.tryParse(value!) == null) {
                  return 'Debe ser un número válido';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionNotas() {
    return Card(
      color: _cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notas Adicionales',
              style: TextStyle(
                color: _primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _nota1Controller,
              maxLines: 2,
              style: TextStyle(color: _textLight),
              decoration: InputDecoration(
                labelText: 'Nota 1',
                labelStyle: TextStyle(color: _textLight),
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 8),
            TextFormField(
              controller: _nota2Controller,
              maxLines: 2,
              style: TextStyle(color: _textLight),
              decoration: InputDecoration(
                labelText: 'Nota 2',
                labelStyle: TextStyle(color: _textLight),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampoTexto({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: _textLight),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[400]),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[600]),
        prefixIcon: Icon(icon, color: _primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[600]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 16)),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[600]!),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: value,
            onChanged: onChanged,
            style: TextStyle(color: _textLight),
            dropdownColor: _cardBg,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: _primary),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            items: items.map((item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item, style: TextStyle(color: _textLight)),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: _primary, size: 24),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _textLight,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: _primary,
          ),
        ],
      ),
    );
  }

  Widget _buildBotonGuardar() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _guardarInformacion,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: _isSaving
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Guardando...'),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save),
                  SizedBox(width: 8),
                  Text(
                    'Guardar Información',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }
}
