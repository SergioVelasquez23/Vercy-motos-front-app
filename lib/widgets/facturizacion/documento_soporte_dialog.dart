import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/factura_compra.dart';
import '../../models/proveedor.dart';
import '../../providers/user_provider.dart';
import '../../services/matias_service.dart';
import '../../services/negocio_info_service.dart';
import '../../services/proveedor_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_utils.dart';

class DocumentoSoporteDialog extends StatefulWidget {
  /// Cuando se pasa, el dialog pre-llena todo desde la compra y solo
  /// pide la forma/medio de pago y la fecha de vencimiento.
  final FacturaCompra? compra;

  /// DS existente para emitir nota de ajuste.
  final DocumentoSoporteRef? dsExistente;

  final VoidCallback? onSuccess;

  // ── Campos legacy (cuando no hay compra) ──
  final String? proveedorNombreInicial;
  final String? proveedorNitInicial;
  final String? proveedorEmailInicial;
  final String? proveedorDireccionInicial;
  final double? valorInicial;

  const DocumentoSoporteDialog({
    Key? key,
    this.compra,
    this.dsExistente,
    this.onSuccess,
    this.proveedorNombreInicial,
    this.proveedorNitInicial,
    this.proveedorEmailInicial,
    this.proveedorDireccionInicial,
    this.valorInicial,
  }) : super(key: key);

  @override
  State<DocumentoSoporteDialog> createState() => _DocumentoSoporteDialogState();
}

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

// ── Opciones de forma de pago ────────────────────────────────────────────────

const _formasPago = [
  (1, 'Contado'),
  (2, 'Crédito'),
];

const _mediosPago = [
  (10, 'Efectivo'),
  (47, 'Transferencia / PSE'),
  (41, 'Tarjeta crédito'),
  (42, 'Tarjeta débito'),
  (20, 'Cheque'),
  (71, 'Bonos / Vales'),
];

// ── Estado ───────────────────────────────────────────────────────────────────

