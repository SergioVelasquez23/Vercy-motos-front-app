import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'users_screen.dart';
import '../theme/app_theme.dart';
import '../providers/theme_provider.dart';
import '../models/negocio_info.dart';
import '../services/negocio_info_service.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Configuración'),
      ),
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primary,
              isScrollable: true,
              tabs: const [
                Tab(icon: Icon(Icons.people), text: 'Usuarios'),
                Tab(icon: Icon(Icons.palette), text: 'Apariencia'),
                Tab(icon: Icon(Icons.store_outlined), text: 'Mi Negocio'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [UsersScreen(), _AparienciaTab()] + [_NegocioTab()],
            ),
          ),
        ],
      ),
    );
  }
}

class _AparienciaTab extends StatelessWidget {
  const _AparienciaTab();

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacingLarge),
      children: [
        Text('Tema de la aplicación', style: AppTheme.headlineSmall),
        const SizedBox(height: AppTheme.spacingSmall),
        Text(
          'Elige cómo se ve la aplicación. El modo oscuro reduce la fatiga visual en ambientes con poca luz.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
        ),
        const SizedBox(height: AppTheme.spacingLarge),
        _ThemeOption(
          icon: Icons.light_mode,
          title: 'Claro',
          subtitle: 'Fondos suaves, ideal para uso diurno.',
          selected: themeProvider.mode == ThemeMode.light,
          onTap: () => themeProvider.setMode(ThemeMode.light),
        ),
        _ThemeOption(
          icon: Icons.dark_mode,
          title: 'Oscuro',
          subtitle: 'Bajo contraste, menos cansador de noche.',
          selected: themeProvider.mode == ThemeMode.dark,
          onTap: () => themeProvider.setMode(ThemeMode.dark),
        ),
        _ThemeOption(
          icon: Icons.brightness_auto,
          title: 'Automático (sistema)',
          subtitle: 'Sigue la configuración del dispositivo.',
          selected: themeProvider.mode == ThemeMode.system,
          onTap: () => themeProvider.setMode(ThemeMode.system),
        ),
      ],
    );
  }
}


