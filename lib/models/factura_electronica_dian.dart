/// Modelo completo para Factura Electrónica según normativa DIAN
/// Basado en UBL 2.1 y Resolución 000012 de 2021
class FacturaElectronicaDian {
  // ===== IDENTIFICACIÓN DE LA FACTURA =====
  final String? id; // ID MongoDB
  final String numeroFactura; // Número con prefijo (ej: SETP990000002)
  final String? cufe; // Código Único de Factura Electrónica (SHA-384)
  final String? cude; // Para notas crédito/débito
  final DateTime fechaEmision;
  final String horaEmision; // Formato: HH:mm:ss-05:00
  final String
  tipoFactura; // 01: Factura de Venta, 02: Factura de Exportación, etc.
  final String
  tipoOperacion; // 05: Factura estándar, 10: Factura venta nacional

  // ===== AUTORIZACIÓN DIAN =====
  final String? numeroAutorizacion; // Número de autorización DIAN
  final DateTime? fechaInicioAutorizacion;
  final DateTime? fechaFinAutorizacion;
  final String? prefijoFactura; // Prefijo autorizado (ej: SETP)
  final String? rangoDesde;
  final String? rangoHasta;

  // ===== SOFTWARE Y SEGURIDAD =====
  final String? softwareId; // ID del software ante la DIAN
  final String? softwareSecurityCode; // Código de seguridad del software
  final String? proveedorSoftwareNit; // NIT del proveedor del software
  final String? qrCode; // Código QR para validación

  // ===== INFORMACIÓN DEL EMISOR (Restaurante) =====
  final EmisorDian emisor;

  // ===== INFORMACIÓN DEL ADQUIRIENTE (Cliente) =====
  final AdquirienteDian adquiriente;

  // ===== ITEMS DE LA FACTURA =====
  final List<ItemFacturaDian> items;

  // ===== TOTALES E IMPUESTOS =====
  final double subtotal; // Suma antes de impuestos
  final double totalImpuestos; // Total de todos los impuestos
  final double totalDescuentos; // Total de descuentos aplicados
  final double totalCargos; // Total de cargos adicionales
  final double totalFactura; // Total final a pagar
  final String moneda; // COP para Colombia

  // ===== IMPUESTOS DETALLADOS =====
  final List<ImpuestoDian> impuestos; // IVA, INC, ICA, etc.

  // ===== MEDIOS Y FORMAS DE PAGO =====
  final String? formaPago; // 1: Contado, 2: Crédito
  final String?
  medioPago; // 10: Efectivo, 41: Tarjeta débito, 42: Tarjeta crédito
  final DateTime? fechaVencimiento;
  final String? referenciaPago; // Número de transacción/recibo

  // ===== INFORMACIÓN ADICIONAL =====
  final String? pedidoId; // ID del pedido asociado
  final String? vendedor; // Nombre del vendedor
  final double? propina; // Propina incluida
  final String? observaciones;
  final bool anulada;
  final String? motivoAnulacion;
  final DateTime? fechaAnulacion;

  // ===== INFORMACIÓN DE ENTREGA =====
  final DireccionEntrega? direccionEntrega;

  // ===== NOTAS =====
  final String? notas; // Notas adicionales en la factura

  // ===== CONTROL INTERNO =====
  final String
  estado; // PENDIENTE, EMITIDA, ENVIADA_DIAN, ACEPTADA, RECHAZADA, ANULADA
  final DateTime? fechaEnvioDian;
  final String? respuestaDian; // XML de respuesta de la DIAN
  final String? xmlGenerado; // XML UBL generado

