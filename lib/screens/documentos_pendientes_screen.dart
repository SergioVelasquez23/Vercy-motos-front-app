import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../../theme/app_theme.dart';
import '../../widgets/vercy_sidebar_layout.dart';
import '../../services/documento_service.dart';
import '../../services/matias_service.dart';
import '../../services/matias_webhook_service.dart';
import '../../models/matias_webhook_event.dart';
import '../../widgets/facturizacion/confirmacion_dian_dialog.dart';
import '../../widgets/facturizacion/nota_credito_debito_dialog.dart';
import '../../utils/logger.dart';

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
  List<DocumentoFE> _documentos = [];
  bool _isLoading = false;
  String _filtroEstado = ''; // '' = todos

  @override
  void initState() {
    super.initState();
    _cargarDocumentos();
    _setupWebhookListener();
  }

  /// Configura la escucha de eventos WebSocket
  void _setupWebhookListener() async {
    try {
      // URL de backend de Render (producción)
      const String backendUrl =
          'wss://vercy-motos-app-048m.onrender.com';

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
          '💰 Pago aprobado \$${evento.data?.amount?.toStringAsFixed(2)}',
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
      if (mounted) setState(() => _documentos = docs);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<DocumentoFE> get _documentosFiltrados {
    if (_filtroEstado.isEmpty) return _documentos;
    return _documentos.where((d) => d.estado == _filtroEstado).toList();
  }

  @override
  void dispose() {
    _webhookService.disconnect();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${resultado.message}'),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reenviarDocumento(DocumentoFE doc) async {
    // Intentar con el servicio genérico de reenvío
    setState(() => _isLoading = true);
    try {
      final uuid = doc.raw?['uuid']?.toString() ?? doc.id;
      final tipoDoc = doc.tipoDocumento?.toLowerCase() ?? 'invoices';
      String tipo;

      switch (tipoDoc) {
        case 'nota_credito':
        case 'nota credito':
          tipo = 'credit-notes';
          break;
        case 'nota_debito':
        case 'nota debito':
          tipo = 'debit-notes';
          break;
        case 'documento_soporte':
          tipo = 'support-documents';
          break;
        case 'pos':
          tipo = 'pos-documents';
          break;
        case 'nota_ajuste':
          tipo = 'adjustment-notes';
          break;
        default:
          tipo = 'invoices';
      }

      final resultado = await MatiasService.reenviarDocumentoAutoIncrement(
        tipo,
        uuid,
      );

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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${resGen.message}'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Descargas y consultas ─────────────────────────────────────────────────

  Future<void> _descargarPDF(DocumentoFE doc) async {
    final cufe = doc.cufe;
    if (cufe == null) {
      _mostrarError('No se puede descargar: Documento sin CUFE');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final bytes = await MatiasService.descargarPDFFactura(doc.id);
      if (!mounted) return;

      if (bytes != null) {
        _mostrarExito(
          'PDF descargado (${(bytes.length / 1024).toStringAsFixed(2)} KB)',
        );
        // TODO: Guardar/mostrar PDF según plataforma (web/mobile)
        appLog('✅ PDF descargado: ${bytes.length} bytes');
      } else {
        _mostrarError('No se pudo descargar el PDF');
      }
    } catch (e) {
      if (mounted) _mostrarError('Error al descargar PDF: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _descargarQR(DocumentoFE doc) async {
    final cufe = doc.cufe;
    if (cufe == null) {
      _mostrarError('No se puede descargar: Documento sin CUFE');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final bytes = await MatiasService.obtenerQRDocumento(cufe);
      if (!mounted) return;

      if (bytes != null) {
        _mostrarExito(
          'QR descargado (${(bytes.length / 1024).toStringAsFixed(2)} KB)',
        );
        appLog('✅ QR descargado: ${bytes.length} bytes');
      } else {
        _mostrarError('No se pudo descargar el QR');
      }
    } catch (e) {
      if (mounted) _mostrarError('Error al descargar QR: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _descargarXML(DocumentoFE doc) async {
    final cufe = doc.cufe;
    if (cufe == null) {
      _mostrarError('No se puede descargar: Documento sin CUFE');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final xml = await MatiasService.obtenerXMLDocumento(cufe);
      if (!mounted) return;

      if (xml != null) {
        _mostrarExito(
          'XML descargado (${(xml.length / 1024).toStringAsFixed(2)} KB)',
        );
        appLog('✅ XML descargado: ${xml.length} chars');
      } else {
        _mostrarError('No se pudo descargar el XML');
      }
    } catch (e) {
      if (mounted) _mostrarError('Error al descargar XML: $e');
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
      if (mounted) _mostrarError('Error al consultar status: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarStatusDialog(String cufe, Map<String, dynamic> status) {
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
              _buildStatusField(
                'Estado',
                status['estado']?.toString() ?? 'N/A',
              ),
              _buildStatusField(
                'Mensaje',
                status['mensaje']?.toString() ?? 'N/A',
              ),
              if (status['fecha_consulta'] != null)
                _buildStatusField(
                  'Consultado',
                  status['fecha_consulta']?.toString() ?? 'N/A',
                ),
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
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: AppTheme.error),
    );
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
    return VercySidebarLayout(
      title: 'Documentos FE',
      child: Scaffold(
        backgroundColor: AppTheme.backgroundDark,
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
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final totalPendientes = _documentos.where((d) => d.esPendiente).length;
    final totalRechazados = _documentos.where((d) => d.esRechazado).length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.inbox_rounded, color: AppTheme.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bandeja de Documentos Electrónicos',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '$totalPendientes pendientes · $totalRechazados rechazados',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Estado WebSocket
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _webhookService.isConnected
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
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
                            _webhookService.isConnected
                                ? '🔌 En línea'
                                : '⚠️ Desconectado',
                            style: TextStyle(
                              color: _webhookService.isConnected
                                  ? Colors.green
                                  : Colors.orange,
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
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _cargarDocumentos,
            icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
            label: const Text(
              'Actualizar',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
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
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: activo
                            ? Colors.white.withOpacity(0.3)
                            : color.withOpacity(0.15),
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
                ],
              ),
              selectedColor: color,
              backgroundColor: AppTheme.cardBg,
              labelStyle: TextStyle(
                color: activo ? Colors.white : AppTheme.textPrimary,
                fontSize: 13,
              ),
              side: BorderSide(color: activo ? color : Colors.grey.shade300),
              onSelected: (_) => setState(() => _filtroEstado = valor),
            ),
          );
        }).toList(),
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
            color: AppTheme.success.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _filtroEstado.isEmpty
                ? 'No hay documentos en la bandeja'
                : 'No hay documentos ${_filtroEstado.toLowerCase()}s',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Los documentos aparecerán aquí cuando se cobre un pedido',
            style: TextStyle(
              color: AppTheme.textSecondary.withOpacity(0.6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLista() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _documentosFiltrados.length,
      itemBuilder: (context, index) {
        return _DocumentoCard(
          documento: _documentosFiltrados[index],
          onFacturar: _facturarDocumento,
          onReenviar: _reenviarDocumento,
          onDescargarPDF: _descargarPDF,
          onDescargarQR: _descargarQR,
          onDescargarXML: _descargarXML,
          onConsultarStatus: _consultarStatusDIAN,
          onCrearNotaCredito: _crearNotaCredito,
          onCrearNotaDebito: _crearNotaDebito,
        );
      },
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
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor.withOpacity(0.3)),
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
                          color: AppTheme.primary.withOpacity(0.1),
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
                        color: AppTheme.textPrimary,
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
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        documento.clienteNombre ?? 'CONSUMIDOR FINAL',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '\$ ${documento.total.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
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
                      color: AppTheme.textSecondary,
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
                      color: AppTheme.error.withOpacity(0.08),
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
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Procesando',
              style: TextStyle(color: Colors.blue, fontSize: 12),
            ),
          ],
        ),
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
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
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

  const _MenuDescargas({
    required this.documento,
    required this.onDescargarPDF,
    required this.onDescargarQR,
    required this.onDescargarXML,
    required this.onConsultarStatus,
    required this.onCrearNotaCredito,
    required this.onCrearNotaDebito,
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
        PopupMenuItem<void>(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_2, size: 18, color: AppTheme.primary),
              SizedBox(width: 12),
              Text('Código QR'),
            ],
          ),
          onTap: onDescargarQR,
        ),
        PopupMenuItem<void>(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.code, size: 18, color: Colors.orange),
              SizedBox(width: 12),
              Text('XML'),
            ],
          ),
          onTap: onDescargarXML,
        ),
        PopupMenuDivider(),
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
        PopupMenuDivider(),
        PopupMenuItem<void>(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.note_add, size: 18, color: Colors.green),
              SizedBox(width: 12),
              Text('Nota Crédito'),
            ],
          ),
          onTap: onCrearNotaCredito,
        ),
        PopupMenuItem<void>(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.note_add, size: 18, color: Colors.red),
              SizedBox(width: 12),
              Text('Nota Débito'),
            ],
          ),
          onTap: onCrearNotaDebito,
        ),
      ],
    );
  }
}
