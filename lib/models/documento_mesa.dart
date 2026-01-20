/// Modelo que representa un documento de mesa en el sistema
class DocumentoMesa {
  final String? id;
  final String? numeroDocumento;
  final DateTime? fecha;
  final double total;
  final String vendedor;
  final String mesaNombre;
  final List<String> pedidosIds;
  final bool pagado;
  final DateTime? fechaPago;
  final String? formaPago;
  final String? pagadoPor;
  final double propina;

  DocumentoMesa({
    this.id,
    this.numeroDocumento,
    this.fecha,
    required this.total,
    required this.vendedor,
    required this.mesaNombre,
    List<String>? pedidosIds,
    this.pagado = false,
    this.fechaPago,
    this.formaPago,
    this.pagadoPor,
    this.propina = 0.0,
  }) : pedidosIds = pedidosIds ?? [];

  /// Crea una copia del documento con los campos actualizados
  DocumentoMesa copyWith({
    String? id,
    String? numeroDocumento,
    DateTime? fecha,
    double? total,
    String? vendedor,
    String? mesaNombre,
    List<String>? pedidosIds,
    bool? pagado,
    DateTime? fechaPago,
    String? formaPago,
    String? pagadoPor,
    double? propina,
  }) {
    return DocumentoMesa(
      id: id ?? this.id,
      numeroDocumento: numeroDocumento ?? this.numeroDocumento,
      fecha: fecha ?? this.fecha,
      total: total ?? this.total,
      vendedor: vendedor ?? this.vendedor,
      mesaNombre: mesaNombre ?? this.mesaNombre,
      pedidosIds: pedidosIds ?? this.pedidosIds,
      pagado: pagado ?? this.pagado,
      fechaPago: fechaPago ?? this.fechaPago,
      formaPago: formaPago ?? this.formaPago,
      pagadoPor: pagadoPor ?? this.pagadoPor,
      propina: propina ?? this.propina,
    );
  }

  /// Convierte el documento a un mapa JSON
  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      if (numeroDocumento != null) 'numeroDocumento': numeroDocumento,
      if (fecha != null) 'fecha': fecha!.toIso8601String(),
      'total': total,
      'vendedor': vendedor,
      'mesaNombre': mesaNombre,
      'pedidosIds': pedidosIds,
      'pagado': pagado,
      if (fechaPago != null) 'fechaPago': fechaPago!.toIso8601String(),
      if (formaPago != null) 'formaPago': formaPago,
      if (pagadoPor != null) 'pagadoPor': pagadoPor,
      'propina': propina,
    };
  }

  /// Crea un documento desde un mapa JSON
  factory DocumentoMesa.fromJson(Map<String, dynamic> json) {
    return DocumentoMesa(
      id: json['_id'] as String?,
      numeroDocumento: json['numeroDocumento'] as String?,
      fecha: json['fecha'] != null
          ? DateTime.parse(json['fecha'] as String)
          : null,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      vendedor: json['vendedor'] as String? ?? '',
      mesaNombre: json['mesaNombre'] as String? ?? '',
      pedidosIds: json['pedidosIds'] != null
          ? List<String>.from(json['pedidosIds'] as List)
          : [],
      pagado: json['pagado'] as bool? ?? false,
      fechaPago: json['fechaPago'] != null
          ? DateTime.parse(json['fechaPago'] as String)
          : null,
      formaPago: json['formaPago'] as String?,
      pagadoPor: json['pagadoPor'] as String?,
      propina: (json['propina'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Obtiene el estado del documento
  String get estado => pagado ? 'Pagado' : 'Pendiente';

  /// Obtiene la cantidad de pedidos asociados
  int get cantidadPedidos => pedidosIds.length;

  /// Verifica si el documento tiene pedidos
  bool get tienePedidos => pedidosIds.isNotEmpty;

  /// Obtiene el total con propina
  double get totalConPropina => total + propina;

  @override
  String toString() {
    return 'DocumentoMesa{id: $id, numeroDocumento: $numeroDocumento, '
        'mesaNombre: $mesaNombre, total: $total, pagado: $pagado, '
        'cantidadPedidos: $cantidadPedidos}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DocumentoMesa && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
