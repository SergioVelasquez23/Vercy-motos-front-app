class Traslado {
  String? id;
  String? numero;
  String? productoId;
  String? productoNombre;
  String? origenBodegaId;
  String? origenBodegaNombre;
  String? destinoBodegaId;
  String? destinoBodegaNombre;
  double? cantidad;
  String? unidad;
  String? estado; // PENDIENTE, ACEPTADO, RECHAZADO
  String? solicitante;
  String? aprobador;
  String? observaciones;
  DateTime? fechaSolicitud;
  DateTime? fechaAprobacion;
  DateTime? fechaCompletado;

  Traslado({
    this.id,
    this.numero,
    this.productoId,
    this.productoNombre,
    this.origenBodegaId,
    this.origenBodegaNombre,
    this.destinoBodegaId,
    this.destinoBodegaNombre,
    this.cantidad,
    this.unidad,
    this.estado,
    this.solicitante,
    this.aprobador,
    this.observaciones,
    this.fechaSolicitud,
    this.fechaAprobacion,
    this.fechaCompletado,
  });

  factory Traslado.fromJson(Map<String, dynamic> json) {
    return Traslado(
      id: json['_id'] ?? json['id'],
      numero: json['numero'],
      productoId: json['productoId'],
      productoNombre: json['productoNombre'],
      origenBodegaId: json['origenBodegaId'],
      origenBodegaNombre: json['origenBodegaNombre'],
      destinoBodegaId: json['destinoBodegaId'],
      destinoBodegaNombre: json['destinoBodegaNombre'],
      cantidad: json['cantidad']?.toDouble(),
      unidad: json['unidad'],
      estado: json['estado'],
      solicitante: json['solicitante'],
      aprobador: json['aprobador'],
      observaciones: json['observaciones'],
      fechaSolicitud: json['fechaSolicitud'] != null
          ? DateTime.parse(json['fechaSolicitud'])
          : null,
      fechaAprobacion: json['fechaAprobacion'] != null
          ? DateTime.parse(json['fechaAprobacion'])
          : null,
      fechaCompletado: json['fechaCompletado'] != null
          ? DateTime.parse(json['fechaCompletado'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      if (numero != null) 'numero': numero,
      'productoId': productoId,
      'productoNombre': productoNombre,
      'origenBodegaId': origenBodegaId,
      'origenBodegaNombre': origenBodegaNombre,
      'destinoBodegaId': destinoBodegaId,
      'destinoBodegaNombre': destinoBodegaNombre,
      'cantidad': cantidad,
      'unidad': unidad,
      'estado': estado,
      'solicitante': solicitante,
      if (aprobador != null) 'aprobador': aprobador,
      if (observaciones != null) 'observaciones': observaciones,
      if (fechaSolicitud != null)
        'fechaSolicitud': fechaSolicitud!.toIso8601String(),
      if (fechaAprobacion != null)
        'fechaAprobacion': fechaAprobacion!.toIso8601String(),
      if (fechaCompletado != null)
        'fechaCompletado': fechaCompletado!.toIso8601String(),
    };
  }
}
