import '../models/pedido.dart';
import '../models/item_pedido.dart';

class MatiasMapper {
  static Map<String, dynamic> toMatiasPayload(Pedido pedido) {
    final datosAdd = pedido.datosAdicionales ?? {};

    // 1. Mapear datos del cliente desde datosAdicionales (o hardcode defaults para evitar bloqueos)
    String nitFull = datosAdd['clienteNit']?.toString() ?? '111111111';
    // Limpiamos el NIT (le quitamos 'CC ', 'NIT ', guiones)
    String dniPuro = nitFull.replaceAll(RegExp(r'[^0-9]'), '');
    if (dniPuro.isEmpty) dniPuro = "000000000";

    String tipoId = datosAdd['clienteTipoId']?.toString() ?? 'CC';
    String nombre =
        datosAdd['clienteNombreCompleto']?.toString() ??
        pedido.cliente ??
        'CONSUMIDOR FINAL';

    final customer = {
      "country_id": "45",
      "city_id": "836",
      "identity_document_id": _mapTipoIdentificacion(tipoId),
      "type_organization_id": nombre.toLowerCase().contains('juridica') ? 1 : 2,
      "tax_regime_id": 2,
      "tax_level_id": 2,
      "company_name": nombre,
      "dni": dniPuro,
      "mobile": datosAdd['clienteTelefono']?.toString() ?? "0000000000",
      "email": datosAdd['clienteCorreo']?.toString() ?? "factura@example.com",
      "address": datosAdd['clienteDireccion']?.toString() ?? "Sin Direccion",
      "postal_code": "000000",
    };

    // 2. Mapear Líneas
    final linesData = _mapLines(pedido.items);
    final lines = linesData['lines'];
    final sumTaxExclusive = linesData['taxExclusiveAmount'] as double;
    final sumTaxAmount = linesData['taxAmountTotal'] as double;
    final taxTotals = linesData['taxTotalsArray'] as List<dynamic>;

    final taxInclusiveAmount = sumTaxExclusive + sumTaxAmount;

    // 3. Totales legales
    final legalMonetaryTotals = {
      "line_extension_amount": sumTaxExclusive.toStringAsFixed(2),
      "tax_exclusive_amount": sumTaxExclusive.toStringAsFixed(2),
      "tax_inclusive_amount": taxInclusiveAmount.toStringAsFixed(2),
      "payable_amount": taxInclusiveAmount.toStringAsFixed(2),
    };

    // 4. Pagos
    final payments = _mapPayments(pedido, taxInclusiveAmount);

    // 5. Fecha y Hora (Requerido por Mathías)
    final date =
        "${pedido.fecha.year}-${pedido.fecha.month.toString().padLeft(2, '0')}-${pedido.fecha.day.toString().padLeft(2, '0')}";
    final time =
        "${pedido.fecha.hour.toString().padLeft(2, '0')}:${pedido.fecha.minute.toString().padLeft(2, '0')}:${pedido.fecha.second.toString().padLeft(2, '0')}";

    // Generamos un consecutivo numérico basándonos en el ID del pedido
    // (Mathías exige que document_number sea enteramente un número).
    
    // Intentar extraer número de diferentes fuentes
    int docNum;

    // 1. Intentar numeroFactura si existe
    if (pedido.numeroFactura != null && pedido.numeroFactura!.isNotEmpty) {
      final parsedNum = int.tryParse(
        pedido.numeroFactura!.replaceAll(RegExp(r'[^0-9]'), ''),
      );
      if (parsedNum != null && parsedNum > 0) {
        docNum = parsedNum;
      } else {
        // 2. Usar hash del ID si numeroFactura no es válido
        docNum = pedido.id.hashCode.abs();
      }
    } else {
      // 2. Usar hash del ID del pedido como documento único
      docNum = pedido.id.hashCode.abs();
    }

    // Asegurar que es un número válido de 5+ dígitos
    if (docNum < 10000) {
      docNum = 100000 + (docNum % 900000);
    }

    return {
      // Valores requeridos por Mathías
      "resolution_number":
          datosAdd['resolutionNumber']?.toString() ??
          datosAdd['resolucion']?.toString() ??
          "",
      "prefix": datosAdd['prefijoDocumento']?.toString() ?? "LZT",
      "document_number": docNum.toString(),
      "date": date, // Formato "2024-10-17"
      "time": time, // Formato "14:30:00"
      "notes": pedido.notas?.isNotEmpty == true
          ? pedido.notas
          : "Factura de venta generada",
      "type_document_id": 7, // Factura Venta
      "operation_type_id": 1, // Estándar
      "graphic_representation": 0,
      "send_email": customer["email"] != "factura@example.com" ? 1 : 0,
      "customer": customer,
      "lines": lines,
      "legal_monetary_totals": legalMonetaryTotals,
      "tax_totals": taxTotals,
      "payments": payments,
    };
  }

