import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/user_provider.dart';
import '../../services/matias_service.dart';
import '../../services/factura_service.dart';
import '../../models/factura.dart';
import '../../widgets/facturizacion/documento_soporte_dialog.dart';
import '../../widgets/facturizacion/nota_credito_debito_dialog.dart';

/// Pantalla central para gestionar documentos electrónicos adicionales:
///   • Documento Soporte
///   • Nómina Electrónica
///   • POS Electrónico (reenvíos)
///
/// Ruta sugerida: /facturacion-electronica
class FEDocumentosScreen extends StatelessWidget {
  const FEDocumentosScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 12 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPageHeader(context),
            const SizedBox(height: 20),
            _buildBandejaPendientes(context),
            const SizedBox(height: 28),
            _buildCards(context),
            const SizedBox(height: 32),
            _buildNominaSection(context),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildPageHeader(BuildContext context) {
    final isMobile = context.isMobile;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.receipt_long, color: AppTheme.primary, size: isMobile ? 24 : 30),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Documentos Electrónicos',
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 26,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Emite y gestiona todos los documentos electrónicos ante la DIAN',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: isMobile ? 12 : 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        _EstadoAuthChip(),
      ],
    );
  }

  Widget _buildBandejaPendientes(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/documentos-pendientes'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primary.withOpacity(0.12),
              AppTheme.secondary.withOpacity(0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.inbox_rounded,
                color: AppTheme.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bandeja de Documentos',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ver documentos pendientes, enviados y rechazados',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: AppTheme.primary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildCards(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final crossCount = constraints.maxWidth > 900
            ? 3
            : (constraints.maxWidth > 600 ? 2 : 1);
        return GridView.count(
          crossAxisCount: crossCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.8,
          children: [
            _DocCard(
              icon: Icons.file_present_rounded,
              titulo: 'Documento Soporte',
              descripcion: 'Compras a proveedores\nno obligados a facturar',
              color: AppTheme.success,
              onTap: () => showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const DocumentoSoporteDialog(),
              ),
              badge: 'DS',
            ),
            _DocCard(
              icon: Icons.edit_document,
              titulo: 'Nota de Ajuste DS',
              descripcion: 'Corregir o anular\nun Documento Soporte',
              color: Colors.amber.shade700,
              onTap: () => _mostrarBuscarDSDialog(context),
              badge: 'NDS',
            ),
            _DocCard(
              icon: Icons.people_alt_outlined,
              titulo: 'Nómina Electrónica',
              descripcion: 'Emitir nómina individual\npor empleado',
              color: AppTheme.secondary,
              onTap: () => _mostrarNominaDialog(context),
              badge: 'NE',
            ),
            _DocCard(
              icon: Icons.point_of_sale,
              titulo: 'POS Electrónico',
              descripcion:
                  'Ve a la lista de documentos\npara facturar pedidos POS',
              color: AppTheme.primary,
              onTap: () => context.push('/facturas'),
              badge: 'POS',
              esNavegacion: true,
            ),
            _DocCard(
              icon: Icons.remove_circle_outline,
              titulo: 'Nota Crédito',
              descripcion: 'Emitir nota crédito\nsobre una factura',
              color: Colors.orange,
              onTap: () => showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    const _BuscarFacturaParaNotaDialog(tipo: TipoNota.credito),
              ),
              badge: 'NC',
            ),
            _DocCard(
              icon: Icons.add_circle_outline,
              titulo: 'Nota Débito',
              descripcion: 'Emitir nota débito\nsobre una factura',
              color: Colors.blue.shade600,
              onTap: () => showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    const _BuscarFacturaParaNotaDialog(tipo: TipoNota.debito),
              ),
              badge: 'ND',
            ),
          ],
        );
      },
    );
  }

  Widget _buildNominaSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people, color: AppTheme.secondary, size: 22),
              const SizedBox(width: 10),
              Text(
                'Nómina Electrónica',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Emite, corrige o elimina nóminas individuales ante la DIAN.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 13),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _AccionBtn(
                label: 'Nueva Nómina',
                icon: Icons.add,
                color: AppTheme.secondary,
                onTap: () => _mostrarNominaDialog(context),
              ),
              _AccionBtn(
                label: 'Reemplazar Nómina',
                icon: Icons.edit,
                color: Colors.amber.shade700,
                onTap: () => _mostrarReemplazoNominaDialog(context),
              ),
              _AccionBtn(
                label: 'Eliminar Nómina',
                icon: Icons.delete_outline,
                color: AppTheme.error,
                onTap: () => _mostrarEliminacionNominaDialog(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  Dialogs auxiliares
  // ──────────────────────────────────────────────────────────────────────────

  void _mostrarBuscarDSDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => _BuscarDSDialog());
  }

  void _mostrarNominaDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _NominaSimpleDialog(modo: _ModoNomina.nueva),
    );
  }

  void _mostrarReemplazoNominaDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _NominaSimpleDialog(modo: _ModoNomina.reemplazar),
    );
  }

  void _mostrarEliminacionNominaDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _NominaSimpleDialog(modo: _ModoNomina.eliminar),
    );
  }
}

