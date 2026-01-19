class Cliente {
  // Identificación
  String? id;
  String tipoPersona; // "Persona Natural" | "Persona Jurídica"
  String tipoIdentificacion; // "CC" | "NIT" | "CE" | "Pasaporte" | "TI"
  String numeroIdentificacion; // Documento único
  String? digitoVerificacion; // DV para NIT

  // Datos Personales
  String? nombres;
  String? apellidos;
  String? razonSocial; // Auto-generado o manual
  String? correo;
  String? telefono;
  String? telefonoSecundario;
  String? direccion;
  String? departamento;
  String? ciudad;
  String? codigoPostal;

  // Datos Contribuyente (DIAN)
  String responsableIVA; // "Sí" | "No" | "No Aplica"
  String
  calidadAgenteRetencion; // "Autorretenedor" | "Agente de retención" | "No aplica"
  String? regimenTributario; // "Común" | "Simplificado"
  String? responsabilidadesFiscales;

  // Cuentas Contables
  String? cuentasPorCobrar;
  String? cuentasParaDevoluciones;
  String? sobreabonos;
  String? deterioroCartera;

  // Información Comercial
  String? condicionPago;
  int diasCredito;
  double cupoCredito;
  double saldoActual;
  String? categoriaCliente;
  String? vendedorAsignado;
  String? zonaVentas;

  // Tracking
  DateTime? fechaCreacion;
  String? creadoPor;
  String estado; // "activo" | "inactivo" | "bloqueado"
  bool habilitadoFacturacionElectronica;

  // Constructor
  Cliente({
    this.id,
    required this.tipoPersona,
    required this.tipoIdentificacion,
    required this.numeroIdentificacion,
    this.digitoVerificacion,
    this.nombres,
    this.apellidos,
    this.razonSocial,
    this.correo,
    this.telefono,
    this.telefonoSecundario,
    this.direccion,
    this.departamento,
    this.ciudad,
    this.codigoPostal,
    this.responsableIVA = "No",
    this.calidadAgenteRetencion = "No aplica",
    this.regimenTributario,
    this.responsabilidadesFiscales,
    this.cuentasPorCobrar,
    this.cuentasParaDevoluciones,
    this.sobreabonos,
    this.deterioroCartera,
    this.condicionPago,
    this.diasCredito = 0,
    this.cupoCredito = 0.0,
    this.saldoActual = 0.0,
    this.categoriaCliente,
    this.vendedorAsignado,
    this.zonaVentas,
    this.fechaCreacion,
    this.creadoPor,
    this.estado = "activo",
    this.habilitadoFacturacionElectronica = true,
  });

  // Getter: cupo disponible
  double get cupoDisponible => cupoCredito - saldoActual;

  // Getter: tiene cupo
  bool tieneCupoDisponible(double monto) => cupoDisponible >= monto;

  // Getter: nombre completo o razón social
  String get nombreCompleto {
    if (tipoPersona == "Persona Natural") {
      return "${nombres ?? ''} ${apellidos ?? ''}".trim();
    }
    return razonSocial ?? numeroIdentificacion;
  }

  // fromJson
  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      id: json['_id'] ?? json['id'],
      tipoPersona: json['tipoPersona'] ?? '',
      tipoIdentificacion: json['tipoIdentificacion'] ?? '',
      numeroIdentificacion: json['numeroIdentificacion'] ?? '',
      digitoVerificacion: json['digitoVerificacion'],
      nombres: json['nombres'],
      apellidos: json['apellidos'],
      razonSocial: json['razonSocial'],
      correo: json['correo'],
      telefono: json['telefono'],
      telefonoSecundario: json['telefonoSecundario'],
      direccion: json['direccion'],
      departamento: json['departamento'],
      ciudad: json['ciudad'],
      codigoPostal: json['codigoPostal'],
      responsableIVA: json['responsableIVA'] ?? 'No',
      calidadAgenteRetencion: json['calidadAgenteRetencion'] ?? 'No aplica',
      regimenTributario: json['regimenTributario'],
      responsabilidadesFiscales: json['responsabilidadesFiscales'],
      cuentasPorCobrar: json['cuentasPorCobrar'],
      cuentasParaDevoluciones: json['cuentasParaDevoluciones'],
      sobreabonos: json['sobreabonos'],
      deterioroCartera: json['deterioroCartera'],
      condicionPago: json['condicionPago'],
      diasCredito: (json['diasCredito'] ?? 0) is int
          ? json['diasCredito']
          : (json['diasCredito'] as num).toInt(),
      cupoCredito: (json['cupoCredito'] ?? 0.0).toDouble(),
      saldoActual: (json['saldoActual'] ?? 0.0).toDouble(),
      categoriaCliente: json['categoriaCliente'],
      vendedorAsignado: json['vendedorAsignado'],
      zonaVentas: json['zonaVentas'],
      fechaCreacion: json['fechaCreacion'] != null
          ? DateTime.parse(json['fechaCreacion'])
          : null,
      creadoPor: json['creadoPor'],
      estado: json['estado'] ?? 'activo',
      habilitadoFacturacionElectronica:
          json['habilitadoFacturacionElectronica'] ?? true,
    );
  }

  // toJson
  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'tipoPersona': tipoPersona,
      'tipoIdentificacion': tipoIdentificacion,
      'numeroIdentificacion': numeroIdentificacion,
      if (digitoVerificacion != null) 'digitoVerificacion': digitoVerificacion,
      if (nombres != null) 'nombres': nombres,
      if (apellidos != null) 'apellidos': apellidos,
      if (razonSocial != null) 'razonSocial': razonSocial,
      if (correo != null) 'correo': correo,
      if (telefono != null) 'telefono': telefono,
      if (telefonoSecundario != null) 'telefonoSecundario': telefonoSecundario,
      if (direccion != null) 'direccion': direccion,
      if (departamento != null) 'departamento': departamento,
      if (ciudad != null) 'ciudad': ciudad,
      if (codigoPostal != null) 'codigoPostal': codigoPostal,
      'responsableIVA': responsableIVA,
      'calidadAgenteRetencion': calidadAgenteRetencion,
      if (regimenTributario != null) 'regimenTributario': regimenTributario,
      if (responsabilidadesFiscales != null)
        'responsabilidadesFiscales': responsabilidadesFiscales,
      if (cuentasPorCobrar != null) 'cuentasPorCobrar': cuentasPorCobrar,
      if (cuentasParaDevoluciones != null)
        'cuentasParaDevoluciones': cuentasParaDevoluciones,
      if (sobreabonos != null) 'sobreabonos': sobreabonos,
      if (deterioroCartera != null) 'deterioroCartera': deterioroCartera,
      if (condicionPago != null) 'condicionPago': condicionPago,
      'diasCredito': diasCredito,
      'cupoCredito': cupoCredito,
      'saldoActual': saldoActual,
      if (categoriaCliente != null) 'categoriaCliente': categoriaCliente,
      if (vendedorAsignado != null) 'vendedorAsignado': vendedorAsignado,
      if (zonaVentas != null) 'zonaVentas': zonaVentas,
      if (fechaCreacion != null)
        'fechaCreacion': fechaCreacion!.toIso8601String(),
      if (creadoPor != null) 'creadoPor': creadoPor,
      'estado': estado,
      'habilitadoFacturacionElectronica': habilitadoFacturacionElectronica,
    };
  }

  // copyWith
  Cliente copyWith({
    String? id,
    String? tipoPersona,
    String? tipoIdentificacion,
    String? numeroIdentificacion,
    String? digitoVerificacion,
    String? nombres,
    String? apellidos,
    String? razonSocial,
    String? correo,
    String? telefono,
    String? telefonoSecundario,
    String? direccion,
    String? departamento,
    String? ciudad,
    String? codigoPostal,
    String? responsableIVA,
    String? calidadAgenteRetencion,
    String? regimenTributario,
    String? responsabilidadesFiscales,
    String? cuentasPorCobrar,
    String? cuentasParaDevoluciones,
    String? sobreabonos,
    String? deterioroCartera,
    String? condicionPago,
    int? diasCredito,
    double? cupoCredito,
    double? saldoActual,
    String? categoriaCliente,
    String? vendedorAsignado,
    String? zonaVentas,
    DateTime? fechaCreacion,
    String? creadoPor,
    String? estado,
    bool? habilitadoFacturacionElectronica,
  }) {
    return Cliente(
      id: id ?? this.id,
      tipoPersona: tipoPersona ?? this.tipoPersona,
      tipoIdentificacion: tipoIdentificacion ?? this.tipoIdentificacion,
      numeroIdentificacion: numeroIdentificacion ?? this.numeroIdentificacion,
      digitoVerificacion: digitoVerificacion ?? this.digitoVerificacion,
      nombres: nombres ?? this.nombres,
      apellidos: apellidos ?? this.apellidos,
      razonSocial: razonSocial ?? this.razonSocial,
      correo: correo ?? this.correo,
      telefono: telefono ?? this.telefono,
      telefonoSecundario: telefonoSecundario ?? this.telefonoSecundario,
      direccion: direccion ?? this.direccion,
      departamento: departamento ?? this.departamento,
      ciudad: ciudad ?? this.ciudad,
      codigoPostal: codigoPostal ?? this.codigoPostal,
      responsableIVA: responsableIVA ?? this.responsableIVA,
      calidadAgenteRetencion:
          calidadAgenteRetencion ?? this.calidadAgenteRetencion,
      regimenTributario: regimenTributario ?? this.regimenTributario,
      responsabilidadesFiscales:
          responsabilidadesFiscales ?? this.responsabilidadesFiscales,
      cuentasPorCobrar: cuentasPorCobrar ?? this.cuentasPorCobrar,
      cuentasParaDevoluciones:
          cuentasParaDevoluciones ?? this.cuentasParaDevoluciones,
      sobreabonos: sobreabonos ?? this.sobreabonos,
      deterioroCartera: deterioroCartera ?? this.deterioroCartera,
      condicionPago: condicionPago ?? this.condicionPago,
      diasCredito: diasCredito ?? this.diasCredito,
      cupoCredito: cupoCredito ?? this.cupoCredito,
      saldoActual: saldoActual ?? this.saldoActual,
      categoriaCliente: categoriaCliente ?? this.categoriaCliente,
      vendedorAsignado: vendedorAsignado ?? this.vendedorAsignado,
      zonaVentas: zonaVentas ?? this.zonaVentas,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      creadoPor: creadoPor ?? this.creadoPor,
      estado: estado ?? this.estado,
      habilitadoFacturacionElectronica:
          habilitadoFacturacionElectronica ??
          this.habilitadoFacturacionElectronica,
    );
  }

  @override
  String toString() =>
      'Cliente(id: $id, nombre: $nombreCompleto, documento: $numeroIdentificacion)';
}
