import 'categoria.dart';

class Producto {
  final String id;
  final String nombre;
  final double precio;
  final double costo;
  final double impuestos;
  final double utilidad;
  final bool tieneVariantes;
  final String estado;
  final String? imagenUrl;
  final Categoria? categoria;
  final String? descripcion;
  int cantidad;
  String? nota;

  Producto({
    required this.id,
    required this.nombre,
    required this.precio,
    required this.costo,
    this.impuestos = 0,
    required this.utilidad,
    this.tieneVariantes = false,
    this.estado = 'Activo',
    this.imagenUrl,
    this.categoria,
    this.descripcion,
    this.cantidad = 1,
    this.nota,
  });

  // Eliminar: double get subtotal => precio * cantidad;
  // El subtotal debe ser calculado en el backend

  // Métodos para convertir desde/a JSON para futura persistencia
  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'precio': precio,
    'costo': costo,
    'impuestos': impuestos,
    'utilidad': utilidad,
    'tieneVariantes': tieneVariantes,
    'estado': estado,
    'imagenUrl': imagenUrl,
    'categoria': categoria?.toJson(),
    'descripcion': descripcion,
    'cantidad': cantidad,
    'nota': nota,
  };

  factory Producto.fromJson(Map<String, dynamic> json) {
    return Producto(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      precio: (json['precio'] as num?)?.toDouble() ?? 0.0,
      costo: (json['costo'] as num?)?.toDouble() ?? 0.0,
      impuestos: (json['impuestos'] as num?)?.toDouble() ?? 0.0,
      utilidad: (json['utilidad'] as num?)?.toDouble() ?? 0.0,
      tieneVariantes: json['tieneVariantes'] ?? false,
      estado: json['estado']?.toString() ?? 'Activo',
      imagenUrl: json['imagenUrl']?.toString(),
      categoria: json['categoria'] != null
          ? Categoria.fromJson(json['categoria'])
          : null,
      descripcion: json['descripcion']?.toString(),
      cantidad: json['cantidad'] ?? 1,
      nota: json['nota']?.toString(),
    );
  }

  // Método para crear una copia con nuevos valores (útil para edición)
  Producto copyWith({
    String? id,
    String? nombre,
    double? precio,
    double? costo,
    double? impuestos,
    double? utilidad,
    bool? tieneVariantes,
    String? estado,
    String? imagenUrl,
    Categoria? categoria,
    String? descripcion,
    int? cantidad,
    String? nota,
  }) {
    return Producto(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      precio: precio ?? this.precio,
      costo: costo ?? this.costo,
      impuestos: impuestos ?? this.impuestos,
      utilidad: utilidad ?? this.utilidad,
      tieneVariantes: tieneVariantes ?? this.tieneVariantes,
      estado: estado ?? this.estado,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      categoria: categoria ?? this.categoria,
      descripcion: descripcion ?? this.descripcion,
      cantidad: cantidad ?? this.cantidad,
      nota: nota ?? this.nota,
    );
  }
}
