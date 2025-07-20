class Categoria {
  final String id;
  final String nombre;
  final String? imagenUrl;

  Categoria({required this.id, required this.nombre, this.imagenUrl});

  // Método para convertir desde/a JSON para futura persistencia
  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'imagenUrl': imagenUrl,
  };

  factory Categoria.fromJson(Map<String, dynamic> json) {
    return Categoria(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      imagenUrl: json['imagenUrl']?.toString(),
    );
  }
}
