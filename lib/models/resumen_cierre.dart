class ResumenCierre {
  final ResumenFinal resumenFinal;
  final MovimientosEfectivo movimientosEfectivo;
  final ResumenGastosDetallado resumenGastos;
  final ResumenCompras resumenCompras;
  final CuadreInfo cuadreInfo;
  final ResumenVentas resumenVentas;

  ResumenCierre({
    required this.resumenFinal,
    required this.movimientosEfectivo,
    required this.resumenGastos,
    required this.resumenCompras,
    required this.cuadreInfo,
    required this.resumenVentas,
  });

  factory ResumenCierre.fromJson(Map<String, dynamic> json) {
    return ResumenCierre(
      resumenFinal: ResumenFinal.fromJson(json['resumenFinal'] ?? {}),
      movimientosEfectivo: MovimientosEfectivo.fromJson(
        json['movimientosEfectivo'] ?? {},
      ),
      resumenGastos: ResumenGastosDetallado.fromJson(
        json['resumenGastos'] ?? {},
      ),
      resumenCompras: ResumenCompras.fromJson(json['resumenCompras'] ?? {}),
      cuadreInfo: CuadreInfo.fromJson(json['cuadreInfo'] ?? {}),
      resumenVentas: ResumenVentas.fromJson(json['resumenVentas'] ?? {}),
    );
  }
}

class ResumenFinal {
  final double totalGastos;
  final double efectivoEsperado;
  final bool cuadrado;
  final double totalVentas;
  final double utilidadBruta;
  final double totalCompras;
  final double diferencia;
  final double efectivoDeclarado;

  ResumenFinal({
    required this.totalGastos,
    required this.efectivoEsperado,
    required this.cuadrado,
    required this.totalVentas,
    required this.utilidadBruta,
    required this.totalCompras,
    required this.diferencia,
    required this.efectivoDeclarado,
  });

  factory ResumenFinal.fromJson(Map<String, dynamic> json) {
    // Función auxiliar para convertir valores a double de forma segura
    double safeToDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        return parsed ?? 0.0;
      }
      return 0.0;
    }

    return ResumenFinal(
      totalGastos: safeToDouble(json['totalGastos']),
      efectivoEsperado: safeToDouble(json['efectivoEsperado']),
      cuadrado: json['cuadrado'] ?? false,
      totalVentas: safeToDouble(json['totalVentas']),
      utilidadBruta: safeToDouble(json['utilidadBruta']),
      totalCompras: safeToDouble(json['totalCompras']),
      diferencia: safeToDouble(json['diferencia']),
      efectivoDeclarado: safeToDouble(json['efectivoDeclarado']),
    );
  }
}

class MovimientosEfectivo {
  final double efectivoEsperado;
  final double fondoInicial;
  final bool cuadrado;
  final double ventasEfectivo;
  final double gastosEfectivo;
  final double tolerancia;
  final double comprasEfectivo;
  final double diferencia;
  final double efectivoDeclarado;

  MovimientosEfectivo({
    required this.efectivoEsperado,
    required this.fondoInicial,
    required this.cuadrado,
    required this.ventasEfectivo,
    required this.gastosEfectivo,
    required this.tolerancia,
    required this.comprasEfectivo,
    required this.diferencia,
    required this.efectivoDeclarado,
  });

  factory MovimientosEfectivo.fromJson(Map<String, dynamic> json) {
    // Función auxiliar para convertir valores a double de forma segura
    double safeToDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        return parsed ?? 0.0;
      }
      return 0.0;
    }

    return MovimientosEfectivo(
      efectivoEsperado: safeToDouble(json['efectivoEsperado']),
      fondoInicial: safeToDouble(json['fondoInicial']),
      cuadrado: json['cuadrado'] ?? false,
      ventasEfectivo: safeToDouble(json['ventasEfectivo']),
      gastosEfectivo: safeToDouble(json['gastosEfectivo']),
      tolerancia: safeToDouble(json['tolerancia']),
      comprasEfectivo: safeToDouble(json['comprasEfectivo']),
      diferencia: safeToDouble(json['diferencia']),
      efectivoDeclarado: safeToDouble(json['efectivoDeclarado']),
    );
  }
}

