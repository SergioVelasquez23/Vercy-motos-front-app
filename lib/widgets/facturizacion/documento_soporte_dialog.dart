import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/matias_service.dart';
import '../../services/negocio_info_service.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_theme.dart';

/// Dialog para crear un Documento Soporte (compra a proveedor no obligado
/// a facturar) o una Nota de Ajuste de Documento Soporte.
///
/// Uso (nuevo DS):
/// ```dart
/// showDialog(context: context, builder: (_) => DocumentoSoporteDialog());
/// ```
/// Uso (ajuste a DS existente):
/// ```dart
/// showDialog(context: context, builder: (_) => DocumentoSoporteDialog(
///   dsExistente: ds,
/// ));
/// ```

class DocumentoSoporteDialog extends StatefulWidget {
  /// Si se pasa, se emite una Nota de Ajuste sobre este DS.
  final DocumentoSoporteRef? dsExistente;
  final VoidCallback? onSuccess;

  /// Datos opcionales para pre-llenar desde una factura de compra existente.
  final String? proveedorNombreInicial;
  final String? proveedorNitInicial;

  const DocumentoSoporteDialog({
    Key? key,
    this.dsExistente,
    this.onSuccess,
    this.proveedorNombreInicial,
    this.proveedorNitInicial,
  }) : super(key: key);

  @override
  State<DocumentoSoporteDialog> createState() => _DocumentoSoporteDialogState();
}

/// Datos mínimos del DS existente para la nota de ajuste
class DocumentoSoporteRef {
  final String numero;
  final String cude;
  final String fecha;
  final String proveedor;
  final double total;

  const DocumentoSoporteRef({
    required this.numero,
    required this.cude,
    required this.fecha,
    required this.proveedor,
    required this.total,
  });
}

