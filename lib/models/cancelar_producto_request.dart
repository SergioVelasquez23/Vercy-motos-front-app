class CancelarProductoRequest {
  final String pedidoId;
  final String productoId;
  final List<IngredienteDevolucion> ingredientes;
  final String motivo;
  final String responsable;

  CancelarProductoRequest({
    required this.pedidoId,
    required this.productoId,
    required this.ingredientes,
    required this.motivo,
    required this.responsable,
  });

  Map<String, dynamic> toJson() => {
    'pedidoId': pedidoId,
    'productoId': productoId,
    'ingredientes': ingredientes.map((i) => i.toJson()).toList(),
    'motivo': motivo,
    'responsable': responsable,
  };
}

class IngredienteDevolucion {
  final String ingredienteId;
  final String nombre;
  final double cantidadDescontada;
  final double cantidadADevolver;
  final String unidad;
  final bool devolver;
  final String? motivoNoDevolucion;

  IngredienteDevolucion({
    required this.ingredienteId,
    required this.nombre,
    required this.cantidadDescontada,
    required this.cantidadADevolver,
    required this.unidad,
    required this.devolver,
    this.motivoNoDevolucion,
  });

  Map<String, dynamic> toJson() => {
    'ingredienteId': ingredienteId,
    'nombre': nombre,
    'cantidadDescontada': cantidadDescontada,
    'cantidadADevolver': cantidadADevolver,
    'unidad': unidad,
    'devolver': devolver,
    'motivoNoDevolucion': motivoNoDevolucion,
  };

  factory IngredienteDevolucion.fromJson(Map<String, dynamic> json) {
    return IngredienteDevolucion(
      ingredienteId: json['ingredienteId']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      cantidadDescontada:
          (json['cantidadDescontada'] as num?)?.toDouble() ?? 0.0,
      cantidadADevolver: (json['cantidadADevolver'] as num?)?.toDouble() ?? 0.0,
      unidad: json['unidad']?.toString() ?? '',
      devolver: json['devolver'] == true,
      motivoNoDevolucion: json['motivoNoDevolucion']?.toString(),
    );
  }

  IngredienteDevolucion copyWith({
    String? ingredienteId,
    String? nombre,
    double? cantidadDescontada,
    double? cantidadADevolver,
    String? unidad,
    bool? devolver,
    String? motivoNoDevolucion,
  }) {
    return IngredienteDevolucion(
      ingredienteId: ingredienteId ?? this.ingredienteId,
      nombre: nombre ?? this.nombre,
      cantidadDescontada: cantidadDescontada ?? this.cantidadDescontada,
      cantidadADevolver: cantidadADevolver ?? this.cantidadADevolver,
      unidad: unidad ?? this.unidad,
      devolver: devolver ?? this.devolver,
      motivoNoDevolucion: motivoNoDevolucion ?? this.motivoNoDevolucion,
    );
  }
}
