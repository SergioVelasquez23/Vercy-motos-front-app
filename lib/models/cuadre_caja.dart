class CuadreCaja {
  final String? id;
  final String nombre;
  final String responsable;
  final DateTime fechaApertura;
  final DateTime? fechaCierre;
  final double fondoInicial;
  final double efectivoDeclarado;
  final double efectivoEsperado;
  final double diferencia;
  final bool cuadrado;
  final bool cerrada;
  final double tolerancia;
  final String? observaciones;
  final String estado;
  final String? aprobadoPor;
  final DateTime? fechaAprobacion;
  final String? urlComprobanteDiario;
  final String? urlInventario;
  final double totalIngresos; // Nuevo campo para el total de ingresos
  final double descuadre; // Descuadre = efectivoEsperado - efectivoDeclarado
  
  // 📊 TOTALES POR MÉTODO DE PAGO
  final double totalEfectivo;
  final double totalTransferencia;
  final double totalTarjeta;
  final double totalSistecredito;
  final double totalDatafono;

  CuadreCaja({
    this.id,
    required this.nombre,
    required this.responsable,
    required this.fechaApertura,
    this.fechaCierre,
    required this.fondoInicial,
    required this.efectivoDeclarado,
    required this.efectivoEsperado,
    required this.diferencia,
    required this.cuadrado,
    required this.cerrada,
    required this.tolerancia,
    this.observaciones,
    this.estado = 'pendiente',
    this.aprobadoPor,
    this.fechaAprobacion,
    this.urlComprobanteDiario,
    this.urlInventario,
    this.totalIngresos = 0.0, // Valor por defecto
    this.descuadre = 0.0, // Valor por defecto
    // 📊 TOTALES POR MÉTODO DE PAGO
    this.totalEfectivo = 0.0,
    this.totalTransferencia = 0.0,
    this.totalTarjeta = 0.0,
    this.totalSistecredito = 0.0,
    this.totalDatafono = 0.0,
  });

  factory CuadreCaja.fromJson(Map<String, dynamic> json) {
    return CuadreCaja(
      id: json['_id'],
      nombre: json['nombre'] ?? '',
      responsable: json['responsable'] ?? '',
      fechaApertura: DateTime.parse(json['fechaApertura']),
      fechaCierre: json['fechaCierre'] != null
          ? DateTime.parse(json['fechaCierre'])
          : null,
      fondoInicial: (json['fondoInicial'] ?? 0).toDouble(),
      efectivoDeclarado: (json['efectivoDeclarado'] ?? 0).toDouble(),
      efectivoEsperado: (json['efectivoEsperado'] ?? 0).toDouble(),
      diferencia: (json['diferencia'] ?? 0).toDouble(),
      cuadrado: json['cuadrado'] ?? false,
      cerrada: (json['cerrada'] == true) ||
          json['estado'] == 'CERRADA' ||
          json['estado'] == 'cerrada' ||
          json['estado'] == 'cerrado' ||
          json['estado'] == 'aprobado',
      tolerancia: (json['tolerancia'] ?? 0).toDouble(),
      observaciones: json['observaciones'],
      estado: json['estado'] ?? 'pendiente',
      aprobadoPor: json['aprobadoPor'],
      fechaAprobacion: json['fechaAprobacion'] != null
          ? DateTime.parse(json['fechaAprobacion'])
          : null,
      urlComprobanteDiario: json['urlComprobanteDiario'],
      urlInventario: json['urlInventario'],
      totalIngresos: (json['totalIngresos'] ?? 0).toDouble(),
      descuadre: (json['descuadre'] ?? 0).toDouble(),
      // 📊 TOTALES POR MÉTODO DE PAGO
      totalEfectivo: (json['totalEfectivo'] ?? 0).toDouble(),
      totalTransferencia: (json['totalTransferencia'] ?? 0).toDouble(),
      totalTarjeta: (json['totalTarjeta'] ?? 0).toDouble(),
      totalSistecredito: (json['totalSistecredito'] ?? 0).toDouble(),
      totalDatafono: (json['totalDatafono'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'nombre': nombre,
      'responsable': responsable,
      'fechaApertura': fechaApertura.toIso8601String(),
      if (fechaCierre != null) 'fechaCierre': fechaCierre!.toIso8601String(),
      'fondoInicial': fondoInicial,
      'efectivoDeclarado': efectivoDeclarado,
      'efectivoEsperado': efectivoEsperado,
      'diferencia': diferencia,
      'cuadrado': cuadrado,
      'cerrada': cerrada,
      'tolerancia': tolerancia,
      if (observaciones != null) 'observaciones': observaciones,
      'estado': estado,
      if (aprobadoPor != null) 'aprobadoPor': aprobadoPor,
      if (fechaAprobacion != null)
        'fechaAprobacion': fechaAprobacion!.toIso8601String(),
      if (urlComprobanteDiario != null)
        'urlComprobanteDiario': urlComprobanteDiario,
      if (urlInventario != null) 'urlInventario': urlInventario,
      'totalIngresos': totalIngresos,
      'descuadre': descuadre,
      // 📊 TOTALES POR MÉTODO DE PAGO
      'totalEfectivo': totalEfectivo,
      'totalTransferencia': totalTransferencia,
      'totalTarjeta': totalTarjeta,
      'totalSistecredito': totalSistecredito,
      'totalDatafono': totalDatafono,
    };
  }

  CuadreCaja copyWith({
    String? id,
    String? nombre,
    String? responsable,
    DateTime? fechaApertura,
    DateTime? fechaCierre,
    double? fondoInicial,
    double? efectivoDeclarado,
    double? efectivoEsperado,
    double? diferencia,
    bool? cuadrado,
    bool? cerrada,
    double? tolerancia,
    String? observaciones,
    String? estado,
    String? aprobadoPor,
    DateTime? fechaAprobacion,
    String? urlComprobanteDiario,
    String? urlInventario,
    double? totalIngresos,
    double? descuadre,
    // 📊 TOTALES POR MÉTODO DE PAGO
    double? totalEfectivo,
    double? totalTransferencia,
    double? totalTarjeta,
    double? totalSistecredito,
    double? totalDatafono,
  }) {
    return CuadreCaja(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      responsable: responsable ?? this.responsable,
      fechaApertura: fechaApertura ?? this.fechaApertura,
      fechaCierre: fechaCierre ?? this.fechaCierre,
      fondoInicial: fondoInicial ?? this.fondoInicial,
      efectivoDeclarado: efectivoDeclarado ?? this.efectivoDeclarado,
      efectivoEsperado: efectivoEsperado ?? this.efectivoEsperado,
      diferencia: diferencia ?? this.diferencia,
      cuadrado: cuadrado ?? this.cuadrado,
      cerrada: cerrada ?? this.cerrada,
      tolerancia: tolerancia ?? this.tolerancia,
      observaciones: observaciones ?? this.observaciones,
      estado: estado ?? this.estado,
      aprobadoPor: aprobadoPor ?? this.aprobadoPor,
      fechaAprobacion: fechaAprobacion ?? this.fechaAprobacion,
      urlComprobanteDiario: urlComprobanteDiario ?? this.urlComprobanteDiario,
      urlInventario: urlInventario ?? this.urlInventario,
      totalIngresos: totalIngresos ?? this.totalIngresos,
      descuadre: descuadre ?? this.descuadre,
      // 📊 TOTALES POR MÉTODO DE PAGO
      totalEfectivo: totalEfectivo ?? this.totalEfectivo,
      totalTransferencia: totalTransferencia ?? this.totalTransferencia,
      totalTarjeta: totalTarjeta ?? this.totalTarjeta,
      totalSistecredito: totalSistecredito ?? this.totalSistecredito,
      totalDatafono: totalDatafono ?? this.totalDatafono,
    );
  }

  // Métodos de utilidad
  bool get estaAprobado => estado == 'aprobado';
  bool get estaRechazado => estado == 'rechazado';
  bool get estaPendiente => estado == 'pendiente';

  String get estadoFormatted {
    switch (estado) {
      case 'ABIERTA':
        return 'Abierta';
      case 'CERRADA':
        return 'Cerrada';
      case 'RECHAZADA':
        return 'Rechazada';
      case 'aprobado':
        return 'Aprobado';
      case 'rechazado':
        return 'Rechazado';
      case 'pendiente':
        return 'Abierta';
      case 'cerrada':
      case 'cerrado':
        return 'Cerrada';
      default:
        return estado;
    }
  }

  String get diferenciaFormatted {
    if (diferencia >= 0) {
      return '+${diferencia.toStringAsFixed(0)}';
    } else {
      return diferencia.toStringAsFixed(0);
    }
  }
}