class _DocumentoSoporteDialogState extends State<DocumentoSoporteDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _errorMsg;

  bool get esAjuste => widget.dsExistente != null;

  // ── Campos proveedor ──
  final _proveedorNombreCtrl = TextEditingController();
  final _proveedorNitCtrl = TextEditingController();
  final _proveedorEmailCtrl = TextEditingController();
  final _proveedorDireccionCtrl = TextEditingController();

  // ── Campos documento ──
  final _descripcionCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();

  // ── Ajuste ──
  int _motivoAjusteId = 1;
  final _motivoDescCtrl = TextEditingController();

  static const _motivosAjuste = [
    (1, 'Anulación del documento soporte'),
    (2, 'Corrección de valor'),
    (3, 'Corrección de cantidad'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.proveedorNombreInicial != null) {
      _proveedorNombreCtrl.text = widget.proveedorNombreInicial!;
    }
    if (widget.proveedorNitInicial != null) {
      _proveedorNitCtrl.text = widget.proveedorNitInicial!;
    }
  }

  @override
  void dispose() {
    _proveedorNombreCtrl.dispose();
    _proveedorNitCtrl.dispose();
    _proveedorEmailCtrl.dispose();
    _proveedorDireccionCtrl.dispose();
    _descripcionCtrl.dispose();
    _valorCtrl.dispose();
    _motivoDescCtrl.dispose();
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
      final valor = double.parse(_valorCtrl.text.replaceAll(',', '.'));

      // Cargar información del negocio para obtener la resolución
      final negocioInfoService = NegocioInfoService();
      final negocioInfo = await negocioInfoService.getNegocioInfo();
      final resolutionNumber = negocioInfo?.resolutionNumber ?? '';

      MatiasDocumentoResult resultado;

      if (esAjuste) {
        final ds = widget.dsExistente!;
        final motivo = _motivoDescCtrl.text.isNotEmpty
            ? _motivoDescCtrl.text
            : _motivosAjuste.firstWhere((m) => m.$1 == _motivoAjusteId).$2;
        final payload = _buildPayload(
          proveedorNombre: ds.proveedor,
          proveedorNit: '',
          descripcion: _descripcionCtrl.text.isNotEmpty
              ? _descripcionCtrl.text
              : 'Ajuste a DS ${ds.numero}',
          valor: valor,
          resolutionNumber: resolutionNumber,
        );
        resultado = await MatiasService.ajustarDocumentoSoporte(
          dsNumero: ds.numero,
          dsCude: ds.cude,
          dsFecha: ds.fecha,
          motivoId: _motivoAjusteId,
          motivo: motivo,
          invoicePayload: payload,
          token: token,
        );
      } else {
        final payload = _buildPayload(
          proveedorNombre: _proveedorNombreCtrl.text,
          proveedorNit: _proveedorNitCtrl.text.replaceAll(RegExp(r'\D'), ''),
          descripcion: _descripcionCtrl.text,
          valor: valor,
          email: _proveedorEmailCtrl.text,
          direccion: _proveedorDireccionCtrl.text,
          resolutionNumber: resolutionNumber,
        );
        resultado = await MatiasService.crearDocumentoSoporte(
          payload,
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
              '✅ ${esAjuste ? "Nota de Ajuste" : "Documento Soporte"} emitido. CUDE: ${resultado.documentKey ?? "N/A"}',
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

  Map<String, dynamic> _buildPayload({
    required String proveedorNombre,
    required String proveedorNit,
    required String descripcion,
    required double valor,
    required String resolutionNumber,
    String? email,
    String? direccion,
  }) {
    final now = DateTime.now();
    final date =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final time =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    final docNum = now.millisecondsSinceEpoch ~/ 1000;

    return {
      // Campos obligatorios de Matias
      'resolution_number': resolutionNumber,
      'prefix': 'DS',
      'document_number': docNum.toString(),
      'date': date,
      'time': time,
      'type_document_id': 5,
      'operation_type_id': 1,
      'send_email': 1,
      'graphic_representation': 0,
      'customer': {
        'country_id': '45',
        'identity_document_id': '3',
        'type_organization_id': 1,
        'tax_regime_id': 2,
        'tax_level_id': 5,
        'company_name': proveedorNombre.isNotEmpty
            ? proveedorNombre
            : 'PROVEEDOR',
        'dni': proveedorNit.isNotEmpty ? proveedorNit : '222222222',
        'email': email ?? '',
        'address': direccion ?? 'SIN DIRECCIÓN',
        'postal_code': '000000',
      },
      'lines': [
        {
          'invoiced_quantity': '1',
          'quantity_units_id': '1093',
          'line_extension_amount': valor.toStringAsFixed(2),
          'free_of_charge_indicator': false,
          'description': descripcion.isNotEmpty
              ? descripcion
              : 'Compra a proveedor',
          'code': 'DS001',
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
      'notes':
          'Documento de soporte - Compra a proveedor no obligado a facturar',
    };
  }

  @override
  Widget build(BuildContext context) {
    final titulo = esAjuste ? 'Nota de Ajuste DS' : 'Documento Soporte';
    final color = AppTheme.success;

    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
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
                      child: Icon(
                        esAjuste
                            ? Icons.edit_document
                            : Icons.file_present_rounded,
                        color: color,
                        size: 26,
                      ),
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
                          if (esAjuste)
                            Text(
                              'Sobre DS: ${widget.dsExistente!.numero}',
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
                const SizedBox(height: 16),
                Divider(color: Colors.grey.shade200),
                const SizedBox(height: 12),

                // ── Scroll de contenido ──
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!esAjuste) ...[
                          _sectionTitle('Datos del Proveedor'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _field(
                                  _proveedorNombreCtrl,
                                  'Nombre proveedor *',
                                  validator: (v) =>
                                      (v?.isEmpty ?? true) ? 'Requerido' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _field(
                                  _proveedorNitCtrl,
                                  'NIT / Cédula *',
                                  validator: (v) =>
                                      (v?.isEmpty ?? true) ? 'Requerido' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _field(
                                  _proveedorEmailCtrl,
                                  'Correo electrónico',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _field(
                                  _proveedorDireccionCtrl,
                                  'Dirección',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (esAjuste) ...[
                          // Info DS existente
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
                                  Icons.info_outline,
                                  color: color,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Proveedor: ${widget.dsExistente!.proveedor}',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        'Total: \$${widget.dsExistente!.total.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _sectionTitle('Tipo de Ajuste'),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            value: _motivoAjusteId,
                            decoration: _inputDecoration(
                              'Selecciona el tipo de ajuste',
                            ),
                            dropdownColor: Theme.of(context).colorScheme.surface,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 14,
                            ),
                            items: _motivosAjuste
                                .map(
                                  (m) => DropdownMenuItem(
                                    value: m.$1,
                                    child: Text(m.$2),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _motivoAjusteId = v ?? 1),
                          ),
                          const SizedBox(height: 10),
                          _field(
                            _motivoDescCtrl,
                            'Descripción del ajuste (opcional)',
                          ),
                          const SizedBox(height: 14),
                        ],

                        _sectionTitle(
                          esAjuste
                              ? 'Valor del Ajuste'
                              : 'Detalle del Documento',
                        ),
                        const SizedBox(height: 8),
                        if (!esAjuste) ...[
                          _field(
                            _descripcionCtrl,
                            'Descripción del bien/servicio *',
                            validator: (v) =>
                                (v?.isEmpty ?? true) ? 'Requerido' : null,
                          ),
                          const SizedBox(height: 10),
                        ],
                        _field(
                          _valorCtrl,
                          'Valor total *',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Requerido';
                            final n = double.tryParse(v.replaceAll(',', '.'));
                            if (n == null || n <= 0)
                              return 'Ingresa un valor válido';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Error ──
                if (_errorMsg != null) ...[
                  const SizedBox(height: 10),
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
                const SizedBox(height: 16),

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
                          : Icon(
                              esAjuste
                                  ? Icons.edit_document
                                  : Icons.file_present_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                      label: Text(
                        _loading ? 'Enviando...' : 'Emitir $titulo',
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

  Widget _sectionTitle(String t) => Text(
    t,
    style: TextStyle(
      color: Theme.of(context).colorScheme.onSurface,
      fontWeight: FontWeight.w600,
      fontSize: 14,
    ),
  );

  Widget _field(
    TextEditingController ctrl,
    String hint, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: ctrl,
    keyboardType: keyboardType,
    decoration: _inputDecoration(hint),
    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
    validator: validator,
  );

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
