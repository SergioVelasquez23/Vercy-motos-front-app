import 'package:flutter/material.dart';
import 'cuenta_por_cobrar.dart';

/// Frecuencia de recurrencia para cuentas por pagar
enum FrecuenciaCuentaPagar {
  unica,
  mensual,
  bimestral,
  trimestral,
  semestral,
  anual,
}

/// Tipo de cuenta por pagar
enum TipoCuentaPagar {
  arriendo,
  serviciosPublicos,
  facturaProveedor,
  nomina,
  seguros,
  impuestos,
  mantenimiento,
  otros,
}

/// Estado de la cuenta por pagar
enum EstadoCuentaPagar { PENDIENTE, VENCIDA, PAGADA, ABONADA }

class CuentaPorPagar {
  final String? id;
  final String? proveedorId;
  final String proveedorNombre;
  final String numeroFactura;
  final double montoTotal;
  final double montoAbonado;
  final double saldoPendiente;
  final DateTime fechaVencimiento;
  final int diasVencimiento;
  final bool tieneDescuento;
  final double porcentajeDescuento;
  final double montoDescuento;
  final DateTime? fechaLimiteDescuento;
  final int? diasParaPerderDescuento;
  final bool descuentoPerdido;
  final EstadoCuentaPagar estado;
  final DateTime? fechaCreacion;

  // === CAMPOS DE RECURRENCIA ===
  final TipoCuentaPagar tipo;
  final FrecuenciaCuentaPagar frecuencia;
  final bool esRecurrente;
  final int? diaDelMes;
  final DateTime? ultimoPago;
  final double? montoUltimoPago;
  final DateTime? proximoVencimiento;
  final int totalPagosRealizados;
  final bool alertaEnviada;
  final bool activa;
  final String? observaciones;
  final List<HistorialPagoCxP> historialPagos;

  // === CAMPOS PARA ALERTAS AUTOMÁTICAS ===
  final List<int> diasAvisos; // Ej: [15, 7, 3, 1] días antes del vencimiento
  final List<int>
  diasAvisoDescuento; // Ej: [10, 5, 2, 1] días para perder descuento
  final bool avisosActivados;

  CuentaPorPagar({
    this.id,
    this.proveedorId,
    required this.proveedorNombre,
    required this.numeroFactura,
    required this.montoTotal,
    this.montoAbonado = 0.0,
    required this.saldoPendiente,
    required this.fechaVencimiento,
    required this.diasVencimiento,
    this.tieneDescuento = false,
    this.porcentajeDescuento = 0.0,
    this.montoDescuento = 0.0,
    this.fechaLimiteDescuento,
    this.diasParaPerderDescuento,
    this.descuentoPerdido = false,
    required this.estado,
    this.fechaCreacion,
    // Recurrencia
    this.tipo = TipoCuentaPagar.otros,
    this.frecuencia = FrecuenciaCuentaPagar.unica,
    this.esRecurrente = false,
    this.diaDelMes,
    this.ultimoPago,
    this.montoUltimoPago,
    this.proximoVencimiento,
    this.totalPagosRealizados = 0,
    this.alertaEnviada = false,
    this.activa = true,
    this.observaciones,
    this.historialPagos = const [],
    this.diasAvisos = const [15, 7, 3, 1],
    this.diasAvisoDescuento = const [10, 5, 2, 1],
    this.avisosActivados = true,
  });

