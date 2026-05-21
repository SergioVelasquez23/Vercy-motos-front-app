import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import '../config/endpoints_config.dart';
import '../utils/logger.dart';

/// Servicio para integración con API de Facturación Matias
/// Cubre: Facturas, Nota Crédito, Nota Débito, Doc. Soporte,
///        Nota Ajuste DS, POS Electrónico, Nómina y ajustes.
class MatiasService {
  static String get _base => '${EndpointsConfig().currentBaseUrl}/api/matias';
  static const Duration _timeout = Duration(seconds: 60);
  static const String TAG = '🔌 MATIAS';

  // ──────────────────────────────────────────────────────────────────────────
  //  🔐 AUTENTICACIÓN
  // ──────────────────────────────────────────────────────────────────────────

  static Future<bool> authenticate() async {
    try {
      appLog('$TAG 🔐 Autenticando con Matias API...');
      final res = await http.post(
        Uri.parse('$_base/authenticate'),
        headers: _headers(),
      ).timeout(_timeout, onTimeout: () {
        throw TimeoutException('Timeout en autenticación');
      });
      
      if (res.statusCode == 200) {
        appLog('$TAG ✅ Autenticación exitosa');
        return true;
      } else {
        appLog('$TAG ❌ Autenticación falló: ${res.statusCode} - ${res.body}');
        return false;
      }
    } catch (e) {
      appLog('$TAG ❌ authenticate: $e');
      return false;
    }
  }