class ResumenGastosDetallado {
  final Map<String, double> gastosPorTipo;
  final double totalGastos;
  final int totalRegistros;
  final List<dynamic> detallesGastos;
  final Map<String, double> gastosPorFormaPago;
  final Map<String, int> cantidadPorTipo;

  ResumenGastosDetallado({
    required this.gastosPorTipo,
    required this.totalGastos,
    required this.totalRegistros,
    required this.detallesGastos,
    required this.gastosPorFormaPago,
    required this.cantidadPorTipo,
  });

  factory ResumenGastosDetallado.fromJson(Map<String, dynamic> json) {
    // Función auxiliar para convertir valores a double de forma segura
    double safeToDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        return parsed ?? 0.0;
      }
      return 0.0;
    }

    // Función auxiliar para convertir Map<String, dynamic> a Map<String, double>
    Map<String, double> safeMapToDouble(Map<String, dynamic>? map) {
      if (map == null) return {};
      final result = <String, double>{};
      map.forEach((key, value) {
        result[key] = safeToDouble(value);
      });
      return result;
    }

    // Función auxiliar para convertir Map<String, dynamic> a Map<String, int>
    Map<String, int> safeMapToInt(Map<String, dynamic>? map) {
      if (map == null) return {};
      final result = <String, int>{};
      map.forEach((key, value) {
        int safeValue = 0;
        if (value is int) {
          safeValue = value;
        } else if (value is double) {
          safeValue = value.toInt();
        } else if (value is String) {
          safeValue = int.tryParse(value) ?? 0;
        }
        result[key] = safeValue;
      });
      return result;
    }

    return ResumenGastosDetallado(
      gastosPorTipo: safeMapToDouble(
        json['gastosPorTipo']?.cast<String, dynamic>(),
      ),
      totalGastos: safeToDouble(json['totalGastos']),
      totalRegistros: json['totalRegistros'] is int
          ? json['totalRegistros']
          : 0,
      detallesGastos: json['detallesGastos'] ?? [],
      gastosPorFormaPago: safeMapToDouble(
        json['gastosPorFormaPago']?.cast<String, dynamic>(),
      ),
      cantidadPorTipo: safeMapToInt(
        json['cantidadPorTipo']?.cast<String, dynamic>(),
      ),
    );
  }
}

class ResumenCompras {
  final Map<String, double> comprasPorFormaPago;
  final List<dynamic> detallesCompras;
  final double totalCompras;
  final int totalFacturas;

  ResumenCompras({
    required this.comprasPorFormaPago,
    required this.detallesCompras,
    required this.totalCompras,
    required this.totalFacturas,
  });

  factory ResumenCompras.fromJson(Map<String, dynamic> json) {
    // Función auxiliar para convertir valores a double de forma segura
    double safeToDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        return parsed ?? 0.0;
      }
      return 0.0;
    }

    // Función auxiliar para convertir Map<String, dynamic> a Map<String, double>
    Map<String, double> safeMapToDouble(Map<String, dynamic>? map) {
      if (map == null) return {};
      final result = <String, double>{};
      map.forEach((key, value) {
        result[key] = safeToDouble(value);
      });
      return result;
    }

    return ResumenCompras(
      comprasPorFormaPago: safeMapToDouble(
        json['comprasPorFormaPago']?.cast<String, dynamic>(),
      ),
      detallesCompras: json['detallesCompras'] ?? [],
      totalCompras: safeToDouble(json['totalCompras']),
      totalFacturas: json['totalFacturas'] is int ? json['totalFacturas'] : 0,
    );
  }
}

class CuadreInfo {
  final Map<String, double> fondoInicialDesglosado;
  final String? fechaCierre;
  final String estado;
  final bool cerrada;
  final String responsable;
  final String fechaApertura;
  final double fondoInicial;
  final String id;
  final String nombre;

  CuadreInfo({
    required this.fondoInicialDesglosado,
    this.fechaCierre,
    required this.estado,
    required this.cerrada,
    required this.responsable,
    required this.fechaApertura,
    required this.fondoInicial,
    required this.id,
    required this.nombre,
  });

