/// Modelo completo para configuración de Facturación Electrónica DIAN
/// Incluye todos los datos necesarios para enviar facturas electrónicas
class ConfiguracionDian {
  // ===== IDENTIFICACIÓN Y CONTROL =====
  final String? id; // ID en MongoDB

  // ===== DATOS DE LA RESOLUCIÓN DIAN =====
  /// Clave técnica de resolución (hash SHA-384 proporcionado por DIAN)
  final String claveTecnicaResolucion;

  /// Prefijo de resolución (ej: SC, SETP, FE)
  final String prefijoResolucion;

  /// Número de resolución DIAN
  final String numeroResolucion;

  /// Rango de numeración inicial autorizado
  final String rangoNumeracionInicial;

  /// Rango de numeración final autorizado
  final String rangoNumeracionFinal;

  /// Fecha de inicio de validez de la resolución (formato: yyyy-MM-dd)
  final String resolucionValidaDesde;

  /// Fecha de fin de validez de la resolución (formato: yyyy-MM-dd)
  final String resolucionValidaHasta;

  /// Número de factura desde donde iniciar (consecutivo actual)
  final String iniciarNumeroFacturaDesde;

  // ===== DATOS DEL MODO DE OPERACIÓN =====
  /// Modo de operación (ej: "Software propio", "Proveedor tecnológico")
  final String modoOperacion;

  /// Descripción del modo de operación
  final String? descripcionModoOperacion;

  /// Fecha de inicio del modo de operación
  final String? fechaInicioModoOperacion;

  /// Fecha de término del modo de operación
  final String? fechaTerminoModoOperacion;

  // ===== RANGO DE NUMERACIÓN ASIGNADO =====
  /// Prefijo del rango asignado (ej: SETP)
  final String? prefijoRango;

  /// Número de resolución del rango
  final String? numeroResolucionRango;

  /// Rango desde
  final String? rangoDesde;

  /// Rango hasta
  final String? rangoHasta;

  /// Fecha desde del rango
  final String? fechaDesdeRango;

  /// Fecha hasta del rango
  final String? fechaHastaRango;

  // ===== INFORMACIÓN DEL SOFTWARE =====
  /// ID del software registrado en la DIAN
  final String softwareId;

  /// Nombre del software
  final String? nombreSoftware;

  /// Clave técnica del software
  final String? claveTecnicaSoftware;

  /// PIN del software (código de seguridad)
  final String pin;

  // ===== CERTIFICADO DIGITAL =====
  /// Certificado digital en formato base64 o ruta al archivo
  final String? certificado;

  /// Contraseña del certificado digital
  final String? certificadoPassword;

  /// Fecha de vencimiento del certificado
  final String? certificadoVencimiento;

  // ===== AMBIENTE DE PRUEBAS =====
  /// TestSetId para ambiente de pruebas (habilitación)
  final String? testSetId;

  /// Indica si está en modo pruebas (true) o producción (false)
  final bool esModoProduccion;

  // ===== PROVEEDOR TECNOLÓGICO (si aplica) =====
  /// NIT del proveedor tecnológico
  final String? proveedorTecnologicoNit;

  /// Nombre del proveedor tecnológico
  final String? proveedorTecnologicoNombre;

  // ===== CONFIGURACIÓN ADICIONAL =====
  /// URL del web service para envío (ambiente pruebas o producción)
  final String? urlWebService;

  /// Notas o información adicional
  final String? notas;

  // ===== CONTROL DE FECHAS =====
  final DateTime? fechaCreacion;
  final DateTime? fechaActualizacion;

  ConfiguracionDian({
    this.id,
    required this.claveTecnicaResolucion,
    required this.prefijoResolucion,
    required this.numeroResolucion,
    required this.rangoNumeracionInicial,
    required this.rangoNumeracionFinal,
    required this.resolucionValidaDesde,
    required this.resolucionValidaHasta,
    required this.iniciarNumeroFacturaDesde,
    this.modoOperacion = 'Software propio',
    this.descripcionModoOperacion,
    this.fechaInicioModoOperacion,
    this.fechaTerminoModoOperacion,
    this.prefijoRango,
    this.numeroResolucionRango,
    this.rangoDesde,
    this.rangoHasta,
    this.fechaDesdeRango,
    this.fechaHastaRango,
    required this.softwareId,
    this.nombreSoftware,
    this.claveTecnicaSoftware,
    required this.pin,
    this.certificado,
    this.certificadoPassword,
    this.certificadoVencimiento,
    this.testSetId,
    this.esModoProduccion = false,
    this.proveedorTecnologicoNit,
    this.proveedorTecnologicoNombre,
    this.urlWebService,
    this.notas,
    this.fechaCreacion,
    this.fechaActualizacion,
  });

