enum CategoriaGasto {
  serviciosPublicos,
  arriendo,
  nomina,
  mantenimiento,
  seguros,
  impuestos,
  otros,
}

enum FrecuenciaGasto { mensual, quincenal, trimestral, semestral, anual }

enum EstadoGastoProgramado { activo, pausado, inactivo }

class GastoProgramado {
  final String? id;
  final String nombre;
  final CategoriaGasto categoria;
  final FrecuenciaGasto frecuencia;
  final double montoEstimado;
  final int? diaDelMes; // Para gastos mensuales
  final List<int>? diasQuincena; // Para gastos quincenales [15, 30]
  final DateTime? proximaFecha;
  final EstadoGastoProgramado estado;
  final bool activo;
  final DateTime? fechaCreacion;
  final DateTime? fechaUltimoPago;
  final double? montoUltimoPago;

  GastoProgramado({
    this.id,
    required this.nombre,
    required this.categoria,
    required this.frecuencia,
    required this.montoEstimado,
    this.diaDelMes,
    this.diasQuincena,
    this.proximaFecha,
    this.estado = EstadoGastoProgramado.activo,
    this.activo = true,
    this.fechaCreacion,
    this.fechaUltimoPago,
    this.montoUltimoPago,
  });

  factory GastoProgramado.fromJson(Map<String, dynamic> json) {
    return GastoProgramado(
      id: json['_id'],
      nombre: json['nombre'] ?? '',
      categoria: CategoriaGasto.values.firstWhere(
        (e) => e.toString().split('.').last == (json['categoria'] ?? 'otros'),
        orElse: () => CategoriaGasto.otros,
      ),
      frecuencia: FrecuenciaGasto.values.firstWhere(
        (e) =>
            e.toString().split('.').last == (json['frecuencia'] ?? 'mensual'),
        orElse: () => FrecuenciaGasto.mensual,
      ),
      montoEstimado: (json['montoEstimado'] ?? 0).toDouble(),
      diaDelMes: json['diaDelMes'],
      diasQuincena: json['diasQuincena'] != null
          ? List<int>.from(json['diasQuincena'])
          : null,
      proximaFecha: json['proximaFecha'] != null
          ? DateTime.parse(json['proximaFecha'])
          : null,
      estado: EstadoGastoProgramado.values.firstWhere(
        (e) => e.toString().split('.').last == (json['estado'] ?? 'activo'),
        orElse: () => EstadoGastoProgramado.activo,
      ),
      activo: json['activo'] ?? true,
      fechaCreacion: json['fechaCreacion'] != null
          ? DateTime.parse(json['fechaCreacion'])
          : null,
      fechaUltimoPago: json['fechaUltimoPago'] != null
          ? DateTime.parse(json['fechaUltimoPago'])
          : null,
      montoUltimoPago: json['montoUltimoPago'] != null
          ? (json['montoUltimoPago']).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'nombre': nombre,
      'categoria': categoria.toString().split('.').last,
      'frecuencia': frecuencia.toString().split('.').last,
      'montoEstimado': montoEstimado,
      if (diaDelMes != null) 'diaDelMes': diaDelMes,
      if (diasQuincena != null) 'diasQuincena': diasQuincena,
      if (proximaFecha != null) 'proximaFecha': proximaFecha!.toIso8601String(),
      'estado': estado.toString().split('.').last,
      'activo': activo,
      if (fechaCreacion != null)
        'fechaCreacion': fechaCreacion!.toIso8601String(),
      if (fechaUltimoPago != null)
        'fechaUltimoPago': fechaUltimoPago!.toIso8601String(),
      if (montoUltimoPago != null) 'montoUltimoPago': montoUltimoPago,
    };
  }

