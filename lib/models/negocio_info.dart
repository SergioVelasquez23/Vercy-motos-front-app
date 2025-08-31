class NegocioInfo {
  final String? id;
  final String nombre;
  final String nitDoc;
  final String contacto;
  final String email;
  final String direccion;
  final String pais;
  final String departamento;
  final String ciudad;
  final String? logoUrl;
  final bool tieneProductosConIngredientes;
  final bool utilizaMesas;
  final bool realizaDomicilios;
  final String tipoDocumento;
  final String prefijoDocumento;
  final int numeroInicialDocumento;
  final String? notasAdicionales;
  final DateTime fechaCreacion;
  final DateTime fechaActualizacion;

  // Campos agregados para compatibilidad con la app
  final String? telefono;
  final String? nit;
  final String? paginaWeb;
  final double? costosEnvio;
  final String? prefijo;
  final int? numeroInicio;
  final double? porcentajePropinaSugerida;
  final String? nombreDocumento;
  final String? nota1;
  final String? nota2;
  final bool? productosConIngredientes;
  final bool? utilizoMesas;
  final bool? envioADomicilio;

  NegocioInfo({
    this.id,
    required this.nombre,
    required this.nitDoc,
    required this.contacto,
    required this.email,
    required this.direccion,
    required this.pais,
    required this.departamento,
    required this.ciudad,
    this.logoUrl,
    required this.tieneProductosConIngredientes,
    required this.utilizaMesas,
    required this.realizaDomicilios,
    required this.tipoDocumento,
    required this.prefijoDocumento,
    required this.numeroInicialDocumento,
    this.notasAdicionales,
    required this.fechaCreacion,
    required this.fechaActualizacion,
    // Compatibilidad
    this.telefono,
    this.nit,
    this.paginaWeb,
    this.costosEnvio,
    this.prefijo,
    this.numeroInicio,
    this.porcentajePropinaSugerida,
    this.nombreDocumento,
    this.nota1,
    this.nota2,
    this.productosConIngredientes,
    this.utilizoMesas,
    this.envioADomicilio,
  });

  factory NegocioInfo.fromJson(Map<String, dynamic> json) {
    return NegocioInfo(
      id: json['id'],
      nombre: json['nombre'] ?? '',
      nitDoc: json['nitDoc'] ?? '',
      contacto: json['contacto'] ?? '',
      email: json['email'] ?? '',
      direccion: json['direccion'] ?? '',
      pais: json['pais'] ?? 'Colombia',
      departamento: json['departamento'] ?? '',
      ciudad: json['ciudad'] ?? '',
      logoUrl: json['logoUrl'],
      tieneProductosConIngredientes:
          json['tieneProductosConIngredientes'] ?? false,
      utilizaMesas: json['utilizaMesas'] ?? true,
      realizaDomicilios: json['realizaDomicilios'] ?? false,
      tipoDocumento: json['tipoDocumento'] ?? 'Factura',
      prefijoDocumento: json['prefijoDocumento'] ?? 'F',
      numeroInicialDocumento: json['numeroInicialDocumento'] ?? 1,
      notasAdicionales: json['notasAdicionales'],
      fechaCreacion: json['fechaCreacion'] != null
          ? DateTime.parse(json['fechaCreacion'])
          : DateTime.now(),
      fechaActualizacion: json['fechaActualizacion'] != null
          ? DateTime.parse(json['fechaActualizacion'])
          : DateTime.now(),
      // Compatibilidad
      telefono: json['telefono'],
      nit: json['nit'],
      paginaWeb: json['paginaWeb'],
      costosEnvio: (json['costosEnvio'] is num) ? (json['costosEnvio'] as num).toDouble() : null,
      prefijo: json['prefijo'],
      numeroInicio: json['numeroInicio'],
      porcentajePropinaSugerida: (json['porcentajePropinaSugerida'] is num) ? (json['porcentajePropinaSugerida'] as num).toDouble() : null,
      nombreDocumento: json['nombreDocumento'],
      nota1: json['nota1'],
      nota2: json['nota2'],
      productosConIngredientes: json['productosConIngredientes'],
      utilizoMesas: json['utilizoMesas'],
      envioADomicilio: json['envioADomicilio'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'nitDoc': nitDoc,
      'contacto': contacto,
      'email': email,
      'direccion': direccion,
      'pais': pais,
      'departamento': departamento,
      'ciudad': ciudad,
      'logoUrl': logoUrl,
      'tieneProductosConIngredientes': tieneProductosConIngredientes,
      'utilizaMesas': utilizaMesas,
      'realizaDomicilios': realizaDomicilios,
      'tipoDocumento': tipoDocumento,
      'prefijoDocumento': prefijoDocumento,
      'numeroInicialDocumento': numeroInicialDocumento,
      'notasAdicionales': notasAdicionales,
      'fechaCreacion': fechaCreacion.toIso8601String(),
      'fechaActualizacion': fechaActualizacion.toIso8601String(),
      // Compatibilidad
      'telefono': telefono,
      'nit': nit,
      'paginaWeb': paginaWeb,
      'costosEnvio': costosEnvio,
      'prefijo': prefijo,
      'numeroInicio': numeroInicio,
      'porcentajePropinaSugerida': porcentajePropinaSugerida,
      'nombreDocumento': nombreDocumento,
      'nota1': nota1,
      'nota2': nota2,
      'productosConIngredientes': productosConIngredientes,
      'utilizoMesas': utilizoMesas,
      'envioADomicilio': envioADomicilio,
    };
  }

  NegocioInfo copyWith({
    String? id,
    String? nombre,
    String? nitDoc,
    String? contacto,
    String? email,
    String? direccion,
    String? pais,
    String? departamento,
    String? ciudad,
    String? logoUrl,
    bool? tieneProductosConIngredientes,
    bool? utilizaMesas,
    bool? realizaDomicilios,
    String? tipoDocumento,
    String? prefijoDocumento,
    int? numeroInicialDocumento,
    String? notasAdicionales,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    // Compatibilidad
    String? telefono,
    String? nit,
    String? paginaWeb,
    double? costosEnvio,
    String? prefijo,
    int? numeroInicio,
    double? porcentajePropinaSugerida,
    String? nombreDocumento,
    String? nota1,
    String? nota2,
    bool? productosConIngredientes,
    bool? utilizoMesas,
    bool? envioADomicilio,
  }) {
    return NegocioInfo(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      nitDoc: nitDoc ?? this.nitDoc,
      contacto: contacto ?? this.contacto,
      email: email ?? this.email,
      direccion: direccion ?? this.direccion,
      pais: pais ?? this.pais,
      departamento: departamento ?? this.departamento,
      ciudad: ciudad ?? this.ciudad,
      logoUrl: logoUrl ?? this.logoUrl,
      tieneProductosConIngredientes:
          tieneProductosConIngredientes ?? this.tieneProductosConIngredientes,
      utilizaMesas: utilizaMesas ?? this.utilizaMesas,
      realizaDomicilios: realizaDomicilios ?? this.realizaDomicilios,
      tipoDocumento: tipoDocumento ?? this.tipoDocumento,
      prefijoDocumento: prefijoDocumento ?? this.prefijoDocumento,
      numeroInicialDocumento:
          numeroInicialDocumento ?? this.numeroInicialDocumento,
      notasAdicionales: notasAdicionales ?? this.notasAdicionales,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      // Compatibilidad
      telefono: telefono ?? this.telefono,
      nit: nit ?? this.nit,
      paginaWeb: paginaWeb ?? this.paginaWeb,
      costosEnvio: costosEnvio ?? this.costosEnvio,
      prefijo: prefijo ?? this.prefijo,
      numeroInicio: numeroInicio ?? this.numeroInicio,
      porcentajePropinaSugerida: porcentajePropinaSugerida ?? this.porcentajePropinaSugerida,
      nombreDocumento: nombreDocumento ?? this.nombreDocumento,
      nota1: nota1 ?? this.nota1,
      nota2: nota2 ?? this.nota2,
      productosConIngredientes: productosConIngredientes ?? this.productosConIngredientes,
      utilizoMesas: utilizoMesas ?? this.utilizoMesas,
      envioADomicilio: envioADomicilio ?? this.envioADomicilio,
    );
  }
}