  factory CuentaPorPagar.fromJson(Map<String, dynamic> json) {
    return CuentaPorPagar(
      id: json['_id'],
      proveedorId: json['proveedorId'],
      proveedorNombre: json['proveedorNombre'] ?? '',
      numeroFactura: json['numeroFactura'] ?? '',
      montoTotal: (json['montoTotal'] ?? 0).toDouble(),
      montoAbonado: (json['montoAbonado'] ?? 0).toDouble(),
      saldoPendiente: (json['saldoPendiente'] ?? 0).toDouble(),
      fechaVencimiento: DateTime.parse(
        json['fechaVencimiento'] ?? DateTime.now().toIso8601String(),
      ),
      diasVencimiento: json['diasVencimiento'] ?? 0,
      tieneDescuento: json['tieneDescuento'] ?? false,
      porcentajeDescuento: (json['porcentajeDescuento'] ?? 0).toDouble(),
      montoDescuento: (json['montoDescuento'] ?? 0).toDouble(),
      fechaLimiteDescuento: json['fechaLimiteDescuento'] != null
          ? DateTime.parse(json['fechaLimiteDescuento'])
          : null,
      diasParaPerderDescuento: json['diasParaPerderDescuento'],
      descuentoPerdido: json['descuentoPerdido'] ?? false,
      estado: EstadoCuentaPagar.values.firstWhere(
        (e) => e.toString().split('.').last == (json['estado'] ?? 'PENDIENTE'),
        orElse: () => EstadoCuentaPagar.PENDIENTE,
      ),
      fechaCreacion: json['fechaCreacion'] != null
          ? DateTime.parse(json['fechaCreacion'])
          : null,
      // Recurrencia
      tipo: TipoCuentaPagar.values.firstWhere(
        (e) => e.toString().split('.').last == (json['tipo'] ?? 'otros'),
        orElse: () => TipoCuentaPagar.otros,
      ),
      frecuencia: FrecuenciaCuentaPagar.values.firstWhere(
        (e) => e.toString().split('.').last == (json['frecuencia'] ?? 'unica'),
        orElse: () => FrecuenciaCuentaPagar.unica,
      ),
      esRecurrente: json['esRecurrente'] ?? false,
      diaDelMes: json['diaDelMes'],
      ultimoPago: json['ultimoPago'] != null
          ? DateTime.parse(json['ultimoPago'])
          : null,
      montoUltimoPago: json['montoUltimoPago'] != null
          ? (json['montoUltimoPago']).toDouble()
          : null,
      proximoVencimiento: json['proximoVencimiento'] != null
          ? DateTime.parse(json['proximoVencimiento'])
          : null,
      totalPagosRealizados: json['totalPagosRealizados'] ?? 0,
      alertaEnviada: json['alertaEnviada'] ?? false,
      activa: json['activa'] ?? true,
      observaciones: json['observaciones'],
      historialPagos: json['historialPagos'] != null
          ? (json['historialPagos'] as List)
                .map((p) => HistorialPagoCxP.fromJson(p))
                .toList()
          : [],
      diasAvisos: json['diasAvisos'] != null
          ? List<int>.from(json['diasAvisos'])
          : [15, 7, 3, 1],
      diasAvisoDescuento: json['diasAvisoDescuento'] != null
          ? List<int>.from(json['diasAvisoDescuento'])
          : [10, 5, 2, 1],
      avisosActivados: json['avisosActivados'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      if (proveedorId != null) 'proveedorId': proveedorId,
      'proveedorNombre': proveedorNombre,
      'numeroFactura': numeroFactura,
      'montoTotal': montoTotal,
      'montoAbonado': montoAbonado,
      'saldoPendiente': saldoPendiente,
      'fechaVencimiento': fechaVencimiento.toIso8601String(),
      'diasVencimiento': diasVencimiento,
      'tieneDescuento': tieneDescuento,
      'porcentajeDescuento': porcentajeDescuento,
      'montoDescuento': montoDescuento,
      if (fechaLimiteDescuento != null)
        'fechaLimiteDescuento': fechaLimiteDescuento!.toIso8601String(),
      if (diasParaPerderDescuento != null)
        'diasParaPerderDescuento': diasParaPerderDescuento,
      'descuentoPerdido': descuentoPerdido,
      'estado': estado.toString().split('.').last,
      if (fechaCreacion != null)
        'fechaCreacion': fechaCreacion!.toIso8601String(),
      // Recurrencia
      'tipo': tipo.toString().split('.').last,
      'frecuencia': frecuencia.toString().split('.').last,
      'esRecurrente': esRecurrente,
      if (diaDelMes != null) 'diaDelMes': diaDelMes,
      if (ultimoPago != null) 'ultimoPago': ultimoPago!.toIso8601String(),
      if (montoUltimoPago != null) 'montoUltimoPago': montoUltimoPago,
      if (proximoVencimiento != null)
        'proximoVencimiento': proximoVencimiento!.toIso8601String(),
      'totalPagosRealizados': totalPagosRealizados,
      'alertaEnviada': alertaEnviada,
      'activa': activa,
      'diasAvisos': diasAvisos,
      'diasAvisoDescuento': diasAvisoDescuento,
      'avisosActivados': avisosActivados,
      if (observaciones != null) 'observaciones': observaciones,
    };
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'proveedorId': proveedorId ?? '',
      'proveedorNombre': proveedorNombre,
      'numeroFactura': numeroFactura,
      'monto': montoTotal,
      'diasVencimiento': diasVencimiento,
      'tipo': tipo.toString().split('.').last,
      'frecuencia': frecuencia.toString().split('.').last,
      'esRecurrente': esRecurrente,
      if (diaDelMes != null) 'diaDelMes': diaDelMes,
      if (tieneDescuento && porcentajeDescuento > 0)
        'porcentajeDescuento': porcentajeDescuento,
      if (tieneDescuento && fechaLimiteDescuento != null)
        'diasDescuento': fechaLimiteDescuento!
            .difference(DateTime.now())
            .inDays,
      'diasAvisos': diasAvisos,
      'diasAvisoDescuento': diasAvisoDescuento,
      'avisosActivados': avisosActivados,
      if (observaciones != null && observaciones!.isNotEmpty)
        'observaciones': observaciones,
    };
  }