// ── Chip de estado de autenticación ──────────────────────────────────────────

class _EstadoAuthChip extends StatefulWidget {
  @override
  State<_EstadoAuthChip> createState() => _EstadoAuthChipState();
}

class _EstadoAuthChipState extends State<_EstadoAuthChip> {
  bool? _autenticado;

  @override
  void initState() {
    super.initState();
    _verificar();
  }

  Future<void> _verificar() async {
    final ok = await MatiasService.checkStatus();
    if (mounted) setState(() => _autenticado = ok);
  }

  Future<void> _autenticar() async {
    setState(() => _autenticado = null);
    await MatiasService.authenticate();
    await _verificar();
  }

  @override
  Widget build(BuildContext context) {
    if (_autenticado == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('Verificando...', style: TextStyle(fontSize: 12)),
          ],
        ),
      );
    }

    final color = _autenticado! ? AppTheme.success : AppTheme.error;
    final label = _autenticado! ? 'Conectado a Matias' : 'Sin conexión';
    final icon = _autenticado!
        ? Icons.cloud_done_outlined
        : Icons.cloud_off_outlined;

    return GestureDetector(
      onTap: _autenticado! ? null : _autenticar,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!_autenticado!) ...[
              const SizedBox(width: 6),
              Text(
                '(Reintentar)',
                style: TextStyle(color: color.withOpacity(0.7), fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Tarjeta de tipo de documento ─────────────────────────────────────────────

class _DocCard extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String descripcion;
  final Color color;
  final VoidCallback onTap;
  final String badge;
  final bool esNavegacion;

  const _DocCard({
    required this.icon,
    required this.titulo,
    required this.descripcion,
    required this.color,
    required this.onTap,
    required this.badge,
    this.esNavegacion = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (esNavegacion) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    size: 12,
                  ),
                ],
              ],
            ),
            const Spacer(),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              descripcion,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Botón de acción ───────────────────────────────────────────────────────────

class _AccionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AccionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ── Dialog auxiliar: buscar DS para ajuste ────────────────────────────────────

class _BuscarDSDialog extends StatefulWidget {
  @override
  State<_BuscarDSDialog> createState() => _BuscarDSDialogState();
}

class _BuscarDSDialogState extends State<_BuscarDSDialog> {
  final _numeroCtrl = TextEditingController();
  final _cudeCtrl = TextEditingController();
  final _fechaCtrl = TextEditingController();
  final _proveedorCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _cudeCtrl.dispose();
    _fechaCtrl.dispose();
    _proveedorCtrl.dispose();
    _totalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(
        children: [
          Icon(Icons.search, color: AppTheme.success),
          const SizedBox(width: 10),
          Text(
            'Datos del Documento Soporte',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 17),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ingresa los datos del DS que deseas ajustar:',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 13),
            ),
            const SizedBox(height: 14),
            _tf(_numeroCtrl, 'Número del DS *'),
            const SizedBox(height: 10),
            _tf(_cudeCtrl, 'CUDE del DS *'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _tf(_fechaCtrl, 'Fecha (YYYY-MM-DD) *')),
                const SizedBox(width: 10),
                Expanded(
                  child: _tf(
                    _totalCtrl,
                    'Total *',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _tf(_proveedorCtrl, 'Nombre del proveedor *'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancelar',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            if (_numeroCtrl.text.isEmpty || _cudeCtrl.text.isEmpty) return;
            final ds = DocumentoSoporteRef(
              numero: _numeroCtrl.text,
              cude: _cudeCtrl.text,
              fecha: _fechaCtrl.text,
              proveedor: _proveedorCtrl.text,
              total: double.tryParse(_totalCtrl.text) ?? 0,
            );
            Navigator.pop(context);
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => DocumentoSoporteDialog(dsExistente: ds),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.success,
          ),
          child: const Text('Continuar', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _tf(
    TextEditingController ctrl,
    String hint, {
    TextInputType? keyboardType,
  }) => TextField(
    controller: ctrl,
    keyboardType: keyboardType,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 13),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
  );
}

// ── Dialog de nómina simple (JSON directo) ────────────────────────────────────

enum _ModoNomina { nueva, reemplazar, eliminar }

class _NominaSimpleDialog extends StatefulWidget {
  final _ModoNomina modo;
  const _NominaSimpleDialog({required this.modo});

  @override
  State<_NominaSimpleDialog> createState() => _NominaSimpleDialogState();
}

class _NominaSimpleDialogState extends State<_NominaSimpleDialog> {
  final _jsonCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _exito;

  @override
  void dispose() {
    _jsonCtrl.dispose();
    super.dispose();
  }

  String get _titulo => switch (widget.modo) {
    _ModoNomina.nueva => 'Nueva Nómina Electrónica',
    _ModoNomina.reemplazar => 'Reemplazar Nómina',
    _ModoNomina.eliminar => 'Eliminar Nómina',
  };

  Color get _color => switch (widget.modo) {
    _ModoNomina.nueva => AppTheme.secondary,
    _ModoNomina.reemplazar => Colors.amber.shade700,
    _ModoNomina.eliminar => AppTheme.error,
  };

  Future<void> _enviar() async {
    setState(() {
      _loading = true;
      _error = null;
      _exito = null;
    });
    try {
      final token = Provider.of<UserProvider>(context, listen: false).token;
      final payload = Map<String, dynamic>.from(
        (jsonDecode(_jsonCtrl.text) as Map<String, dynamic>),
      );

      MatiasDocumentoResult res;
      switch (widget.modo) {
        case _ModoNomina.nueva:
          res = await MatiasService.enviarNomina(payload, token: token);
          break;
        case _ModoNomina.reemplazar:
          res = await MatiasService.reemplazarNomina(payload, token: token);
          break;
        case _ModoNomina.eliminar:
          res = await MatiasService.eliminarNomina(payload, token: token);
          break;
      }

      if (res.success) {
        setState(() => _exito = 'CUNE: ${res.documentKey ?? "N/A"}');
      } else {
        setState(() => _error = res.message);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 580),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.people, color: _color, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    _titulo,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Pega el JSON de la nómina según la estructura de Matias API (ver documentación):',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 13),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: _jsonCtrl,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: '{ "sequence": "1", "employee": { ... }, ... }',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: AppTheme.error, fontSize: 13),
                  ),
                ),
              ],
              if (_exito != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '✅ Enviado. $_exito',
                    style: TextStyle(color: AppTheme.success, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cerrar',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _enviar,
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, size: 16, color: Colors.white),
                    label: Text(
                      _loading ? 'Enviando...' : 'Enviar',
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _color,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dialog para buscar factura y emitir nota crédito/débito ─────────────────

class _BuscarFacturaParaNotaDialog extends StatefulWidget {
  final TipoNota tipo;

  const _BuscarFacturaParaNotaDialog({required this.tipo});

  @override
  State<_BuscarFacturaParaNotaDialog> createState() =>
      _BuscarFacturaParaNotaDialogState();
}

class _BuscarFacturaParaNotaDialogState
    extends State<_BuscarFacturaParaNotaDialog> {
  final _numeroFacturaCtrl = TextEditingController();
  final _cufeCtrl = TextEditingController();
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _numeroFacturaCtrl.dispose();
    _cufeCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscarFactura() async {
    final numero = _numeroFacturaCtrl.text.trim();
    final cufe = _cufeCtrl.text.trim();

    if (numero.isEmpty && cufe.isEmpty) {
      setState(
        () => _error = 'Ingresa al menos el número o CUFE de la factura',
      );
      return;
    }

    setState(() => _searching = true);
    try {
      // Buscar en la lista de facturas
      final facturaService = FacturaService();
      final facturas = await facturaService.getFacturas();

      Factura? facturaEncontrada;

      if (numero.isNotEmpty) {
        facturaEncontrada = facturas.firstWhere(
          (f) => f.numero?.contains(numero) ?? false,
          orElse: () => facturas.firstWhere(
            (f) =>
                (f.numero ?? '').toLowerCase().contains(numero.toLowerCase()),
            orElse: () => throw 'No encontrada',
          ),
        );
      } else if (cufe.isNotEmpty) {
        facturaEncontrada = facturas.firstWhere(
          (f) => f.cufe == cufe,
          orElse: () => throw 'No encontrada por CUFE',
        );
      }

      if (facturaEncontrada == null ||
          facturaEncontrada.cufe == null ||
          facturaEncontrada.cufe!.isEmpty) {
        setState(
          () => _error =
              'La factura no tiene CUFE. Primero debe ser emitida electrónicamente.',
        );
        return;
      }

      if (!mounted) return;
      Navigator.pop(context); // Cerrar este dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => NotaCreditoDebitoDialog(
          factura: facturaEncontrada,
          tipo: widget.tipo,
        ),
      );
    } catch (e) {
      setState(() => _error = 'Factura no encontrada o error: $e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.tipo == TipoNota.credito
        ? Colors.orange
        : Colors.blue.shade600;
    final titulo = widget.tipo == TipoNota.credito
        ? 'Nota Crédito'
        : 'Nota Débito';

    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(
        children: [
          Icon(
            widget.tipo == TipoNota.credito
                ? Icons.remove_circle_outline
                : Icons.add_circle_outline,
            color: color,
          ),
          const SizedBox(width: 10),
          Text(
            titulo,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 17),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Busca la factura sobre la que deseas emitir esta ${widget.tipo == TipoNota.credito ? "nota crédito" : "nota débito"}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _numeroFacturaCtrl,
              enabled: !_searching,
              decoration: InputDecoration(
                labelText: 'Número de factura',
                hintText: 'Ej: FV-001',
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 13,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _cufeCtrl,
              enabled: !_searching,
              decoration: InputDecoration(
                labelText: 'O CUFE de la factura',
                hintText: 'Código único CUFE',
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 13,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: AppTheme.error, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancelar',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _searching ? null : _buscarFactura,
          icon: _searching
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.search, size: 16, color: Colors.white),
          label: Text(
            _searching ? 'Buscando...' : 'Buscar',
            style: const TextStyle(color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}
