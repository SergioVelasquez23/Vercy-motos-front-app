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

  // Campos para carga masiva desde Excel
  final String? codigo; // CODIGO*
  final String? productoOServicio; // PRODUCTO O SERVICIO*
  final String? controlInventario; // CONTROL DE INVENTARIO
  final double? porcentajeImpuesto; // % IMPUESTO
  final int? inventarioBajo; // INVENTARIO BAJO
  final int? inventarioOptimo; // INVENTARIO ÓPTIMO
  final String? tipoProductoNombre; // TIPO PRODUCTO (NOMBRE)
  final String? lineaProductoNombre; // LINEA PRODUCTO (NOMBRE)
  final String? claseProductoNombre; // CLASE PRODUCTO (NOMBRE)
  final String? codigoBarras; // CÓDIGO DE BARRAS
  final String? localizacion; // LOCALIZACIÓN
  final String? nombreProveedor; // NOMBRE PROVEEDOR
  final String? nitProveedor; // NIT PROVEEDOR (SIN DV)
  final String? marca; // MARCA
  final double? precioVentaOpc1; // PRECIO DE VENTA OPC 1
  final double? precioVentaOpc2; // PRECIO DE VENTA OPC 2
  final double? precioVentaOpc3; // PRECIO DE VENTA OPC 3
  final double? precioVentaOpc4; // PRECIO DE VENTA OPC 4
  final double? precioVentaOpc5; // PRECIO DE VENTA OPC 5
  final int? almacen; // ALMACEN
  final int? bodega; // BODEGA
  final String? ubicacion1; // UBICACIÓN 1
  final String? ubicacion2; // UBICACIÓN 2
  final String? ubicacion3; // UBICACIÓN 3
  final String? ubicacion4; // UBICACIÓN 4
  final String? localizacionUbi1; // LOCALIZACIÓN UBI 1
  final String? localizacionUbi2; // LOCALIZACIÓN UBI 2
  final String? localizacionUbi3; // LOCALIZACIÓN UBI 3
  final String? localizacionUbi4; // LOCALIZACIÓN UBI 4

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
    // Campos para carga masiva
    this.codigo,
    this.productoOServicio,
    this.controlInventario,
    this.porcentajeImpuesto,
    this.inventarioBajo,
    this.inventarioOptimo,
    this.tipoProductoNombre,
    this.lineaProductoNombre,
    this.claseProductoNombre,
    this.codigoBarras,
    this.localizacion,
    this.nombreProveedor,
    this.nitProveedor,
    this.marca,
    this.precioVentaOpc1,
    this.precioVentaOpc2,
    this.precioVentaOpc3,
    this.precioVentaOpc4,
    this.precioVentaOpc5,
    this.almacen,
    this.bodega,
    this.ubicacion1,
    this.ubicacion2,
    this.ubicacion3,
    this.ubicacion4,
    this.localizacionUbi1,
    this.localizacionUbi2,
    this.localizacionUbi3,
    this.localizacionUbi4,
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
    // Campos para carga masiva
    'codigo': codigo,
    'productoOServicio': productoOServicio,
    'controlInventario': controlInventario,
    'porcentajeImpuesto': porcentajeImpuesto,
    'inventarioBajo': inventarioBajo,
    'inventarioOptimo': inventarioOptimo,
    'tipoProductoNombre': tipoProductoNombre,
    'lineaProductoNombre': lineaProductoNombre,
    'claseProductoNombre': claseProductoNombre,
    'codigoBarras': codigoBarras,
    'localizacion': localizacion,
    'nombreProveedor': nombreProveedor,
    'nitProveedor': nitProveedor,
    'marca': marca,
    'precioVentaOpc1': precioVentaOpc1,
    'precioVentaOpc2': precioVentaOpc2,
    'precioVentaOpc3': precioVentaOpc3,
    'precioVentaOpc4': precioVentaOpc4,
    'precioVentaOpc5': precioVentaOpc5,
    'almacen': almacen,
    'bodega': bodega,
    'ubicacion1': ubicacion1,
    'ubicacion2': ubicacion2,
    'ubicacion3': ubicacion3,
    'ubicacion4': ubicacion4,
    'localizacionUbi1': localizacionUbi1,
    'localizacionUbi2': localizacionUbi2,
    'localizacionUbi3': localizacionUbi3,
    'localizacionUbi4': localizacionUbi4,
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
      // Campos para carga masiva
      codigo: json['codigo']?.toString(),
      productoOServicio: json['productoOServicio']?.toString(),
      controlInventario: json['controlInventario']?.toString(),
      porcentajeImpuesto: (json['porcentajeImpuesto'] as num?)?.toDouble(),
      inventarioBajo: json['inventarioBajo'] as int?,
      inventarioOptimo: json['inventarioOptimo'] as int?,
      tipoProductoNombre: json['tipoProductoNombre']?.toString(),
      lineaProductoNombre: json['lineaProductoNombre']?.toString(),
      claseProductoNombre: json['claseProductoNombre']?.toString(),
      codigoBarras: json['codigoBarras']?.toString(),
      localizacion: json['localizacion']?.toString(),
      nombreProveedor: json['nombreProveedor']?.toString(),
      nitProveedor: json['nitProveedor']?.toString(),
      marca: json['marca']?.toString(),
      precioVentaOpc1: (json['precioVentaOpc1'] as num?)?.toDouble(),
      precioVentaOpc2: (json['precioVentaOpc2'] as num?)?.toDouble(),
      precioVentaOpc3: (json['precioVentaOpc3'] as num?)?.toDouble(),
      precioVentaOpc4: (json['precioVentaOpc4'] as num?)?.toDouble(),
      precioVentaOpc5: (json['precioVentaOpc5'] as num?)?.toDouble(),
      almacen: json['almacen'] as int?,
      bodega: json['bodega'] as int?,
      ubicacion1: json['ubicacion1']?.toString(),
      ubicacion2: json['ubicacion2']?.toString(),
      ubicacion3: json['ubicacion3']?.toString(),
      ubicacion4: json['ubicacion4']?.toString(),
      localizacionUbi1: json['localizacionUbi1']?.toString(),
      localizacionUbi2: json['localizacionUbi2']?.toString(),
      localizacionUbi3: json['localizacionUbi3']?.toString(),
      localizacionUbi4: json['localizacionUbi4']?.toString(),
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
    String? codigo,
    String? productoOServicio,
    String? controlInventario,
    double? porcentajeImpuesto,
    int? inventarioBajo,
    int? inventarioOptimo,
    String? tipoProductoNombre,
    String? lineaProductoNombre,
    String? claseProductoNombre,
    String? codigoBarras,
    String? localizacion,
    String? nombreProveedor,
    String? nitProveedor,
    String? marca,
    double? precioVentaOpc1,
    double? precioVentaOpc2,
    double? precioVentaOpc3,
    double? precioVentaOpc4,
    double? precioVentaOpc5,
    int? almacen,
    int? bodega,
    String? ubicacion1,
    String? ubicacion2,
    String? ubicacion3,
    String? ubicacion4,
    String? localizacionUbi1,
    String? localizacionUbi2,
    String? localizacionUbi3,
    String? localizacionUbi4,
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
      codigo: codigo ?? this.codigo,
      productoOServicio: productoOServicio ?? this.productoOServicio,
      controlInventario: controlInventario ?? this.controlInventario,
      porcentajeImpuesto: porcentajeImpuesto ?? this.porcentajeImpuesto,
      inventarioBajo: inventarioBajo ?? this.inventarioBajo,
      inventarioOptimo: inventarioOptimo ?? this.inventarioOptimo,
      tipoProductoNombre: tipoProductoNombre ?? this.tipoProductoNombre,
      lineaProductoNombre: lineaProductoNombre ?? this.lineaProductoNombre,
      claseProductoNombre: claseProductoNombre ?? this.claseProductoNombre,
      codigoBarras: codigoBarras ?? this.codigoBarras,
      localizacion: localizacion ?? this.localizacion,
      nombreProveedor: nombreProveedor ?? this.nombreProveedor,
      nitProveedor: nitProveedor ?? this.nitProveedor,
      marca: marca ?? this.marca,
      precioVentaOpc1: precioVentaOpc1 ?? this.precioVentaOpc1,
      precioVentaOpc2: precioVentaOpc2 ?? this.precioVentaOpc2,
      precioVentaOpc3: precioVentaOpc3 ?? this.precioVentaOpc3,
      precioVentaOpc4: precioVentaOpc4 ?? this.precioVentaOpc4,
      precioVentaOpc5: precioVentaOpc5 ?? this.precioVentaOpc5,
      almacen: almacen ?? this.almacen,
      bodega: bodega ?? this.bodega,
      ubicacion1: ubicacion1 ?? this.ubicacion1,
      ubicacion2: ubicacion2 ?? this.ubicacion2,
      ubicacion3: ubicacion3 ?? this.ubicacion3,
      ubicacion4: ubicacion4 ?? this.ubicacion4,
      localizacionUbi1: localizacionUbi1 ?? this.localizacionUbi1,
      localizacionUbi2: localizacionUbi2 ?? this.localizacionUbi2,
      localizacionUbi3: localizacionUbi3 ?? this.localizacionUbi3,
      localizacionUbi4: localizacionUbi4 ?? this.localizacionUbi4,
    );
  }
}