  // === HELPERS DE RECURRENCIA ===

  /// Calcula la próxima fecha de vencimiento según la frecuencia
  DateTime calcularProximoVencimiento() {
    final base = ultimoPago ?? fechaVencimiento;
    switch (frecuencia) {
      case FrecuenciaCuentaPagar.mensual:
        return DateTime(base.year, base.month + 1, diaDelMes ?? base.day);
      case FrecuenciaCuentaPagar.bimestral:
        return DateTime(base.year, base.month + 2, diaDelMes ?? base.day);
      case FrecuenciaCuentaPagar.trimestral:
        return DateTime(base.year, base.month + 3, diaDelMes ?? base.day);
      case FrecuenciaCuentaPagar.semestral:
        return DateTime(base.year, base.month + 6, diaDelMes ?? base.day);
      case FrecuenciaCuentaPagar.anual:
        return DateTime(base.year + 1, base.month, diaDelMes ?? base.day);
      case FrecuenciaCuentaPagar.unica:
        return fechaVencimiento;
    }
  }

  /// Verifica si la cuenta está pagada en el periodo actual
  bool get estaPagadaEstePeriodo {
    if (ultimoPago == null) return false;
    if (!esRecurrente) return estado == EstadoCuentaPagar.PAGADA;

    final ahora = DateTime.now();
    switch (frecuencia) {
      case FrecuenciaCuentaPagar.mensual:
        return ultimoPago!.month == ahora.month &&
            ultimoPago!.year == ahora.year;
      case FrecuenciaCuentaPagar.bimestral:
        final diffMeses =
            (ahora.year - ultimoPago!.year) * 12 +
            ahora.month -
            ultimoPago!.month;
        return diffMeses < 2;
      case FrecuenciaCuentaPagar.trimestral:
        final diffMeses =
            (ahora.year - ultimoPago!.year) * 12 +
            ahora.month -
            ultimoPago!.month;
        return diffMeses < 3;
      case FrecuenciaCuentaPagar.semestral:
        final diffMeses =
            (ahora.year - ultimoPago!.year) * 12 +
            ahora.month -
            ultimoPago!.month;
        return diffMeses < 6;
      case FrecuenciaCuentaPagar.anual:
        return ultimoPago!.year == ahora.year;
      case FrecuenciaCuentaPagar.unica:
        return estado == EstadoCuentaPagar.PAGADA;
    }
  }

  /// Días restantes para el vencimiento (negativo = vencida)
  int get diasRestantes {
    final target = esRecurrente
        ? (proximoVencimiento ?? calcularProximoVencimiento())
        : fechaVencimiento;
    return target.difference(DateTime.now()).inDays;
  }

  /// Indica si requiere atención pronto (5 días o menos)
  bool get requiereAtencionPronto =>
      !estaPagadaEstePeriodo && diasRestantes <= 5 && diasRestantes >= 0;

  /// Indica si está vencida y sin pagar en este periodo
  bool get estaVencidaSinPagar => !estaPagadaEstePeriodo && diasRestantes < 0;

  bool get proximoAPerderDescuento =>
      tieneDescuento &&
      !descuentoPerdido &&
      diasParaPerderDescuento != null &&
      diasParaPerderDescuento! <= 5;