class _DocumentoSoporteDialogState extends State<DocumentoSoporteDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _errorMsg;
  bool _esResidente = true;

  List<Proveedor> _proveedores = [];
  Proveedor? _proveedorEncontrado;

  // Proveedor manual (legacy / sin compra)
  final _proveedorNombreCtrl = TextEditingController();
  final _proveedorNitCtrl = TextEditingController();
  final _proveedorEmailCtrl = TextEditingController();
  final _proveedorDireccionCtrl = TextEditingController();
  final _ciudadExtranjeraCtrl = TextEditingController();
  final _codigoPaisCtrl = TextEditingController();

  // Campos de documento
  final _descripcionCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();

  // Ciudad DIAN (código numérico, ej: "149" = Bogotá, "836" = Medellín)
  final _cityCodeCtrl = TextEditingController(text: '149');

  // Pago
  int _paymentMethodId = 1; // 1=Contado, 2=Crédito
  int _meansPaymentId = 10; // 10=Efectivo
  final _dueDateCtrl = TextEditingController();

  // Ajuste
  int _motivoAjusteId = 1;
  final _motivoDescCtrl = TextEditingController();

  static const _motivosAjuste = [
    (1, 'Anulación del documento soporte'),
    (2, 'Corrección de valor'),
    (3, 'Corrección de cantidad'),
  ];

  bool get _esAjuste => widget.dsExistente != null;
  bool get _tieneCompra => widget.compra != null;

  @override
  void initState() {
    super.initState();
    _initFechaVencimiento();
    _initCamposLegacy();
    _cargarProveedores();
  }

  void _initFechaVencimiento() {
    final due = widget.compra?.fechaVencimiento ?? DateTime.now().add(const Duration(days: 30));
    _dueDateCtrl.text = DateFormat('yyyy-MM-dd').format(due);
  }

  void _initCamposLegacy() {
    if (widget.proveedorNombreInicial != null) {
      _proveedorNombreCtrl.text = widget.proveedorNombreInicial!;
    }
    if (widget.proveedorNitInicial != null) {
      _proveedorNitCtrl.text = widget.proveedorNitInicial!;
    }
    if (widget.proveedorEmailInicial != null) {
      _proveedorEmailCtrl.text = widget.proveedorEmailInicial!;
    }
    if (widget.proveedorDireccionInicial != null) {
      _proveedorDireccionCtrl.text = widget.proveedorDireccionInicial!;
    }
    if (widget.valorInicial != null && widget.valorInicial! > 0) {
      _valorCtrl.text = widget.valorInicial!.toStringAsFixed(0);
    }
  }

  Future<void> _cargarProveedores() async {
    try {
      final lista = await ProveedorService().getProveedores();
      if (!mounted) return;
      setState(() {
        _proveedores = lista;
        _matchProveedorPorNit();
      });
    } catch (_) {}
  }

  void _matchProveedorPorNit() {
    final nit = widget.compra?.proveedorNit ?? widget.proveedorNitInicial;
    if (nit == null || nit.isEmpty) return;
    final clean = nit.replaceAll(RegExp(r'\D'), '');
    try {
      _proveedorEncontrado = _proveedores.firstWhere(
        (p) => (p.documento ?? '').replaceAll(RegExp(r'\D'), '') == clean,
      );
      // Pre-poblar desde campos DIAN guardados en el proveedor
      final p = _proveedorEncontrado!;
      if (p.codigoCiudadDian?.isNotEmpty == true) {
        _cityCodeCtrl.text = p.codigoCiudadDian!;
      }
      if (p.esResidenteColombia != null) {
        _esResidente = p.esResidenteColombia!;
      }
    } catch (_) {
      _proveedorEncontrado = null;
    }
  }

  void _seleccionarProveedor(Proveedor p) {
    setState(() {
      _proveedorEncontrado = p;
      _proveedorNombreCtrl.text = _nombreCompleto(p);
      _proveedorNitCtrl.text = p.documento ?? '';
      _proveedorEmailCtrl.text = p.email ?? '';
      _proveedorDireccionCtrl.text = p.direccion ?? '';
    });
  }

  String _nombreCompleto(Proveedor p) =>
      [p.nombre, p.apellidos].where((s) => s != null && s.isNotEmpty).join(' ');

  @override
  void dispose() {
    _proveedorNombreCtrl.dispose();
    _proveedorNitCtrl.dispose();
    _proveedorEmailCtrl.dispose();
    _proveedorDireccionCtrl.dispose();
    _ciudadExtranjeraCtrl.dispose();
    _codigoPaisCtrl.dispose();
    _descripcionCtrl.dispose();
    _valorCtrl.dispose();
    _cityCodeCtrl.dispose();
    _dueDateCtrl.dispose();
    _motivoDescCtrl.dispose();
    super.dispose();
  }

  // ── Emitir ───────────────────────────────────────────────────────────────

  Future<void> _emitir() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _errorMsg = null; });

    try {
      final token = Provider.of<UserProvider>(context, listen: false).token;
      final negocioInfo = await NegocioInfoService().getNegocioInfo();
      final resolutionNumber = negocioInfo?.dsResolutionNumber?.isNotEmpty == true
          ? negocioInfo!.dsResolutionNumber!
          : negocioInfo?.resolutionNumber ?? '';

      MatiasDocumentoResult resultado;

      if (_esAjuste) {
        final ds = widget.dsExistente!;
        final motivo = _motivoDescCtrl.text.isNotEmpty
            ? _motivoDescCtrl.text
            : _motivosAjuste.firstWhere((m) => m.$1 == _motivoAjusteId).$2;
        final valor = double.tryParse(_valorCtrl.text.replaceAll(',', '.')) ?? 0;
        final payload = _buildPayloadSimple(
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
      } else if (_tieneCompra) {
        final payload = _buildPayloadFromCompra(resolutionNumber);
        resultado = await MatiasService.crearDocumentoSoporte(payload, token: token);
      } else {
        final valor = double.parse(_valorCtrl.text.replaceAll(',', '.'));
        final payload = _buildPayloadSimple(
          proveedorNombre: _proveedorNombreCtrl.text,
          proveedorNit: _proveedorNitCtrl.text.replaceAll(RegExp(r'\D'), ''),
          descripcion: _descripcionCtrl.text,
          valor: valor,
          resolutionNumber: resolutionNumber,
          email: _proveedorEmailCtrl.text,
          direccion: _proveedorDireccionCtrl.text,
          ciudadExtranjera: _ciudadExtranjeraCtrl.text,
          codigoPais: _codigoPaisCtrl.text,
        );
        resultado = await MatiasService.crearDocumentoSoporte(payload, token: token);
      }

      if (!mounted) return;
      if (resultado.success) {
        Navigator.of(context).pop();
        widget.onSuccess?.call();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            '✅ ${_esAjuste ? "Nota de Ajuste" : "Documento Soporte"} emitido. '
            'CUDE: ${resultado.documentKey ?? "N/A"}',
          ),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 5),
        ));
      } else {
        setState(() => _errorMsg = resultado.message);
      }
    } catch (e) {
      setState(() => _errorMsg = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Payload desde FacturaCompra (multi-línea) ─────────────────────────────

  Map<String, dynamic> _buildPayloadFromCompra(String resolutionNumber) {
    final compra = widget.compra!;
    final p = _proveedorEncontrado;
    final fechaCompra = compra.fechaCreacion;
    final date = DateFormat('yyyy-MM-dd').format(fechaCompra);
    final time = DateFormat('HH:mm:ss').format(fechaCompra);

    // Número de documento: usar numeroFactura de la compra (sin prefijo si tiene)
    final docNum = compra.numeroFactura.replaceAll(RegExp(r'^[A-Z]+-'), '');

    // Notas
    final notes = compra.descripcion?.isNotEmpty == true
        ? 'Factura proveedor: ${compra.descripcion}'
        : 'Documento soporte - Compra ${compra.numeroFactura}';

    // Customer
    final customer = _buildCustomer(p, compra, date);

    // Lines
    final lines = _buildLines(compra.items, date);

    // Tax totals agrupados por porcentaje
    final taxGroups = <int, Map<String, double>>{};
    for (final item in compra.items) {
      final pct = item.porcentajeImpuesto.round();
      taxGroups.putIfAbsent(pct, () => {'taxable': 0.0, 'amount': 0.0});
      final base = item.subtotal - item.valorDescuento;
      taxGroups[pct]!['taxable'] = taxGroups[pct]!['taxable']! + base;
      taxGroups[pct]!['amount'] = taxGroups[pct]!['amount']! + item.valorImpuesto;
    }
    final taxTotals = taxGroups.entries.map((e) => {
      'tax_id': '1',
      'percent': e.key,
      'tax_amount': e.value['amount']!.toStringAsFixed(2),
      'taxable_amount': e.value['taxable']!.toStringAsFixed(2),
    }).toList();

    // Totales legales
    final subtotal = compra.subtotal > 0
        ? compra.subtotal
        : compra.items.fold<double>(0, (s, i) => s + i.subtotal - i.valorDescuento);
    final totalIva = compra.totalImpuestos > 0
        ? compra.totalImpuestos
        : compra.items.fold<double>(0, (s, i) => s + i.valorImpuesto);
    final total = compra.total > 0 ? compra.total : subtotal + totalIva;

    final legalMonetaryTotals = <String, dynamic>{
      'line_extension_amount': subtotal.toStringAsFixed(2),
      'tax_exclusive_amount': subtotal.toStringAsFixed(2),
      'tax_inclusive_amount': total.toStringAsFixed(2),
      'payable_amount': total.toStringAsFixed(2),
      if (compra.totalDescuentos > 0)
        'allowance_total_amount': compra.totalDescuentos.toStringAsFixed(2),
    };

    final dueDate = _dueDateCtrl.text.isNotEmpty
        ? _dueDateCtrl.text
        : date;

    return {
      'resolution_number': resolutionNumber,
      'prefix': 'DS',
      'document_number': docNum,
      'date': date,
      'time': time,
      'type_document_id': 11,
      'operation_type_id': _esResidente ? 9 : 10,
      'currency_id': 272,
      'send_email': 1,
      'graphic_representation': 1,
      'notes': notes,
      'customer': customer,
      'lines': lines,
      'legal_monetary_totals': legalMonetaryTotals,
      'tax_totals': taxTotals.isEmpty
          ? [{'tax_id': '1', 'percent': 0, 'tax_amount': '0.00', 'taxable_amount': subtotal.toStringAsFixed(2)}]
          : taxTotals,
      'payments': [{
        'payment_method_id': _paymentMethodId,
        'means_payment_id': _meansPaymentId,
        'value_paid': total.toStringAsFixed(2),
        'payment_due_date': dueDate,
      }],
    };
  }

  Map<String, dynamic> _buildCustomer(Proveedor? p, FacturaCompra compra, String date) {
    if (p == null) {
      // Sin proveedor encontrado: usar datos básicos de la compra
      final esNit = (compra.proveedorNit?.length ?? 0) >= 9;
      return {
        'country_id': '45',
        'city_id': _cityCodeCtrl.text.isNotEmpty ? _cityCodeCtrl.text : '149',
        'identity_document_id': esNit ? '6' : '3',
        'type_organization_id': esNit ? 1 : 2,
        'tax_regime_id': esNit ? 1 : 2,
        'tax_level_id': 5,
        'company_name': compra.proveedorNombre.isNotEmpty ? compra.proveedorNombre : 'PROVEEDOR',
        'dni': (compra.proveedorNit ?? '').replaceAll(RegExp(r'\D'), '').isNotEmpty
            ? (compra.proveedorNit ?? '').replaceAll(RegExp(r'\D'), '')
            : '222222222',
        'email': '',
        'address': 'SIN DIRECCIÓN',
        'postal_code': '000000',
      };
    }

    final tipoId = p.tipoId ?? 'CC';
    final esNit = tipoId.toUpperCase() == 'NIT';
    final esJuridica = (p.tipo ?? '').contains('Jurídica') || esNit;
    final responsableIva = (p.responsableIVA ?? 'NO').toUpperCase() == 'SI';

    // Régimen y nivel tributario — usar campo guardado si existe, derivar si no
    final int taxRegimeId;
    final int taxLevelId;
    switch (p.tipoRegimenTributario) {
      case 'Responsable de IVA':
        taxRegimeId = 1; taxLevelId = 1;
      case 'Gran Contribuyente':
        taxRegimeId = 4; taxLevelId = 1;
      case 'No Responsable de IVA':
        taxRegimeId = 2; taxLevelId = 5;
      default:
        taxRegimeId = responsableIva ? 1 : 2;
        taxLevelId = responsableIva ? 1 : 5;
    }

    // Residente: campo guardado tiene prioridad sobre el toggle del dialog
    final esResidente = p.esResidenteColombia ?? _esResidente;

    // Ciudad: campo guardado tiene prioridad sobre el campo manual del dialog
    final cityCode = (p.codigoCiudadDian?.isNotEmpty == true)
        ? p.codigoCiudadDian!
        : (_cityCodeCtrl.text.isNotEmpty ? _cityCodeCtrl.text : '149');

    return {
      'country_id': esResidente ? '45' : (_codigoPaisCtrl.text.isNotEmpty ? _codigoPaisCtrl.text : '239'),
      if (esResidente)
        'city_id': cityCode
      else
        'city_name': _ciudadExtranjeraCtrl.text.isNotEmpty ? _ciudadExtranjeraCtrl.text : 'Extranjero',
      'identity_document_id': _mapTipoId(tipoId),
      'type_organization_id': esJuridica ? 1 : 2,
      'tax_regime_id': taxRegimeId,
      'tax_level_id': taxLevelId,
      'company_name': _nombreCompleto(p).isNotEmpty ? _nombreCompleto(p) : 'PROVEEDOR',
      'dni': (p.documento ?? '').replaceAll(RegExp(r'\D'), '').isNotEmpty
          ? (p.documento ?? '').replaceAll(RegExp(r'\D'), '')
          : '222222222',
      'mobile': p.telefono?.isNotEmpty == true ? p.telefono! : '0000000000',
      'email': p.email?.isNotEmpty == true ? p.email! : 'proveedor@sin-correo.com',
      'address': p.direccion?.isNotEmpty == true ? p.direccion! : 'SIN DIRECCIÓN',
      'postal_code': '000000',
    };
  }

  List<Map<String, dynamic>> _buildLines(List<ItemFacturaCompra> items, String date) {
    return List.generate(items.length, (idx) {
      final item = items[idx];
      final pct = item.porcentajeImpuesto.round();
      final base = item.subtotal - item.valorDescuento;
      final lineMap = <String, dynamic>{
        'line_number': (idx + 1).toString(),
        'description': item.ingredienteNombre.isNotEmpty ? item.ingredienteNombre : 'Producto',
        'code': item.ingredienteId.isNotEmpty ? item.ingredienteId : 'PROD${idx + 1}',
        'invoiced_quantity': item.cantidad.toStringAsFixed(0),
        'base_quantity': item.cantidad.toStringAsFixed(0),
        'quantity_units_id': '1093',
        'price_amount': item.precioUnitario.toStringAsFixed(2),
        'line_extension_amount': base.toStringAsFixed(2),
        'free_of_charge_indicator': false,
        'type_item_identifications_id': '4',
        'reference_price_id': '1',
        'invoice_period': {'start_date': date, 'description_code': 1},
        'tax_totals': [{
          'tax_id': '1',
          'percent': pct,
          'tax_amount': item.valorImpuesto.toStringAsFixed(2),
          'taxable_amount': base.toStringAsFixed(2),
        }],
      };
      if (item.valorDescuento > 0) {
        final lineGross = item.cantidad * item.precioUnitario;
        lineMap['allowance_charges'] = [{
          'discount_id': '1',
          'charge_indicator': false,
          'allowance_charge_reason': 'Descuento',
          'amount': item.valorDescuento.toStringAsFixed(2),
          'base_amount': lineGross.toStringAsFixed(2),
          if (lineGross > 0)
            'multiplier_factor_numeric':
                (item.valorDescuento / lineGross * 100).toStringAsFixed(2),
        }];
      }
      return lineMap;
    });
  }

  // ── Payload simple (legacy / ajuste) ─────────────────────────────────────

  Map<String, dynamic> _buildPayloadSimple({
    required String proveedorNombre,
    required String proveedorNit,
    required String descripcion,
    required double valor,
    required String resolutionNumber,
    bool esResidente = true,
    String? email,
    String? direccion,
    String? ciudadExtranjera,
    String? codigoPais,
  }) {
    final now = DateTime.now();
    final date = DateFormat('yyyy-MM-dd').format(now);
    final time = DateFormat('HH:mm:ss').format(now);
    final docNum = now.millisecondsSinceEpoch ~/ 1000;
    final dueDate = _dueDateCtrl.text.isNotEmpty ? _dueDateCtrl.text : date;

    final customer = <String, dynamic>{
      'country_id': esResidente ? '45' : (codigoPais?.isNotEmpty == true ? codigoPais! : '239'),
      'identity_document_id': esResidente ? '3' : '10',
      'type_organization_id': 2,
      'tax_regime_id': 2,
      'tax_level_id': 5,
      'company_name': proveedorNombre.isNotEmpty ? proveedorNombre : 'PROVEEDOR',
      'dni': proveedorNit.isNotEmpty ? proveedorNit : '222222222',
      'email': email ?? '',
      'address': direccion ?? 'SIN DIRECCIÓN',
      'postal_code': '000000',
    };
    if (esResidente) {
      customer['city_id'] = _cityCodeCtrl.text.isNotEmpty ? _cityCodeCtrl.text : '149';
    } else {
      customer['city_name'] = ciudadExtranjera?.isNotEmpty == true ? ciudadExtranjera! : 'Extranjero';
    }

    return {
      'resolution_number': resolutionNumber,
      'prefix': 'DS',
      'document_number': docNum.toString(),
      'date': date,
      'time': time,
      'type_document_id': 11,
      'operation_type_id': esResidente ? 9 : 10,
      'currency_id': 272,
      'send_email': 1,
      'graphic_representation': 1,
      'customer': customer,
      'lines': [{
        'invoiced_quantity': '1',
        'base_quantity': '1',
        'quantity_units_id': '1093',
        'line_extension_amount': valor.toStringAsFixed(2),
        'free_of_charge_indicator': false,
        'description': descripcion.isNotEmpty ? descripcion : 'Compra a proveedor',
        'code': 'DS001',
        'type_item_identifications_id': '4',
        'reference_price_id': '1',
        'price_amount': valor.toStringAsFixed(2),
        'invoice_period': {'start_date': date, 'description_code': 1},
        'tax_totals': [{'tax_id': '1', 'percent': 0, 'tax_amount': '0.00', 'taxable_amount': valor.toStringAsFixed(2)}],
      }],
      'legal_monetary_totals': {
        'line_extension_amount': valor.toStringAsFixed(2),
        'tax_exclusive_amount': valor.toStringAsFixed(2),
        'tax_inclusive_amount': valor.toStringAsFixed(2),
        'payable_amount': valor.toStringAsFixed(2),
      },
      'tax_totals': [{'tax_id': '1', 'percent': 0, 'tax_amount': '0.00', 'taxable_amount': valor.toStringAsFixed(2)}],
      'payments': [{
        'payment_method_id': _paymentMethodId,
        'means_payment_id': _meansPaymentId,
        'value_paid': valor.toStringAsFixed(2),
        'payment_due_date': dueDate,
      }],
      'notes': descripcion.isNotEmpty ? descripcion : 'Documento soporte - Compra a proveedor no obligado a facturar',
    };
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _mapTipoId(String tipo) {
    switch (tipo.toUpperCase()) {
      case 'CC': return '3';
      case 'CE': return '2';
      case 'NIT': return '6';
      case 'TI': return '4';
      case 'PAS':
      case 'PASAPORTE': return '7';
      default: return '3';
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final titulo = _esAjuste ? 'Nota de Ajuste DS' : 'Documento Soporte';
    final color = AppTheme.success;
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Título ──
                _buildTitulo(titulo, color, cs),
                const SizedBox(height: 14),
                Divider(color: cs.onSurface.withValues(alpha:0.1)),
                const SizedBox(height: 8),

                // ── Contenido scrollable ──
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_tieneCompra && !_esAjuste) ...[
                          _buildSeccionCompra(cs),
                          const SizedBox(height: 16),
                        ] else if (!_esAjuste) ...[
                          _buildSeccionProveedorManual(cs),
                          const SizedBox(height: 14),
                          _buildSeccionDetalle(cs),
                          const SizedBox(height: 14),
                        ],

                        if (_esAjuste) ...[
                          _buildInfoDsExistente(cs, color),
                          const SizedBox(height: 14),
                          _buildSeccionAjuste(cs),
                          const SizedBox(height: 14),
                          _field(_valorCtrl, 'Valor del ajuste *', keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Requerido';
                              if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Valor inválido';
                              return null;
                            }),
                          const SizedBox(height: 14),
                        ],

                        // ── Pago (siempre) ──
                        _buildSeccionPago(cs),
                      ],
                    ),
                  ),
                ),

                // ── Error ──
                if (_errorMsg != null) ...[
                  const SizedBox(height: 10),
                  _buildError(cs),
                ],
                const SizedBox(height: 14),

                // ── Botones ──
                _buildBotones(titulo, color, cs),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Secciones UI ─────────────────────────────────────────────────────────

  Widget _buildTitulo(String titulo, Color color, ColorScheme cs) {
    final compra = widget.compra;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha:0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(_esAjuste ? Icons.edit_document : Icons.file_present_rounded, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
              if (_esAjuste)
                Text('Sobre DS: ${widget.dsExistente!.numero}', style: TextStyle(color: cs.onSurface.withValues(alpha:0.6), fontSize: 12))
              else if (compra != null)
                Text('Compra: ${compra.numeroFactura}', style: TextStyle(color: cs.onSurface.withValues(alpha:0.6), fontSize: 12)),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          color: cs.onSurface.withValues(alpha:0.6),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildSeccionCompra(ColorScheme cs) {
    final compra = widget.compra!;
    final p = _proveedorEncontrado;
    final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Proveedor
        _sectionTitle('Proveedor', cs),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (p != null ? AppTheme.success : cs.surface).withValues(alpha:p != null ? 0.06 : 1),
            border: Border.all(color: p != null ? AppTheme.success.withValues(alpha:0.3) : cs.onSurface.withValues(alpha:0.15)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: p != null
              ? _buildProveedorEncontrado(p, cs)
              : _buildProveedorBasico(compra, cs),
        ),
        if (p != null) ...[
          const SizedBox(height: 8),
          // Campos DIAN: usar guardados o permitir edición manual
          _buildDianConfigRow(p, cs),
        ] else ...[
          const SizedBox(height: 6),
          Text(
            '⚠️ Proveedor no encontrado en la lista — verifica el NIT o registra el proveedor primero.',
            style: TextStyle(color: Colors.orange.shade700, fontSize: 11),
          ),
        ],
        const SizedBox(height: 16),

        // Items
        _sectionTitle('Productos (${compra.items.length})', cs),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: cs.onSurface.withValues(alpha:0.1)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              ...compra.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(item.ingredienteNombre, style: TextStyle(fontSize: 12, color: cs.onSurface), overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      '${item.cantidad.toStringAsFixed(0)} × ${fmt.format(item.precioUnitario)}',
                      style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha:0.6)),
                    ),
                    const SizedBox(width: 8),
                    Text(fmt.format(item.subtotal), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface)),
                  ],
                ),
              )),
              Divider(height: 1, color: cs.onSurface.withValues(alpha:0.1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  children: [
                    _totalRow('Subtotal', fmt.format(compra.subtotal), cs),
                    if (compra.totalDescuentos > 0) _totalRow('Descuentos', '−${fmt.format(compra.totalDescuentos)}', cs, color: AppTheme.error),
                    if (compra.totalImpuestos > 0) _totalRow('IVA', fmt.format(compra.totalImpuestos), cs),
                    _totalRow('TOTAL', fmt.format(compra.total), cs, bold: true, color: AppTheme.primary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProveedorEncontrado(Proveedor p, ColorScheme cs) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppTheme.success.withValues(alpha:0.15),
          child: Text(_nombreCompleto(p).isNotEmpty ? _nombreCompleto(p)[0].toUpperCase() : '?',
              style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_nombreCompleto(p), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: cs.onSurface)),
              Text(
                '${p.tipoId ?? "Doc"}: ${p.documento ?? "-"}  •  ${p.tipo ?? ""}',
                style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha:0.6)),
              ),
              if (p.email?.isNotEmpty == true)
                Text(p.email!, style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha:0.5))),
            ],
          ),
        ),
        Icon(Icons.check_circle, color: AppTheme.success, size: 18),
      ],
    );
  }

  Widget _buildDianConfigRow(Proveedor p, ColorScheme cs) {
    final tieneCiudad = p.codigoCiudadDian?.isNotEmpty == true;
    final tieneResidente = p.esResidenteColombia != null;
    final tieneRegimen = p.tipoRegimenTributario?.isNotEmpty == true;
    final todoConfigurado = tieneCiudad && tieneResidente && tieneRegimen;

    if (todoConfigurado) {
      // Todo guardado: mostrar resumen compacto
      final esRes = p.esResidenteColombia!;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.success.withValues(alpha: 0.07),
          border: Border.all(color: AppTheme.success.withValues(alpha: 0.25)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.verified_outlined, color: AppTheme.success, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'DIAN: ciudad ${p.codigoCiudadDian} · ${p.tipoRegimenTributario} · ${esRes ? "Residente" : "No residente"}',
                style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.7)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // Faltan campos: mostrar campos editables con lo que haya
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!tieneCiudad || !tieneResidente)
          Row(children: [
            SizedBox(
              width: 160,
              child: _field(_cityCodeCtrl, '149 = Bogotá, 836 = Medellín', label: 'Código ciudad DIAN'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(_esResidente ? 'Residente Colombia' : 'No residente',
                    style: TextStyle(fontSize: 12, color: cs.onSurface)),
                value: _esResidente,
                activeThumbColor: AppTheme.success,
                onChanged: (v) => setState(() => _esResidente = v),
              ),
            ),
          ]),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '⚠️ Configura los campos DIAN en el perfil del proveedor para no tener que ingresarlos cada vez.',
            style: TextStyle(color: Colors.orange.shade700, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildProveedorBasico(FacturaCompra compra, ColorScheme cs) {
    return Row(
      children: [
        Icon(Icons.person_outline, color: cs.onSurface.withValues(alpha:0.5), size: 20),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(compra.proveedorNombre, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: cs.onSurface)),
            if (compra.proveedorNit?.isNotEmpty == true)
              Text('NIT: ${compra.proveedorNit}', style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha:0.6))),
          ],
        ),
      ],
    );
  }

  Widget _totalRow(String label, String value, ColorScheme cs, {bool bold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha:0.6))),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color ?? cs.onSurface)),
      ],
    );
  }

  Widget _buildSeccionProveedorManual(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Tipo de Proveedor', cs),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(border: Border.all(color: cs.onSurface.withValues(alpha:0.2)), borderRadius: BorderRadius.circular(8)),
          child: SwitchListTile(
            dense: true,
            title: Text(_esResidente ? 'Proveedor colombiano (residente)' : 'Proveedor extranjero', style: TextStyle(fontSize: 13, color: cs.onSurface)),
            subtitle: Text(_esResidente ? 'Operación tipo 9' : 'Operación tipo 10', style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha:0.5))),
            value: _esResidente,
            activeColor: AppTheme.success,
            onChanged: (v) => setState(() => _esResidente = v),
          ),
        ),
        const SizedBox(height: 12),
        _sectionTitle('Datos del Proveedor', cs),
        const SizedBox(height: 8),
        if (_proveedores.isNotEmpty) ...[
          _ProveedorBuscador(proveedores: _proveedores, onSelected: _seleccionarProveedor),
          const SizedBox(height: 10),
        ],
        Row(children: [
          Expanded(child: _field(_proveedorNombreCtrl, 'Nombre proveedor *', validator: (v) => (v?.isEmpty ?? true) ? 'Requerido' : null)),
          const SizedBox(width: 12),
          Expanded(child: _field(_proveedorNitCtrl, 'NIT / Cédula *', validator: (v) => (v?.isEmpty ?? true) ? 'Requerido' : null)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _field(_proveedorEmailCtrl, 'Correo electrónico')),
          const SizedBox(width: 12),
          Expanded(child: _field(_proveedorDireccionCtrl, 'Dirección')),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          SizedBox(width: 160, child: _field(_cityCodeCtrl, '149 = Bogotá', label: 'Código ciudad DIAN')),
          if (!_esResidente) ...[
            const SizedBox(width: 10),
            Expanded(child: _field(_ciudadExtranjeraCtrl, 'ej: New York', label: 'Ciudad extranjera')),
            const SizedBox(width: 10),
            Expanded(child: _field(_codigoPaisCtrl, 'ej: 239 = USA', label: 'Código país DIAN', keyboardType: TextInputType.number)),
          ],
        ]),
      ],
    );
  }

  Widget _buildSeccionDetalle(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Detalle del Documento', cs),
        const SizedBox(height: 8),
        _field(_descripcionCtrl, 'Descripción del bien/servicio *', validator: (v) => (v?.isEmpty ?? true) ? 'Requerido' : null),
        const SizedBox(height: 10),
        _field(_valorCtrl, 'Valor total *',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Requerido';
            final n = double.tryParse(v.replaceAll(',', '.'));
            if (n == null || n <= 0) return 'Valor inválido';
            return null;
          }),
      ],
    );
  }

  Widget _buildInfoDsExistente(ColorScheme cs, Color color) {
    final ds = widget.dsExistente!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.onSurface.withValues(alpha:0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Proveedor: ${ds.proveedor}', style: TextStyle(color: cs.onSurface, fontSize: 13)),
                Text('Total: ${CurrencyUtils.format(ds.total)}', style: TextStyle(color: cs.onSurface.withValues(alpha:0.6), fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionAjuste(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Tipo de Ajuste', cs),
        const SizedBox(height: 6),
        DropdownButtonFormField<int>(
          initialValue: _motivoAjusteId,
          decoration: _inputDecoration('Selecciona el tipo de ajuste'),
          dropdownColor: cs.surface,
          style: TextStyle(color: cs.onSurface, fontSize: 14),
          items: _motivosAjuste.map((m) => DropdownMenuItem(value: m.$1, child: Text(m.$2))).toList(),
          onChanged: (v) => setState(() => _motivoAjusteId = v ?? 1),
        ),
        const SizedBox(height: 10),
        _field(_motivoDescCtrl, 'Descripción del ajuste (opcional)'),
      ],
    );
  }

  Widget _buildSeccionPago(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Forma de Pago', cs),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: _paymentMethodId,
              decoration: _inputDecoration('Método', label: 'Método'),
              dropdownColor: cs.surface,
              style: TextStyle(color: cs.onSurface, fontSize: 13),
              items: _formasPago.map((f) => DropdownMenuItem(value: f.$1, child: Text(f.$2))).toList(),
              onChanged: (v) => setState(() => _paymentMethodId = v ?? 1),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: _meansPaymentId,
              decoration: _inputDecoration('Medio', label: 'Medio'),
              dropdownColor: cs.surface,
              style: TextStyle(color: cs.onSurface, fontSize: 13),
              items: _mediosPago.map((f) => DropdownMenuItem(value: f.$1, child: Text(f.$2))).toList(),
              onChanged: (v) => setState(() => _meansPaymentId = v ?? 10),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        _field(_dueDateCtrl, 'YYYY-MM-DD', label: 'Fecha de vencimiento',
          validator: (v) {
            if (v == null || v.isEmpty) return 'Requerido';
            if (DateTime.tryParse(v) == null) return 'Formato YYYY-MM-DD';
            return null;
          }),
      ],
    );
  }

  Widget _buildError(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppTheme.error.withValues(alpha:0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppTheme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(_errorMsg!, style: TextStyle(color: AppTheme.error, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildBotones(String titulo, Color color, ColorScheme cs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: Text('Cancelar', style: TextStyle(color: cs.onSurface.withValues(alpha:0.6))),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: _loading ? null : _emitir,
          icon: _loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Icon(_esAjuste ? Icons.edit_document : Icons.send_rounded, color: Colors.white, size: 16),
          label: Text(_loading ? 'Enviando...' : 'Emitir $titulo', style: const TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String t, ColorScheme cs) => Text(
    t,
    style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600, fontSize: 13),
  );

  Widget _field(TextEditingController ctrl, String hint, {
    String? label, TextInputType? keyboardType, String? Function(String?)? validator,
  }) => TextFormField(
    controller: ctrl,
    keyboardType: keyboardType,
    decoration: _inputDecoration(hint, label: label),
    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
    validator: validator,
  );

  InputDecoration _inputDecoration(String hint, {String? label}) => InputDecoration(
    labelText: label,
    hintText: hint,
    hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.4), fontSize: 11),
    labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha:0.7), fontSize: 13),
    filled: true,
    fillColor: Theme.of(context).colorScheme.surface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    isDense: true,
  );
}

