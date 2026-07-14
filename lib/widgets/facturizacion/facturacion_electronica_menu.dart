import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/factura.dart';
import '../../models/pedido.dart';
import '../../providers/user_provider.dart';
import '../../services/matias_service.dart';
import '../../services/documento_service.dart';
import '../../services/negocio_info_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/base64_file_launcher.dart';
import '../../utils/logger.dart';
import '../../utils/api_error.dart';
import 'nota_credito_debito_dialog.dart';
import 'documento_soporte_dialog.dart';
import 'confirmacion_dian_dialog.dart';

/// Menú de acciones de facturación electrónica para una fila de documento.
///
/// Muestra un botón "FE ▾" que al presionarlo despliega las opciones
/// disponibles según el tipo y estado del documento.
///
/// Para facturas ya emitidas electrónicamente:
///   - Nota Crédito
///   - Nota Débito
///   - Reenviar (si fue rechazada)
///
/// Para pedidos POS pagados:
///   - Facturar (POS electrónico)
///   - Facturar con Nota Crédito (si ya fue facturado)
class FacturacionElectronicaMenu extends StatefulWidget {
  final dynamic documento; // Factura | Pedido
  final VoidCallback? onRefresh;

  const FacturacionElectronicaMenu({
    Key? key,
    required this.documento,
    this.onRefresh,
  }) : super(key: key);

  @override
  State<FacturacionElectronicaMenu> createState() =>
      _FacturacionElectronicaMenuState();
}