  FacturaElectronicaDian({
    this.id,
    required this.numeroFactura,
    this.cufe,
    this.cude,
    required this.fechaEmision,
    required this.horaEmision,
    this.tipoFactura = '01', // Por defecto: Factura de venta
    this.tipoOperacion = '10', // Por defecto: Venta nacional estándar
    this.numeroAutorizacion,
    this.fechaInicioAutorizacion,
    this.fechaFinAutorizacion,
    this.prefijoFactura,
    this.rangoDesde,
    this.rangoHasta,
    this.softwareId,
    this.softwareSecurityCode,
    this.proveedorSoftwareNit,
    this.qrCode,
    required this.emisor,
    required this.adquiriente,
    required this.items,
    required this.subtotal,
    required this.totalImpuestos,
    this.totalDescuentos = 0.0,
    this.totalCargos = 0.0,
    required this.totalFactura,
    this.moneda = 'COP',
    required this.impuestos,
    this.formaPago = '1', // Por defecto: Contado
    this.medioPago = '10', // Por defecto: Efectivo
    this.fechaVencimiento,
    this.referenciaPago,
    this.pedidoId,
    this.vendedor,
    this.propina,
    this.observaciones,
    this.anulada = false,
    this.motivoAnulacion,
    this.fechaAnulacion,
    this.direccionEntrega,
    this.notas,
    this.estado = 'PENDIENTE',
    this.fechaEnvioDian,
    this.respuestaDian,
    this.xmlGenerado,
  });

