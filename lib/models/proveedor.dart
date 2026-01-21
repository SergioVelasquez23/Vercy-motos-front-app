class Proveedor {
  final String id;
  final String nombre;
  final String? apellidos;
  final String? nombreComercial;
  final String? documento;
  final String? digitoVerificacion;
  final String? email;
  final String? telefono;
  final String? direccion;
  final String? tipo; // "Persona Natural" o "Persona Jurídica"
  final String? tipoId; // "CC", "NIT", "Pasaporte", etc.
  final String? departamento;
  final String? ciudad;
  final String? actividadEconomica;
  final String? responsableIVA; // "SI" o "NO"
  final String? calidadRetenedor; // "Agente de retención" o "No aplica"
  final String? banco;
  final String? tipoCuenta; // "Ahorros" o "Corriente"
  final String? numeroCuenta;
  final String? cuentasPorPagar;
  final String? cuentasDevolucion;
  final String? paginaWeb;
  final String? contacto;
  final String? nota;
  final DateTime fechaCreacion;
  final DateTime fechaActualizacion;

  Proveedor({
    required this.id,
    required this.nombre,
    this.apellidos,
    this.nombreComercial,
    this.documento,
    this.digitoVerificacion,
    this.email,
    this.telefono,
    this.direccion,
    this.tipo,
    this.tipoId,
    this.departamento,
    this.ciudad,
    this.actividadEconomica,
    this.responsableIVA,
    this.calidadRetenedor,
    this.banco,
    this.tipoCuenta,
    this.numeroCuenta,
    this.cuentasPorPagar,
    this.cuentasDevolucion,
    this.paginaWeb,
    this.contacto,
    this.nota,
    required this.fechaCreacion,
    required this.fechaActualizacion,
  });

  factory Proveedor.fromJson(Map<String, dynamic> json) {
    return Proveedor(
      id: json['id'] ?? '',
      nombre: json['nombre'] ?? '',
      apellidos: json['apellidos'],
      nombreComercial: json['nombreComercial'],
      documento: json['documento'],
      digitoVerificacion: json['digitoVerificacion'],
      email: json['email'],
      telefono: json['telefono'],
      direccion: json['direccion'],
      tipo: json['tipo'],
      tipoId: json['tipoId'],
      departamento: json['departamento'],
      ciudad: json['ciudad'],
      actividadEconomica: json['actividadEconomica'],
      responsableIVA: json['responsableIVA'],
      calidadRetenedor: json['calidadRetenedor'],
      banco: json['banco'],
      tipoCuenta: json['tipoCuenta'],
      numeroCuenta: json['numeroCuenta'],
      cuentasPorPagar: json['cuentasPorPagar'],
      cuentasDevolucion: json['cuentasDevolucion'],
      paginaWeb: json['paginaWeb'],
      contacto: json['contacto'],
      nota: json['nota'],
      fechaCreacion: json['fechaCreacion'] != null
          ? DateTime.parse(json['fechaCreacion'])
          : DateTime.now(),
      fechaActualizacion: json['fechaActualizacion'] != null
          ? DateTime.parse(json['fechaActualizacion'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'apellidos': apellidos,
      'nombreComercial': nombreComercial,
      'documento': documento,
      'digitoVerificacion': digitoVerificacion,
      'email': email,
      'telefono': telefono,
      'direccion': direccion,
      'tipo': tipo,
      'tipoId': tipoId,
      'departamento': departamento,
      'ciudad': ciudad,
      'actividadEconomica': actividadEconomica,
      'responsableIVA': responsableIVA,
      'calidadRetenedor': calidadRetenedor,
      'banco': banco,
      'tipoCuenta': tipoCuenta,
      'numeroCuenta': numeroCuenta,
      'cuentasPorPagar': cuentasPorPagar,
      'cuentasDevolucion': cuentasDevolucion,
      'paginaWeb': paginaWeb,
      'contacto': contacto,
      'nota': nota,
      'fechaCreacion': fechaCreacion.toIso8601String(),
      'fechaActualizacion': fechaActualizacion.toIso8601String(),
    };
  }

  Map<String, dynamic> toJsonCreate() {
    final json = <String, dynamic>{'nombre': nombre};

    if (apellidos != null && apellidos!.isNotEmpty) {
      json['apellidos'] = apellidos;
    }
    if (nombreComercial != null && nombreComercial!.isNotEmpty) {
      json['nombreComercial'] = nombreComercial;
    }
    if (documento != null && documento!.isNotEmpty) {
      json['documento'] = documento;
    }
    if (digitoVerificacion != null && digitoVerificacion!.isNotEmpty) {
      json['digitoVerificacion'] = digitoVerificacion;
    }
    if (email != null && email!.isNotEmpty) {
      json['email'] = email;
    }
    if (telefono != null && telefono!.isNotEmpty) {
      json['telefono'] = telefono;
    }
    if (direccion != null && direccion!.isNotEmpty) {
      json['direccion'] = direccion;
    }
    if (tipo != null && tipo!.isNotEmpty) {
      json['tipo'] = tipo;
    }
    if (tipoId != null && tipoId!.isNotEmpty) {
      json['tipoId'] = tipoId;
    }
    if (departamento != null && departamento!.isNotEmpty) {
      json['departamento'] = departamento;
    }
    if (ciudad != null && ciudad!.isNotEmpty) {
      json['ciudad'] = ciudad;
    }
    if (actividadEconomica != null && actividadEconomica!.isNotEmpty) {
      json['actividadEconomica'] = actividadEconomica;
    }
    if (responsableIVA != null && responsableIVA!.isNotEmpty) {
      json['responsableIVA'] = responsableIVA;
    }
    if (calidadRetenedor != null && calidadRetenedor!.isNotEmpty) {
      json['calidadRetenedor'] = calidadRetenedor;
    }
    if (banco != null && banco!.isNotEmpty) {
      json['banco'] = banco;
    }
    if (tipoCuenta != null && tipoCuenta!.isNotEmpty) {
      json['tipoCuenta'] = tipoCuenta;
    }
    if (numeroCuenta != null && numeroCuenta!.isNotEmpty) {
      json['numeroCuenta'] = numeroCuenta;
    }
    if (cuentasPorPagar != null && cuentasPorPagar!.isNotEmpty) {
      json['cuentasPorPagar'] = cuentasPorPagar;
    }
    if (cuentasDevolucion != null && cuentasDevolucion!.isNotEmpty) {
      json['cuentasDevolucion'] = cuentasDevolucion;
    }
    if (paginaWeb != null && paginaWeb!.isNotEmpty) {
      json['paginaWeb'] = paginaWeb;
    }
    if (contacto != null && contacto!.isNotEmpty) {
      json['contacto'] = contacto;
    }
    if (nota != null && nota!.isNotEmpty) {
      json['nota'] = nota;
    }

    return json;
  }
}