class _FacturacionElectronicaMenuState
    extends State<FacturacionElectronicaMenu> {
  bool _loading = false;

  bool get _esFactura => widget.documento is Factura;
  bool get _esPedido => widget.documento is Pedido;

  Factura? get _factura => _esFactura ? widget.documento as Factura : null;
  Pedido? get _pedido => _esPedido ? widget.documento as Pedido : null;

  /// La factura fue emitida electrónicamente si tiene CUFE o estadoDIAN == 'ACEPTADA'
  bool get _tieneEmisionElectronica =>
      (_factura?.cufe != null && _factura!.cufe!.isNotEmpty) ||
      _factura?.estadoDIAN == 'ACEPTADA';

  // ──────────────────────────────────────────────────────────────────────────
  //  Acciones
  // ──────────────────────────────────────────────────────────────────────────

  void _abrirNotaCredito() {
    if (_factura == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => NotaCreditoDebitoDialog(
        factura: _factura!,
        tipo: TipoNota.credito,
        onSuccess: widget.onRefresh,
      ),
    );
  }

  void _abrirNotaDebito() {
    if (_factura == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => NotaCreditoDebitoDialog(
        factura: _factura!,
        tipo: TipoNota.debito,
        onSuccess: widget.onRefresh,
      ),
    );
  }

  Future<void> _facturarElectronicaNormal() async {
    if (_pedido == null) return;
    setState(() => _loading = true);
    try {
      appLog('📋 [FE] Enviando pedido a DIAN: ${_pedido!.id}');
      final token = Provider.of<UserProvider>(context, listen: false).token;
      
      // Enviar solo el pedidoId, el backend lo resuelve todo
      final payload = {
        'pedidoId': _pedido!.id,
      };
      
      appLog('📋 [FE] Enviando payload: $payload');

      final resultado = await MatiasService.emitirFacturaElectronica(
        payload,
        token: token,
      );
      
      appLog('📋 [FE] Resultado: success=${resultado.success}, message=${resultado.message}');
      
      if (!mounted) return;
      if (resultado.success) {
        final facturacionResult = FacturacionResult(
          success: true,
          message: 'Factura Electrónica emitida exitosamente',
          cufe: resultado.documentKey,
          pdfUrl: resultado.pdfUrl,
          raw: resultado.raw,
        );
        showDialog(
          context: context,
          builder: (_) => ConfirmacionDianDialog(
            resultado: facturacionResult,
            tipoDocumento: 'Factura Electrónica',
            onClose: widget.onRefresh,
          ),
        );
      } else {
        // Mostrar dialog con el error detallado
        _mostrarErrorDialog('Factura Electrónica', resultado.message);
      }
    } catch (e) {
      _mostrarErrorDialog('Error', 'Error al emitir FE: ${errorMessage(e)}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _facturarPOS() async {
    if (_pedido == null) return;
    setState(() => _loading = true);
    try {
      appLog('📋 [POS] Enviando pedido a DIAN: ${_pedido!.id}');
      final token = Provider.of<UserProvider>(context, listen: false).token;

      // Cargar información del negocio para obtener la resolución
      final negocioInfoService = NegocioInfoService();
      final negocioInfo = await negocioInfoService.getNegocioInfo();

      // Enviar solo el pedidoId, el backend lo resuelve todo
      final payload = {
        'pedidoId': _pedido!.id,
      };

      // Agregar resolución si existe
      if (negocioInfo?.resolutionNumber != null &&
          negocioInfo!.resolutionNumber!.isNotEmpty) {
        payload['resolutionNumber'] = negocioInfo!.resolutionNumber!;
      }

      appLog('📋 [POS] Enviando payload: $payload');

      final resultado = await MatiasService.emitirDocumentoPOS(
        payload,
        token: token,
      );
      
      appLog('📋 [POS] Resultado: success=${resultado.success}, message=${resultado.message}');
      
      if (!mounted) return;
      if (resultado.success) {
        // Mostrar dialog de confirmación con QR + CUFE
        final facturacionResult = FacturacionResult(
          success: true,
          message: 'POS facturado exitosamente',
          cufe: resultado.documentKey,
          pdfUrl: resultado.pdfUrl,
          raw: resultado.raw,
        );
        showDialog(
          context: context,
          builder: (_) => ConfirmacionDianDialog(
            resultado: facturacionResult,
            tipoDocumento: 'POS Electrónico',
            onClose: widget.onRefresh,
          ),
        );
      } else {
        _mostrarErrorDialog('POS Electrónico', resultado.message);
      }
    } catch (e) {
      _mostrarErrorDialog('Error', 'Error al emitir POS: ${errorMessage(e)}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _facturarPOSRapido() async {
    if (_pedido == null) return;
    setState(() => _loading = true);
    try {
      appLog('📋 [POS-RÁPIDO] Enviando pedido a DIAN: ${_pedido!.id}');
      final token = Provider.of<UserProvider>(context, listen: false).token;

      // Cargar información del negocio para obtener la resolución
      final negocioInfoService = NegocioInfoService();
      final negocioInfo = await negocioInfoService.getNegocioInfo();

      // Validar que tenemos la información necesaria
      if (negocioInfo?.resolutionNumber == null ||
          negocioInfo!.resolutionNumber!.isEmpty) {
        throw Exception('⚠️ Número de resolución no configurado. Por favor, verifique la configuración del negocio.');
      }

      // Construir documento POS COMPLETO con todos los campos requeridos
      final payload = MatiasService.buildCompletePOSDocument(
        pedido: _pedido!,
        negocioInfo: negocioInfo,
        resolutionNumber: negocioInfo.resolutionNumber!,
        type_document_id: 20,
      );

      appLog('📋 [POS-RÁPIDO] Documento POS construido con ${(_pedido!.items?.length ?? 0)} items');
      appLog('📋 [POS-RÁPIDO] Campos principales: resolution=${payload['resolution_number']}, total=${payload['legal_monetary_totals']['payable_amount']}');

      final resultado = await MatiasService.emitirDocumentoPOS(
        payload,
        token: token,
      );
      
      appLog('📋 [POS-RÁPIDO] Resultado: success=${resultado.success}, message=${resultado.message}');
      
      if (!mounted) return;
      if (resultado.success) {
        final facturacionResult = FacturacionResult(
          success: true,
          message: 'POS rápido emitido',
          cufe: resultado.documentKey,
          pdfUrl: resultado.pdfUrl,
          raw: resultado.raw,
        );
        showDialog(
          context: context,
          builder: (_) => ConfirmacionDianDialog(
            resultado: facturacionResult,
            tipoDocumento: 'POS Rápido',
            onClose: widget.onRefresh,
          ),
        );
      } else {
        _mostrarErrorDialog('POS Rápido', resultado.message);
      }
    } catch (e) {
      _mostrarErrorDialog('Error', errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reenviarDocumento() async {
    // Para facturas rechazadas — intenta reenviar como auto-increment invoice
    if (_factura == null) return;
    final uuid = _factura!.uuid ?? _factura!.id;
    if (uuid == null) {
      _snack('UUID no disponible', AppTheme.warning);
      return;
    }

    setState(() => _loading = true);
    try {
      final token = Provider.of<UserProvider>(context, listen: false).token;
      final resultado = await MatiasService.reenviarDocumentoAutoIncrement(
        'invoices',
        uuid,
        token: token,
      );
      if (!mounted) return;
      if (resultado.success) {
        _snack('✅ Documento reenviado correctamente', AppTheme.success);
        widget.onRefresh?.call();
      } else {
        _mostrarErrorDialog('Reenviar Documento', resultado.message);
      }
    } catch (e) {
      _mostrarErrorDialog('Error', errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _mostrarErrorDialog(String titulo, String mensaje) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('❌ $titulo'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                mensaje,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  Build
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    // ── Pedido ──
    if (_esPedido) {
      // LOCAL: solo documento interno, sin opciones FE
      if (_pedido?.tipoFactura == 'LOCAL') {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_outlined, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), size: 13),
              const SizedBox(width: 5),
              Text(
                'Local',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }

      // POS y FACTURA ELECTRÓNICA: mostrar opciones FE
      return _BotonFE(
        label: 'Facturar',
        color: AppTheme.primary,
        icon: Icons.receipt_long,
        items: [
          _MenuItem(
            icon: Icons.receipt,
            label: 'Emitir Factura Electrónica',
            color: AppTheme.success,
            onTap: _facturarElectronicaNormal,
          ),
          _MenuItem(
            icon: Icons.point_of_sale,
            label: 'Emitir POS Electrónico',
            color: AppTheme.primary,
            onTap: _facturarPOS,
          ),
          _MenuItem(
            icon: Icons.flash_on_rounded,
            label: 'POS Rápido (sin cliente)',
            color: Colors.teal,
            onTap: _facturarPOSRapido,
          ),
        ],
      );
    }

    // ── Factura electrónica ──
    if (_esFactura) {
      return _BotonFE(
        label: 'FE',
        color: AppTheme.secondary,
        icon: Icons.more_horiz,
        items: [
          if (_tieneEmisionElectronica) ...[
            _MenuItem(
              icon: Icons.remove_circle_outline,
              label: 'Nota Crédito',
              color: Colors.orange,
              onTap: _abrirNotaCredito,
            ),
            _MenuItem(
              icon: Icons.add_circle_outline,
              label: 'Nota Débito',
              color: Colors.blue.shade600,
              onTap: _abrirNotaDebito,
            ),
          ],
          if (_factura?.estadoDIAN == 'RECHAZADA')
            _MenuItem(
              icon: Icons.refresh,
              label: 'Reenviar a DIAN',
              color: AppTheme.warning,
              onTap: _reenviarDocumento,
            ),
          if (!_tieneEmisionElectronica)
            _MenuItem(
              icon: Icons.send,
              label: 'Emitir Factura Electrónica',
              color: AppTheme.success,
              onTap: () => _snack(
                'Usa el botón Facturar desde la pantalla de Pedidos',
                AppTheme.info,
              ),
            ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}

// ── Widget auxiliar: botón con popup ──────────────────────────────────────────

class _MenuItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class _BotonFE extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final List<_MenuItem> items;

  const _BotonFE({
    required this.label,
    required this.color,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<int>(
      tooltip: 'Opciones de Facturación Electrónica',
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      offset: const Offset(0, 36),
      onSelected: (i) => items[i].onTap(),
      itemBuilder: (_) => items.asMap().entries.map((e) {
        final item = e.value;
        return PopupMenuItem<int>(
          value: e.key,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(item.icon, color: item.color, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                item.label,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              ),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.arrow_drop_down, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
//  Menú adicional: acciones sobre el documento ya emitido en Matias
//  (Descargar PDF DIAN, Reenviar correo, Reenviar a DIAN si rechazado)
// ────────────────────────────────────────────────────────────────────────────

class AccionesMatiasMenu extends StatefulWidget {
  final dynamic documento; // Factura | Pedido
  final VoidCallback? onRefresh;

  const AccionesMatiasMenu({
    Key? key,
    required this.documento,
    this.onRefresh,
  }) : super(key: key);

  @override
  State<AccionesMatiasMenu> createState() => _AccionesMatiasMenuState();
}

class _AccionesMatiasMenuState extends State<AccionesMatiasMenu> {
  bool _loading = false;

  /// Cache del DocumentoFE resuelto (solo para Pedidos POS): se cachea para
  /// evitar consultar el backend en cada acción del mismo menú.
  DocumentoFE? _documentoPedido;
  bool _documentoPedidoCargado = false;

  Factura? get _factura =>
      widget.documento is Factura ? widget.documento as Factura : null;

  Pedido? get _pedido =>
      widget.documento is Pedido ? widget.documento as Pedido : null;

  bool get _esFactura => _factura != null;
  bool get _esPedido => _pedido != null;

  /// trackId resuelto para llamar al backend de Matías.
  /// Prioriza XmlDocumentKey (lo que el endpoint de PDF exige) y cae a CUFE
  /// y luego a trackId como respaldo.
  String? get _trackId {
    if (_factura != null) {
      final xml = _factura!.xmlDocumentKey;
      if (xml != null && xml.isNotEmpty) return xml;
      if (_factura!.cufe?.isNotEmpty == true) return _factura!.cufe;
      return _factura!.trackId;
    }
    return _documentoPedido?.pdfTrackId;
  }

  String? get _uuid {
    if (_factura != null) {
      final u = _factura!.uuid;
      if (u != null && u.isNotEmpty) return u;
      return _factura!.id;
    }
    return _documentoPedido?.id;
  }

  bool get _rechazada {
    if (_factura != null) return _factura!.estadoDIAN == 'RECHAZADA';
    return _documentoPedido?.esRechazado ?? false;
  }

  String? get _correoCliente {
    if (_factura != null) return _factura!.clienteCorreo;
    return null;
  }

  /// Resuelve el DocumentoFE del Pedido (con CUFE) bajo demanda.
  /// Retorna true si después de la llamada hay un trackId disponible.
  Future<bool> _asegurarDocumentoPedido() async {
    if (_factura != null) return _trackId != null && _trackId!.isNotEmpty;
    if (_pedido == null) return false;
    if (_documentoPedidoCargado) {
      return _documentoPedido?.cufe != null && _documentoPedido!.cufe!.isNotEmpty;
    }

    setState(() => _loading = true);
    try {
      final doc = await DocumentoService().getDocumentoPorPedidoId(_pedido!.id);
      if (!mounted) return false;
      setState(() {
        _documentoPedido = doc;
        _documentoPedidoCargado = true;
      });
      return doc?.cufe != null && doc!.cufe!.isNotEmpty;
    } catch (e) {
      appLog('❌ _asegurarDocumentoPedido: $e');
      return false;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verPDFMatias() async {
    final hayTrack = await _asegurarDocumentoPedido();
    final track = _trackId;
    if (!hayTrack || track == null || track.isEmpty) {
      _snack('Este documento no se ha emitido a DIAN aún', AppTheme.warning);
      return;
    }
    setState(() => _loading = true);
    try {
      final token = Provider.of<UserProvider>(context, listen: false).token;

      // 1) Intentar URL directa de Matias (más fiable que el binario base64).
      final url = await MatiasService.obtenerURLPDF(track, token: token);
      if (!mounted) return;
      if (url != null && url.isNotEmpty) {
        final ok = await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
        if (!ok) _mostrarErrorDialog('Descargar PDF', 'No se pudo abrir el PDF.');
        return;
      }

      // 2) Fallback: descargar binario base64 desde el backend.
      final res = await MatiasService.descargarPDF(track, token: token);
      if (!mounted) return;
      if (res == null) {
        _mostrarErrorDialog('Descargar PDF',
            'PDF no disponible. El documento debe estar ACEPTADO por la DIAN.');
        return;
      }
      final ok = await Base64FileLauncher.open(
        base64: res['base64']!,
        mimeType: res['mimeType']!,
      );
      if (!ok) _mostrarErrorDialog('Descargar PDF', 'No se pudo abrir el PDF.');
    } catch (e) {
      _mostrarErrorDialog('Descargar PDF', errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reenviarCorreo() async {
    final hayTrack = await _asegurarDocumentoPedido();
    final track = _trackId;
    if (!hayTrack || track == null || track.isEmpty) {
      _snack('Este documento no se ha emitido a DIAN aún', AppTheme.warning);
      return;
    }

    final defaultEmail = _correoCliente ?? '';
    final emailCtrl = TextEditingController(text: defaultEmail);
    final formKey = GlobalKey<FormState>();

    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reenviar correo'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Se enviará la factura electrónica al correo indicado.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailCtrl,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo del cliente',
                  hintText: 'cliente@ejemplo.com',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Correo requerido';
                  final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                  if (!regex.hasMatch(v.trim())) return 'Correo no válido';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.send),
            label: const Text('Reenviar'),
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.of(ctx).pop(emailCtrl.text.trim());
              }
            },
          ),
        ],
      ),
    );

    if (email == null) return;
    if (!mounted) return;

    setState(() => _loading = true);
    try {
      final token = Provider.of<UserProvider>(context, listen: false).token;
      final res = await MatiasService.reenviarCorreoFactura(
        track,
        email,
        token: token,
      );
      if (!mounted) return;
      if (res.success) {
        _snack('✉️ Correo reenviado a $email', AppTheme.success);
      } else {
        _mostrarErrorDialog('Reenviar correo', res.message);
      }
    } catch (e) {
      _mostrarErrorDialog('Reenviar correo', errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reenviarDIAN() async {
    await _asegurarDocumentoPedido();
    final uuid = _uuid;
    if (uuid == null || uuid.isEmpty) {
      _snack('UUID no disponible', AppTheme.warning);
      return;
    }
    final esPOS = _esPedido && _pedido?.tipoFactura == 'POS';
    setState(() => _loading = true);
    try {
      final token = Provider.of<UserProvider>(context, listen: false).token;
      // POS tiene endpoint propio: PATCH /api/matias/pos/documents/{uuid}/resend
      // El resto pasa por: PATCH /api/matias/auto-increment/{tipo}/{uuid}
      final res = esPOS
          ? await MatiasService.reenviarPOS(uuid, token: token)
          : await MatiasService.reenviarDocumentoAutoIncrement(
              'invoices',
              uuid,
              token: token,
            );
      if (!mounted) return;
      if (res.success) {
        _snack('🔁 Documento reenviado a DIAN', AppTheme.success);
        widget.onRefresh?.call();
      } else {
        _mostrarErrorDialog('Reenviar a DIAN', res.message);
      }
    } catch (e) {
      _mostrarErrorDialog('Reenviar a DIAN', errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copiarCUFE() async {
    await _asegurarDocumentoPedido();
    final cufe = _trackId;
    if (cufe == null || cufe.isEmpty) {
      _snack('No hay CUFE disponible', AppTheme.warning);
      return;
    }
    await Clipboard.setData(ClipboardData(text: cufe));
    if (!mounted) return;
    _snack('📋 CUFE copiado al portapapeles', AppTheme.info);
  }

  Future<void> _consultarEstado() async {
    final hayTrack = await _asegurarDocumentoPedido();
    final track = _trackId;
    if (!hayTrack || track == null || track.isEmpty) {
      _snack('Este documento no se ha emitido a DIAN aún', AppTheme.warning);
      return;
    }
    setState(() => _loading = true);
    try {
      final estado = await MatiasService.consultarStatusDIAN(track);
      if (!mounted) return;
      if (estado == null) {
        _mostrarErrorDialog('Consultar estado', 'No se pudo consultar el estado.');
        return;
      }
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('📋 Estado DIAN'),
          content: SingleChildScrollView(
            child: Text(
              estado.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      _mostrarErrorDialog('Consultar estado', errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _mostrarErrorDialog(String titulo, String mensaje) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('❌ $titulo'),
        content: SingleChildScrollView(
          child: Text(mensaje, style: const TextStyle(fontSize: 13)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Aplica a Facturas y a Pedidos POS / Electrónica.
    if (!_esFactura && !_esPedido) return const SizedBox.shrink();

    // No mostrar para Pedidos LOCAL (no van a DIAN).
    if (_esPedido && _pedido!.tipoFactura == 'LOCAL') {
      return const SizedBox.shrink();
    }

    if (_loading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    // Para Factura sabemos sin consulta si tiene CUFE.
    // Para Pedido, al ser bajo demanda, asumimos posible y resolvemos al pulsar.
    final tieneTrackConocido = _esFactura
        ? (_trackId != null && _trackId!.isNotEmpty)
        : (_documentoPedidoCargado &&
            _documentoPedido?.cufe != null &&
            _documentoPedido!.cufe!.isNotEmpty);
    final puedeIntentar = tieneTrackConocido || _esPedido; // Pedido se resuelve al hacer click
    final color = puedeIntentar ? AppTheme.info : AppTheme.metal;

    return _BotonFE(
      label: 'Acciones',
      color: color,
      icon: Icons.cloud_done_outlined,
      items: [
        _MenuItem(
          icon: Icons.picture_as_pdf,
          label: 'Descargar PDF (DIAN)',
          color: Colors.red.shade400,
          onTap: _verPDFMatias,
        ),
        _MenuItem(
          icon: Icons.forward_to_inbox,
          label: 'Reenviar al correo',
          color: AppTheme.primary,
          onTap: _reenviarCorreo,
        ),
        _MenuItem(
          icon: Icons.fact_check_outlined,
          label: 'Consultar estado DIAN',
          color: AppTheme.success,
          onTap: _consultarEstado,
        ),
        if (_rechazada)
          _MenuItem(
            icon: Icons.refresh,
            label: 'Reenviar a DIAN',
            color: AppTheme.warning,
            onTap: _reenviarDIAN,
          ),
        _MenuItem(
          icon: Icons.content_copy,
          label: 'Copiar CUFE',
          color: AppTheme.secondary,
          onTap: _copiarCUFE,
        ),
      ],
    );
  }
}
