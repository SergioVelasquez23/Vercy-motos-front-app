import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import '../config/endpoints_config.dart';
import '../utils/logger.dart';
import '../utils/datetime_utils.dart';
import '../utils/payment_mapping.dart' as payment_mapping;
import 'base_api_service.dart';

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
        headers: await _headers(),
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
        headers: await _headers(),
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
        headers: await _headers(),
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
      'operation_type_id': 12,
      'billing_reference': {
        'number': facturaNumero,
        'uuid': facturaCufe,
        'date': facturaFecha,
      },
      'discrepancy_response': {
        'reference_id': motivoId,
        'response_id': motivoId,
        'description': motivo,
      },
    };
    body.remove('resolution_number');
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
      'discrepancy_response': {
        'reference_id': motivoId,
        // ND response_id catalog: 1=Intereses→9, 2=Gastos→10, 3=Cambio valor→11
        'response_id': {1: 9, 2: 10, 3: 11}[motivoId] ?? motivoId,
        'description': motivo,
      },
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
    final body = {...payload, 'type_document_id': 11};
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
    final now = DateTimeUtils.nowColombia();
    final date = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final time = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    final items = (pedido.items as List?) ?? const [];
    final descuentoGeneral = _asDouble(pedido.descuentoGeneral);

    // ── 1) Primera pasada: subtotal bruto para distribución proporcional ─
    double subtotalBruto = 0;
    for (final item in items) {
      subtotalBruto += _asDouble(item.cantidad) * _asDouble(item.precioUnitario);
    }

    // ── 2) Construir líneas con descuento general distribuido ────────────
    // El descuento general se reparte proporcionalmente y se incluye en el
    // allowance_charge de cada línea. El IVA se recalcula sobre la base
    // DESPUÉS de todos los descuentos (cumple DIAN DEAU06/08/14).
    final lines = <Map<String, dynamic>>[];
    final Map<int, _TaxGroup> taxGroups = {};
    double totalDescuentosItem = 0;
    double totalImpuestosRecalc = 0;
    double generalDescDistribuido = 0;

    for (var idx = 0; idx < items.length; idx++) {
      final item = items[idx];
      final qty = _asDouble(item.cantidad);
      final price = _asDouble(item.precioUnitario);
      final descValorItem = _asDouble(item.valorDescuento);

      final impPct = _asDouble(item.porcentajeImpuesto).round();

      final lineGross = qty * price;

      // Porción del descuento general para esta línea (proporcional al bruto).
      // La última línea absorbe el residuo para evitar diferencias de centavo.
      final double generalDiscForLine;
      if (descuentoGeneral <= 0 || subtotalBruto <= 0) {
        generalDiscForLine = 0;
      } else if (idx == items.length - 1) {
        generalDiscForLine = descuentoGeneral - generalDescDistribuido;
      } else {
        generalDiscForLine = descuentoGeneral * lineGross / subtotalBruto;
        generalDescDistribuido += generalDiscForLine;
      }

      final totalLineDisc = descValorItem + generalDiscForLine;
      final lineAfterAllDisc = lineGross - totalLineDisc;

      // IVA recalculado sobre la base completamente descontada
      final impValorRecalc = lineAfterAllDisc * impPct / 100;

      totalDescuentosItem += descValorItem;
      totalImpuestosRecalc += impValorRecalc;

      final group = taxGroups.putIfAbsent(impPct, () => _TaxGroup(impPct));
      group.taxableAmount += lineAfterAllDisc;
      group.taxAmount += impValorRecalc;

      final lineMap = <String, dynamic>{
        'line_number': (idx + 1).toString(),
        'description': item.productoNombre ?? 'Producto',
        'code': item.productoId ?? 'PROD',
        'invoiced_quantity': qty.toStringAsFixed(0),
        'base_quantity': qty.toStringAsFixed(0),
        'quantity_units_id': '1093',
        'price_amount': price.toStringAsFixed(2),
        'line_extension_amount': lineAfterAllDisc.toStringAsFixed(2),
        'free_of_charge_indicator': false,
        'type_item_identifications_id': '4',
        'reference_price_id': '1',
        'um': 'UND',
        'tax_totals': [
          {
            'tax_id': '1',
            'percent': impPct,
            'tax_amount': impValorRecalc.toStringAsFixed(2),
            'taxable_amount': lineAfterAllDisc.toStringAsFixed(2),
          }
        ],
      };

      if (totalLineDisc > 0) {
        lineMap['allowance_charges'] = [
          {
            'discount_id': '1',
            'charge_indicator': false,
            'allowance_charge_reason': 'Descuento',
            'amount': totalLineDisc.toStringAsFixed(2),
            'base_amount': lineGross.toStringAsFixed(2),
            if (lineGross > 0)
              'multiplier_factor_numeric':
                  (totalLineDisc / lineGross * 100).toStringAsFixed(2),
          }
        ];
      }

      lines.add(lineMap);
    }

    // ── 3) Cliente ───────────────────────────────────────────────────────
    final customer = buildCustomerFromPedido(pedido);

    // ── 4) Montos legales ────────────────────────────────────────────────
    // Todos los descuentos están en líneas → tax_inclusive == payable_amount.
    // DIAN DEAU06: line_extension + taxes == tax_inclusive_amount ✓
    if (taxGroups.isEmpty) {
      final base = subtotalBruto - totalDescuentosItem - descuentoGeneral;
      taxGroups[0] = _TaxGroup(0)..taxableAmount = base;
    }

    final taxTotalsList = taxGroups.values
        .map((g) => {
              'tax_id': '1',
              'percent': g.percent,
              'tax_amount': g.taxAmount.toStringAsFixed(2),
              'taxable_amount': g.taxableAmount.toStringAsFixed(2),
            })
        .toList();

    final lineExtensionTotal = subtotalBruto - totalDescuentosItem - descuentoGeneral;
    final taxInclusiveAmount = lineExtensionTotal + totalImpuestosRecalc;
    final totalFinalStr = taxInclusiveAmount.toStringAsFixed(2);

    final legalMonetaryTotals = <String, dynamic>{
      'line_extension_amount': lineExtensionTotal.toStringAsFixed(2),
      'tax_exclusive_amount': lineExtensionTotal.toStringAsFixed(2),
      'tax_inclusive_amount': totalFinalStr,
      'payable_amount': totalFinalStr,
      if (totalDescuentosItem + descuentoGeneral > 0)
        'allowance_total_amount':
            (totalDescuentosItem + descuentoGeneral).toStringAsFixed(2),
    };

    return {
      'resolution_number': resolutionNumber,
      'prefix': _valorOrDefault(negocioInfo.posPrefijo, 'POS'),
      // document_number omitido — POS usa consecutivo automático de Matias
      'date': date,
      'time': time,
      'type_document_id': type_document_id,
      'graphic_representation': 1,
      'send_email': 0,
      'notes': customer['company_name'] == 'Consumidor Final'
          ? 'Documento POS rápido - Sin cliente'
          : 'Documento POS rápido',
      // 1 = ESTANDAR — único válido para POS según DIAN (DEAD02)
      'operation_type_id': 1,
      'currency_id': 272,
      'cash_register_number': _valorOrDefault(negocioInfo.posCashierName, 'CAJA-01'),
      'seller_name': _valorOrDefault(negocioInfo.posCashierName, 'Vendedor'),
      'software_manufacturer': {
        'owner_name': _valorOrDefault(negocioInfo.softwareOwnerName, _valorOrDefault(negocioInfo.nombre, 'Software Owner')),
        'company_name': _valorOrDefault(negocioInfo.softwareCompanyName, _valorOrDefault(negocioInfo.nombre, 'Software Company')),
        'software_name': _valorOrDefault(negocioInfo.softwareName, 'Vercy POS'),
      },
      'point_of_sale': {
        // Matias exige point_of_sale.cashier_name cuando type_document_id es
        // 20 (POS). Si el negocio guardó el nombre del cajero como "" (campo
        // vacío en configuración) en vez de null, `?? 'Vendedor'` NO lo
        // detecta porque "" no es null — Matias lo trata como ausente y
        // rechaza el documento. _valorOrDefault sí trata "" como vacío.
        'cashier_name': _valorOrDefault(negocioInfo.posCashierName, 'Vendedor'),
        'terminal_number': _valorOrDefault(negocioInfo.posTerminalNumber, 'T001'),
        'cashier_type': _valorOrDefault(negocioInfo.posCashierType, 'Dependiente'),
        'sales_code': _valorOrDefault(negocioInfo.posSalesCode, 'V001'),
        'address': _valorOrDefault(negocioInfo.direccion, 'Sin dirección'),
        'sub_total': lineExtensionTotal.toStringAsFixed(2),
        'total': totalFinalStr,
      },
      'customer': customer,
      'lines': lines,
      'legal_monetary_totals': legalMonetaryTotals,
      'tax_totals': taxTotalsList,
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

  /// Helper: devuelve [valor] si no es nulo ni vacío (tras trim); si no,
  /// [fallback]. A diferencia de `valor ?? fallback`, esto SÍ detecta un
  /// campo guardado como cadena vacía "" (no solo null) — necesario porque
  /// varios campos de configuración del negocio se guardan como "" cuando el
  /// usuario deja el campo en blanco, y Matias rechaza esos campos como si
  /// no hubieran sido enviados.
  static String _valorOrDefault(String? valor, String fallback) {
    final v = valor?.trim();
    return (v == null || v.isEmpty) ? fallback : v;
  }

  /// Construye el bloque `customer` del documento. Si el pedido tiene cliente
  /// real (en `datosAdicionales`) lo usa; si no, retorna "Consumidor Final".
  static Map<String, dynamic> buildCustomerFromPedido(dynamic pedido) {
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


  /// Construye el array `payments` para el documento POS de Matías a partir
  /// del pedido. Soporta pago único (`formaPago`) y pago mixto
  /// (`pagosParciales` con varios montos/formas).
  static List<Map<String, dynamic>> _buildPaymentsFromPedido(
    dynamic pedido,
    String total,
    String date,
  ) {
    // Para DIAN, Σ value_paid debe igualar payable_amount (= total con IVA).
    // Usamos el `total` calculado del documento, no el monto cobrado en caja,
    // para evitar el rechazo por discrepancia de totales.
    final parciales = pedido.pagosParciales as List? ?? const [];
    if (parciales.isNotEmpty) {
      // Pago mixto: distribuir el total del documento proporcionalmente entre
      // los medios de pago, pero manteniendo la suma = total.
      final totalNum = double.tryParse(total) ?? 0.0;
      final montosParciales = parciales
          .map<double>((p) => (p.monto as num).toDouble())
          .toList();
      final sumaParciales =
          montosParciales.fold<double>(0, (a, b) => a + b);

      return List<Map<String, dynamic>>.generate(parciales.length, (i) {
        final p = parciales[i];
        // Prorratear el total del documento según la proporción de cada pago parcial.
        final proporcion =
            sumaParciales > 0 ? montosParciales[i] / sumaParciales : 1.0;
        final valorPago = i == parciales.length - 1
            ? totalNum -
                montosParciales
                    .sublist(0, i)
                    .fold<double>(0, (a, b) => a + b * totalNum / sumaParciales)
            : (totalNum * proporcion);
        return {
          'payment_method_id': 1, // Contado (un pago mixto se paga completo de inmediato)
          'means_payment_id': _mapFormaPagoToMeansId(
            p.formaPago as String?,
            detallePago: p.detallePago as String?,
          ),
          'value_paid': valorPago.toStringAsFixed(2),
          'payment_due_date': date,
        };
      });
    }

    // Venta a crédito: marcar payment_method_id 2 y usar la fecha de
    // vencimiento real del pedido (no la fecha de la factura).
    final esCredito = (pedido.formaPago as String?)?.toLowerCase().trim() == 'crédito';
    String fechaVencimientoStr = date;
    if (esCredito) {
      final fechaVencimiento = pedido.fechaVencimiento as DateTime?;
      if (fechaVencimiento != null) {
        fechaVencimientoStr =
            "${fechaVencimiento.year}-${fechaVencimiento.month.toString().padLeft(2, '0')}-${fechaVencimiento.day.toString().padLeft(2, '0')}";
      }
    }

    // Pago único: usar el total del documento para que Σvalue_paid = payable_amount.
    return [
      {
        'payment_method_id': esCredito ? 2 : 1, // 1=Contado, 2=Crédito
        'means_payment_id': _mapFormaPagoToMeansId(
          pedido.formaPago as String?,
          detallePago: pedido.detallePago as String?,
        ),
        'value_paid': total,
        'payment_due_date': fechaVencimientoStr,
      }
    ];
  }

  /// Mapea formaPago/detallePago al `means_payment_id` (medio de pago) de
  /// Matías. Delega a lib/utils/payment_mapping.dart, compartido con
  /// facturacion_screen.dart y con MatiasTransformer en el backend — ver el
  /// comentario ahí: antes esta función tenía su propia tabla desalineada
  /// (sistecredito y transferencia caían en códigos DIAN distintos a los que
  /// usa el backend para el mismo pedido).
  static int _mapFormaPagoToMeansId(String? formaPago, {String? detallePago}) {
    return payment_mapping.mapFormaPagoToMeansId(
      formaPago,
      detallePago: detallePago,
    );
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
        headers: await _headers(token: token),
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
  /// Usa consultarDatosFactura (GET /api/matias/invoices/{trackId}/pdf).
  /// Nota: el endpoint /invoices/pdf no retorna QR — siempre retorna null.
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

  /// Obtiene la URL directa del PDF.
  ///
  /// Llama a `GET /api/matias/invoices/{trackId}/pdf` (JSON: {url, base64}).
  /// Si hay URL directa la devuelve; si no, devuelve null
  /// (el caller debe usar [descargarPDF] para abrir el base64).
  static Future<String?> obtenerURLPDF(
    String trackId, {
    String? token,
  }) async {
    try {
      // Intentar vía el endpoint directo de PDF (retorna JSON con url + base64)
      final pdfData = await _descargarArchivo('pdf', trackId, token: token);
      if (pdfData != null) {
        final url = pdfData['url'];
        if (url != null && url.isNotEmpty) return url;
      }
      // Fallback: consultar datos de factura
      final data = await consultarDatosFactura(trackId, token: token);
      final pdf = data?['pdf'];
      if (pdf is Map) {
        final url = pdf['url']?.toString();
        if (url != null && url.isNotEmpty) return url;
      } else if (pdf is String && pdf.isNotEmpty) {
        return pdf; // el backend devuelve la URL directamente como string
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
        headers: await _headers(token: token),
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

      final url = data['url']?.toString();
      final base64 = data['base64']?.toString();

      if ((url == null || url.isEmpty) && (base64 == null || base64.isEmpty)) {
        appLog('$TAG ⚠️ Respuesta sin URL ni base64');
        return null;
      }
      appLog('$TAG ✅ $tipo: url=${url != null ? '✓' : '✗'} base64=${base64 != null ? '${base64.length} chars' : '✗'}');
      return {
        'cufe': data['cufe']?.toString() ?? cufe,
        'mimeType': data['mimeType']?.toString() ??
            (tipo == 'pdf' ? 'application/pdf' : 'application/xml'),
        if (url != null && url.isNotEmpty) 'url': url,
        if (base64 != null && base64.isNotEmpty) 'base64': base64,
      };
    } catch (e) {
      appLog('$TAG ❌ _descargarArchivo($tipo): $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  📥 PDF / EMAIL / CONTADOR (Matias API)
  // ──────────────────────────────────────────────────────────────────────────

  /// Consulta datos completos de la factura electrónica (PDF, CUFE).
  ///
  /// Backend: GET /api/matias/invoices/{trackId}/pdf
  /// [trackId] puede ser CUFE/CUNE/XmlDocumentKey retornado al emitir.
  /// Retorna Map normalizado con claves: cufe, pdf: {url, path, data}, qr: null.
  static Future<Map<String, dynamic>?> consultarDatosFactura(
    String trackId, {
    String? token,
  }) async {
    try {
      await _ensureAuth();
      appLog('$TAG 📥 GET /invoices/$trackId/pdf (len=${trackId.length})');
      final res = await http.get(
        Uri.parse('$_base/invoices/$trackId/pdf'),
        headers: await _headers(token: token),
      ).timeout(_timeout, onTimeout: () {
        throw TimeoutException('Timeout consultando datos del documento');
      });

      if (res.statusCode != 200) {
        appLog('$TAG ❌ invoices/pdf: ${res.statusCode} - ${res.body}');
        appLog('$TAG    → trackId enviado: "$trackId"');
        return null;
      }
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      if (j['success'] != true) return null;
      final raw = j['data'] as Map<String, dynamic>?;
      // Normalizar al esquema esperado por los callers: pdf:{url,path,data}, qr:null
      final data = <String, dynamic>{
        'cufe': raw?['cufe'],
        'pdf': {
          'url': raw?['url'],
          'path': raw?['path'],
          'data': raw?['base64'],
        },
        'qr': null,
      };
      appLog('$TAG ✅ Datos factura obtenidos para $trackId — url=${raw?['url']}');
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
        headers: await _headers(token: token),
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
      appLog('$TAG ❌ TIMEOUT reenviarCorreoFactura: $e');
      return MatiasDocumentoResult.error('La solicitud tardó demasiado tiempo. Intenta nuevamente.');
    } catch (e) {
      appLog('$TAG ❌ reenviarCorreoFactura: $e');
      return MatiasDocumentoResult.error('Error de conexión con Matias.');
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
        headers: await _headers(token: token),
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

  /// Headers con Authorization. Si no llega token explícito, lo resuelve
  /// desde BaseApiService (localStorage en web, secure storage en móvil) —
  /// antes las llamadas sin token explícito salían sin Authorization.
  static Future<Map<String, String>> _headers({String? token}) async {
    final t = (token != null && token.isNotEmpty)
        ? token
        : await BaseApiService().getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (t != null && t.isNotEmpty) 'Authorization': 'Bearer $t',
    };
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
        headers: await _headers(token: token),
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
      return MatiasDocumentoResult.error('La solicitud tardó demasiado tiempo. Intenta nuevamente.');
    } catch (e) {
      appLog('$TAG ❌ _postDocumento: $e');
      return MatiasDocumentoResult.error('Error de conexión con Matias.');
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
        headers: await _headers(token: token),
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
        headers: await _headers(token: token),
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
      return MatiasDocumentoResult.error('La solicitud tardó demasiado tiempo. Intenta nuevamente.');
    } catch (e) {
      appLog('$TAG ❌ _patch: $e');
      return MatiasDocumentoResult.error('Error de conexión con Matias.');
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
          data['XmlDocumentKey']?.toString() ??
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
