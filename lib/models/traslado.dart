class ItemTraslado {
  final String? productoId;
  final String? nombreProducto;
  final String? referencia;
  final int cantidad;

  const ItemTraslado({
    this.productoId,
    this.nombreProducto,
    this.referencia,
    this.cantidad = 0,
  });

  factory ItemTraslado.fromJson(Map<String, dynamic> json) => ItemTraslado(
        productoId: json['productoId'],
        nombreProducto: json['nombreProducto'],
        referencia: json['referencia'],
        cantidad: (json['cantidad'] as num?)?.toInt() ?? 0,
      );
}

class Traslado {
  String? id;
  String? numero;

  // Campos del backend real
  String? tipo;           // "BODEGA_A_ALMACEN" | "ALMACEN_A_BODEGA"
  String? asesor;
  String? observaciones;
  String? estado;
  DateTime? fecha;
  List<ItemTraslado> items;

  // Campos derivados / compatibilidad con UI existente
  String? get solicitante => asesor;
  String? get origenBodegaNombre => _origenFromTipo(tipo);
  String? get destinoBodegaNombre => _destinoFromTipo(tipo);
  String? get origenBodegaId => origenBodegaNombre;
  String? get destinoBodegaId => destinoBodegaNombre;
  DateTime? get fechaSolicitud => fecha;

  // Primer producto del traslado (para UI de lista de un solo producto)
  String? get productoNombre =>
      items.isNotEmpty ? items.first.nombreProducto : null;
  String? get productoId =>
      items.isNotEmpty ? items.first.productoId : null;
  double? get cantidad =>
      items.fold<int>(0, (sum, i) => sum + i.cantidad).toDouble();

  Traslado({
    this.id,
    this.numero,
    this.tipo,
    this.asesor,
    this.observaciones,
    this.estado,
    this.fecha,
    this.items = const [],
  });

  factory Traslado.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final List<ItemTraslado> items = rawItems is List
        ? rawItems
            .whereType<Map<String, dynamic>>()
            .map(ItemTraslado.fromJson)
            .toList()
        : [];

    // fecha puede venir como array [y,m,d,h,min,s] o como string ISO
    DateTime? fecha;
    final rawFecha = json['fecha'];
    if (rawFecha is String) {
      fecha = DateTime.tryParse(rawFecha);
    } else if (rawFecha is List && rawFecha.length >= 5) {
      fecha = DateTime(
        rawFecha[0] as int,
        rawFecha[1] as int,
        rawFecha[2] as int,
        rawFecha[3] as int,
        rawFecha[4] as int,
        rawFecha.length > 5 ? rawFecha[5] as int : 0,
      );
    }

    return Traslado(
      id: json['_id'] ?? json['id'],
      numero: json['numero'],
      tipo: json['tipo'],
      asesor: json['asesor'] ?? json['solicitante'],
      observaciones: json['observaciones'],
      estado: json['estado'],
      fecha: fecha,
      items: items,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) '_id': id,
        if (tipo != null) 'tipo': tipo,
        if (asesor != null) 'asesor': asesor,
        if (observaciones != null) 'observaciones': observaciones,
        'estado': estado,
        if (fecha != null) 'fecha': fecha!.toIso8601String(),
        'items': items
            .map((i) => {
                  'productoId': i.productoId,
                  'nombreProducto': i.nombreProducto,
                  'cantidad': i.cantidad,
                })
            .toList(),
      };

  static String? _origenFromTipo(String? tipo) {
    if (tipo == null) return null;
    return tipo.startsWith('BODEGA') ? 'BODEGA' : 'ALMACEN';
  }

  static String? _destinoFromTipo(String? tipo) {
    if (tipo == null) return null;
    return tipo.endsWith('ALMACEN') ? 'ALMACEN' : 'BODEGA';
  }
}