  /// Convierte la factura a JSON
  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'numeroFactura': numeroFactura,
      if (cufe != null) 'cufe': cufe,
      if (cude != null) 'cude': cude,
      'fechaEmision': fechaEmision.toIso8601String(),
      'horaEmision': horaEmision,
      'tipoFactura': tipoFactura,
      'tipoOperacion': tipoOperacion,
      if (numeroAutorizacion != null) 'numeroAutorizacion': numeroAutorizacion,
      if (fechaInicioAutorizacion != null)
        'fechaInicioAutorizacion': fechaInicioAutorizacion!.toIso8601String(),
      if (fechaFinAutorizacion != null)
        'fechaFinAutorizacion': fechaFinAutorizacion!.toIso8601String(),
      if (prefijoFactura != null) 'prefijoFactura': prefijoFactura,
      if (rangoDesde != null) 'rangoDesde': rangoDesde,
      if (rangoHasta != null) 'rangoHasta': rangoHasta,
      if (softwareId != null) 'softwareId': softwareId,
      if (softwareSecurityCode != null)
        'softwareSecurityCode': softwareSecurityCode,
      if (proveedorSoftwareNit != null)
        'proveedorSoftwareNit': proveedorSoftwareNit,
      if (qrCode != null) 'qrCode': qrCode,
      'emisor': emisor.toJson(),
      'adquiriente': adquiriente.toJson(),
      'items': items.map((item) => item.toJson()).toList(),
      'subtotal': subtotal,
      'totalImpuestos': totalImpuestos,
      'totalDescuentos': totalDescuentos,
      'totalCargos': totalCargos,
      'totalFactura': totalFactura,
      'moneda': moneda,
      'impuestos': impuestos.map((imp) => imp.toJson()).toList(),
      if (formaPago != null) 'formaPago': formaPago,
      if (medioPago != null) 'medioPago': medioPago,
      if (fechaVencimiento != null)
        'fechaVencimiento': fechaVencimiento!.toIso8601String(),
      if (referenciaPago != null) 'referenciaPago': referenciaPago,
      if (pedidoId != null) 'pedidoId': pedidoId,
      if (vendedor != null) 'vendedor': vendedor,
      if (propina != null) 'propina': propina,
      if (observaciones != null) 'observaciones': observaciones,
      'anulada': anulada,
      if (motivoAnulacion != null) 'motivoAnulacion': motivoAnulacion,
      if (fechaAnulacion != null)
        'fechaAnulacion': fechaAnulacion!.toIso8601String(),
      if (direccionEntrega != null)
        'direccionEntrega': direccionEntrega!.toJson(),
      if (notas != null) 'notas': notas,
      'estado': estado,
      if (fechaEnvioDian != null)
        'fechaEnvioDian': fechaEnvioDian!.toIso8601String(),
      if (respuestaDian != null) 'respuestaDian': respuestaDian,
      if (xmlGenerado != null) 'xmlGenerado': xmlGenerado,
    };
  }

  /// Crea una instancia desde JSON
  factory FacturaElectronicaDian.fromJson(Map<String, dynamic> json) {
    return FacturaElectronicaDian(
      id: json['_id'] ?? json['id'],
      numeroFactura: json['numeroFactura'] ?? '',
      cufe: json['cufe'],
      cude: json['cude'],
      fechaEmision: DateTime.parse(json['fechaEmision']),
      horaEmision: json['horaEmision'] ?? '',
      tipoFactura: json['tipoFactura'] ?? '01',
      tipoOperacion: json['tipoOperacion'] ?? '10',
      numeroAutorizacion: json['numeroAutorizacion'],
      fechaInicioAutorizacion: json['fechaInicioAutorizacion'] != null
          ? DateTime.parse(json['fechaInicioAutorizacion'])
          : null,
      fechaFinAutorizacion: json['fechaFinAutorizacion'] != null
          ? DateTime.parse(json['fechaFinAutorizacion'])
          : null,
      prefijoFactura: json['prefijoFactura'],
      rangoDesde: json['rangoDesde'],
      rangoHasta: json['rangoHasta'],
      softwareId: json['softwareId'],
      softwareSecurityCode: json['softwareSecurityCode'],
      proveedorSoftwareNit: json['proveedorSoftwareNit'],
      qrCode: json['qrCode'],
      emisor: EmisorDian.fromJson(json['emisor']),
      adquiriente: AdquirienteDian.fromJson(json['adquiriente']),
      items: (json['items'] as List)
          .map((item) => ItemFacturaDian.fromJson(item))
          .toList(),
      subtotal: (json['subtotal'] as num).toDouble(),
      totalImpuestos: (json['totalImpuestos'] as num).toDouble(),
      totalDescuentos: (json['totalDescuentos'] as num?)?.toDouble() ?? 0.0,
      totalCargos: (json['totalCargos'] as num?)?.toDouble() ?? 0.0,
      totalFactura: (json['totalFactura'] as num).toDouble(),
      moneda: json['moneda'] ?? 'COP',
      impuestos: (json['impuestos'] as List)
          .map((imp) => ImpuestoDian.fromJson(imp))
          .toList(),
      formaPago: json['formaPago'],
      medioPago: json['medioPago'],
      fechaVencimiento: json['fechaVencimiento'] != null
          ? DateTime.parse(json['fechaVencimiento'])
          : null,
      referenciaPago: json['referenciaPago'],
      pedidoId: json['pedidoId'],
      vendedor: json['vendedor'],
      propina: json['propina'] != null
          ? (json['propina'] as num).toDouble()
          : null,
      observaciones: json['observaciones'],
      anulada: json['anulada'] ?? false,
      motivoAnulacion: json['motivoAnulacion'],
      fechaAnulacion: json['fechaAnulacion'] != null
          ? DateTime.parse(json['fechaAnulacion'])
          : null,
      direccionEntrega: json['direccionEntrega'] != null
          ? DireccionEntrega.fromJson(json['direccionEntrega'])
          : null,
      notas: json['notas'],
      estado: json['estado'] ?? 'PENDIENTE',
      fechaEnvioDian: json['fechaEnvioDian'] != null
          ? DateTime.parse(json['fechaEnvioDian'])
          : null,
      respuestaDian: json['respuestaDian'],
      xmlGenerado: json['xmlGenerado'],
    );
  }

  /// Crea una copia con campos modificados
  FacturaElectronicaDian copyWith({
    String? id,
    String? numeroFactura,
    String? cufe,
    String? qrCode,
    String? estado,
    bool? anulada,
    String? motivoAnulacion,
    String? xmlGenerado,
    String? respuestaDian,
  }) {
    return FacturaElectronicaDian(
      id: id ?? this.id,
      numeroFactura: numeroFactura ?? this.numeroFactura,
      cufe: cufe ?? this.cufe,
      cude: cude,
      fechaEmision: fechaEmision,
      horaEmision: horaEmision,
      tipoFactura: tipoFactura,
      tipoOperacion: tipoOperacion,
      numeroAutorizacion: numeroAutorizacion,
      fechaInicioAutorizacion: fechaInicioAutorizacion,
      fechaFinAutorizacion: fechaFinAutorizacion,
      prefijoFactura: prefijoFactura,
      rangoDesde: rangoDesde,
      rangoHasta: rangoHasta,
      softwareId: softwareId,
      softwareSecurityCode: softwareSecurityCode,
      proveedorSoftwareNit: proveedorSoftwareNit,
      qrCode: qrCode ?? this.qrCode,
      emisor: emisor,
      adquiriente: adquiriente,
      items: items,
      subtotal: subtotal,
      totalImpuestos: totalImpuestos,
      totalDescuentos: totalDescuentos,
      totalCargos: totalCargos,
      totalFactura: totalFactura,
      moneda: moneda,
      impuestos: impuestos,
      formaPago: formaPago,
      medioPago: medioPago,
      fechaVencimiento: fechaVencimiento,
      referenciaPago: referenciaPago,
      pedidoId: pedidoId,
      vendedor: vendedor,
      propina: propina,
      observaciones: observaciones,
      anulada: anulada ?? this.anulada,
      motivoAnulacion: motivoAnulacion ?? this.motivoAnulacion,
      fechaAnulacion: fechaAnulacion,
      direccionEntrega: direccionEntrega,
      notas: notas,
      estado: estado ?? this.estado,
      fechaEnvioDian: fechaEnvioDian,
      respuestaDian: respuestaDian ?? this.respuestaDian,
      xmlGenerado: xmlGenerado ?? this.xmlGenerado,
    );
  }
}

