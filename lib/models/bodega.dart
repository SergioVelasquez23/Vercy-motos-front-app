/// Modelo para representar una bodega/almacén/ubicación de inventario
class Bodega {
  final String? id;
  final String nombre;
  final String? codigo;
  final String? tipo; // BODEGA, ALMACEN, PUNTO_VENTA, etc.
  final String? descripcion;
  final String? direccion;
  final String? telefono;
  final String? responsable;
  final bool activa;
  final DateTime? fechaCreacion;
  final DateTime? fechaActualizacion;

  Bodega({
    this.id,
    required this.nombre,
    this.codigo,
    this.tipo,
    this.descripcion,
    this.direccion,
    this.telefono,
    this.responsable,
    this.activa = true,
    this.fechaCreacion,
    this.fechaActualizacion,
  });

  factory Bodega.fromJson(Map<String, dynamic> json) {
    return Bodega(
      id: json['_id'] ?? json['id'],
      nombre: json['nombre'] ?? '',
      codigo: json['codigo'],
      tipo: json['tipo'],
      descripcion: json['descripcion'],
      direccion: json['direccion'],
      telefono: json['telefono'],
      responsable: json['responsable'],
      activa: json['activa'] ?? true,
      fechaCreacion: json['fechaCreacion'] != null
          ? DateTime.parse(json['fechaCreacion'])
          : null,
      fechaActualizacion: json['fechaActualizacion'] != null
          ? DateTime.parse(json['fechaActualizacion'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'nombre': nombre,
      if (codigo != null) 'codigo': codigo,
      if (tipo != null) 'tipo': tipo,
      if (descripcion != null) 'descripcion': descripcion,
      if (direccion != null) 'direccion': direccion,
      if (telefono != null) 'telefono': telefono,
      if (responsable != null) 'responsable': responsable,
      'activa': activa,
    };
  }

  Bodega copyWith({
    String? id,
    String? nombre,
    String? codigo,
    String? tipo,
    String? descripcion,
    String? direccion,
    String? telefono,
    String? responsable,
    bool? activa,
  }) {
    return Bodega(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      codigo: codigo ?? this.codigo,
      tipo: tipo ?? this.tipo,
      descripcion: descripcion ?? this.descripcion,
      direccion: direccion ?? this.direccion,
      telefono: telefono ?? this.telefono,
      responsable: responsable ?? this.responsable,
      activa: activa ?? this.activa,
      fechaCreacion: fechaCreacion,
      fechaActualizacion: fechaActualizacion,
    );
  }
}
