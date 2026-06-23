import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/matias_service.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_theme.dart';
import '../../models/factura.dart';

enum TipoNota { credito, debito }

class NotaCreditoDebitoDialog extends StatefulWidget {
  // Opción 1: Pasar factura completa (retrocompatibilidad)
  final Factura? factura;
  final TipoNota? tipo;

  // Opción 2: Pasar parámetros individuales (para DocumentoFE/bandeja)
  final String? facturaNumero;
  final String? facturaCufe;
  /// XmlDocumentKey para billing_reference.uuid — obligatorio en POS;
  /// si viene aquí se prefiere sobre facturaCufe para la referencia de facturación.
  final String? facturaXmlKey;
  final String? facturaFecha;
  final String? tipoNota; // 'credito' o 'debito'

  final VoidCallback? onSuccess;

  const NotaCreditoDebitoDialog({
    Key? key,
    this.factura,
    this.tipo,
    this.facturaNumero,
    this.facturaCufe,
    this.facturaXmlKey,
    this.facturaFecha,
    this.tipoNota,
    this.onSuccess,
  }) : super(key: key);

  @override
  State<NotaCreditoDebitoDialog> createState() =>
      _NotaCreditoDebitoDialogState();
}

class _NotaCreditoDebitoDialogState extends State<NotaCreditoDebitoDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _errorMsg;

  int _motivoId = 1;
  final _motivoDescCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();

  TipoNota get _tipo {
    if (widget.tipo != null) return widget.tipo!;
    if (widget.tipoNota == 'debito') return TipoNota.debito;
    return TipoNota.credito;
  }

  bool get esCredito => _tipo == TipoNota.credito;

  // CUFE/CUNE para mostrar en la UI
  String get _cufeEfectivo =>
      widget.factura?.cufe ?? widget.facturaCufe ?? '';

  bool get _tieneCufe => _cufeEfectivo.isNotEmpty;

  // UUID que va en billing_reference — prioriza XmlDocumentKey para POS
  String get _uuidParaBilling =>
      widget.facturaXmlKey ?? widget.factura?.cufe ?? widget.facturaCufe ?? '';

  static const _motivosCredito = [
    (1, 'Devolución parcial de los bienes y/o no aceptación parcial del servicio'),
    (2, 'Anulación de factura electrónica'),
    (3, 'Descuento post-venta / rebaja'),
    (4, 'Ajuste de precio'),
    (5, 'Otros'),
  ];

  static const _motivosDebito = [
    (1, 'Intereses'),
    (2, 'Gastos por cobrar al adquiriente'),
    (3, 'Cambio en el valor'),
  ];

  List<(int, String)> get _motivos =>
      esCredito ? _motivosCredito : _motivosDebito;

  @override
  void dispose() {
    _motivoDescCtrl.dispose();
    _valorCtrl.dispose();
    super.dispose();
  }

  Future<void> _emitir() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      final token = Provider.of<UserProvider>(context, listen: false).token;

      final factura = widget.factura;
      final facturaNumero = factura?.numero ?? widget.facturaNumero ?? '';
      final facturaCufe = _uuidParaBilling;
      final facturaFecha = factura != null
          ? _formatFecha(factura.fechaCreacion)
          : (widget.facturaFecha ?? _formatFecha(null));

      final totalRef = factura?.total ?? 0;
      final valor =
          double.tryParse(_valorCtrl.text.replaceAll(',', '.')) ?? totalRef;
      final motivo = _motivoDescCtrl.text.isNotEmpty
          ? _motivoDescCtrl.text
          : _motivos.firstWhere((m) => m.$1 == _motivoId).$2;

      final payload = factura != null
          ? _buildPayload(factura, valor)
          : _buildPayloadFromParams(facturaNumero, valor);

      MatiasDocumentoResult resultado;
      if (esCredito) {
        resultado = await MatiasService.emitirNotaCredito(
          facturaNumero: facturaNumero,
          facturaCufe: facturaCufe,
          facturaFecha: facturaFecha,
          motivoId: _motivoId,
          motivo: motivo,
          invoicePayload: payload,
          token: token,
        );
      } else {
        resultado = await MatiasService.emitirNotaDebito(
          facturaNumero: facturaNumero,
          facturaCufe: facturaCufe,
          facturaFecha: facturaFecha,
          motivoId: _motivoId,
          motivo: motivo,
          invoicePayload: payload,
          token: token,
        );
      }

      if (!mounted) return;

      if (resultado.success) {
        Navigator.of(context).pop();
        widget.onSuccess?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ ${esCredito ? "Nota Crédito" : "Nota Débito"} emitida. CUFE: ${resultado.documentKey ?? "N/A"}',
            ),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        setState(() => _errorMsg = resultado.message);
      }
    } catch (e) {
      setState(() => _errorMsg = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _buildPayload(Factura factura, double valor) {
    return {
      'resolution_number': '',
      'prefix': '',
      'operation_type_id': 1,
      'send_email': 1,
      'graphic_representation': 0,
      'customer': {
        'country_id': '45',
        'identity_document_id': '3',
        'type_organization_id': 1,
        'tax_regime_id': 2,
        'tax_level_id': 5,
        'company_name': factura.clienteNombre,
        'dni': (factura.clienteNit ?? '222222222').replaceAll(RegExp(r'\D'), ''),
        'email': factura.clienteCorreo ?? '',
        'address': factura.clienteDireccion ?? 'SIN DIRECCIÓN',
        'postal_code': '000000',
      },
      'lines': [_buildLine(valor, factura.numero ?? '')],
      'legal_monetary_totals': _buildTotales(valor),
      'tax_totals': [_buildTax(valor)],
      'payments': [_buildPayment(valor)],
    };
  }

  Map<String, dynamic> _buildPayloadFromParams(String facturaNumero, double valor) {
    return {
      'resolution_number': '',
      'prefix': '',
      'operation_type_id': 1,
      'send_email': 1,
      'graphic_representation': 0,
      'customer': {
        'country_id': '45',
        'identity_document_id': '3',
        'type_organization_id': 1,
        'tax_regime_id': 2,
        'tax_level_id': 5,
        'company_name': 'Cliente',
        'dni': '222222222',
        'email': '',
        'address': 'SIN DIRECCIÓN',
        'postal_code': '000000',
      },
      'lines': [_buildLine(valor, facturaNumero)],
      'legal_monetary_totals': _buildTotales(valor),
      'tax_totals': [_buildTax(valor)],
      'payments': [_buildPayment(valor)],
    };
  }

  Map<String, dynamic> _buildLine(double valor, String refNumero) => {
    'invoiced_quantity': '1',
    'quantity_units_id': '1093',
    'line_extension_amount': valor.toStringAsFixed(2),
    'free_of_charge_indicator': false,
    'description': esCredito
        ? 'Nota Crédito sobre $refNumero'
        : 'Nota Débito sobre $refNumero',
    'code': 'NOTA',
    'type_item_identifications_id': '4',
    'reference_price_id': '1',
    'price_amount': valor.toStringAsFixed(2),
    'base_quantity': '1',
    'tax_totals': [_buildTax(valor)],
  };

  Map<String, dynamic> _buildTotales(double valor) => {
    'line_extension_amount': valor.toStringAsFixed(2),
    'tax_exclusive_amount': valor.toStringAsFixed(2),
    'tax_inclusive_amount': valor.toStringAsFixed(2),
    'payable_amount': valor,
  };

  Map<String, dynamic> _buildTax(double valor) => {
    'tax_id': '1',
    'tax_amount': 0,
    'taxable_amount': valor.toStringAsFixed(2),
    'percent': 0,
  };

  Map<String, dynamic> _buildPayment(double valor) => {
    'payment_method_id': 1,
    'means_payment_id': 10,
    'value_paid': valor.toStringAsFixed(2),
  };

  String _formatFecha(DateTime? d) {
    final dt = d ?? DateTime.now();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final titulo = esCredito ? 'Nota Crédito' : 'Nota Débito';
    final color = esCredito ? Colors.orange : Colors.blue.shade600;
    final icono = esCredito ? Icons.remove_circle_outline : Icons.add_circle_outline;
    final facturaNumero = widget.factura?.numero ?? widget.facturaNumero ?? 'N/A';
    final totalRef = widget.factura?.total ?? 0;

    return Dialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: cs.outlineVariant)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icono, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          'Factura: $facturaNumero',
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: cs.onSurface.withValues(alpha: 0.6)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ── Contenido con scroll ────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Info factura ──
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: cs.outline.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.receipt_long, color: AppTheme.primary, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (widget.factura?.clienteNombre != null)
                                    Text(
                                      'Cliente: ${widget.factura!.clienteNombre}',
                                      style: TextStyle(color: cs.onSurface, fontSize: 13),
                                    ),
                                  if (totalRef > 0)
                                    Text(
                                      'Total original: \$${totalRef.toStringAsFixed(0)}',
                                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7), fontSize: 12),
                                    ),
                                  if (!_tieneCufe) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 14),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'Sin CUFE — la factura debe haberse emitido electrónicamente.',
                                            style: TextStyle(color: AppTheme.warning, fontSize: 11),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.verified, color: AppTheme.success, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          'CUFE: ${_cufeEfectivo.substring(0, _cufeEfectivo.length.clamp(0, 20))}...',
                                          style: TextStyle(
                                            color: AppTheme.success,
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // ── Motivo ──
                      _label('Motivo'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        initialValue: _motivoId,
                        isExpanded: true,
                        decoration: _inputDeco('Selecciona el motivo'),
                        dropdownColor: cs.surfaceContainerHighest,
                        style: TextStyle(color: cs.onSurface, fontSize: 14),
                        items: _motivos
                            .map((m) => DropdownMenuItem(value: m.$1, child: Text(m.$2, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (v) => setState(() => _motivoId = v ?? 1),
                      ),
                      const SizedBox(height: 14),

                      // ── Descripción libre ──
                      _label('Descripción adicional (opcional)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _motivoDescCtrl,
                        decoration: _inputDeco('Ej: Devolución por producto dañado'),
                        style: TextStyle(color: cs.onSurface, fontSize: 14),
                        maxLength: 200,
                        maxLines: 2,
                        buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                            Text('$currentLength/${maxLength ?? 200}',
                                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5), fontSize: 11)),
                      ),
                      const SizedBox(height: 14),

                      // ── Valor ──
                      _label('Valor de la nota'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _valorCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _inputDeco(
                          totalRef > 0
                              ? 'Vacío = total factura (\$${totalRef.toStringAsFixed(0)})'
                              : 'Ingresa el valor',
                        ),
                        style: TextStyle(color: cs.onSurface, fontSize: 14),
                        validator: (v) {
                          if (v != null && v.isNotEmpty) {
                            final n = double.tryParse(v.replaceAll(',', '.'));
                            if (n == null || n <= 0) return 'Valor debe ser mayor a 0';
                          }
                          return null;
                        },
                      ),

                      // ── Error ──
                      if (_errorMsg != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.error_outline, color: AppTheme.error, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMsg!,
                                  style: TextStyle(color: AppTheme.error, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // ── Footer con botones ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: cs.outlineVariant)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _loading ? null : () => Navigator.of(context).pop(),
                    child: Text('Cancelar', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6))),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _emitir,
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(icono, color: Colors.white, size: 16),
                    label: Text(
                      _loading ? 'Emitiendo...' : 'Emitir $titulo',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: TextStyle(
      color: Theme.of(context).colorScheme.onSurface,
      fontWeight: FontWeight.w600,
      fontSize: 13,
    ),
  );

  InputDecoration _inputDeco(String hint) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.45), fontSize: 13),
      filled: true,
      fillColor: cs.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: cs.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppTheme.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