  /// Convierte el modelo a JSON para enviar al backend
  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'claveTecnicaResolucion': claveTecnicaResolucion,
      'prefijoResolucion': prefijoResolucion,
      'numeroResolucion': numeroResolucion,
      'rangoNumeracionInicial': rangoNumeracionInicial,
      'rangoNumeracionFinal': rangoNumeracionFinal,
      'resolucionValidaDesde': resolucionValidaDesde,
      'resolucionValidaHasta': resolucionValidaHasta,
      'iniciarNumeroFacturaDesde': iniciarNumeroFacturaDesde,
      'modoOperacion': modoOperacion,
      if (descripcionModoOperacion != null)
        'descripcionModoOperacion': descripcionModoOperacion,
      if (fechaInicioModoOperacion != null)
        'fechaInicioModoOperacion': fechaInicioModoOperacion,
      if (fechaTerminoModoOperacion != null)
        'fechaTerminoModoOperacion': fechaTerminoModoOperacion,
      if (prefijoRango != null) 'prefijoRango': prefijoRango,
      if (numeroResolucionRango != null)
        'numeroResolucionRango': numeroResolucionRango,
      if (rangoDesde != null) 'rangoDesde': rangoDesde,
      if (rangoHasta != null) 'rangoHasta': rangoHasta,
      if (fechaDesdeRango != null) 'fechaDesdeRango': fechaDesdeRango,
      if (fechaHastaRango != null) 'fechaHastaRango': fechaHastaRango,
      'softwareId': softwareId,
      if (nombreSoftware != null) 'nombreSoftware': nombreSoftware,
      if (claveTecnicaSoftware != null)
        'claveTecnicaSoftware': claveTecnicaSoftware,
      'pin': pin,
      if (certificado != null) 'certificado': certificado,
      if (certificadoPassword != null)
        'certificadoPassword': certificadoPassword,
      if (certificadoVencimiento != null)
        'certificadoVencimiento': certificadoVencimiento,
      if (testSetId != null) 'testSetId': testSetId,
      'esModoProduccion': esModoProduccion,
      if (proveedorTecnologicoNit != null)
        'proveedorTecnologicoNit': proveedorTecnologicoNit,
      if (proveedorTecnologicoNombre != null)
        'proveedorTecnologicoNombre': proveedorTecnologicoNombre,
      if (urlWebService != null) 'urlWebService': urlWebService,
      if (notas != null) 'notas': notas,
      if (fechaCreacion != null)
        'fechaCreacion': fechaCreacion!.toIso8601String(),
      if (fechaActualizacion != null)
        'fechaActualizacion': fechaActualizacion!.toIso8601String(),
    };
  }

  /// Crea una instancia desde JSON recibido del backend
  factory ConfiguracionDian.fromJson(Map<String, dynamic> json) {
    return ConfiguracionDian(
      id: json['_id'],
      claveTecnicaResolucion: json['claveTecnicaResolucion'] ?? '',
      prefijoResolucion: json['prefijoResolucion'] ?? '',
      numeroResolucion: json['numeroResolucion'] ?? '',
      rangoNumeracionInicial: json['rangoNumeracionInicial'] ?? '',
      rangoNumeracionFinal: json['rangoNumeracionFinal'] ?? '',
      resolucionValidaDesde: json['resolucionValidaDesde'] ?? '',
      resolucionValidaHasta: json['resolucionValidaHasta'] ?? '',
      iniciarNumeroFacturaDesde: json['iniciarNumeroFacturaDesde'] ?? '1',
      modoOperacion: json['modoOperacion'] ?? 'Software propio',
      descripcionModoOperacion: json['descripcionModoOperacion'],
      fechaInicioModoOperacion: json['fechaInicioModoOperacion'],
      fechaTerminoModoOperacion: json['fechaTerminoModoOperacion'],
      prefijoRango: json['prefijoRango'],
      numeroResolucionRango: json['numeroResolucionRango'],
      rangoDesde: json['rangoDesde'],
      rangoHasta: json['rangoHasta'],
      fechaDesdeRango: json['fechaDesdeRango'],
      fechaHastaRango: json['fechaHastaRango'],
      softwareId: json['softwareId'] ?? '',
      nombreSoftware: json['nombreSoftware'],
      claveTecnicaSoftware: json['claveTecnicaSoftware'],
      pin: json['pin'] ?? '',
      certificado: json['certificado'],
      certificadoPassword: json['certificadoPassword'],
      certificadoVencimiento: json['certificadoVencimiento'],
      testSetId: json['testSetId'],
      esModoProduccion: json['esModoProduccion'] ?? false,
      proveedorTecnologicoNit: json['proveedorTecnologicoNit'],
      proveedorTecnologicoNombre: json['proveedorTecnologicoNombre'],
      urlWebService: json['urlWebService'],
      notas: json['notas'],
      fechaCreacion: json['fechaCreacion'] != null
          ? DateTime.parse(json['fechaCreacion'])
          : null,
      fechaActualizacion: json['fechaActualizacion'] != null
          ? DateTime.parse(json['fechaActualizacion'])
          : null,
    );
  }

  /// Crea una copia con algunos campos modificados
  ConfiguracionDian copyWith({
    String? id,
    String? claveTecnicaResolucion,
    String? prefijoResolucion,
    String? numeroResolucion,
    String? rangoNumeracionInicial,
    String? rangoNumeracionFinal,
    String? resolucionValidaDesde,
    String? resolucionValidaHasta,
    String? iniciarNumeroFacturaDesde,
    String? modoOperacion,
    String? descripcionModoOperacion,
    String? fechaInicioModoOperacion,
    String? fechaTerminoModoOperacion,
    String? prefijoRango,
    String? numeroResolucionRango,
    String? rangoDesde,
    String? rangoHasta,
    String? fechaDesdeRango,
    String? fechaHastaRango,
    String? softwareId,
    String? nombreSoftware,
    String? claveTecnicaSoftware,
    String? pin,
    String? certificado,
    String? certificadoPassword,
    String? certificadoVencimiento,
    String? testSetId,
    bool? esModoProduccion,
    String? proveedorTecnologicoNit,
    String? proveedorTecnologicoNombre,
    String? urlWebService,
    String? notas,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
  }) {
    return ConfiguracionDian(
      id: id ?? this.id,
      claveTecnicaResolucion:
          claveTecnicaResolucion ?? this.claveTecnicaResolucion,
      prefijoResolucion: prefijoResolucion ?? this.prefijoResolucion,
      numeroResolucion: numeroResolucion ?? this.numeroResolucion,
      rangoNumeracionInicial:
          rangoNumeracionInicial ?? this.rangoNumeracionInicial,
      rangoNumeracionFinal: rangoNumeracionFinal ?? this.rangoNumeracionFinal,
      resolucionValidaDesde:
          resolucionValidaDesde ?? this.resolucionValidaDesde,
      resolucionValidaHasta:
          resolucionValidaHasta ?? this.resolucionValidaHasta,
      iniciarNumeroFacturaDesde:
          iniciarNumeroFacturaDesde ?? this.iniciarNumeroFacturaDesde,
      modoOperacion: modoOperacion ?? this.modoOperacion,
      descripcionModoOperacion:
          descripcionModoOperacion ?? this.descripcionModoOperacion,
      fechaInicioModoOperacion:
          fechaInicioModoOperacion ?? this.fechaInicioModoOperacion,
      fechaTerminoModoOperacion:
          fechaTerminoModoOperacion ?? this.fechaTerminoModoOperacion,
      prefijoRango: prefijoRango ?? this.prefijoRango,
      numeroResolucionRango:
          numeroResolucionRango ?? this.numeroResolucionRango,
      rangoDesde: rangoDesde ?? this.rangoDesde,
      rangoHasta: rangoHasta ?? this.rangoHasta,
      fechaDesdeRango: fechaDesdeRango ?? this.fechaDesdeRango,
      fechaHastaRango: fechaHastaRango ?? this.fechaHastaRango,
      softwareId: softwareId ?? this.softwareId,
      nombreSoftware: nombreSoftware ?? this.nombreSoftware,
      claveTecnicaSoftware: claveTecnicaSoftware ?? this.claveTecnicaSoftware,
      pin: pin ?? this.pin,
      certificado: certificado ?? this.certificado,
      certificadoPassword: certificadoPassword ?? this.certificadoPassword,
      certificadoVencimiento:
          certificadoVencimiento ?? this.certificadoVencimiento,
      testSetId: testSetId ?? this.testSetId,
      esModoProduccion: esModoProduccion ?? this.esModoProduccion,
      proveedorTecnologicoNit:
          proveedorTecnologicoNit ?? this.proveedorTecnologicoNit,
      proveedorTecnologicoNombre:
          proveedorTecnologicoNombre ?? this.proveedorTecnologicoNombre,
      urlWebService: urlWebService ?? this.urlWebService,
      notas: notas ?? this.notas,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
    );
  }

  @override
  String toString() {
    return 'ConfiguracionDian{numeroResolucion: $numeroResolucion, '
        'prefijo: $prefijoResolucion, softwareId: $softwareId, '
        'testSetId: $testSetId, esModoProduccion: $esModoProduccion}';
  }
}