// ── Buscador autocomplete de proveedores ─────────────────────────────────────

class _ProveedorBuscador extends StatelessWidget {
  final List<Proveedor> proveedores;
  final void Function(Proveedor) onSelected;

  const _ProveedorBuscador({required this.proveedores, required this.onSelected});

  String _display(Proveedor p) =>
      [p.nombre, p.apellidos].where((s) => s != null && s.isNotEmpty).join(' ');

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Proveedor>(
      optionsBuilder: (v) {
        if (v.text.length < 2) return const Iterable.empty();
        final q = v.text.toLowerCase();
        return proveedores.where((p) => _display(p).toLowerCase().contains(q) || (p.documento ?? '').contains(q));
      },
      displayStringForOption: _display,
      onSelected: onSelected,
      fieldViewBuilder: (ctx, ctrl, focusNode, _) {
        return TextField(
          controller: ctrl,
          focusNode: focusNode,
          style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Buscar proveedor registrado...',
            hintStyle: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha:0.5), fontSize: 12),
            prefixIcon: Icon(Icons.search, size: 18, color: AppTheme.success),
            filled: true,
            fillColor: AppTheme.success.withValues(alpha:0.06),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.success.withValues(alpha:0.4))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.success.withValues(alpha:0.4))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        );
      },
      optionsViewBuilder: (ctx, onSel, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 500),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final p = options.elementAt(i);
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: AppTheme.success.withValues(alpha:0.12),
                      child: Text(_display(p).isNotEmpty ? _display(p)[0].toUpperCase() : '?',
                          style: TextStyle(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(_display(p), style: const TextStyle(fontSize: 13)),
                    subtitle: p.documento != null ? Text('${p.tipoId ?? "Doc"}: ${p.documento}', style: const TextStyle(fontSize: 11)) : null,
                    onTap: () => onSel(p),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
