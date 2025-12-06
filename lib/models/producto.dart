import 'categoria.dart';

class IngredienteProducto {
  final String ingredienteId;
  final String ingredienteNombre;
  final double cantidadNecesaria;
  final bool esOpcional;
  final double precioAdicional;

  IngredienteProducto({
    required this.ingredienteId,
    required this.ingredienteNombre,
    required this.cantidadNecesaria,
    this.esOpcional = false,
    this.precioAdicional = 0.0,
  });

  factory IngredienteProducto.fromJson(Map<String, dynamic> json) {
    // ✅ COMENTADO: Log de parsing removido para reducir ruido
    // print('🔍 Parsing IngredienteProducto from JSON: $json');

    // El backend Java usa 'nombre' como campo principal
    String nombre = '';
    if (json.containsKey('nombre') && json['nombre'] != null) {
      nombre = json['nombre'].toString();
    } else if (json.containsKey('ingredienteNombre') &&
        json['ingredienteNombre'] != null) {
      nombre = json['ingredienteNombre'].toString();
    } else if (json.containsKey('ingrediente') && json['ingrediente'] != null) {
      if (json['ingrediente'] is Map) {
        nombre = json['ingrediente']['nombre']?.toString() ?? '';
      } else {
        nombre = json['ingrediente'].toString();
      }
    } else if (json.containsKey('ingredienteId') &&
        json['ingredienteId'] != null) {
      // Como fallback, usar el ID si no hay nombre
      nombre = json['ingredienteId'].toString();
    }

    // ✅ COMENTADO: Log de nombre extraído removido para reducir ruido
    // print('🔍 Nombre extraído: "$nombre"');

    return IngredienteProducto(
      ingredienteId:
          json['ingredienteId']?.toString() ??
          json['_id']?.toString() ??
          json['id']?.toString() ??
          '',
      ingredienteNombre: nombre,
      cantidadNecesaria:
          (json['cantidadNecesaria'] as num?)?.toDouble() ??
          (json['cantidad'] as num?)?.toDouble() ??
          0.0,
      esOpcional: json['esOpcional'] ?? false,
      precioAdicional:
          (json['precioAdicional'] as num?)?.toDouble() ??
          (json['precio'] as num?)?.toDouble() ??
          0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'ingredienteId': ingredienteId,
    'ingredienteNombre': ingredienteNombre,
    'cantidadNecesaria': cantidadNecesaria,
    'esOpcional': esOpcional,
    'precioAdicional': precioAdicional,
  };
}

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
  final List<String> ingredientesDisponibles;
  final bool tieneIngredientes; // Nuevo campo
  final String tipoProducto; // Nuevo campo: "combo" o "individual"
  final List<IngredienteProducto> ingredientesRequeridos; // Nuevo campo
  final List<IngredienteProducto> ingredientesOpcionales; // Nuevo campo
  final List<String>
  ingredientesSeleccionadosCombo; // Nuevo campo para combo seleccionado

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
    this.ingredientesDisponibles = const [],
    this.tieneIngredientes = false,
    this.tipoProducto = 'individual',
    this.ingredientesRequeridos = const [],
    this.ingredientesOpcionales = const [],
    this.ingredientesSeleccionadosCombo = const [], // Nuevo campo
  });

  // Métodos de conveniencia para verificar tipo de producto
  bool get esCombo => tipoProducto == 'combo';
  bool get esIndividual => tipoProducto == 'individual';

  // Método para verificar si tiene ingredientes seleccionables
  bool get puedeSeleccionarIngredientes =>
      (esCombo &&
          (ingredientesOpcionales.isNotEmpty ||
              ingredientesRequeridos.isNotEmpty)) ||
      (esIndividual); // Los productos individuales siempre pueden seleccionar ingredientes

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
    // Enviamos tanto el ID como el nombre de la categoría
    'categoriaId': categoria?.id,
    'categoriaNombre':
        categoria?.nombre, // Incluimos el nombre para mantener consistencia
    'descripcion': descripcion,
    'cantidad': cantidad,
    'nota': nota,
    'ingredientesDisponibles': ingredientesDisponibles,
    'tieneIngredientes': tieneIngredientes,
    'tipoProducto': tipoProducto,
    'ingredientesRequeridos': ingredientesRequeridos
        .map((i) => i.toJson())
        .toList(),
    'ingredientesOpcionales': ingredientesOpcionales
        .map((i) => i.toJson())
        .toList(),
    'ingredientesSeleccionadosCombo': ingredientesSeleccionadosCombo,
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
          : json['categoriaId'] != null && json['categoriaNombre'] != null
          ? Categoria(
              id: json['categoriaId'].toString(),
              nombre: json['categoriaNombre'].toString(),
            )
          : json['categoriaId'] != null
          ? Categoria(
              id: json['categoriaId'].toString(),
              nombre:
                  'Adicionales', // Default name that makes more sense in context
            )
          : null,
      descripcion: json['descripcion']?.toString(),
      cantidad: json['cantidad'] ?? 1,
      nota: json['nota']?.toString(),
      ingredientesDisponibles: json['ingredientesDisponibles'] != null
          ? List<String>.from(json['ingredientesDisponibles'])
          : [],
      tieneIngredientes: json['tieneIngredientes'] ?? false,
      tipoProducto: json['tipoProducto']?.toString() ?? 'individual',
      ingredientesRequeridos: json['ingredientesRequeridos'] != null
          ? (json['ingredientesRequeridos'] as List)
                .map((i) => IngredienteProducto.fromJson(i))
                .toList()
          : [],
      ingredientesOpcionales: json['ingredientesOpcionales'] != null
          ? (json['ingredientesOpcionales'] as List)
                .map((i) => IngredienteProducto.fromJson(i))
                .toList()
          : [],
      ingredientesSeleccionadosCombo:
          json['ingredientesSeleccionadosCombo'] != null
          ? List<String>.from(json['ingredientesSeleccionadosCombo'])
          : [],
    );
  }

  // Método ligero para cargas rápidas - solo campos esenciales del endpoint paginado
  factory Producto.fromJsonLigero(Map<String, dynamic> json) {
    return Producto(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      precio: (json['precio'] as num?)?.toDouble() ?? 0.0,
      costo: 0.0, // No viene en el endpoint ligero
      impuestos: 0.0, // No viene en el endpoint ligero
      utilidad: 0.0, // No viene en el endpoint ligero
      tieneVariantes: false, // No viene en el endpoint ligero
      estado: json['estado']?.toString() ?? 'Activo',
      imagenUrl: null, // ⚡ NO CARGAR IMAGEN para máxima velocidad
      categoria: json['categoriaId'] != null
          ? Categoria(
              id: json['categoriaId'].toString(),
              nombre: json['categoriaNombre']?.toString() ?? 'Categoría',
            )
          : json['categoria'] != null
          ? Categoria.fromJson(json['categoria'])
          : null,
      descripcion: null, // No viene en el endpoint ligero
      cantidad: 1, // Default
      nota: null, // No viene en el endpoint ligero
      ingredientesDisponibles: [], // No viene en el endpoint ligero
      tieneIngredientes: json['tieneIngredientes'] ?? false,
      tipoProducto: json['tipoProducto']?.toString() ?? 'individual',
      ingredientesRequeridos: [], // No vienen en el endpoint ligero
      ingredientesOpcionales: [], // No vienen en el endpoint ligero
      ingredientesSeleccionadosCombo: [],
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
    List<String>? ingredientesDisponibles,
    bool? tieneIngredientes,
    String? tipoProducto,
    List<IngredienteProducto>? ingredientesRequeridos,
    List<IngredienteProducto>? ingredientesOpcionales,
    List<String>? ingredientesSeleccionadosCombo,
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
      ingredientesDisponibles:
          ingredientesDisponibles ?? this.ingredientesDisponibles,
      tieneIngredientes: tieneIngredientes ?? this.tieneIngredientes,
      tipoProducto: tipoProducto ?? this.tipoProducto,
      ingredientesRequeridos:
          ingredientesRequeridos ?? this.ingredientesRequeridos,
      ingredientesOpcionales:
          ingredientesOpcionales ?? this.ingredientesOpcionales,
      ingredientesSeleccionadosCombo:
          ingredientesSeleccionadosCombo ?? this.ingredientesSeleccionadosCombo,
    );
  }
}
