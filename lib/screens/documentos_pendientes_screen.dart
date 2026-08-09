import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../config/constants.dart';
import '../services/documento_service.dart';
import '../services/matias_service.dart';
import '../services/matias_webhook_service.dart';
import '../models/matias_webhook_event.dart';
import '../widgets/facturizacion/confirmacion_dian_dialog.dart';
import '../widgets/facturizacion/nota_credito_debito_dialog.dart';
import '../utils/base64_file_launcher.dart';
import '../utils/logger.dart';
import '../utils/api_error.dart';
import '../utils/currency_utils.dart';
import '../utils/dialogs_helper.dart';

/// Pantalla "Bandeja de Documentos Electrónicos"
///
/// Muestra documentos en estados:
///   RECHAZADO → con botón "Reintentar"
///   PENDIENTE → con botón "Enviar a DIAN"
///   ENVIADO   → en proceso
///   ACEPTADO  → con CUFE (informativo)
///
/// Ruta: /documentos-pendientes
class DocumentosPendientesScreen extends StatefulWidget {
  const DocumentosPendientesScreen({Key? key}) : super(key: key);

  @override
  State<DocumentosPendientesScreen> createState() =>
      _DocumentosPendientesScreenState();
}

class _DocumentosPendientesScreenState
    extends State<DocumentosPendientesScreen> {
  final DocumentoService _documentoService = DocumentoService();
  final MatiasWebhookService _webhookService = MatiasWebhookService();
  final ScrollController _scrollController = ScrollController();
  List<DocumentoFE> _documentos = [];
  bool _isLoading = false;
  String _filtroEstado = ''; // '' = todos
  int _paginaActual = 0;
  static const int _porPagina = 20;

  @override
  void initState() {
    super.initState();
    _cargarDocumentos();
    _setupWebhookListener();
  }

  /// Configura la escucha de eventos WebSocket
  void _setupWebhookListener() async {
    try {
      final String backendUrl = kDynamicBackendUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');

      await _webhookService.connect(
        baseUrl: backendUrl,
        onEvent: _handleWebhookEvent,
        onConnectionStatusChanged: (isConnected) {
          if (mounted) {
            setState(() {});
            if (isConnected) {
              appLog('✅ WebSocket de webhooks conectado');
            } else {
              appLog('⚠️ WebSocket desconectado');
            }
          }
        },
      );
    } catch (e) {
      appLog('❌ Error conectando a webhooks: $e');
    }
  }

  /// Procesa eventos que llegan por WebSocket
  void _handleWebhookEvent(MatiasWebhookEvent evento) {
    if (mounted) {
      _procesarEventoPorTipo(evento);
    }
  }

  /// Lógica específica para cada tipo de evento
  void _procesarEventoPorTipo(MatiasWebhookEvent evento) {
    switch (evento.event) {
      case 'document.created':
        appLog('📄 Documento creado: ${evento.data?.documentNumber}');
        _mostrarExito('📄 Factura creada #${evento.data?.documentNumber}');
        _cargarDocumentos(); // Recargar lista
        break;

      case 'document.accepted':
        appLog('✅ Documento aceptado por DIAN');
        _mostrarExito(
          '✅ Factura aceptada por DIAN #${evento.data?.documentNumber}',
        );
        _cargarDocumentos();
        break;

      case 'document.rejected':
        appLog('❌ Documento rechazado');
        _mostrarError(
          '❌ Factura rechazada: ${evento.data?.message ?? "Error"}',
        );
        _cargarDocumentos();
        break;

      case 'email.sent':
        appLog('📧 Email enviado a: ${evento.data?.recipient}');
        _mostrarExito('📧 Email enviado a ${evento.data?.recipient}');
        break;

      case 'payment.approved':
        appLog('💰 Pago aprobado por \$${evento.data?.amount}');
        _mostrarExito(
          '💰 Pago aprobado ${evento.data?.amount == null ? '' : CurrencyUtils.format(evento.data!.amount!)}',
        );
        break;

      case 'payment.declined':
        appLog('⚠️ Pago rechazado');
        _mostrarError('⚠️ Pago rechazado: Intenta con otro método');
        break;

      case 'quota.limit_reached':
        appLog('⚠️ Cuota al 80%');
        _mostrarError(
          '⚠️ Cuota al 80%: ${evento.data?.quotaUsed}/${evento.data?.quotaLimit}',
        );
        break;

      default:
        appLog('🔔 Evento recibido: ${evento.event}');
    }
  }

  Future<void> _cargarDocumentos() async {
    setState(() => _isLoading = true);
    try {
      final docs = await _documentoService.getDocumentos();
      if (mounted) {
        setState(() {
          _documentos = docs;
          _paginaActual = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, 'Error al cargar: ${errorMessage(e)}');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<DocumentoFE> get _documentosFiltrados {
    if (_filtroEstado.isEmpty) return _documentos;
    return _documentos.where((d) => d.estado == _filtroEstado).toList();
  }

  int get _totalPaginas =>
      (_documentosFiltrados.length / _porPagina).ceil().clamp(1, 999999);

  List<DocumentoFE> get _documentosPaginados {
    final inicio = _paginaActual * _porPagina;
    if (inicio >= _documentosFiltrados.length) return const [];
    final fin = (inicio + _porPagina).clamp(0, _documentosFiltrados.length);
    return _documentosFiltrados.sublist(inicio, fin);
  }

  void _cambiarFiltro(String valor) {
    setState(() {
      _filtroEstado = valor;
      _paginaActual = 0;
    });
  }

  void _cambiarPagina(int delta) {
    final nueva = _paginaActual + delta;
    if (nueva < 0 || nueva >= _totalPaginas) return;
    setState(() => _paginaActual = nueva);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _webhookService.disconnect();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Acciones ───────────────────────────────────────────────────────────────

  Future<void> _facturarDocumento(DocumentoFE doc) async {
    setState(() => _isLoading = true);
    try {
      final resultado = await _documentoService.facturarDocumento(doc.id);
      if (!mounted) return;

      if (resultado.success) {
        showDialog(
          context: context,
          builder: (_) => ConfirmacionDianDialog(
            resultado: resultado,
            tipoDocumento: doc.tipoDocumento ?? 'Factura',
            onClose: _cargarDocumentos,
          ),
        );
      } else {
        showErrorDialog(context, resultado.message);
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, errorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reenviarDocumento(DocumentoFE doc) async {
    setState(() => _isLoading = true);
    try {
      final uuid = doc.raw?['uuid']?.toString() ?? doc.id;
      final tipoDoc = doc.tipoDocumento?.toLowerCase() ?? 'invoices';
      final esPOS = tipoDoc == 'pos';

      MatiasDocumentoResult resultado;
      if (esPOS) {
        // POS usa endpoint dedicado: PATCH /api/matias/pos/documents/{uuid}/resend
        resultado = await MatiasService.reenviarPOS(uuid);
      } else {
        final tipo = switch (tipoDoc) {
          'nota_credito' || 'nota credito' => 'credit-notes',
          'nota_debito' || 'nota debito' => 'debit-notes',
          'documento_soporte' => 'support-documents',
          'nota_ajuste' => 'adjustment-notes',
          _ => 'invoices',
        };
        resultado = await MatiasService.reenviarDocumentoAutoIncrement(tipo, uuid);
      }

      if (!mounted) return;

      if (resultado.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Documento reenviado. CUFE: ${resultado.documentKey ?? "Procesando"}',
            ),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 4),
          ),
        );
        _cargarDocumentos();
      } else {
        // Si falla auto-increment, intentar reenvío genérico
        final resGen = await _documentoService.reenviarDocumento(uuid);
        if (!mounted) return;
        if (resGen.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Reenviado. CUFE: ${resGen.cufe ?? "Procesando"}',
              ),
              backgroundColor: AppTheme.success,
            ),
          );
          _cargarDocumentos();
        } else {
          showErrorDialog(context, resGen.message);
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, errorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Descargas y consultas ─────────────────────────────────────────────────

  Future<void> _descargarPDF(DocumentoFE doc) async {
    setState(() => _isLoading = true);
    try {
      // doc.id es el id numérico INTERNO de Matias (viene del listado
      // GET /api/matias/documentos), no nuestro _id de Mongo — llamar a
      // getDocumentoPorId(doc.id) siempre daba 404 contra /local/documentos/{id}.
      // El listado ya trae el CUFE/XmlDocumentKey real en doc.cufe/doc.xmlDocumentKey,
      // así que no hace falta esa consulta extra.
      final trackId = doc.pdfTrackId;
      if (trackId == null || trackId.isEmpty) {
        if (mounted) _mostrarError('No se puede descargar: documento sin XmlDocumentKey ni CUFE');
        return;
      }
      appLog('📥 Descargando PDF con XmlDocumentKey: $trackId');
      final res = await MatiasService.descargarPDF(trackId);
      if (!mounted) return;
      if (res != null) {
        final url = res['url'];
        final base64 = res['base64'];
        if (url != null && url.isNotEmpty) {
          final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          if (!ok && mounted) _mostrarError('No se pudo abrir el PDF.');
          return;
        }
        if (base64 != null && base64.isNotEmpty) {
          final ok = await Base64FileLauncher.open(
            base64: base64,
            mimeType: res['mimeType'] ?? 'application/pdf',
          );
          if (!ok && mounted) _mostrarError('No se pudo abrir el PDF.');
          return;
        }
      }

      if (mounted) {
        _mostrarError(
          'PDF no disponible: Matias lo elimina por mantenimiento diario (4am) y '
          'no se pudo regenerar. Intenta de nuevo en unos minutos.',
        );
      }
    } catch (e) {
      if (mounted) _mostrarError('Error al descargar PDF: ${errorMessage(e)}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reenviarCorreo(DocumentoFE doc) async {
    final cufe = doc.cufe;
    if (cufe == null || cufe.isEmpty) {
      _mostrarError('No se puede reenviar: Documento sin CUFE');
      return;
    }

    final emailCtrl = TextEditingController();
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
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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

    if (email == null || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final res = await MatiasService.reenviarCorreoFactura(cufe, email);
      if (!mounted) return;
      if (res.success) {
        _mostrarExito('✉️ Correo reenviado a $email');
      } else {
        _mostrarError('Reenviar correo: ${res.message}');
      }
    } catch (e) {
      if (mounted) _mostrarError('Error: ${errorMessage(e)}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _descargarQR(DocumentoFE doc) async {
    final cufe = doc.cufe;
    if (cufe == null || cufe.isEmpty) {
      _mostrarError('No se puede descargar: Documento sin CUFE');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // El QR viene en /document-pdf/{trackId}.data.qr.url
      final url = await MatiasService.obtenerQRDocumento(cufe);
      if (!mounted) return;

      if (url == null || url.isEmpty) {
        _mostrarError('No se pudo obtener el QR. ¿El documento está ACEPTADO?');
        return;
      }
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && mounted) _mostrarError('No se pudo abrir el QR. URL: $url');
    } catch (e) {
      if (mounted) _mostrarError('Error al obtener el QR: ${errorMessage(e)}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _descargarXML(DocumentoFE doc) async {
    final cufe = doc.cufe;
    if (cufe == null || cufe.isEmpty) {
      _mostrarError('No se puede descargar: Documento sin CUFE');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await MatiasService.descargarXML(cufe);
      if (!mounted) return;
      if (res == null) {
        _mostrarError('XML no disponible. El documento debe estar ACEPTADO por la DIAN.');
        return;
      }
      // Forzamos descarga con nombre — los navegadores no muestran XML inline.
      final ok = await Base64FileLauncher.open(
        base64: res['base64']!,
        mimeType: res['mimeType']!,
        filename: '${doc.numero ?? cufe}.xml',
      );
      if (!ok && mounted) _mostrarError('No se pudo abrir el XML.');
    } catch (e) {
      if (mounted) _mostrarError('Error al obtener el XML: ${errorMessage(e)}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _crearNotaCredito(DocumentoFE doc) async {
    if (doc.cufe == null) {
      _mostrarError('No se puede crear nota: Documento sin CUFE');
      return;
    }

    showDialog(
      context: context,
      builder: (_) => NotaCreditoDebitoDialog(
        facturaNumero: doc.numero ?? doc.id,
        facturaCufe: doc.cufe!,
        facturaXmlKey: doc.xmlDocumentKey,
        facturaFecha:
            doc.fechaCreacion?.toIso8601String().split('T')[0] ??
            DateTime.now().toIso8601String().split('T')[0],
        tipoNota: 'credito',
        onSuccess: _cargarDocumentos,
      ),
    );
  }

  Future<void> _crearNotaDebito(DocumentoFE doc) async {
    if (doc.cufe == null) {
      _mostrarError('No se puede crear nota: Documento sin CUFE');
      return;
    }

    showDialog(
      context: context,
      builder: (_) => NotaCreditoDebitoDialog(
        facturaNumero: doc.numero ?? doc.id,
        facturaCufe: doc.cufe!,
        facturaXmlKey: doc.xmlDocumentKey,
        facturaFecha:
            doc.fechaCreacion?.toIso8601String().split('T')[0] ??
            DateTime.now().toIso8601String().split('T')[0],
        tipoNota: 'debito',
        onSuccess: _cargarDocumentos,
      ),
    );
  }

  Future<void> _consultarStatusDIAN(DocumentoFE doc) async {
    final cufe = doc.cufe;
    if (cufe == null) {
      _mostrarError('No se puede consultar: Documento sin CUFE');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final status = await MatiasService.consultarStatusDIAN(cufe);
      if (!mounted) return;

      if (status != null) {
        _mostrarStatusDialog(cufe, status);
      } else {
        _mostrarError('No se pudo consultar el status');
      }
    } catch (e) {
      if (mounted) _mostrarError('Error al consultar status: ${errorMessage(e)}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarStatusDialog(String cufe, Map<String, dynamic> status) {
    // Estructura backend (MatiasDocumentStatus):
    //   { status, message, success, document: { uuid, document_number, order_number,
    //     document_key, document_name, is_valid, invoice_date, qr } }
    final document = status['document'] as Map<String, dynamic>?;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Estado en DIAN'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusField('CUFE', cufe),
              _buildStatusField('Estado', status['status']?.toString() ?? 'N/A'),
              _buildStatusField('Mensaje', status['message']?.toString() ?? 'N/A'),
              if (document != null) ...[
                if (document['document_number'] != null)
                  _buildStatusField('N° Documento', document['document_number'].toString()),
                if (document['document_name'] != null)
                  _buildStatusField('Tipo', document['document_name'].toString()),
                if (document['is_valid'] != null)
                  _buildStatusField('Válido', document['is_valid'].toString()),
                if (document['invoice_date'] != null)
                  _buildStatusField('Fecha emisión', document['invoice_date'].toString()),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          SizedBox(height: 4),
          SelectableText(
            value,
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    showErrorDialog(context, mensaje);
  }

  void _mostrarExito(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: AppTheme.success),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            _buildHeader(),
            _buildEstadoFiltros(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _documentosFiltrados.isEmpty
                  ? _buildEmpty()
                  : _buildLista(),
            ),
            if (!_isLoading && _documentosFiltrados.isNotEmpty)
              _buildPaginacion(),
          ],
        ),
      );
  }

  Widget _buildPaginacion() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_documentosFiltrados.length} documento${_documentosFiltrados.length == 1 ? '' : 's'}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _paginaActual > 0 ? () => _cambiarPagina(-1) : null,
              ),
              Text(
                'Página ${_paginaActual + 1} de $_totalPaginas',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _paginaActual < _totalPaginas - 1
                    ? () => _cambiarPagina(1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final totalPendientes = _documentos.where((d) => d.esPendiente).length;
    final totalRechazados = _documentos.where((d) => d.esRechazado).length;
    final isMobile = context.isMobile;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: isMobile ? 12 : 18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.inbox_rounded, color: AppTheme.primary, size: isMobile ? 22 : 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isMobile ? 'Bandeja DIAN' : 'Bandeja de Documentos Electrónicos',
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '$totalPendientes pendientes · $totalRechazados rechazados',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _webhookService.isConnected
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _webhookService.isConnected
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _webhookService.isConnected ? '🔌 En línea' : '⚠️ Desconectado',
                            style: TextStyle(
                              color: _webhookService.isConnected ? Colors.green : Colors.orange,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _cargarDocumentos,
            icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
            label: Text(
              isMobile ? '' : 'Actualizar',
              style: const TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: isMobile ? 10 : 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoFiltros() {
    final estados = [
      ('', 'Todos', AppTheme.primary, _documentos.length),
      (
        'RECHAZADO',
        'Rechazados',
        AppTheme.error,
        _documentos.where((d) => d.esRechazado).length,
      ),
      (
        'PENDIENTE',
        'Pendientes',
        AppTheme.warning,
        _documentos.where((d) => d.esPendiente).length,
      ),
      (
        'ENVIADO',
        'Enviados',
        Colors.blue,
        _documentos.where((d) => d.esEnviado).length,
      ),
      (
        'ACEPTADO',
        'Aceptados',
        AppTheme.success,
        _documentos.where((d) => d.esAceptado).length,
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
        children: estados.map((e) {
          final (valor, label, color, count) = e;
          final activo = _filtroEstado == valor;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: activo,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: activo
                          ? Colors.white.withValues(alpha: 0.3)
                          : color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: activo ? Colors.white : color,
                      ),
                    ),
                  ),
                ],
              ),
              selectedColor: color,
              backgroundColor: Theme.of(context).colorScheme.surface,
              labelStyle: TextStyle(
                color: activo ? Colors.white : Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
              ),
              side: BorderSide(color: activo ? color : Colors.grey.shade300),
              onSelected: (_) => _cambiarFiltro(valor),
            ),
          );
        }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: AppTheme.success.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _filtroEstado.isEmpty
                ? 'No hay documentos en la bandeja'
                : 'No hay documentos ${_filtroEstado.toLowerCase()}s',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Los documentos aparecerán aquí cuando se cobre un pedido',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7).withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLista() {
    final documentosPagina = _documentosPaginados;
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(24),
        itemCount: documentosPagina.length,
        itemBuilder: (context, index) {
          return _DocumentoCard(
            documento: documentosPagina[index],
            onFacturar: _facturarDocumento,
            onReenviar: _reenviarDocumento,
            onDescargarPDF: _descargarPDF,
            onDescargarQR: _descargarQR,
            onDescargarXML: _descargarXML,
            onConsultarStatus: _consultarStatusDIAN,
            onCrearNotaCredito: _crearNotaCredito,
            onCrearNotaDebito: _crearNotaDebito,
            onReenviarCorreo: _reenviarCorreo,
          );
        },
      ),
    );
  }
}

// ── Card de documento ────────────────────────────────────────────────────────

class _DocumentoCard extends StatelessWidget {
  final DocumentoFE documento;
  final Future<void> Function(DocumentoFE) onFacturar;
  final Future<void> Function(DocumentoFE) onReenviar;
  final Future<void> Function(DocumentoFE) onDescargarPDF;
  final Future<void> Function(DocumentoFE) onDescargarQR;
  final Future<void> Function(DocumentoFE) onDescargarXML;
  final Future<void> Function(DocumentoFE) onConsultarStatus;
  final Future<void> Function(DocumentoFE) onCrearNotaCredito;
  final Future<void> Function(DocumentoFE) onCrearNotaDebito;
  final Future<void> Function(DocumentoFE) onReenviarCorreo;

  const _DocumentoCard({
    required this.documento,
    required this.onFacturar,
    required this.onReenviar,
    required this.onDescargarPDF,
    required this.onDescargarQR,
    required this.onDescargarXML,
    required this.onConsultarStatus,
    required this.onCrearNotaCredito,
    required this.onCrearNotaDebito,
    required this.onReenviarCorreo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor.withValues(alpha: 0.3)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          // ── Indicador de estado ──
          Container(
            width: 4,
            height: 60,
            decoration: BoxDecoration(
              color: _estadoColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 16),
          // ── Info principal ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _EstadoBadge(estado: documento.estado, color: _estadoColor),
                    const SizedBox(width: 8),
                    if (documento.tipoDocumento != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          documento.tipoDocumento!,
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      documento.numero ??
                          (documento.id.length >= 8
                              ? documento.id.substring(0, 8).toUpperCase()
                              : documento.id.toUpperCase()),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        documento.clienteNombre ?? 'CONSUMIDOR FINAL',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      CurrencyUtils.format(documento.total),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (documento.fechaCreacion != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatFecha(documento.fechaCreacion!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
                if (documento.esRechazado &&
                    documento.motivoRechazo != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: AppTheme.error,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            documento.motivoRechazo!,
                            style: TextStyle(
                              color: AppTheme.error,
                              fontSize: 11,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (documento.tieneCufe) ...[
                  const SizedBox(height: 6),
                  Text(
                    'CUFE: ${documento.cufe!.substring(0, documento.cufe!.length.clamp(0, 30))}...',
                    style: TextStyle(
                      color: AppTheme.success,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // ── Botón de acción ──
          _buildAccion(context),
        ],
      ),
    );
  }

  Widget _buildAccion(BuildContext context) {
    if (documento.esPendiente) {
      return _AccionButton(
        label: 'Enviar a DIAN',
        icon: Icons.send,
        color: AppTheme.primary,
        onTap: () => onFacturar(documento),
      );
    }
    if (documento.esRechazado) {
      return _AccionButton(
        label: 'Reintentar',
        icon: Icons.refresh,
        color: AppTheme.warning,
        onTap: () => onReenviar(documento),
      );
    }
    if (documento.esEnviado) {
      // Si ya tiene CUFE el documento fue aceptado por la DIAN aunque el
      // backend no haya actualizado el estado todavía.
      if (documento.tieneCufe) {
        return _MenuDescargas(
          documento: documento,
          onDescargarPDF: () => onDescargarPDF(documento),
          onDescargarQR: () => onDescargarQR(documento),
          onDescargarXML: () => onDescargarXML(documento),
          onConsultarStatus: () => onConsultarStatus(documento),
          onCrearNotaCredito: () => onCrearNotaCredito(documento),
          onCrearNotaDebito: () => onCrearNotaDebito(documento),
          onReenviarCorreo: () => onReenviarCorreo(documento),
        );
      }
      // Sin CUFE: realmente en tránsito → mostrar botón para consultar estado
      return _AccionButton(
        label: 'Consultar estado',
        icon: Icons.refresh,
        color: Colors.blue,
        onTap: () => onConsultarStatus(documento),
      );
    }
    if (documento.esAceptado) {
      return _MenuDescargas(
        documento: documento,
        onDescargarPDF: () => onDescargarPDF(documento),
        onDescargarQR: () => onDescargarQR(documento),
        onDescargarXML: () => onDescargarXML(documento),
        onConsultarStatus: () => onConsultarStatus(documento),
        onCrearNotaCredito: () => onCrearNotaCredito(documento),
        onCrearNotaDebito: () => onCrearNotaDebito(documento),
        onReenviarCorreo: () => onReenviarCorreo(documento),
      );
    }
    return const SizedBox.shrink();
  }

  Color get _estadoColor {
    switch (documento.estado) {
      case 'RECHAZADO':
        return AppTheme.error;
      case 'PENDIENTE':
        return AppTheme.warning;
      case 'ENVIADO':
        return Colors.blue;
      case 'ACEPTADO':
        return AppTheme.success;
      default:
        return Colors.grey;
    }
  }

  Color get _borderColor => _estadoColor;

  String _formatFecha(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

// ── Badge de estado ──────────────────────────────────────────────────────────

class _EstadoBadge extends StatelessWidget {
  final String estado;
  final Color color;
  const _EstadoBadge({required this.estado, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        estado,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ── Botón de acción ──────────────────────────────────────────────────────────

class _AccionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AccionButton({
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
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ── Menú de descargas para documentos aceptados ──────────────────────────────

class _MenuDescargas extends StatelessWidget {
  final DocumentoFE documento;
  final VoidCallback onDescargarPDF;
  final VoidCallback onDescargarQR;
  final VoidCallback onDescargarXML;
  final VoidCallback onConsultarStatus;
  final VoidCallback onCrearNotaCredito;
  final VoidCallback onCrearNotaDebito;
  final VoidCallback onReenviarCorreo;

  const _MenuDescargas({
    required this.documento,
    required this.onDescargarPDF,
    required this.onDescargarQR,
    required this.onDescargarXML,
    required this.onConsultarStatus,
    required this.onCrearNotaCredito,
    required this.onCrearNotaDebito,
    required this.onReenviarCorreo,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<void>(
      icon: Icon(Icons.download_rounded, color: AppTheme.success, size: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => <PopupMenuEntry<void>>[
        PopupMenuItem<void>(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.picture_as_pdf, size: 18, color: AppTheme.error),
              SizedBox(width: 12),
              Text('PDF'),
            ],
          ),
          onTap: onDescargarPDF,
        ),
        PopupMenuDivider(),
        PopupMenuItem<void>(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.email_outlined, size: 18, color: AppTheme.secondary),
              SizedBox(width: 12),
              Text('Reenviar correo'),
            ],
          ),
          onTap: onReenviarCorreo,
        ),
        PopupMenuItem<void>(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.blue),
              SizedBox(width: 12),
              Text('Estado DIAN'),
            ],
          ),
          onTap: onConsultarStatus,
        ),
        if (documento.tipoDocumento?.toLowerCase() != 'pos') ...[
          PopupMenuDivider(),
          PopupMenuItem<void>(
            onTap: onCrearNotaCredito,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.note_add, size: 18, color: Colors.green),
                SizedBox(width: 12),
                Text('Nota Crédito'),
              ],
            ),
          ),
          PopupMenuItem<void>(
            onTap: onCrearNotaDebito,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.note_add, size: 18, color: Colors.red),
                SizedBox(width: 12),
                Text('Nota Débito'),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