class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: AppTheme.headlineSmall),
      const SizedBox(height: AppTheme.spacingSmall),
      Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
        child: Column(children: children),
      ),
    ]);
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool required;
  final String? hint;
  final TextInputType keyboardType;

  const _Field(
    this.label,
    this.controller, {
    this.required = false,
    this.hint,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMedium, vertical: AppTheme.spacingSmall),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null
            : null,
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      child: Material(
        color: selected ? color.primary.withOpacity(0.08) : color.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacingMedium),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                color: selected ? color.primary : color.onSurface.withOpacity(0.12),
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: selected ? color.primary : color.onSurface.withOpacity(0.6)),
                const SizedBox(width: AppTheme.spacingMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: color.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: color.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected) Icon(Icons.check_circle, color: color.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TAB MI NEGOCIO — Información general + campos DIAN (FE, DS, POS)
// ─────────────────────────────────────────────────────────────────────────────
class _NegocioTab extends StatefulWidget {
  const _NegocioTab();

  @override
  State<_NegocioTab> createState() => _NegocioTabState();
}

class _NegocioTabState extends State<_NegocioTab> {
  final _formKey = GlobalKey<FormState>();
  final _service = NegocioInfoService();
  bool _loading = true;
  bool _saving = false;
  String? _errorMsg;
  String? _successMsg;
  NegocioInfo? _negocio;

  // ── Controladores información general ──
  final _nombreCtrl = TextEditingController();
  final _nitCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _ciudadCtrl = TextEditingController();

  // ── Controladores DIAN — Factura Electrónica ──
  final _resolucionFECtrl = TextEditingController();
  final _prefijoFECtrl = TextEditingController();

  // ── Controladores DIAN — Documento Soporte ──
  final _resolucionDSCtrl = TextEditingController();
  final _prefijoDSCtrl = TextEditingController();

  // ── Controladores DIAN — POS ──
  final _resolucionPOSCtrl = TextEditingController();
  final _prefijoPOSCtrl = TextEditingController();
  final _cajeroNombreCtrl = TextEditingController();
  final _terminalCtrl = TextEditingController();
  final _tipoCajaCtrl = TextEditingController();
  final _codigoVentaCtrl = TextEditingController();

  // ── Controladores Software DIAN ──
  final _softwareOwnerCtrl = TextEditingController();
  final _softwareCompanyCtrl = TextEditingController();
  final _softwareNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in [
      _nombreCtrl, _nitCtrl, _emailCtrl, _telefonoCtrl, _direccionCtrl, _ciudadCtrl,
      _resolucionFECtrl, _prefijoFECtrl,
      _resolucionDSCtrl, _prefijoDSCtrl,
      _resolucionPOSCtrl, _prefijoPOSCtrl, _cajeroNombreCtrl, _terminalCtrl, _tipoCajaCtrl, _codigoVentaCtrl,
      _softwareOwnerCtrl, _softwareCompanyCtrl, _softwareNameCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _errorMsg = null; });
    try {
      final info = await _service.getNegocioInfo();
      if (info != null) {
        _negocio = info;
        _nombreCtrl.text = info.nombre;
        _nitCtrl.text = info.nitDoc;
        _emailCtrl.text = info.email;
        _telefonoCtrl.text = info.telefono ?? '';
        _direccionCtrl.text = info.direccion;
        _ciudadCtrl.text = info.ciudad;
        _resolucionFECtrl.text = info.resolutionNumber ?? '';
        _prefijoFECtrl.text = info.prefijo ?? '';
        final prefs = await SharedPreferences.getInstance();
        _resolucionDSCtrl.text = info.dsResolutionNumber?.isNotEmpty == true
            ? info.dsResolutionNumber!
            : (prefs.getString('dsResolutionNumber') ?? '');
        _prefijoDSCtrl.text = 'DS';
        _resolucionPOSCtrl.text = info.posResolutionNumber ?? '';
        _prefijoPOSCtrl.text = info.posPrefijo ?? 'POS';
        _cajeroNombreCtrl.text = info.posCashierName ?? '';
        _terminalCtrl.text = info.posTerminalNumber ?? 'T001';
        _tipoCajaCtrl.text = info.posCashierType ?? 'Dependiente';
        _codigoVentaCtrl.text = info.posSalesCode ?? 'V001';
        _softwareOwnerCtrl.text = info.softwareOwnerName ?? '';
        _softwareCompanyCtrl.text = info.softwareCompanyName ?? '';
        _softwareNameCtrl.text = info.softwareName ?? 'Vercy POS';
      }
    } catch (e) {
      _errorMsg = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _errorMsg = null; _successMsg = null; });
    try {
      final base = _negocio ?? NegocioInfo(
        nombre: '', nitDoc: '', contacto: '', email: '', direccion: '',
        pais: 'Colombia', departamento: '', ciudad: '',
        tieneProductosConIngredientes: false, utilizaMesas: false,
        realizaDomicilios: false, tipoDocumento: 'Factura',
        prefijoDocumento: 'F', numeroInicialDocumento: 1,
        fechaCreacion: DateTime.now(), fechaActualizacion: DateTime.now(),
      );
      final actualizado = base.copyWith(
        nombre: _nombreCtrl.text.trim(),
        nitDoc: _nitCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim(),
        direccion: _direccionCtrl.text.trim(),
        ciudad: _ciudadCtrl.text.trim(),
        resolutionNumber: _resolucionFECtrl.text.trim(),
        prefijo: _prefijoFECtrl.text.trim(),
        dsResolutionNumber: _resolucionDSCtrl.text.trim(),
        posResolutionNumber: _resolucionPOSCtrl.text.trim(),
        posPrefijo: _prefijoPOSCtrl.text.trim(),
        posCashierName: _cajeroNombreCtrl.text.trim(),
        posTerminalNumber: _terminalCtrl.text.trim(),
        posCashierType: _tipoCajaCtrl.text.trim(),
        posSalesCode: _codigoVentaCtrl.text.trim(),
        softwareOwnerName: _softwareOwnerCtrl.text.trim(),
        softwareCompanyName: _softwareCompanyCtrl.text.trim(),
        softwareName: _softwareNameCtrl.text.trim(),
      );
      _negocio = await _service.saveNegocioInfo(actualizado);
      // Refrescar controllers con los valores guardados por si el backend
      // no los retorna en la respuesta (campos DIAN nuevos).
      _resolucionFECtrl.text = actualizado.resolutionNumber ?? _resolucionFECtrl.text;
      _prefijoFECtrl.text = actualizado.prefijo ?? _prefijoFECtrl.text;
      final dsVal = actualizado.dsResolutionNumber ?? _resolucionDSCtrl.text;
      _resolucionDSCtrl.text = dsVal;
      if (dsVal.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('dsResolutionNumber', dsVal);
      }
      _resolucionPOSCtrl.text = actualizado.posResolutionNumber ?? _resolucionPOSCtrl.text;
      _prefijoPOSCtrl.text = actualizado.posPrefijo ?? _prefijoPOSCtrl.text;
      _cajeroNombreCtrl.text = actualizado.posCashierName ?? _cajeroNombreCtrl.text;
      _terminalCtrl.text = actualizado.posTerminalNumber ?? _terminalCtrl.text;
      _tipoCajaCtrl.text = actualizado.posCashierType ?? _tipoCajaCtrl.text;
      _codigoVentaCtrl.text = actualizado.posSalesCode ?? _codigoVentaCtrl.text;
      _softwareOwnerCtrl.text = actualizado.softwareOwnerName ?? _softwareOwnerCtrl.text;
      _softwareCompanyCtrl.text = actualizado.softwareCompanyName ?? _softwareCompanyCtrl.text;
      _softwareNameCtrl.text = actualizado.softwareName ?? _softwareNameCtrl.text;
      setState(() => _successMsg = 'Configuración guardada correctamente');
    } catch (e) {
      setState(() => _errorMsg = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Mensajes ──
          if (_errorMsg != null) _banner(_errorMsg!, AppTheme.error, Icons.error_outline),
          if (_successMsg != null) _banner(_successMsg!, AppTheme.success, Icons.check_circle_outline),

          // ─────────────────────────────────────
          _sectionHeader(context, Icons.store_outlined, 'Información General'),
          _field(_nombreCtrl, 'Nombre del negocio *', required: true),
          _row([
            _field(_nitCtrl, 'NIT / Documento *', required: true),
            _field(_telefonoCtrl, 'Teléfono', keyboard: TextInputType.phone),
          ]),
          _row([
            _field(_emailCtrl, 'Correo electrónico', keyboard: TextInputType.emailAddress),
            _field(_ciudadCtrl, 'Ciudad'),
          ]),
          _field(_direccionCtrl, 'Dirección'),

          const SizedBox(height: 8),

          // ─────────────────────────────────────
          _sectionHeader(context, Icons.receipt_long, 'Factura Electrónica (FE)',
              subtitle: 'Resolución DIAN para facturas de venta (FAEL)'),
          _row([
            _field(_resolucionFECtrl, 'Número de resolución FE', hint: 'ej: 18764099537925'),
            _field(_prefijoFECtrl, 'Prefijo', hint: 'ej: FAEL'),
          ]),

          const SizedBox(height: 8),

          // ─────────────────────────────────────
          _sectionHeader(context, Icons.file_present_rounded, 'Documento Soporte (DS)',
              subtitle: 'Resolución DIAN para compras a proveedores no obligados'),
          _row([
            _field(_resolucionDSCtrl, 'Número de resolución DS', hint: 'ej: 18764109195176'),
            _field(_prefijoDSCtrl, 'Prefijo DS', hint: 'ej: DS'),
          ]),

          const SizedBox(height: 8),

          // ─────────────────────────────────────
          _sectionHeader(context, Icons.point_of_sale, 'POS Electrónico',
              subtitle: 'Resolución y datos del punto de venta registrados en DIAN'),
          _row([
            _field(_resolucionPOSCtrl, 'Número de resolución POS', hint: 'ej: 18764109195373'),
            _field(_prefijoPOSCtrl, 'Prefijo POS', hint: 'ej: POS'),
          ]),
          _row([
            _field(_cajeroNombreCtrl, 'Nombre cajero/vendedor', hint: 'ej: Vendedor Principal'),
            _field(_terminalCtrl, 'Terminal número', hint: 'ej: T001'),
          ]),
          _row([
            _field(_tipoCajaCtrl, 'Tipo de caja', hint: 'ej: Dependiente'),
            _field(_codigoVentaCtrl, 'Código punto de venta', hint: 'ej: V001'),
          ]),

          const SizedBox(height: 8),

          // ─────────────────────────────────────
          _sectionHeader(context, Icons.developer_board, 'Software DIAN',
              subtitle: 'Datos del software registrado ante la DIAN'),
          _field(_softwareOwnerCtrl, 'Nombre del propietario del software', hint: 'ej: Juan Pérez'),
          _row([
            _field(_softwareCompanyCtrl, 'Empresa del software', hint: 'ej: Vercy Motos S.A.S'),
            _field(_softwareNameCtrl, 'Nombre del software', hint: 'ej: Vercy POS'),
          ]),

          const SizedBox(height: 24),

          // ── Botón guardar ──
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _guardar,
              icon: _saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded, color: Colors.white, size: 20),
              label: Text(
                _saving ? 'Guardando...' : 'Guardar configuración',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, IconData icon, String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                )),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
                  )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    String? hint,
    TextInputType keyboard = TextInputType.text,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            fontSize: 12,
          ),
          labelStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            fontSize: 13,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.15)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        validator: required ? (v) => (v?.trim().isEmpty ?? true) ? 'Campo requerido' : null : null,
      ),
    );
  }

  Widget _row(List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children.map((w) => Expanded(child: Padding(
        padding: EdgeInsets.only(right: children.last == w ? 0 : 10),
        child: w,
      ))).toList(),
    ),
  );

  Widget _banner(String msg, Color color, IconData icon) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: TextStyle(color: color, fontSize: 13))),
      ],
    ),
  );
}
