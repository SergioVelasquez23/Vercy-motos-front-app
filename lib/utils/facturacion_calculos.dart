// Cálculos puros de líneas de factura: subtotal, descuento e IVA.
//
// Antes de esta extracción, facturacion_screen.dart reimplementaba esta
// misma aritmética (con variaciones menores) en al menos 6 lugares
// distintos (_calcularValorTotal, _agregarItem, _recalcularItemDesdeTotal,
// la precarga de pedido de asesor y la edición de borrador) — ver
// docs/AUDITORIA_SIN_FILTROS_V2.md punto 6. Un cambio en la fórmula (ej. el
// redondeo, o cómo se interpreta un descuento en valor vs. porcentaje) tenía
// que replicarse a mano en cada copia.

/// Resultado de aplicar descuento + IVA sobre cantidad × precio unitario.
class CalculoItemFactura {
  final double subtotal;
  final double valorDescuento;
  final double porcentajeDescuento;
  final double valorImpuesto;
  final double total;

  const CalculoItemFactura({
    required this.subtotal,
    required this.valorDescuento,
    required this.porcentajeDescuento,
    required this.valorImpuesto,
    required this.total,
  });
}

/// Extrae el precio neto (sin IVA) de un precio que ya trae el IVA incluido.
/// Se usa para pedidos de asesor/vendedor, donde el precio guardado es
/// siempre el precio final que paga el cliente.
///
/// `porcentajeImpuesto` fuera de (0, 100) no se considera una tasa de IVA
/// válida y se devuelve el precio tal cual (mismo criterio defensivo que ya
/// usaban los sitios que se unificaron aquí).
double extraerPrecioBaseDeGravado(double precioConIva, double porcentajeImpuesto) {
  if (porcentajeImpuesto <= 0 || porcentajeImpuesto >= 100) return precioConIva;
  return precioConIva / (1 + porcentajeImpuesto / 100);
}

/// Calcula subtotal, descuento, IVA y total de una línea de factura a partir
/// de cantidad, precio unitario NETO (sin IVA) y lo ingresado por el cajero.
///
/// [descuentoIngresado] es un valor en pesos si [descuentoEsPorcentaje] es
/// `false`; si es `true` (default), es un porcentaje aplicado sobre el
/// subtotal.
CalculoItemFactura calcularItemFactura({
  required double cantidad,
  required double precioUnitario,
  required double porcentajeImpuesto,
  required double descuentoIngresado,
  bool descuentoEsPorcentaje = true,
}) {
  final subtotal = cantidad * precioUnitario;

  final double valorDescuento;
  final double porcentajeDescuento;
  if (descuentoEsPorcentaje) {
    valorDescuento = subtotal * (descuentoIngresado / 100);
    porcentajeDescuento = descuentoIngresado;
  } else {
    valorDescuento = descuentoIngresado;
    porcentajeDescuento = subtotal > 0 ? (descuentoIngresado / subtotal) * 100 : 0;
  }

  final baseGravable = subtotal - valorDescuento;
  final valorImpuesto = porcentajeImpuesto > 0 && porcentajeImpuesto < 100
      ? baseGravable * (porcentajeImpuesto / 100)
      : 0.0;
  final total = baseGravable + valorImpuesto;

  return CalculoItemFactura(
    subtotal: subtotal,
    valorDescuento: valorDescuento,
    porcentajeDescuento: porcentajeDescuento,
    valorImpuesto: valorImpuesto,
    total: total,
  );
}

/// Precio base e impuesto reconstruidos a partir de un total editado a mano.
class RecalculoDesdeTotal {
  final double precioUnitario;
  final double valorDescuento;
  final double valorImpuesto;

  const RecalculoDesdeTotal({
    required this.precioUnitario,
    required this.valorDescuento,
    required this.valorImpuesto,
  });
}

/// Reconstruye precio base e impuesto a partir de un TOTAL editado
/// manualmente, manteniendo fijos cantidad, %impuesto y %descuento:
///   total = subtotalBase × (1 - %dcto/100) × (1 + %iva/100)
///   subtotalBase = total / [(1 - %dcto/100) × (1 + %iva/100)]
RecalculoDesdeTotal recalcularBaseDesdeTotal({
  required double nuevoTotal,
  required double cantidad,
  required double porcentajeImpuesto,
  required double porcentajeDescuento,
}) {
  final factorDescuento = 1 - (porcentajeDescuento / 100);
  final factorImpuesto = 1 + (porcentajeImpuesto / 100);
  final denominador = factorDescuento * factorImpuesto;

  final nuevoSubtotalBase = denominador > 0 ? nuevoTotal / denominador : nuevoTotal;
  final nuevoPrecioUnitario =
      cantidad > 0 ? nuevoSubtotalBase / cantidad : nuevoSubtotalBase;
  final nuevoValorDescuento = nuevoSubtotalBase * (porcentajeDescuento / 100);
  final baseGravable = nuevoSubtotalBase - nuevoValorDescuento;
  final nuevoValorImpuesto = baseGravable * (porcentajeImpuesto / 100);

  return RecalculoDesdeTotal(
    precioUnitario: nuevoPrecioUnitario,
    valorDescuento: nuevoValorDescuento,
    valorImpuesto: nuevoValorImpuesto,
  );
}