/// Información del Emisor (Restaurante)
class EmisorDian {
  final String razonSocial;
  final String nit; // NIT sin dígito de verificación
  final String digitoVerificacion;
  final String tipoDocumento; // 31: NIT, 13: Cédula, etc.
  final String tipoPersona; // 1: Jurídica, 2: Natural
  final String
  tipoRegimen; // 0-99: Gran contribuyente, O-13: Autoretenedor, etc.
  final String nombreComercial;
  final String direccion;
  final String ciudad;
  final String codigoCiudad; // Código DANE
  final String departamento;
  final String codigoDepartamento;
  final String pais; // CO para Colombia
  final String telefono;
  final String email;
  final String?
  responsabilidadesFiscales; // Lista separada por ; (ej: "O-13;O-15;O-23")

  EmisorDian({
    required this.razonSocial,
    required this.nit,
    required this.digitoVerificacion,
    this.tipoDocumento = '31',
    this.tipoPersona = '1',
    this.tipoRegimen = 'O-99',
    required this.nombreComercial,
    required this.direccion,
    required this.ciudad,
    required this.codigoCiudad,
    required this.departamento,
    required this.codigoDepartamento,
    this.pais = 'CO',
    required this.telefono,
    required this.email,
    this.responsabilidadesFiscales,
  });

  Map<String, dynamic> toJson() => {
    'razonSocial': razonSocial,
    'nit': nit,
    'digitoVerificacion': digitoVerificacion,
    'tipoDocumento': tipoDocumento,
    'tipoPersona': tipoPersona,
    'tipoRegimen': tipoRegimen,
    'nombreComercial': nombreComercial,
    'direccion': direccion,
    'ciudad': ciudad,
    'codigoCiudad': codigoCiudad,
    'departamento': departamento,
    'codigoDepartamento': codigoDepartamento,
    'pais': pais,
    'telefono': telefono,
    'email': email,
    if (responsabilidadesFiscales != null)
      'responsabilidadesFiscales': responsabilidadesFiscales,
  };

  factory EmisorDian.fromJson(Map<String, dynamic> json) => EmisorDian(
    razonSocial: json['razonSocial'] ?? '',
    nit: json['nit'] ?? '',
    digitoVerificacion: json['digitoVerificacion'] ?? '',
    tipoDocumento: json['tipoDocumento'] ?? '31',
    tipoPersona: json['tipoPersona'] ?? '1',
    tipoRegimen: json['tipoRegimen'] ?? 'O-99',
    nombreComercial: json['nombreComercial'] ?? '',
    direccion: json['direccion'] ?? '',
    ciudad: json['ciudad'] ?? '',
    codigoCiudad: json['codigoCiudad'] ?? '',
    departamento: json['departamento'] ?? '',
    codigoDepartamento: json['codigoDepartamento'] ?? '',
    pais: json['pais'] ?? 'CO',
    telefono: json['telefono'] ?? '',
    email: json['email'] ?? '',
    responsabilidadesFiscales: json['responsabilidadesFiscales'],
  );
}

/// Información del Adquiriente (Cliente)
class AdquirienteDian {
  final String nombre;
  final String identificacion; // NIT o Cédula
  final String? digitoVerificacion; // Solo si es NIT
  final String tipoDocumento; // 13: CC, 31: NIT, 22: CE, 91: NUIP
  final String tipoPersona; // 1: Jurídica, 2: Natural
  final String? tipoRegimen;
  final String? direccion;
  final String? ciudad;
  final String? codigoCiudad;
  final String? departamento;
  final String? codigoDepartamento;
  final String pais;
  final String? telefono;
  final String? email;
  final String? responsabilidadesFiscales;