  factory CuadreInfo.fromJson(Map<String, dynamic> json) {
    // Función auxiliar para convertir valores a double de forma segura
    double safeToDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        return parsed ?? 0.0;
      }
      return 0.0;
    }

    // Función auxiliar para convertir Map<String, dynamic> a Map<String, double>
    Map<String, double> safeMapToDouble(Map<String, dynamic>? map) {
      if (map == null) return {};
      final result = <String, double>{};
      map.forEach((key, value) {
        result[key] = safeToDouble(value);
      });
      return result;
    }

    return CuadreInfo(
      fondoInicialDesglosado: safeMapToDouble(
        json['fondoInicialDesglosado']?.cast<String, dynamic>(),
      ),
      fechaCierre: json['fechaCierre'],
      estado: json['estado']?.toString() ?? '',
      cerrada: json['cerrada'] ?? false,
      responsable: json['responsable']?.toString() ?? '',
      fechaApertura: json['fechaApertura']?.toString() ?? '',
      fondoInicial: safeToDouble(json['fondoInicial']),
      id: json['id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
    );
  }
}

class ResumenVentas {
  final int totalPedidos;
  final List<DetallePedido> detallesPedidos;
  final Map<String, double> ventasPorFormaPago;
  final double totalVentas;
  final Map<String, int> cantidadPorFormaPago;

  ResumenVentas({
    required this.totalPedidos,
    required this.detallesPedidos,
    required this.ventasPorFormaPago,
    required this.totalVentas,
    required this.cantidadPorFormaPago,
  });

  factory ResumenVentas.fromJson(Map<String, dynamic> json) {
    // Función auxiliar para convertir valores a double de forma segura
    double safeToDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        return parsed ?? 0.0;
      }
      return 0.0;
    }

    // Función auxiliar para convertir Map<String, dynamic> a Map<String, double>
    Map<String, double> safeMapToDouble(Map<String, dynamic>? map) {
      if (map == null) return {};
      final result = <String, double>{};
      map.forEach((key, value) {
        result[key] = safeToDouble(value);
      });
      return result;
    }

    // Función auxiliar para convertir Map<String, dynamic> a Map<String, int>
    Map<String, int> safeMapToInt(Map<String, dynamic>? map) {
      if (map == null) return {};
      final result = <String, int>{};
      map.forEach((key, value) {
        int safeValue = 0;
        if (value is int) {
          safeValue = value;
        } else if (value is double) {
          safeValue = value.toInt();
        } else if (value is String) {
          safeValue = int.tryParse(value) ?? 0;
        }
        result[key] = safeValue;
      });
      return result;
    }

    return ResumenVentas(
      totalPedidos: json['totalPedidos'] is int ? json['totalPedidos'] : 0,
      detallesPedidos:
          (json['detallesPedidos'] as List<dynamic>?)
              ?.map((item) => DetallePedido.fromJson(item))
              .toList() ??
          [],
      ventasPorFormaPago: safeMapToDouble(
        json['ventasPorFormaPago']?.cast<String, dynamic>(),
      ),
      totalVentas: safeToDouble(json['totalVentas']),
      cantidadPorFormaPago: safeMapToInt(
        json['cantidadPorFormaPago']?.cast<String, dynamic>(),
      ),
    );
  }
}

class DetallePedido {
  final double total;
  final String tipo;
  final String mesa;
  final String id;
  final String formaPago;
  final String fechaPago;

  DetallePedido({
    required this.total,
    required this.tipo,
    required this.mesa,
    required this.id,
    required this.formaPago,
    required this.fechaPago,
  });

  factory DetallePedido.fromJson(Map<String, dynamic> json) {
    // Función auxiliar para convertir valores a double de forma segura
    double safeToDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        return parsed ?? 0.0;
      }
      return 0.0;
    }

    return DetallePedido(
      total: safeToDouble(json['total']),
      tipo: json['tipo']?.toString() ?? '',
      mesa: json['mesa']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
      formaPago: json['formaPago']?.toString() ?? '',
      fechaPago: json['fechaPago']?.toString() ?? '',
    );
  }
}
