import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/matias_service.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_theme.dart';
import '../../models/factura.dart';

/// Dialog para emitir Nota Crédito o Nota Débito sobre una factura existente.
///
/// Uso:
/// ```dart
/// await showDialog(
///   context: context,
///   builder: (_) => NotaCreditoDebitoDialog(
///     factura: factura,
///     tipo: TipoNota.credito,   // o TipoNota.debito
///   ),
/// );
/// ```
enum TipoNota { credito, debito }

class NotaCreditoDebitoDialog extends StatefulWidget {
  // Opción 1: Pasar factura completa (retrocompatibilidad)
  final Factura? factura;
  final TipoNota? tipo;

  // Opción 2: Pasar parámetros individuales (para DocumentoFE/bandeja)
  final String? facturaNumero;
  final String? facturaCufe;
  final String? facturaFecha;
  final String? tipoNota; // 'credito' o 'debito'

  final VoidCallback? onSuccess;

  const NotaCreditoDebitoDialog({
    Key? key,
    // Opción 1
    this.factura,
    this.tipo,
    // Opción 2
    this.facturaNumero,
    this.facturaCufe,
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

  // ── Campos del formulario ──
  int _motivoId = 1;
  final _motivoDescCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();

  // Helper: obtener tipo
  TipoNota get _tipo {
    if (widget.tipo != null) return widget.tipo!;
    if (widget.tipoNota == 'debito') return TipoNota.debito;
    return TipoNota.credito;
  }

  bool get esCredito => _tipo == TipoNota.credito;

  // Motivos Nota Crédito (DIAN)
  static const _motivosCredito = [
    (
      1,
      'Devolución parcial de los bienes y/o no aceptación parcial del servicio',
    ),
    (2, 'Anulación de factura electrónica'),
    (3, 'Descuento post-venta / rebaja'),
    (4, 'Ajuste de precio'),
    (5, 'Otros'),
  ];

  // Motivos Nota Débito (DIAN)
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

      // Obtener datos según el origen (Factura o parámetros individuales)
      final factura = widget.factura;
      final facturaNumero = factura?.numero ?? widget.facturaNumero ?? '';
      final facturaCufe = factura?.cufe ?? widget.facturaCufe ?? '';
      final facturaFecha = factura != null
          ? _formatFecha(factura.fechaCreacion)
          : (widget.facturaFecha ?? _formatFecha(null));

      final valor =
          double.tryParse(_valorCtrl.text.replaceAll(',', '.')) ??
          (factura?.total ?? 0);
      final motivo = _motivoDescCtrl.text.isNotEmpty
          ? _motivoDescCtrl.text
          : _motivos.firstWhere((m) => m.$1 == _motivoId).$2;

      // Construye el payload
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
      'resolution_number': '', // el backend usa la configurada
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
        'dni': (factura.clienteNit ?? '222222222').replaceAll(
          RegExp(r'\D'),
          '',
        ),
        'email': factura.clienteCorreo ?? '',
        'address': factura.clienteDireccion ?? 'SIN DIRECCIÓN',
        'postal_code': '000000',
      },
      'lines': [
        {
          'invoiced_quantity': '1',
          'quantity_units_id': '1093',
          'line_extension_amount': valor.toStringAsFixed(2),
          'free_of_charge_indicator': false,
          'description': esCredito
              ? 'Nota Crédito sobre ${factura.numero}'
              : 'Nota Débito sobre ${factura.numero}',
          'code': 'NOTA',
          'type_item_identifications_id': '4',
          'reference_price_id': '1',
          'price_amount': valor.toStringAsFixed(2),
          'base_quantity': '1',
          'tax_totals': [
            {
              'tax_id': '1',
              'tax_amount': 0,
              'taxable_amount': valor.toStringAsFixed(2),
              'percent': 0,
            },
          ],
        },
      ],
      'legal_monetary_totals': {
        'line_extension_amount': valor.toStringAsFixed(2),
        'tax_exclusive_amount': valor.toStringAsFixed(2),
        'tax_inclusive_amount': valor.toStringAsFixed(2),
        'payable_amount': valor,
      },
      'tax_totals': [
        {
          'tax_id': '1',
          'tax_amount': 0,
          'taxable_amount': valor.toStringAsFixed(2),
          'percent': 0,
        },
      ],
      'payments': [
        {
          'payment_method_id': 1,
          'means_payment_id': 10,
          'value_paid': valor.toStringAsFixed(2),
        },
      ],
    };
  }

  // Payload para DocumentoFE sin objeto Factura completo
  Map<String, dynamic> _buildPayloadFromParams(
    String facturaNumero,
    double valor,
  ) {
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
      'lines': [
        {
          'invoiced_quantity': '1',
          'quantity_units_id': '1093',
          'line_extension_amount': valor.toStringAsFixed(2),
          'free_of_charge_indicator': false,
          'description': esCredito
              ? 'Nota Crédito sobre $facturaNumero'
              : 'Nota Débito sobre $facturaNumero',
          'code': 'NOTA',
          'type_item_identifications_id': '4',
          'reference_price_id': '1',
          'price_amount': valor.toStringAsFixed(2),
          'base_quantity': '1',
          'tax_totals': [
            {
              'tax_id': '1',
              'tax_amount': 0,
              'taxable_amount': valor.toStringAsFixed(2),
              'percent': 0,
            },
          ],
        },
      ],
      'legal_monetary_totals': {
        'line_extension_amount': valor.toStringAsFixed(2),
        'tax_exclusive_amount': valor.toStringAsFixed(2),
        'tax_inclusive_amount': valor.toStringAsFixed(2),
        'payable_amount': valor,
      },
      'tax_totals': [
        {
          'tax_id': '1',
          'tax_amount': 0,
          'taxable_amount': valor.toStringAsFixed(2),
          'percent': 0,
        },
      ],
      'payments': [
        {
          'payment_method_id': 1,
          'means_payment_id': 10,
          'value_paid': valor.toStringAsFixed(2),
        },
      ],
    };
  }

  String _formatFecha(DateTime? d) {
    if (d == null) return DateTime.now().toIso8601String().substring(0, 10);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final titulo = esCredito ? 'Nota Crédito' : 'Nota Débito';
    final color = esCredito ? Colors.orange : Colors.blue;
    final icono = esCredito
        ? Icons.remove_circle_outline
        : Icons.add_circle_outline;

    final facturaNumero =
        widget.factura?.numero ?? widget.facturaNumero ?? 'N/A';

    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Título ──
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icono, color: color, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titulo,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'Sobre factura: $facturaNumero',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Divider(color: Colors.grey.shade200),
                const SizedBox(height: 16),

                // ── Info factura original ──
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.receipt_long,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cliente: ${widget.factura?.clienteNombre ?? "N/A"}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Total: \$${(widget.factura?.total ?? 0).toStringAsFixed(0)}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                fontSize: 13,
                              ),
                            ),
                            if (widget.factura?.cufe == null ||
                                (widget.factura?.cufe ?? '').isEmpty)
                              Text(
                                '⚠️ CUFE no disponible — asegúrate de haber facturado electrónicamente.',
                                style: TextStyle(
                                  color: AppTheme.warning,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ── Motivo (dropdown) ──
                Text(
                  'Motivo',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  value: _motivoId,
                  decoration: _inputDecoration('Selecciona el motivo'),
                  dropdownColor: Theme.of(context).colorScheme.surface,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                  items: _motivos
                      .map(
                        (m) => DropdownMenuItem(value: m.$1, child: Text(m.$2)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _motivoId = v ?? 1),
                ),
                const SizedBox(height: 14),

                // ── Descripción libre ──
                Text(
                  'Descripción adicional (opcional)',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _motivoDescCtrl,
                  decoration: _inputDecoration(
                    'Ej: Devolución por producto dañado',
                  ),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                  maxLength: 200,
                  buildCounter:
                      (
                        _, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => Text(
                        '$currentLength/${maxLength ?? 200}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 11,
                        ),
                      ),
                ),
                const SizedBox(height: 14),

                // ── Valor ──
                Text(
                  'Valor de la nota',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _valorCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _inputDecoration(
                    'Valor (por defecto = total factura)',
                  ),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                  validator: (v) {
                    if (v != null && v.isNotEmpty) {
                      final n = double.tryParse(v.replaceAll(',', '.'));
                      if (n == null || n <= 0)
                        return 'Ingresa un valor válido mayor a 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  'Si dejas vacío se usa el total de la factura (\$${(widget.factura?.total ?? 0).toStringAsFixed(0)})',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 11),
                ),

                // ── Error ──
                if (_errorMsg != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: AppTheme.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMsg!,
                            style: TextStyle(
                              color: AppTheme.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // ── Botones ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _loading ? null : _emitir,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(icono, color: Colors.white, size: 18),
                      label: Text(
                        _loading ? 'Emitiendo...' : 'Emitir $titulo',
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 13),
    filled: true,
    fillColor: Theme.of(context).colorScheme.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
}