  AdquirienteDian({
    required this.nombre,
    required this.identificacion,
    this.digitoVerificacion,
    this.tipoDocumento = '13', // Por defecto: Cédula
    this.tipoPersona = '2', // Por defecto: Persona natural
    this.tipoRegimen,
    this.direccion,
    this.ciudad,
    this.codigoCiudad,
    this.departamento,
    this.codigoDepartamento,
    this.pais = 'CO',
    this.telefono,
    this.email,
    this.responsabilidadesFiscales,
  });

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'identificacion': identificacion,
    if (digitoVerificacion != null) 'digitoVerificacion': digitoVerificacion,
    'tipoDocumento': tipoDocumento,
    'tipoPersona': tipoPersona,
    if (tipoRegimen != null) 'tipoRegimen': tipoRegimen,
    if (direccion != null) 'direccion': direccion,
    if (ciudad != null) 'ciudad': ciudad,
    if (codigoCiudad != null) 'codigoCiudad': codigoCiudad,
    if (departamento != null) 'departamento': departamento,
    if (codigoDepartamento != null) 'codigoDepartamento': codigoDepartamento,
    'pais': pais,
    if (telefono != null) 'telefono': telefono,
    if (email != null) 'email': email,
    if (responsabilidadesFiscales != null)
      'responsabilidadesFiscales': responsabilidadesFiscales,
  };

  factory AdquirienteDian.fromJson(Map<String, dynamic> json) =>
      AdquirienteDian(
        nombre: json['nombre'] ?? '',
        identificacion: json['identificacion'] ?? '',
        digitoVerificacion: json['digitoVerificacion'],
        tipoDocumento: json['tipoDocumento'] ?? '13',
        tipoPersona: json['tipoPersona'] ?? '2',
        tipoRegimen: json['tipoRegimen'],
        direccion: json['direccion'],
        ciudad: json['ciudad'],
        codigoCiudad: json['codigoCiudad'],
        departamento: json['departamento'],
        codigoDepartamento: json['codigoDepartamento'],
        pais: json['pais'] ?? 'CO',
        telefono: json['telefono'],
        email: json['email'],
        responsabilidadesFiscales: json['responsabilidadesFiscales'],
      );
}

/// Item individual de la factura
class ItemFacturaDian {
  final int numeroLinea; // Número de línea en la factura (1, 2, 3...)
  final String codigoProducto; // Código interno del producto
  final String? codigoEstandar; // Código UNSPSC, EAN, etc.
  final String descripcion;
  final double cantidad;
  final String unidadMedida; // EA: Unidad, KG: Kilogramo, NIU: Número de items
  final double precioUnitario;
  final double subtotalItem; // Precio * Cantidad antes de impuestos
  final double? descuento; // Descuento aplicado a este item
  final double? porcentajeDescuento;
  final List<ImpuestoDian> impuestos; // Impuestos aplicados a este item
  final double totalItem; // Total incluyendo impuestos
  final bool muestraGratis; // Si es una muestra gratis
  final String? notas;

  ItemFacturaDian({
    required this.numeroLinea,
    required this.codigoProducto,
    this.codigoEstandar,
    required this.descripcion,
    required this.cantidad,
    this.unidadMedida = 'EA',
    required this.precioUnitario,
    required this.subtotalItem,
    this.descuento = 0.0,
    this.porcentajeDescuento,
    required this.impuestos,
    required this.totalItem,
    this.muestraGratis = false,
    this.notas,
  });

  Map<String, dynamic> toJson() => {
    'numeroLinea': numeroLinea,
    'codigoProducto': codigoProducto,
    if (codigoEstandar != null) 'codigoEstandar': codigoEstandar,
    'descripcion': descripcion,
    'cantidad': cantidad,
    'unidadMedida': unidadMedida,
    'precioUnitario': precioUnitario,
    'subtotalItem': subtotalItem,
    if (descuento != null) 'descuento': descuento,
    if (porcentajeDescuento != null) 'porcentajeDescuento': porcentajeDescuento,
    'impuestos': impuestos.map((imp) => imp.toJson()).toList(),
    'totalItem': totalItem,
    'muestraGratis': muestraGratis,
    if (notas != null) 'notas': notas,
  };

