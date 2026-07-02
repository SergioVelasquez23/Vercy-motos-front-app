/// Resultado de subir un PDF de factura de compra para revisión: NO representa
/// nada persistido todavía. El usuario edita estos datos en la pantalla de
/// importación y solo al confirmar se crean productos/compra reales.
class FacturaCompraPdfPreview {
  final String plantilla;
  final String? proveedorNombre;
  final String? proveedorNit;
  final String? numeroFacturaProveedor;
  final DateTime? fechaFactura;
  final DateTime? fechaVencimiento;
  final List<ItemFacturaPdfPreview> items;
  final List<String> advertencias;

  FacturaCompraPdfPreview({
    required this.plantilla,
    this.proveedorNombre,
    this.proveedorNit,
    this.numeroFacturaProveedor,
    this.fechaFactura,
    this.fechaVencimiento,
    required this.items,
    this.advertencias = const [],
  });

  factory FacturaCompraPdfPreview.fromJson(Map<String, dynamic> json) {
    return FacturaCompraPdfPreview(
      plantilla: json['plantilla']?.toString() ?? 'AKT',
      proveedorNombre: json['proveedorNombre']?.toString(),
      proveedorNit: json['proveedorNit']?.toString(),
      numeroFacturaProveedor: json['numeroFacturaProveedor']?.toString(),
      fechaFactura: _parseFechaAkt(json['fechaFactura']?.toString()),
      fechaVencimiento: _parseFechaAkt(json['fechaVencimiento']?.toString()),
      items: (json['items'] as List<dynamic>? ?? [])
          .map((i) => ItemFacturaPdfPreview.fromJson(i as Map<String, dynamic>))
          .toList(),
      advertencias: (json['advertencias'] as List<dynamic>? ?? [])
          .map((a) => a.toString())
          .toList(),
    );
  }

  /// Parsea fechas en formato "dd-MMM-yyyy" con mes en español abreviado
  /// (ej. "29-Jun-2026"), tal como las devuelve el parser del backend.
  static DateTime? _parseFechaAkt(String? valor) {
    if (valor == null || valor.trim().isEmpty) return null;
    final partes = valor.trim().split('-');
    if (partes.length != 3) return null;

    const meses = {
      'ene': 1, 'feb': 2, 'mar': 3, 'abr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'ago': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dic': 12,
    };

    final dia = int.tryParse(partes[0]);
    final mes = meses[partes[1].toLowerCase()];
    final anio = int.tryParse(partes[2]);
    if (dia == null || mes == null || anio == null) return null;

    return DateTime(anio, mes, dia);
  }
}

class ItemFacturaPdfPreview {
  final String plu;
  final String? codigoInterno;
  final String? codigoBarras;
  final String descripcion;
  final double cantidad;
  final double valorUnitario;
  final double porcentajeIva;
  final double valorIva;
  final double subtotal;
  final double valorTotal;

  final bool esNuevo;
  final String? productoId;
  final String? productoNombreActual;
  final double? costoActual;
  final double? precioActual;
  final int? cantidadAlmacen;
  final int? cantidadBodega;
  final bool? controlInventario;

  ItemFacturaPdfPreview({
    required this.plu,
    this.codigoInterno,
    this.codigoBarras,
    required this.descripcion,
    required this.cantidad,
    required this.valorUnitario,
    required this.porcentajeIva,
    required this.valorIva,
    required this.subtotal,
    required this.valorTotal,
    required this.esNuevo,
    this.productoId,
    this.productoNombreActual,
    this.costoActual,
    this.precioActual,
    this.cantidadAlmacen,
    this.cantidadBodega,
    this.controlInventario,
  });

  factory ItemFacturaPdfPreview.fromJson(Map<String, dynamic> json) {
    return ItemFacturaPdfPreview(
      plu: json['plu']?.toString() ?? '',
      codigoInterno: json['codigoInterno']?.toString(),
      codigoBarras: json['codigoBarras']?.toString(),
      descripcion: json['descripcion']?.toString() ?? '',
      cantidad: (json['cantidad'] as num?)?.toDouble() ?? 0,
      valorUnitario: (json['valorUnitario'] as num?)?.toDouble() ?? 0,
      porcentajeIva: (json['porcentajeIva'] as num?)?.toDouble() ?? 0,
      valorIva: (json['valorIva'] as num?)?.toDouble() ?? 0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      valorTotal: (json['valorTotal'] as num?)?.toDouble() ?? 0,
      esNuevo: json['esNuevo'] == true,
      productoId: json['productoId']?.toString(),
      productoNombreActual: json['productoNombreActual']?.toString(),
      costoActual: (json['costoActual'] as num?)?.toDouble(),
      precioActual: (json['precioActual'] as num?)?.toDouble(),
      cantidadAlmacen: (json['cantidadAlmacen'] as num?)?.toInt(),
      cantidadBodega: (json['cantidadBodega'] as num?)?.toInt(),
      controlInventario: json['controlInventario'] as bool?,
    );
  }
}