  static Map<String, dynamic> _mapLines(List<ItemPedido> items) {
    List<Map<String, dynamic>> lines = [];
    double taxExclusiveAmount = 0.0;
    double taxAmountTotal = 0.0;
    int lineNumber = 0;

    for (var item in items) {
      lineNumber++;
      double basePrice = item.precioUnitario;
      double quantity = item.cantidad.toDouble();

      double lineExtension = basePrice * quantity;

      double taxPercent = item.porcentajeImpuesto ?? 0.0;
      double taxAmt = (lineExtension * taxPercent) / 100;

      taxExclusiveAmount += lineExtension;
      taxAmountTotal += taxAmt;

      List<Map<String, dynamic>> taxTotalsItem = [];
      taxTotalsItem.add({
        "tax_id": 1, // IVA
        "percent": taxAmt > 0 ? taxPercent.toInt() : 0,
        "tax_amount": taxAmt.toStringAsFixed(1),
        "taxable_amount": lineExtension.toStringAsFixed(1),
      });

      double discountPercent = item.porcentajeDescuento ?? 0.0;
      double discountAmount = (lineExtension * discountPercent) / 100;

      lines.add({
        "line_number": lineNumber,
        "description": item.productoNombre ?? "Item Genérico",
        "invoiced_quantity": quantity.toStringAsFixed(0),
        "quantity_units_id": "1093",
        "base_quantity": quantity.toStringAsFixed(0),
        "code": item.productoId ?? "000",
        "type_item_identifications_id": "4",
        "reference_price_id": "1",
        "price_amount": basePrice.toStringAsFixed(1),
        "line_extension_amount": lineExtension.toStringAsFixed(1),
        "free_of_charge_indicator": false,
        "discount_percent": discountPercent,
        "discount_amount": discountAmount,
        "tax_totals": taxTotalsItem,
      });
    }

    List<Map<String, dynamic>> taxTotalsGlobal = [];
    taxTotalsGlobal.add({
      "tax_id": 1,
      "percent": taxAmountTotal > 0 ? 19 : 0, // Al menos el IVA es requerido
      "tax_amount": taxAmountTotal.toStringAsFixed(1),
      "taxable_amount": taxExclusiveAmount.toStringAsFixed(1),
    });

    return {
      'lines': lines,
      'taxExclusiveAmount': taxExclusiveAmount,
      'taxAmountTotal': taxAmountTotal,
      'taxTotalsArray': taxTotalsGlobal,
    };
  }

  static List<Map<String, dynamic>> _mapPayments(
    Pedido pedido,
    double payableAmount,
  ) {
    int meansPaymentId = 10;

    if (pedido.formaPago?.toLowerCase().contains('transferencia') == true) {
      meansPaymentId = 42;
    } else if (pedido.formaPago?.toLowerCase().contains('tarjeta') == true ||
        pedido.formaPago?.toLowerCase().contains('datafono') == true) {
      meansPaymentId = 48;
    }

    return [
      {
        "payment_method_id": 1,
        "means_payment_id": meansPaymentId,
        "value_paid": payableAmount.toStringAsFixed(1),
        // "due_date": se añade si la factura tiene vencimiento
      },
    ];
  }

  static String _mapTipoIdentificacion(String tipo) {
    switch (tipo.toUpperCase()) {
      case 'CC':
        return "1";
      case 'CE':
        return "2";
      case 'NIT':
        return "3";
      case 'TI':
        return "5";
      case 'PASAPORTE':
        return "4";
      default:
        return "1";
    }
  }
}