  bool get estaVencida => DateTime.now().isAfter(fechaVencimiento);

  double get montoConDescuento => tieneDescuento && !descuentoPerdido
      ? montoTotal - montoDescuento
      : montoTotal;

  /// Crea una copia con campos actualizados
  CuentaPorPagar copyWith({
    String? id,
    String? proveedorId,
    String? proveedorNombre,
    String? numeroFactura,
    double? montoTotal,
    double? montoAbonado,
    double? saldoPendiente,
    DateTime? fechaVencimiento,
    int? diasVencimiento,
    bool? tieneDescuento,
    double? porcentajeDescuento,
    double? montoDescuento,
    DateTime? fechaLimiteDescuento,
    int? diasParaPerderDescuento,
    bool? descuentoPerdido,
    EstadoCuentaPagar? estado,
    DateTime? fechaCreacion,
    TipoCuentaPagar? tipo,
    FrecuenciaCuentaPagar? frecuencia,
    bool? esRecurrente,
    int? diaDelMes,
    DateTime? ultimoPago,
    double? montoUltimoPago,
    DateTime? proximoVencimiento,
    int? totalPagosRealizados,
    bool? alertaEnviada,
    bool? activa,
    String? observaciones,
    List<HistorialPagoCxP>? historialPagos,
    List<int>? diasAvisos,
    List<int>? diasAvisoDescuento,
    bool? avisosActivados,
  }) {
    return CuentaPorPagar(
      id: id ?? this.id,
      proveedorId: proveedorId ?? this.proveedorId,
      proveedorNombre: proveedorNombre ?? this.proveedorNombre,
      numeroFactura: numeroFactura ?? this.numeroFactura,
      montoTotal: montoTotal ?? this.montoTotal,
      montoAbonado: montoAbonado ?? this.montoAbonado,
      saldoPendiente: saldoPendiente ?? this.saldoPendiente,
      fechaVencimiento: fechaVencimiento ?? this.fechaVencimiento,
      diasVencimiento: diasVencimiento ?? this.diasVencimiento,
      tieneDescuento: tieneDescuento ?? this.tieneDescuento,
      porcentajeDescuento: porcentajeDescuento ?? this.porcentajeDescuento,
      montoDescuento: montoDescuento ?? this.montoDescuento,
      fechaLimiteDescuento: fechaLimiteDescuento ?? this.fechaLimiteDescuento,
      diasParaPerderDescuento:
          diasParaPerderDescuento ?? this.diasParaPerderDescuento,
      descuentoPerdido: descuentoPerdido ?? this.descuentoPerdido,
      estado: estado ?? this.estado,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      tipo: tipo ?? this.tipo,
      frecuencia: frecuencia ?? this.frecuencia,
      esRecurrente: esRecurrente ?? this.esRecurrente,
      diaDelMes: diaDelMes ?? this.diaDelMes,
      ultimoPago: ultimoPago ?? this.ultimoPago,
      montoUltimoPago: montoUltimoPago ?? this.montoUltimoPago,
      proximoVencimiento: proximoVencimiento ?? this.proximoVencimiento,
      totalPagosRealizados: totalPagosRealizados ?? this.totalPagosRealizados,
      alertaEnviada: alertaEnviada ?? this.alertaEnviada,
      activa: activa ?? this.activa,
      observaciones: observaciones ?? this.observaciones,
      historialPagos: historialPagos ?? this.historialPagos,
      diasAvisos: diasAvisos ?? this.diasAvisos,
      diasAvisoDescuento: diasAvisoDescuento ?? this.diasAvisoDescuento,
      avisosActivados: avisosActivados ?? this.avisosActivados,
    );
  }
}

/// Registro de un pago individual dentro de una CxP recurrente
class HistorialPagoCxP {
  final DateTime fechaPago;
  final double montoPagado;
  final String? observaciones;
  final String? periodo; // "2025-01", "2025-02", etc.

  HistorialPagoCxP({
    required this.fechaPago,
    required this.montoPagado,
    this.observaciones,
    this.periodo,
  });

  factory HistorialPagoCxP.fromJson(Map<String, dynamic> json) {
    return HistorialPagoCxP(
      fechaPago: DateTime.parse(json['fechaPago']),
      montoPagado: (json['montoPagado'] ?? 0).toDouble(),
      observaciones: json['observaciones'],
      periodo: json['periodo'],
    );
  }