  Map<String, dynamic> toCreateJson() {
    Map<String, dynamic> data = {
      'nombre': nombre,
      'categoria': categoria.toString().split('.').last,
      'frecuencia': frecuencia.toString().split('.').last,
      'montoEstimado': montoEstimado,
    };

    if (frecuencia == FrecuenciaGasto.mensual && diaDelMes != null) {
      data['diaDelMes'] = diaDelMes;
    }

    if (frecuencia == FrecuenciaGasto.quincenal && diasQuincena != null) {
      data['diasQuincena'] = diasQuincena;
    }

    return data;
  }

  bool get proximoAPagar =>
      proximaFecha != null &&
      proximaFecha!.difference(DateTime.now()).inDays <= 3 &&
      proximaFecha!.isAfter(DateTime.now());

  bool get estaVencido =>
      proximaFecha != null &&
      DateTime.now().isAfter(proximaFecha!) &&
      estado == EstadoGastoProgramado.activo;

  DateTime? calcularProximaFecha() {
    final now = DateTime.now();

    switch (frecuencia) {
      case FrecuenciaGasto.mensual:
        if (diaDelMes == null) return null;
        final nextMonth = DateTime(now.year, now.month + 1, diaDelMes!);
        return nextMonth.isAfter(now)
            ? nextMonth
            : DateTime(now.year, now.month + 2, diaDelMes!);

      case FrecuenciaGasto.quincenal:
        if (diasQuincena == null) return null;
        final currentMonth = DateTime(now.year, now.month);

        for (int dia in diasQuincena!) {
          final fechaQuincena = DateTime(now.year, now.month, dia);
          if (fechaQuincena.isAfter(now)) {
            return fechaQuincena;
          }
        }

        // Si ya pasaron todas las quincenas del mes, tomar la primera del siguiente
        return DateTime(now.year, now.month + 1, diasQuincena!.first);

      default:
        return null;
    }
  }
}

extension CategoriaGastoExtension on CategoriaGasto {
  String get displayName {
    switch (this) {
      case CategoriaGasto.serviciosPublicos:
        return 'Servicios Públicos';
      case CategoriaGasto.arriendo:
        return 'Arriendo';
      case CategoriaGasto.nomina:
        return 'Nómina';
      case CategoriaGasto.mantenimiento:
        return 'Mantenimiento';
      case CategoriaGasto.seguros:
        return 'Seguros';
      case CategoriaGasto.impuestos:
        return 'Impuestos';
      case CategoriaGasto.otros:
        return 'Otros';
    }
  }

  String get icon {
    switch (this) {
      case CategoriaGasto.serviciosPublicos:
        return '⚡';
      case CategoriaGasto.arriendo:
        return '🏢';
      case CategoriaGasto.nomina:
        return '👥';
      case CategoriaGasto.mantenimiento:
        return '🔧';
      case CategoriaGasto.seguros:
        return '🛡️';
      case CategoriaGasto.impuestos:
        return '📄';
      case CategoriaGasto.otros:
        return '📋';
    }
  }
}

extension FrecuenciaGastoExtension on FrecuenciaGasto {
  String get displayName {
    switch (this) {
      case FrecuenciaGasto.mensual:
        return 'Mensual';
      case FrecuenciaGasto.quincenal:
        return 'Quincenal';
      case FrecuenciaGasto.trimestral:
        return 'Trimestral';
      case FrecuenciaGasto.semestral:
        return 'Semestral';
      case FrecuenciaGasto.anual:
        return 'Anual';
    }
  }
}

extension EstadoGastoProgramadoExtension on EstadoGastoProgramado {
  String get displayName {
    switch (this) {
      case EstadoGastoProgramado.activo:
        return 'Activo';
      case EstadoGastoProgramado.pausado:
        return 'Pausado';
      case EstadoGastoProgramado.inactivo:
        return 'Inactivo';
    }
  }

  String get colorName {
    switch (this) {
      case EstadoGastoProgramado.activo:
        return 'green';
      case EstadoGastoProgramado.pausado:
        return 'orange';
      case EstadoGastoProgramado.inactivo:
        return 'red';
    }
  }
}