  factory ItemFacturaDian.fromJson(Map<String, dynamic> json) =>
      ItemFacturaDian(
        numeroLinea: json['numeroLinea'] ?? 0,
        codigoProducto: json['codigoProducto'] ?? '',
        codigoEstandar: json['codigoEstandar'],
        descripcion: json['descripcion'] ?? '',
        cantidad: (json['cantidad'] as num).toDouble(),
        unidadMedida: json['unidadMedida'] ?? 'EA',
        precioUnitario: (json['precioUnitario'] as num).toDouble(),
        subtotalItem: (json['subtotalItem'] as num).toDouble(),
        descuento: json['descuento'] != null
            ? (json['descuento'] as num).toDouble()
            : 0.0,
        porcentajeDescuento: json['porcentajeDescuento'] != null
            ? (json['porcentajeDescuento'] as num).toDouble()
            : null,
        impuestos: (json['impuestos'] as List)
            .map((imp) => ImpuestoDian.fromJson(imp))
            .toList(),
        totalItem: (json['totalItem'] as num).toDouble(),
        muestraGratis: json['muestraGratis'] ?? false,
        notas: json['notas'],
      );
}

/// Información de impuestos
class ImpuestoDian {
  final String tipoImpuesto; // 01: IVA, 02: IC, 03: ICA, 04: INC
  final String nombreImpuesto;
  final double baseImponible; // Base sobre la que se calcula el impuesto
  final double porcentaje; // Porcentaje del impuesto (19, 5, 0, etc.)
  final double valorImpuesto; // Valor calculado del impuesto

  ImpuestoDian({
    required this.tipoImpuesto,
    required this.nombreImpuesto,
    required this.baseImponible,
    required this.porcentaje,
    required this.valorImpuesto,
  });

  Map<String, dynamic> toJson() => {
    'tipoImpuesto': tipoImpuesto,
    'nombreImpuesto': nombreImpuesto,
    'baseImponible': baseImponible,
    'porcentaje': porcentaje,
    'valorImpuesto': valorImpuesto,
  };

  factory ImpuestoDian.fromJson(Map<String, dynamic> json) => ImpuestoDian(
    tipoImpuesto: json['tipoImpuesto'] ?? '01',
    nombreImpuesto: json['nombreImpuesto'] ?? 'IVA',
    baseImponible: (json['baseImponible'] as num).toDouble(),
    porcentaje: (json['porcentaje'] as num).toDouble(),
    valorImpuesto: (json['valorImpuesto'] as num).toDouble(),
  );
}

/// Información de entrega
class DireccionEntrega {
  final String direccion;
  final String ciudad;
  final String codigoCiudad;
  final String departamento;
  final String codigoDepartamento;
  final String pais;
  final String? nombreContacto;
  final String? telefonoContacto;

  DireccionEntrega({
    required this.direccion,
    required this.ciudad,
    required this.codigoCiudad,
    required this.departamento,
    required this.codigoDepartamento,
    this.pais = 'CO',
    this.nombreContacto,
    this.telefonoContacto,
  });

  Map<String, dynamic> toJson() => {
    'direccion': direccion,
    'ciudad': ciudad,
    'codigoCiudad': codigoCiudad,
    'departamento': departamento,
    'codigoDepartamento': codigoDepartamento,
    'pais': pais,
    if (nombreContacto != null) 'nombreContacto': nombreContacto,
    if (telefonoContacto != null) 'telefonoContacto': telefonoContacto,
  };

  factory DireccionEntrega.fromJson(Map<String, dynamic> json) =>
      DireccionEntrega(
        direccion: json['direccion'] ?? '',
        ciudad: json['ciudad'] ?? '',
        codigoCiudad: json['codigoCiudad'] ?? '',
        departamento: json['departamento'] ?? '',
        codigoDepartamento: json['codigoDepartamento'] ?? '',
        pais: json['pais'] ?? 'CO',
        nombreContacto: json['nombreContacto'],
        telefonoContacto: json['telefonoContacto'],
      );
}