  Map<String, dynamic> toJson() => {
    'fechaPago': fechaPago.toIso8601String(),
    'montoPagado': montoPagado,
    if (observaciones != null) 'observaciones': observaciones,
    if (periodo != null) 'periodo': periodo,
  };
}

// === EXTENSIONS ===

extension EstadoCuentaPagarExtension on EstadoCuentaPagar {
  String get displayName {
    switch (this) {
      case EstadoCuentaPagar.PENDIENTE:
        return 'Pendiente';
      case EstadoCuentaPagar.VENCIDA:
        return 'Vencida';
      case EstadoCuentaPagar.PAGADA:
        return 'Pagada';
      case EstadoCuentaPagar.ABONADA:
        return 'Abonada';
    }
  }

  String get colorName {
    switch (this) {
      case EstadoCuentaPagar.PENDIENTE:
        return 'orange';
      case EstadoCuentaPagar.VENCIDA:
        return 'red';
      case EstadoCuentaPagar.PAGADA:
        return 'green';
      case EstadoCuentaPagar.ABONADA:
        return 'blue';
    }
  }
}

extension FrecuenciaCuentaPagarExtension on FrecuenciaCuentaPagar {
  String get displayName {
    switch (this) {
      case FrecuenciaCuentaPagar.unica:
        return 'Única';
      case FrecuenciaCuentaPagar.mensual:
        return 'Mensual';
      case FrecuenciaCuentaPagar.bimestral:
        return 'Bimestral';
      case FrecuenciaCuentaPagar.trimestral:
        return 'Trimestral';
      case FrecuenciaCuentaPagar.semestral:
        return 'Semestral';
      case FrecuenciaCuentaPagar.anual:
        return 'Anual';
    }
  }

  int get meses {
    switch (this) {
      case FrecuenciaCuentaPagar.unica:
        return 0;
      case FrecuenciaCuentaPagar.mensual:
        return 1;
      case FrecuenciaCuentaPagar.bimestral:
        return 2;
      case FrecuenciaCuentaPagar.trimestral:
        return 3;
      case FrecuenciaCuentaPagar.semestral:
        return 6;
      case FrecuenciaCuentaPagar.anual:
        return 12;
    }
  }
}

extension TipoCuentaPagarExtension on TipoCuentaPagar {
  String get displayName {
    switch (this) {
      case TipoCuentaPagar.arriendo:
        return 'Arriendo';
      case TipoCuentaPagar.serviciosPublicos:
        return 'Servicios Públicos';
      case TipoCuentaPagar.facturaProveedor:
        return 'Factura Proveedor';
      case TipoCuentaPagar.nomina:
        return 'Nómina';
      case TipoCuentaPagar.seguros:
        return 'Seguros';
      case TipoCuentaPagar.impuestos:
        return 'Impuestos';
      case TipoCuentaPagar.mantenimiento:
        return 'Mantenimiento';
      case TipoCuentaPagar.otros:
        return 'Otros';
    }
  }

  String get emoji {
    switch (this) {
      case TipoCuentaPagar.arriendo:
        return '🏢';
      case TipoCuentaPagar.serviciosPublicos:
        return '⚡';
      case TipoCuentaPagar.facturaProveedor:
        return '📦';
      case TipoCuentaPagar.nomina:
        return '👥';
      case TipoCuentaPagar.seguros:
        return '🛡️';
      case TipoCuentaPagar.impuestos:
        return '📄';
      case TipoCuentaPagar.mantenimiento:
        return '🔧';
      case TipoCuentaPagar.otros:
        return '📋';
    }
  }

  IconData get icon {
    switch (this) {
      case TipoCuentaPagar.arriendo:
        return Icons.home_work;
      case TipoCuentaPagar.serviciosPublicos:
        return Icons.electrical_services;
      case TipoCuentaPagar.facturaProveedor:
        return Icons.inventory;
      case TipoCuentaPagar.nomina:
        return Icons.people;
      case TipoCuentaPagar.seguros:
        return Icons.security;
      case TipoCuentaPagar.impuestos:
        return Icons.account_balance;
      case TipoCuentaPagar.mantenimiento:
        return Icons.build;
      case TipoCuentaPagar.otros:
        return Icons.more_horiz;
    }
  }
}
