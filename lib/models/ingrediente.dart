class Ingrediente {
  final String id;
  final String nombre;
  final String categoria;
  final double cantidad;
  final String unidad;
  final double costo;
  final String estado;
  final bool descontable;
  final double? stockActual;
  final double? stockMinimo;

  Ingrediente({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.cantidad,
    required this.unidad,
    required this.costo,
    this.estado = 'Activo',
    this.descontable = true,
    this.stockActual,
    this.stockMinimo,
  });

  // Getter para obtener el stock actual, priorizando stockActual si existe
  double get stock => stockActual ?? cantidad;

  // Getter para obtener el stock mínimo, con valor por defecto
  double get stockMin => stockMinimo ?? 0.0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'categoriaId': categoria,
    'cantidad': cantidad,
    'unidad': unidad,
    'costo': costo,
    'estado': estado,
    'descontable': descontable,
    if (stockActual != null) 'stockActual': stockActual,
    if (stockMinimo != null) 'stockMinimo': stockMinimo,
  };

  factory Ingrediente.fromJson(Map<String, dynamic> json) {
    return Ingrediente(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      categoria:
          json['categoria']?.toString() ??
          json['categoriaId']?.toString() ??
          '',
      cantidad:
          (json['cantidad'] as num?)?.toDouble() ??
          (json['stockActual'] as num?)?.toDouble() ??
          0.0,
      unidad: json['unidad']?.toString() ?? '',
      costo: (json['costo'] as num?)?.toDouble() ?? 0.0,
      estado: json['estado']?.toString() ?? 'Activo',
      descontable: json['descontable'] ?? true,
      stockActual: (json['stockActual'] as num?)?.toDouble(),
      stockMinimo: (json['stockMinimo'] as num?)?.toDouble(),
    );
  }

  Ingrediente copyWith({
    String? id,
    String? nombre,
    String? categoria,
    double? cantidad,
    String? unidad,
    double? costo,
    String? estado,
    bool? descontable,
    double? stockActual,
    double? stockMinimo,
  }) {
    return Ingrediente(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      categoria: categoria ?? this.categoria,
      cantidad: cantidad ?? this.cantidad,
      unidad: unidad ?? this.unidad,
      costo: costo ?? this.costo,
      estado: estado ?? this.estado,
      descontable: descontable ?? this.descontable,
      stockActual: stockActual ?? this.stockActual,
      stockMinimo: stockMinimo ?? this.stockMinimo,
    );
  }
}