  static Future<bool> checkStatus() async {
    try {
      appLog('$TAG 🔍 Verificando status de autenticación...');
      final res = await http.get(
        Uri.parse('$_base/status'),
        headers: _headers(),
      ).timeout(_timeout, onTimeout: () {
        throw TimeoutException('Timeout verificando status');
      });
      
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        final isAuth = j['data']?['authenticated'] ?? false;
        if (isAuth) {
          appLog('$TAG ✅ Autenticado');
        } else {
          appLog('$TAG ⚠️ No autenticado');
        }
        return isAuth;
      } else {
        appLog('$TAG ⚠️ Status: ${res.statusCode}');
        return false;
      }
    } catch (e) {
      appLog('$TAG ❌ checkStatus: $e');
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  📊 TABLAS MAESTRAS (LOOKUP)
  // ──────────────────────────────────────────────────────────────────────────

  /// Obtener tipos de documento disponibles (CC, NIT, CE, etc.)
  static Future<List<String>> obtenerTiposDocumento() async {
    return _getLookupList('lookup/tipos-documento', 'tipos de documento');
  }

  /// Obtener formas de pago (01, 02, 03, etc.)
  static Future<List<String>> obtenerFormasPago() async {
    return _getLookupList('lookup/formas-pago', 'formas de pago');
  }

  /// Obtener medios de pago (10, 20, 41, etc.)
  static Future<List<String>> obtenerMediosPago() async {
    return _getLookupList('lookup/medios-pago', 'medios de pago');
  }

  /// Obtener tipos de organización (1, 2, 3, etc.)
  static Future<List<String>> obtenerTiposOrganizacion() async {
    return _getLookupList('lookup/tipos-organizacion', 'tipos de organización');
  }

  /// Obtener tipos de operación
  static Future<List<String>> obtenerTiposOperacion() async {
    return _getLookupList('lookup/tipos-operacion', 'tipos de operación');
  }

  /// Obtener tipos de documento electrónico (01, 02, 03, etc.)
  static Future<List<String>> obtenerTiposDocumentoElectronico() async {
    return _getLookupList('lookup/tipos-documento-electronico', 'tipos de documento electrónico');
  }

  /// Obtener unidades de medida (94, 69, ACR, etc.)
  static Future<List<String>> obtenerUnidadesMedida() async {
    return _getLookupList('lookup/unidades-medida', 'unidades de medida');
  }

  /// Obtener conceptos de nota de corrección
  static Future<List<String>> obtenerConceptosNotaCorreccion() async {
    return _getLookupList('lookup/conceptos-nota-correccion', 'conceptos de nota de corrección');
  }

  /// Obtener monedas disponibles (COP, USD, etc.)
  static Future<List<String>> obtenerMonedas() async {
    return _getLookupList('lookup/monedas', 'monedas');
  }

  /// Helper privado para obtener listas de lookup con manejo de errores robusto
  static Future<List<String>> _getLookupList(String endpoint, String nombre) async {
    try {
      appLog('$TAG 📥 Obteniendo $nombre...');
      final url = '$_base/$endpoint';
      final res = await http.get(
        Uri.parse(url),
        headers: _headers(),
      ).timeout(_timeout);

      appLog('$TAG 📊 $endpoint: StatusCode ${res.statusCode}');

      if (res.statusCode == 200) {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        
        if (j['success'] != true) {
          appLog('$TAG ⚠️ Respuesta con success=false: ${j['message']}');
          return [];
        }
        
        final data = j['data'];
        if (data == null) {
          appLog('$TAG ⚠️ No hay datos en la respuesta');
          return [];
        }
        
        List<String> list = [];
        if (data is List) {
          list = List<String>.from(data);
        }
        appLog('$TAG ✅ $nombre: ${list.length} registros');
        return list;
      } else {
        appLog('$TAG ❌ Error HTTP ${res.statusCode}: ${res.body}');
        return [];
      }
    } catch (e) {
      appLog('$TAG ❌ _getLookupList($endpoint): $e');
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  📝 FACTURA (POS / Pedido)
  // ──────────────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> facturarPedido(
    String pedidoId, {
    String? token,
    Map<String, dynamic>? payload,
  }) async {
    await _ensureAuth();

    // Si enviamos el payload, removemos document_number para usar el autoincrement del backend
    if (payload != null) {
      payload.remove('document_number');
    }

    return _post(
      '$_base/documento-mesa/$pedidoId/facturar',
      payload,
      token: token,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  📝 NOTA CRÉDITO
  // ──────────────────────────────────────────────────────────────────────────

  /// Emite una Nota Crédito sobre una factura existente.
  /// [facturaNumero]  número de la factura (ej: "LZT836")
  /// [facturaCufe]    CUFE de la factura
  /// [facturaFecha]   fecha de la factura (YYYY-MM-DD)
  /// [motivoId]       1=Anulación, 2=Devolución parcial, 3=Rebaja precio,
  ///                  4=Ajuste precio, 5=Otra
  /// [motivo]         descripción libre del motivo
  /// [invoicePayload] cuerpo completo de la nota crédito (líneas, totales, etc.)
  static Future<MatiasDocumentoResult> emitirNotaCredito({
    required String facturaNumero,
    required String facturaCufe,
    required String facturaFecha,
    required int motivoId,
    required String motivo,
    required Map<String, dynamic> invoicePayload,
    String? token,
  }) async {
    await _ensureAuth();
    final body = {
      ...invoicePayload,
      'type_document_id': 5,
      'billing_reference': {
        'number': facturaNumero,
        'uuid': facturaCufe,
        'date': facturaFecha,
      },
      'discrepancy_response': {'reference_id': motivoId, 'description': motivo},
    };
    return _postDocumento('$_base/notes/credit', body, token: token);
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  📝 NOTA DÉBITO
  // ──────────────────────────────────────────────────────────────────────────

  /// Emite una Nota Débito sobre una factura a crédito.
  /// [motivoId] 1=Intereses, 2=Gastos por cobrar, 3=Cambio en valor
  static Future<MatiasDocumentoResult> emitirNotaDebito({
    required String facturaNumero,
    required String facturaCufe,
    required String facturaFecha,
    required int motivoId,
    required String motivo,
    required Map<String, dynamic> invoicePayload,
    String? token,
  }) async {
    await _ensureAuth();
    final body = {
      ...invoicePayload,
      'type_document_id': 4,
      'billing_reference': {
        'number': facturaNumero,
        'uuid': facturaCufe,
        'date': facturaFecha,
      },
      'discrepancy_response': {'reference_id': motivoId, 'description': motivo},
    };
    return _postDocumento('$_base/notes/debit', body, token: token);
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  📄 DOCUMENTO SOPORTE
  // ──────────────────────────────────────────────────────────────────────────

  /// Crea un Documento Soporte para proveedores no obligados a facturar.
  static Future<MatiasDocumentoResult> crearDocumentoSoporte(
    Map<String, dynamic> payload, {
    String? token,
  }) async {
    await _ensureAuth();
    final body = {...payload, 'type_document_id': 5};
    return _postDocumento('$_base/ds/document', body, token: token);
  }

  /// Nota de Ajuste de un Documento Soporte.
  /// [motivoId] tipo de ajuste (ver endpoint /ep/adjustment-note-type)
  static Future<MatiasDocumentoResult> ajustarDocumentoSoporte({
    required String dsNumero,
    required String dsCude,
    required String dsFecha,
    required int motivoId,
    required String motivo,
    required Map<String, dynamic> invoicePayload,
    String? token,
  }) async {
    await _ensureAuth();
    final body = {
      ...invoicePayload,
      'billing_reference': {
        'number': dsNumero,
        'uuid': dsCude,
        'date': dsFecha,
      },
      'discrepancy_response': {'reference_id': motivoId, 'description': motivo},
    };
    return _postDocumento('$_base/ds/adjustment-note', body, token: token);
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  🏪 DOCUMENTO POS
  // ──────────────────────────────────────────────────────────────────────────

  /// Emite una Factura Electrónica Normal con consecutivo manejado manualmente.
  /// 1️⃣ AUTO-INCREMENT (Factura con consecutivo automático)
  /// Requiere: documentoId existente en local (creado del pedido pagado)
  /// POST /api/matias/invoices/auto-increment
  static Future<MatiasDocumentoResult> emitirFacturaElectronica(
    Map<String, dynamic> payload, {
    String? token,
  }) async {
    await _ensureAuth();
    final body = {...payload};
    appLog('$TAG 📤 POST /invoices/auto-increment');
    return _postDocumento('$_base/invoices/auto-increment', body, token: token);
  }

  /// 2️⃣ POS ELECTRÓNICO (Sin datos de cliente obligatorios)
  /// No requiere: Cliente previo, genera consumidor final automático
  /// POST /api/matias/pos/documents
  static Future<MatiasDocumentoResult> emitirDocumentoPOS(
    Map<String, dynamic> payload, {
    String? token,
  }) async {
    await _ensureAuth();
    final body = {...payload, 'type_document_id': 20};
    appLog('$TAG 📤 POST /pos/documents (Tipo: POS Electrónico)');
    return _postDocumento('$_base/pos/documents', body, token: token);
  }

  /// 🔧 CONSTRUCTOR DE DOCUMENTO POS COMPLETO
  /// Construye un documento POS electrónico completo con todos los campos
  /// requeridos por Matías a partir de un [Pedido] y la [NegocioInfo].
  ///
  /// Toma del pedido:
  ///   • Cliente real (`pedido.datosAdicionales`) si existe, sino "Consumidor Final"
  ///   • Por cada línea: porcentaje y valor de IVA, porcentaje y valor de descuento
  ///   • Descuento general (`pedido.descuentoGeneral`)
  ///   • Forma de pago / pagos parciales
  ///
  /// Agrupa los `tax_totals` finales por porcentaje real de IVA, no los manda en 0.
  static Map<String, dynamic> buildCompletePOSDocument({
    required dynamic pedido, // Pedido object
    required dynamic negocioInfo, // NegocioInfo object
    required String resolutionNumber,
    int type_document_id = 20, // POS tipo 20
  }) {
    // Obtener fecha y hora actuales
    final now = DateTime.now();
    final date = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final time = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    final docNum = (now.millisecondsSinceEpoch ~/ 1000).toString();

    // ── 1) Totales recalculados desde los items ──────────────────────────
    final items = (pedido.items as List?) ?? const [];

    double subtotalBruto = 0;     // Σ (cant × precio) — antes de descuentos
    double totalDescuentosItem = 0;
    double totalImpuestos = 0;

    // tax_totals agrupados por porcentaje de IVA
    final Map<int, _TaxGroup> taxGroups = {};

    for (final item in items) {
      final qty = _asDouble(item.cantidad);
      final price = _asDouble(item.precioUnitario);
      final descValor = _asDouble(item.valorDescuento);
      final impValor = _asDouble(item.valorImpuesto);
      final impPct = _asDouble(item.porcentajeImpuesto).round();

      final lineGross = qty * price;
      final lineBase = lineGross - descValor; // base gravable

      subtotalBruto += lineGross;
      totalDescuentosItem += descValor;
      totalImpuestos += impValor;

      final group = taxGroups.putIfAbsent(impPct, () => _TaxGroup(impPct));
      group.taxableAmount += lineBase;
      group.taxAmount += impValor;
    }

    final descuentoGeneral = _asDouble(pedido.descuentoGeneral);
    final baseImponible = subtotalBruto - totalDescuentosItem - descuentoGeneral;
    final totalFinal = baseImponible + totalImpuestos;
    final totalFinalStr = totalFinal.toStringAsFixed(2);

    // Si no hubo items con impuesto, dejar un grupo en 0% para que el
    // schema no quede vacío.
    if (taxGroups.isEmpty) {
      taxGroups[0] = _TaxGroup(0)..taxableAmount = baseImponible;
    }

    final taxTotalsList = taxGroups.values
        .map((g) => {
              'tax_id': '1',
              'percent': g.percent,
              'tax_amount': g.taxAmount.toStringAsFixed(2),
              'taxable_amount': g.taxableAmount.toStringAsFixed(2),
            })
        .toList();

    // ── 2) Construir líneas con IVA y descuento real ─────────────────────
    final lines = <Map<String, dynamic>>[];
    for (var idx = 0; idx < items.length; idx++) {
      final item = items[idx];
      final qty = _asDouble(item.cantidad);
      final price = _asDouble(item.precioUnitario);
      final descValor = _asDouble(item.valorDescuento);
      final descPct = _asDouble(item.porcentajeDescuento);
      final impValor = _asDouble(item.valorImpuesto);
      final impPct = _asDouble(item.porcentajeImpuesto).round();

      final lineGross = qty * price;
      final lineBase = lineGross - descValor;

      final lineMap = <String, dynamic>{
        'line_number': (idx + 1).toString(),
        'description': item.productoNombre ?? 'Producto',
        'code': item.productoId ?? 'PROD',
        'invoiced_quantity': qty.toStringAsFixed(0),
        'base_quantity': qty.toStringAsFixed(0),
        'quantity_units_id': '1093', // TODO: leer unidad de medida real del producto
        'price_amount': price.toStringAsFixed(2),
        'line_extension_amount': lineBase.toStringAsFixed(2),
        'free_of_charge_indicator': false,
        'type_item_identifications_id': '4',
        'reference_price_id': '1',
        'um': 'UND',
        'tax_totals': [
          {
            'tax_id': '1',
            'percent': impPct,
            'tax_amount': impValor.toStringAsFixed(2),
            'taxable_amount': lineBase.toStringAsFixed(2),
          }
        ],
      };

      // Solo agregar allowance_charges si hay descuento aplicado.
      if (descValor > 0) {
        lineMap['allowance_charges'] = [
          {
            'discount_id': '1',
            'charge_indicator': false, // false = descuento, true = recargo
            'allowance_charge_reason': 'Descuento',
            'amount': descValor.toStringAsFixed(2),
            'base_amount': lineGross.toStringAsFixed(2),
            if (descPct > 0)
              'multiplier_factor_numeric': descPct.toStringAsFixed(2),
          }
        ];
      }

      lines.add(lineMap);
    }

    // ── 3) Cliente: usar datos reales del pedido si existen ──────────────
    final customer = _buildCustomerFromPedido(pedido);

    // ── 4) Montos legales ────────────────────────────────────────────────
    final legalMonetaryTotals = <String, dynamic>{
      'line_extension_amount': subtotalBruto.toStringAsFixed(2),
      'tax_exclusive_amount': baseImponible.toStringAsFixed(2),
      'tax_inclusive_amount': totalFinal.toStringAsFixed(2),
      'payable_amount': totalFinal.toStringAsFixed(2),
    };
    final totalDescuentos = totalDescuentosItem + descuentoGeneral;
    if (totalDescuentos > 0) {
      legalMonetaryTotals['allowance_total_amount'] =
          totalDescuentos.toStringAsFixed(2);
    }

    return {
      // Campos obligatorios para Matias
      'resolution_number': resolutionNumber,
      'prefix': negocioInfo.prefijo ?? negocioInfo.prefijoDocumento ?? 'POS',
      'document_number': docNum,
      'date': date,
      'time': time,
      'type_document_id': type_document_id,
      'graphic_representation': 1,
      'send_email': 0,
      'notes': customer['company_name'] == 'Consumidor Final'
          ? 'Documento POS rápido - Sin cliente'
          : 'Documento POS rápido',

      // Operación y moneda
      'operation_type_id': 10, // Venta estándar
      'currency_id': 272, // Peso colombiano

      // POS - Información de punto de venta
      'cash_register_number': negocioInfo.posCashierName ?? 'CAJA-01',
      'seller_name': negocioInfo.posCashierName ?? 'Vendedor',

      // Información del software/fabricante
      'software_manufacturer': {
        'owner_name': negocioInfo.softwareOwnerName ?? negocioInfo.nombre ?? 'Software Owner',
        'company_name': negocioInfo.softwareCompanyName ?? negocioInfo.nombre ?? 'Software Company',
        'software_name': negocioInfo.softwareName ?? 'Vercy POS',
      },

      // Punto de venta
      'point_of_sale': {
        'cashier_name': negocioInfo.posCashierName ?? 'Vendedor',
        'terminal_number': negocioInfo.posTerminalNumber ?? 'T001',
        'cashier_type': negocioInfo.posCashierType ?? 'Dependiente',
        'sales_code': negocioInfo.posSalesCode ?? 'V001',
        'address': negocioInfo.direccion ?? 'Sin dirección',
        'sub_total': subtotalBruto.toStringAsFixed(2),
        'total': totalFinalStr,
      },

      'customer': customer,
      'lines': lines,
      'legal_monetary_totals': legalMonetaryTotals,
      'tax_totals': taxTotalsList,

      // Información de pago — lee del pedido en vez de hardcodear "EFECTIVO".
      // Si hay pagos parciales (pago mixto) crea una entrada por cada uno;
      // si no, una sola con la formaPago del pedido.
      'payments': _buildPaymentsFromPedido(pedido, totalFinalStr, date),
    };
  }

  /// Helper: convierte un dynamic (int, double, num, String, null) a double.
  static double _asDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  /// Construye el bloque `customer` del documento. Si el pedido tiene cliente
  /// real (en `datosAdicionales`) lo usa; si no, retorna "Consumidor Final".
  static Map<String, dynamic> _buildCustomerFromPedido(dynamic pedido) {
    final datos = pedido.datosAdicionales as Map<String, dynamic>?;
    final nombreCliente = (datos?['clienteNombreCompleto']?.toString()
            ?? pedido.cliente?.toString()
            ?? '')
        .trim();

    final esConsumidorFinal = nombreCliente.isEmpty ||
        nombreCliente.toUpperCase().contains('CONSUMIDOR FINAL');

    if (esConsumidorFinal) return _consumidorFinalDefault();

    // Limpiar NIT: a veces viene como "CC 1234567" o "NIT 900123456-7"
    String? nit = datos?['clienteNit']?.toString();
    if (nit != null) {
      nit = nit
          .replaceAll(RegExp(r'^(CC|NIT|CE|TI|Pasaporte)\s*'), '')
          .split('-')
          .first
          .trim();
    }
    final tipoId = (datos?['clienteTipoId']?.toString() ?? 'CC').toUpperCase();
    final esNit = tipoId == 'NIT';
    final direccion = datos?['clienteDireccion']?.toString() ?? '';
    final telefono = datos?['clienteTelefono']?.toString() ?? '';
    final correo = datos?['clienteCorreo']?.toString() ?? '';

    return {
      'identity_document_id': _mapTipoIdentificacionToMatiasId(tipoId),
      'type_organization_id': esNit ? 1 : 2, // 1=Jurídica, 2=Natural
      'tax_regime_id': esNit ? 1 : 2,
      'tax_level_id': 5, // TODO: leer responsableIVA del cliente
      'company_name': nombreCliente,
      'dni': (nit?.isNotEmpty == true) ? nit : '222222222222',
      'city_id': '836', // TODO: agregar campo cityId al modelo Cliente
      'country_id': '45',
      'address': direccion.isNotEmpty ? direccion : 'Sin dirección',
      'postal_code': '000000',
      'mobile': telefono.isNotEmpty ? telefono : '0000000000',
      'email': correo.isNotEmpty ? correo : 'cliente@sin-correo.com',
    };
  }

  /// Datos por defecto para consumidor final (cuando el pedido no tiene
  /// cliente registrado).
  static Map<String, dynamic> _consumidorFinalDefault() {
    return {
      'identity_document_id': '1',
      'type_organization_id': 2,
      'tax_regime_id': 2,
      'tax_level_id': 5,
      'company_name': 'Consumidor Final',
      'dni': '222222222222', // DNI estándar DIAN para consumidor final
      'city_id': '836',
      'country_id': '45',
      'address': 'Sin dirección',
      'postal_code': '000000',
      'mobile': '0000000000',
      'email': 'cliente@sin-correo.com',
    };
  }

  /// Mapea el tipo de identificación del cliente al ID que espera Matías.
  /// Los IDs de Matías pueden no coincidir con los códigos DIAN — verificar
  /// con `lookup/tipos-documento` si hay rechazo.
  static String _mapTipoIdentificacionToMatiasId(String tipo) {
    switch (tipo.toUpperCase()) {
      case 'CC':
        return '1'; // Cédula de ciudadanía
      case 'CE':
        return '2'; // Cédula de extranjería
      case 'NIT':
        return '6'; // NIT
      case 'TI':
        return '4'; // Tarjeta de identidad
      case 'PAS':
      case 'PASAPORTE':
        return '7';
      default:
        return '1';
    }
  }

  /// Mapea el string `formaPago` del pedido al `payment_method_id` que espera
  /// Matías. Los IDs siguen la tabla maestra de Matías (consulta vía
  /// `lookup/medios-pago` si necesitas validar). Si no se reconoce, cae a 1
  /// (Efectivo) que es lo más seguro para POS contado.
  static int _mapFormaPagoToMatiasId(String? formaPago) {
    if (formaPago == null || formaPago.isEmpty) return 1;
    final f = formaPago.toLowerCase().trim().replaceAll(' ', '_');
    switch (f) {
      case 'efectivo':
        return 1;
      case 'tarjeta_credito':
      case 'credito':
      case 'tc':
        return 2;
      case 'tarjeta_debito':
      case 'debito':
      case 'td':
        return 3;
      case 'transferencia':
      case 'transferencia_bancaria':
      case 'nequi':
      case 'daviplata':
      case 'pse':
        return 4;
      case 'cheque':
        return 5;
      default:
        return 1; // Default Efectivo
    }
  }

  /// Construye el array `payments` para el documento POS de Matías a partir
  /// del pedido. Soporta pago único (`formaPago`) y pago mixto
  /// (`pagosParciales` con varios montos/formas).
  static List<Map<String, dynamic>> _buildPaymentsFromPedido(
    dynamic pedido,
    String total,
    String date,
  ) {
    // Pago mixto: una entrada por cada pago parcial.
    final parciales = pedido.pagosParciales as List? ?? const [];
    if (parciales.isNotEmpty) {
      return parciales.map<Map<String, dynamic>>((p) {
        return {
          'payment_method_id': _mapFormaPagoToMatiasId(p.formaPago as String?),
          'means_payment_id': 10, // Contado — el pedido ya fue pagado
          'value_paid': (p.monto as num).toStringAsFixed(2),
          'payment_due_date': date,
        };
      }).toList();
    }

    // Pago único: lo que esté en pedido.formaPago.
    return [
      {
        'payment_method_id': _mapFormaPagoToMatiasId(pedido.formaPago as String?),
        'means_payment_id': 10, // Contado
        'value_paid': total,
        'payment_due_date': date,
      }
    ];
  }

  /// Reenvía un POS rechazado por la DIAN.
  static Future<MatiasDocumentoResult> reenviarPOS(
    String uuid, {
    String? token,
  }) async {
    await _ensureAuth();
    return _patch('$_base/pos/documents/$uuid/resend', token: token);
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  💼 NÓMINA
  // ──────────────────────────────────────────────────────────────────────────

  static Future<MatiasDocumentoResult> enviarNomina(
    Map<String, dynamic> payload, {
    String? token,
  }) async {
    await _ensureAuth();
    return _postDocumento('$_base/ep/payroll', payload, token: token);
  }

  static Future<MatiasDocumentoResult> reemplazarNomina(
    Map<String, dynamic> payload, {
    String? token,
  }) async {
    await _ensureAuth();
    return _postDocumento('$_base/ep/payroll/replace', payload, token: token);
  }

  static Future<MatiasDocumentoResult> eliminarNomina(
    Map<String, dynamic> payload, {
    String? token,
  }) async {
    await _ensureAuth();
    return _postDocumento('$_base/ep/payroll/delete', payload, token: token);
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  🔄 REENVÍO GENÉRICO (auto-increment PATCH)
  // ──────────────────────────────────────────────────────────────────────────

  /// Reenvía cualquier documento del grupo auto-increment rechazado por la DIAN.
  ///
  /// Backend: PATCH /api/matias/auto-increment/{tipo}/{uuid}
  /// [tipo]: 'invoices' | 'credit-notes' | 'debit-notes' |
  ///        'adjustment-notes' | 'support-documents'
  /// [uuid]: UUID del documento rechazado
  static Future<MatiasDocumentoResult> reenviarDocumentoAutoIncrement(
    String tipo,
    String uuid, {
    String? token,
  }) async {
    await _ensureAuth();
    return _patch('$_base/auto-increment/$tipo/$uuid', token: token);
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  � DESCARGAS Y CONSULTAS
  // ──────────────────────────────────────────────────────────────────────────

  /// Consultar estado detallado del documento en la DIAN.
  ///
  /// Backend: GET /api/matias/status/documento/{trackId}
  /// [trackId] puede ser CUFE/CUNE/XmlDocumentKey.
  /// Retorna: Map con el MatiasDocumentStatus serializado (status, message, etc.)
  static Future<Map<String, dynamic>?> consultarStatusDIAN(
    String trackId, {
    String? token,
  }) async {
    try {
      await _ensureAuth();
      appLog('$TAG 🔍 GET /status/documento/$trackId');
      final res = await http.get(
        Uri.parse('$_base/status/documento/$trackId'),
        headers: _headers(token: token),
      ).timeout(_timeout, onTimeout: () {
        throw TimeoutException('Timeout consultando status DIAN');
      });

      if (res.statusCode != 200) {
        appLog('$TAG ❌ status/documento: ${res.statusCode} - ${res.body}');
        return null;
      }
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      if (j['success'] != true) return null;
      final data = j['data'];
      if (data is Map<String, dynamic>) {
        appLog('$TAG ✅ Status: ${data['status'] ?? data['estado']}');
        return data;
      }
      return null;
    } catch (e) {
      appLog('$TAG ❌ consultarStatusDIAN: $e');
      return null;
    }
  }

  /// Obtener URL pública del código QR del documento.
  ///
  /// No hay endpoint dedicado: el QR viene incluido en la respuesta de
  /// GET /api/matias/document-pdf/{trackId} dentro de `data.qr`.
  /// Retorna: URL del QR (o la cadena qrDian como fallback) o null.
  static Future<String?> obtenerQRDocumento(
    String trackId, {
    String? token,
  }) async {
    try {
      final data = await consultarDatosFactura(trackId, token: token);
      final qr = data?['qr'];
      if (qr is Map) {
        final url = qr['url']?.toString();
        if (url != null && url.isNotEmpty) return url;
        final qrDian = qr['qrDian']?.toString();
        if (qrDian != null && qrDian.isNotEmpty) return qrDian;
      }
      appLog('$TAG ⚠️ QR no disponible para $trackId');
      return null;
    } catch (e) {
      appLog('$TAG ❌ obtenerQRDocumento: $e');
      return null;
    }
  }

  /// Descargar PDF de la factura.
  ///
  /// Backend: GET /api/matias/invoices/{cufe}/pdf
  /// Retorna `{ cufe, mimeType, base64 }` — Matias no expone URL pública,
  /// el backend entrega el binario codificado.
  static Future<Map<String, String>?> descargarPDF(
    String cufe, {
    String? token,
  }) async {
    return _descargarArchivo('pdf', cufe, token: token);
  }

  /// Obtiene la URL directa del PDF si Matias la expone.
  ///
  /// Usa `GET /api/matias/document-pdf/{trackId}` y lee `data.pdf.url`.
  /// Devuelve null si no hay URL (en ese caso el caller debe usar
  /// [descargarPDF] y abrir el binario base64).
  static Future<String?> obtenerURLPDF(
    String trackId, {
    String? token,
  }) async {
    try {
      final data = await consultarDatosFactura(trackId, token: token);
      final pdf = data?['pdf'];
      if (pdf is Map) {
        final url = pdf['url']?.toString();
        if (url != null && url.isNotEmpty) return url;
      }
      return null;
    } catch (e) {
      appLog('$TAG ❌ obtenerURLPDF: $e');
      return null;
    }
  }

  /// Descargar XML de la factura.
  ///
  /// Backend: GET /api/matias/invoices/{cufe}/xml
  /// Retorna `{ cufe, mimeType, base64 }`.
  static Future<Map<String, String>?> descargarXML(
    String cufe, {
    String? token,
  }) async {
    return _descargarArchivo('xml', cufe, token: token);
  }

  static Future<Map<String, String>?> _descargarArchivo(
    String tipo,
    String cufe, {
    String? token,
  }) async {
    try {
      await _ensureAuth();
      appLog('$TAG 📥 GET /invoices/$cufe/$tipo');
      final res = await http.get(
        Uri.parse('$_base/invoices/$cufe/$tipo'),
        headers: _headers(token: token),
      ).timeout(_timeout, onTimeout: () {
        throw TimeoutException('Timeout descargando $tipo');
      });

      if (res.statusCode != 200) {
        appLog('$TAG ❌ invoices/$tipo: ${res.statusCode} - ${res.body}');
        return null;
      }
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      if (j['success'] != true) return null;
      final data = j['data'];
      if (data is! Map<String, dynamic>) return null;
      final base64 = data['base64']?.toString();
      if (base64 == null || base64.isEmpty) {
        appLog('$TAG ⚠️ Respuesta sin campo base64');
        return null;
      }
      appLog('$TAG ✅ $tipo descargado: ${base64.length} chars base64');
      return {
        'cufe': data['cufe']?.toString() ?? cufe,
        'mimeType': data['mimeType']?.toString() ??
            (tipo == 'pdf' ? 'application/pdf' : 'application/xml'),
        'base64': base64,
      };
    } catch (e) {
      appLog('$TAG ❌ _descargarArchivo($tipo): $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  📥 PDF / EMAIL / CONTADOR (Matias API)
  // ──────────────────────────────────────────────────────────────────────────

  /// Consulta datos completos de la factura electrónica (PDF, QR, UUID, CUFE).
  ///
  /// Backend: GET /api/matias/document-pdf/{trackId}
  /// [trackId] puede ser CUFE/CUNE/XmlDocumentKey retornado al emitir.
  /// Retorna Map con claves: trackId, uuid, cufe, qr, pdf, message.
  static Future<Map<String, dynamic>?> consultarDatosFactura(
    String trackId, {
    String? token,
  }) async {
    try {
      await _ensureAuth();
      appLog('$TAG 📥 GET /document-pdf/$trackId (len=${trackId.length})');
      final res = await http.get(
        Uri.parse('$_base/document-pdf/$trackId'),
        headers: _headers(token: token),
      ).timeout(_timeout, onTimeout: () {
        throw TimeoutException('Timeout consultando datos del documento');
      });

      if (res.statusCode != 200) {
        appLog('$TAG ❌ document-pdf: ${res.statusCode} - ${res.body}');
        appLog('$TAG    → trackId enviado: "$trackId"');
        appLog('$TAG    → Si ves 500: bug del backend (MatiasApiClient.getPdfDocumentBytes lee bytes en vez de JSON)');
        return null;
      }
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      if (j['success'] != true) return null;
      final data = j['data'] as Map<String, dynamic>?;
      appLog('$TAG ✅ Datos factura obtenidos para $trackId — keys: ${data?.keys.toList()}');
      if (data?['pdf'] != null) {
        appLog('$TAG    → pdf field: ${data!['pdf']}');
      }
      return data;
    } catch (e) {
      appLog('$TAG ❌ consultarDatosFactura: $e');
      return null;
    }
  }

  /// Reenvía por correo la factura electrónica al cliente.
  ///
  /// Backend: POST /api/matias/invoices/{cufe}/resend-email
  /// Body: { "email": "destinatario@ejemplo.com" }
  static Future<MatiasDocumentoResult> reenviarCorreoFactura(
    String cufe,
    String email, {
    String? token,
  }) async {
    try {
      await _ensureAuth();
      appLog('$TAG ✉️ POST /invoices/$cufe/resend-email → $email');
      final res = await http.post(
        Uri.parse('$_base/invoices/$cufe/resend-email'),
        headers: _headers(token: token),
        body: jsonEncode({'email': email}),
      ).timeout(_timeout, onTimeout: () {
        throw TimeoutException('Timeout reenviando correo');
      });

      if (res.statusCode != 200) {
        String msg = 'Error HTTP ${res.statusCode}';
        try {
          final j = jsonDecode(res.body) as Map<String, dynamic>;
          msg = j['message']?.toString() ?? msg;
        } catch (_) {}
        appLog('$TAG ❌ resend-email: $msg');
        return MatiasDocumentoResult.error(msg);
      }

      final j = jsonDecode(res.body) as Map<String, dynamic>;
      return MatiasDocumentoResult.fromJson(j);
    } on TimeoutException catch (e) {
      return MatiasDocumentoResult.error('Timeout: $e');
    } catch (e) {
      appLog('$TAG ❌ reenviarCorreoFactura: $e');
      return MatiasDocumentoResult.error(e.toString());
    }
  }

  /// Obtiene la cantidad total de documentos emitidos en Matias.
  ///
  /// Backend: GET /api/matias/documentos?limit=1
  /// Lee `data.paginacion.total_registros` que es el contador global.
  /// Retorna -1 si no se pudo obtener.
  static Future<int> obtenerCantidadDocumentos({String? token}) async {
    try {
      await _ensureAuth();
      appLog('$TAG 📊 GET /documentos?limit=1 (cantidad)');
      final res = await http.get(
        Uri.parse('$_base/documentos?limit=1'),
        headers: _headers(token: token),
      ).timeout(_timeout, onTimeout: () {
        throw TimeoutException('Timeout obteniendo cantidad de documentos');
      });

      if (res.statusCode != 200) {
        appLog('$TAG ❌ documentos: ${res.statusCode} - ${res.body}');
        return -1;
      }
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      if (j['success'] != true) return -1;
      final data = j['data'] as Map<String, dynamic>?;
      final paginacion = data?['paginacion'] as Map<String, dynamic>?;
      // Fallback: si no hay paginación, usar 'cantidad' del propio response
      final total = paginacion?['total_registros'] ?? data?['cantidad'];
      if (total is int) return total;
      if (total is num) return total.toInt();
      if (total is String) return int.tryParse(total) ?? -1;
      return -1;
    } catch (e) {
      appLog('$TAG ❌ obtenerCantidadDocumentos: $e');
      return -1;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  �🛠️ PRIVADOS
  // ──────────────────────────────────────────────────────────────────────────

  static Future<void> _ensureAuth() async {
    final ok = await checkStatus();
    if (!ok) await authenticate();
  }

  static Map<String, String> _headers({String? token}) {
    final h = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) h['Authorization'] = 'Bearer $token';
    return h;
  }

  /// POST que devuelve MatiasDocumentoResult CON TIMEOUT y mejor logging
  static Future<MatiasDocumentoResult> _postDocumento(
    String url,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    try {
      appLog('$TAG 📤 POST: $url');
      final bodyJson = jsonEncode(body);
      final bodyPreview = bodyJson.length > 200 
        ? '${bodyJson.substring(0, 200)}...' 
        : bodyJson;
      appLog('$TAG 📋 Body: $bodyPreview');
      
      final res = await http.post(
        Uri.parse(url),
        headers: _headers(token: token),
        body: bodyJson,
      ).timeout(_timeout, onTimeout: () {
        throw TimeoutException('Timeout esperando respuesta de $url después de ${_timeout.inSeconds}s');
      });

      appLog('$TAG 📥 Status: ${res.statusCode}');
      final respBody = res.body.length > 500 
        ? '${res.body.substring(0, 500)}...' 
        : res.body;
      appLog('$TAG 📥 Response: $respBody');

      if (res.statusCode != 200 && res.statusCode != 201) {
        appLog('$TAG ❌ HTTP Error ${res.statusCode}');
        appLog('$TAG 📥 Response headers: ${res.headers}');
        appLog('$TAG 📥 Response body length: ${res.body.length}');
        
        // Parsear mensaje de error — backend usa formato ApiResponse
        String errorMessage = 'Error HTTP ${res.statusCode}';
        try {
          if (res.body.isEmpty) {
            errorMessage = 'Error HTTP ${res.statusCode}: Respuesta vacía del servidor';
          } else {
            final errorJson = jsonDecode(res.body) as Map<String, dynamic>;
            // ApiResponse: { success, code, message, data (detalles), timestamp }
            errorMessage = errorJson['message']?.toString() ??
                           errorJson['error']?.toString() ??
                           'Error desconocido';

            // Incluir código de error si está disponible
            final code = errorJson['code']?.toString();
            if (code != null && code.isNotEmpty) {
              errorMessage = '[$code] $errorMessage';
            }

            // Incluir detalles de validación si data es un Map de errores
            final data = errorJson['data'];
            if (data is Map && data.isNotEmpty) {
              final fieldErrors = data.entries
                  .map((e) => '${e.key}: ${e.value}')
                  .join(', ');
              errorMessage = '$errorMessage\n$fieldErrors';
            } else if (data is String && data.isNotEmpty) {
              errorMessage = '$errorMessage\n$data';
            }
          }
        } catch (e) {
          final bodyPreview = res.body.length > 300
              ? '${res.body.substring(0, 300)}...'
              : res.body;
          errorMessage = 'Error HTTP ${res.statusCode}: $bodyPreview';
        }
        
        appLog('$TAG ❌ Error parseado: $errorMessage');
        return MatiasDocumentoResult.error(errorMessage);
      }

      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final result = MatiasDocumentoResult.fromJson(j);
      
      if (result.success) {
        appLog('$TAG ✅ Éxito: ${result.documentKey}');
      } else {
        appLog('$TAG ⚠️ Fallo: ${result.message}');
      }
      
      return result;
    } on TimeoutException catch (e) {
      appLog('$TAG ❌ TIMEOUT: $e');
      return MatiasDocumentoResult.error('Timeout: $e');
    } catch (e) {
      appLog('$TAG ❌ _postDocumento: $e');
      return MatiasDocumentoResult.error(e.toString());
    }
  }

  /// POST legacy (retorna Map nullable — mantiene compatibilidad con facturarPedido)
  static Future<Map<String, dynamic>?> _post(
    String url,
    Map<String, dynamic>? body, {
    String? token,
  }) async {
    try {
      appLog('$TAG 📤 POST (legacy): $url');
      
      final res = await http.post(
        Uri.parse(url),
        headers: _headers(token: token),
        body: body != null ? jsonEncode(body) : null,
      ).timeout(_timeout, onTimeout: () {
        throw TimeoutException('Timeout en POST $url');
      });

      appLog('$TAG 📥 Status: ${res.statusCode}');
      
      if (res.statusCode != 200 && res.statusCode != 201) {
        appLog('$TAG ❌ HTTP Error ${res.statusCode}: ${res.body}');
        return null;
      }

      final j = jsonDecode(res.body);
      if (j['success'] == true) {
        appLog('$TAG ✅ Respuesta exitosa');
        return j['data'];
      } else {
        appLog('$TAG ⚠️ success=false: ${j['message']}');
        return null;
      }
    } on TimeoutException catch (e) {
      appLog('$TAG ❌ TIMEOUT: $e');
      return null;
    } catch (e) {
      appLog('$TAG ❌ _post legacy: $e');
      return null;
    }
  }

  /// PATCH para reenvíos
  static Future<MatiasDocumentoResult> _patch(
    String url, {
    String? token,
  }) async {
    try {
      appLog('$TAG 📤 PATCH: $url');
      
      final res = await http.patch(
        Uri.parse(url),
        headers: _headers(token: token),
      ).timeout(_timeout, onTimeout: () {
        throw TimeoutException('Timeout en PATCH $url');
      });

      appLog('$TAG 📥 Status: ${res.statusCode}');
      final respBody = res.body.length > 300 
        ? '${res.body.substring(0, 300)}...' 
        : res.body;
      appLog('$TAG 📥 Response: $respBody');

      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final result = MatiasDocumentoResult.fromJson(j);
      
      if (result.success) {
        appLog('$TAG ✅ PATCH exitoso');
      } else {
        appLog('$TAG ⚠️ PATCH falló: ${result.message}');
      }
      
      return result;
    } on TimeoutException catch (e) {
      appLog('$TAG ❌ TIMEOUT: $e');
      return MatiasDocumentoResult.error('Timeout: $e');
    } catch (e) {
      appLog('$TAG ❌ _patch: $e');
      return MatiasDocumentoResult.error(e.toString());
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────
//  📦 Modelo de resultado unificado
// ────────────────────────────────────────────────────────────────────────────

class MatiasDocumentoResult {
  final bool success;
  final String message;

  /// CUFE / CUNE / CUDE según el tipo de documento
  final String? documentKey;
  final String? pdfUrl;
  final String? xmlUrl;
  final Map<String, dynamic>? raw;

  const MatiasDocumentoResult({
    required this.success,
    required this.message,
    this.documentKey,
    this.pdfUrl,
    this.xmlUrl,
    this.raw,
  });

  factory MatiasDocumentoResult.fromJson(Map<String, dynamic> j) {
    // data puede ser Map (éxito) o String/null (detalle de error del backend)
    final rawData = j['data'];
    final data = rawData is Map<String, dynamic> ? rawData : <String, dynamic>{};
    return MatiasDocumentoResult(
      success: j['success'] == true,
      message: j['message']?.toString() ?? '',
      documentKey:
          data['cufe']?.toString() ??
          data['cune']?.toString() ??
          data['xmlDocumentKey']?.toString(),
      pdfUrl: data['pdf']?.toString(),
      raw: j,
    );
  }

  factory MatiasDocumentoResult.error(String msg) =>
      MatiasDocumentoResult(success: false, message: msg);
}

/// Acumulador interno usado por `buildCompletePOSDocument` para agrupar los
/// `tax_totals` por porcentaje real de IVA (ej. 0%, 5%, 19%).
class _TaxGroup {
  final int percent;
  double taxableAmount = 0;
  double taxAmount = 0;

  _TaxGroup(this.percent);
}
