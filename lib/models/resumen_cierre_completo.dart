class ResumenCierreCompleto {
  final ResumenFinalCompleto resumenFinal;
  final MovimientosEfectivoCompleto movimientosEfectivo;
  final ResumenGastosCompleto resumenGastos;
  final ResumenComprasCompleto resumenCompras;
  final CuadreInfoCompleto cuadreInfo;
  final ResumenVentasCompleto resumenVentas;

  ResumenCierreCompleto({
    required this.resumenFinal,
    required this.movimientosEfectivo,
    required this.resumenGastos,
    required this.resumenCompras,
    required this.cuadreInfo,
    required this.resumenVentas,
  });

  factory ResumenCierreCompleto.fromJson(Map<String, dynamic> json) {
    return ResumenCierreCompleto(
      resumenFinal: ResumenFinalCompleto.fromJson(json['resumenFinal'] ?? {}),
      movimientosEfectivo: MovimientosEfectivoCompleto.fromJson(
        json['movimientosEfectivo'] ?? {},
      ),
      resumenGastos: ResumenGastosCompleto.fromJson(
        json['resumenGastos'] ?? {},
      ),
      resumenCompras: ResumenComprasCompleto.fromJson(
        json['resumenCompras'] ?? {},
      ),
      cuadreInfo: CuadreInfoCompleto.fromJson(json['cuadreInfo'] ?? {}),
      resumenVentas: ResumenVentasCompleto.fromJson(
        json['resumenVentas'] ?? {},
      ),
    );
  }

  // Getters que usan los datos correctos (prioriza movimientosEfectivo sobre resumenFinal cuando sea necesario)
  double get ventasEfectivo {
    // Si movimientosEfectivo tiene datos, usarlos; si no, usar resumenFinal
    return movimientosEfectivo.ventasEfectivo > 0
        ? movimientosEfectivo.ventasEfectivo
        : resumenFinal.ventasEfectivo;
  }

  double get totalVentas {
    // Calcular total de ventas desde movimientosEfectivo
    return movimientosEfectivo.ventasEfectivo +
        movimientosEfectivo.ventasTransferencia;
  }

  double get totalGastos => resumenFinal.totalGastos;
  double get gastosEfectivo => resumenFinal.gastosEfectivo;
  double get fondoInicial => resumenFinal.fondoInicial;
  double get efectivoEsperado => resumenFinal.efectivoEsperado;
  double get gastosDirectos => resumenFinal.gastosDirectos;
  double get utilidadBruta => resumenFinal.utilidadBruta;
  double get totalCompras => resumenFinal.totalCompras;
  double get comprasEfectivo => resumenFinal.comprasEfectivo;
  double get facturasPagadasDesdeCaja => resumenFinal.facturasPagadasDesdeCaja;
}

class ResumenFinalCompleto {
  final double totalGastos;
  final double efectivoEsperado;
  final double fondoInicial;
  final double gastosDirectos;
  final double ventasEfectivo;
  final double totalVentas;
  final double gastosEfectivo;
  final double utilidadBruta;
  final double totalCompras;
  final double comprasEfectivo;
  final double facturasPagadasDesdeCaja;

  ResumenFinalCompleto({
    required this.totalGastos,
    required this.efectivoEsperado,
    required this.fondoInicial,
    required this.gastosDirectos,
    required this.ventasEfectivo,
    required this.totalVentas,
    required this.gastosEfectivo,
    required this.utilidadBruta,
    required this.totalCompras,
    required this.comprasEfectivo,
    required this.facturasPagadasDesdeCaja,
  });

  factory ResumenFinalCompleto.fromJson(Map<String, dynamic> json) {
    double safeToDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return ResumenFinalCompleto(
      totalGastos: safeToDouble(json['totalGastos']),
      efectivoEsperado: safeToDouble(json['efectivoEsperado']),
      fondoInicial: safeToDouble(json['fondoInicial']),
      gastosDirectos: safeToDouble(json['gastosDirectos']),
      ventasEfectivo: safeToDouble(json['ventasEfectivo']),
      totalVentas: safeToDouble(json['totalVentas']),
      gastosEfectivo: safeToDouble(json['gastosEfectivo']),
      utilidadBruta: safeToDouble(json['utilidadBruta']),
      totalCompras: safeToDouble(json['totalCompras']),
      comprasEfectivo: safeToDouble(json['comprasEfectivo']),
      facturasPagadasDesdeCaja: safeToDouble(json['facturasPagadasDesdeCaja']),
    );
  }
}

class MovimientosEfectivoCompleto {
  final double ingresosTransferencia;
  final double ingresosEfectivo;
  final Map<String, double> ingresosPorFormaPago;
  final double gastosTransferencia;
  final double transferenciaEsperada;
  final double efectivoEsperado;
  final double totalIngresosCaja;
  final double fondoInicial;
  final double comprasTransferencia;
  final double ventasEfectivo;
  final double ventasTransferencia;
  final double gastosEfectivo;
  final double comprasEfectivo;

  MovimientosEfectivoCompleto({
    required this.ingresosTransferencia,
    required this.ingresosEfectivo,
    required this.ingresosPorFormaPago,
    required this.gastosTransferencia,
    required this.transferenciaEsperada,
    required this.efectivoEsperado,
    required this.totalIngresosCaja,
    required this.fondoInicial,
    required this.comprasTransferencia,
    required this.ventasEfectivo,
    required this.ventasTransferencia,
    required this.gastosEfectivo,
    required this.comprasEfectivo,
  });

  factory MovimientosEfectivoCompleto.fromJson(Map<String, dynamic> json) {
    // Print the complete JSON for debugging
    print('📋 MovimientosEfectivoCompleto.fromJson - Datos recibidos:');
    json.forEach((key, value) {
      print('  - $key: $value');
    });

    double safeToDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    Map<String, double> safeMapToDouble(Map<String, dynamic>? map) {
      if (map == null) return {};
      final result = <String, double>{};
      map.forEach((key, value) {
        result[key] = safeToDouble(value);
      });
      return result;
    }

    // Check alternative keys for ventasEfectivo and ventasTransferencia
    double ventasEf = 0.0;
    double ventasTrans = 0.0;

    // Try different possible field names in the API response
    if (json['ventasEfectivo'] != null) {
      ventasEf = safeToDouble(json['ventasEfectivo']);
    } else if (json['efectivo'] != null) {
      ventasEf = safeToDouble(json['efectivo']);
    } else if (json['totalEfectivo'] != null) {
      ventasEf = safeToDouble(json['totalEfectivo']);
    }

    if (json['ventasTransferencia'] != null) {
      ventasTrans = safeToDouble(json['ventasTransferencia']);
    } else if (json['transferencia'] != null) {
      ventasTrans = safeToDouble(json['transferencia']);
    } else if (json['ventasTransferencias'] != null) {
      ventasTrans = safeToDouble(json['ventasTransferencias']);
    } else if (json['totalTransferencia'] != null) {
      ventasTrans = safeToDouble(json['totalTransferencia']);
    }

    print('💵 MovimientosEfectivoCompleto - ventas efectivo: $ventasEf');
    print(
      '💸 MovimientosEfectivoCompleto - ventas transferencia: $ventasTrans',
    );

    return MovimientosEfectivoCompleto(
      ingresosTransferencia: safeToDouble(json['ingresosTransferencia']),
      ingresosEfectivo: safeToDouble(json['ingresosEfectivo']),
      ingresosPorFormaPago: safeMapToDouble(
        json['ingresosPorFormaPago']?.cast<String, dynamic>(),
      ),
      gastosTransferencia: safeToDouble(json['gastosTransferencia']),
      transferenciaEsperada: safeToDouble(json['transferenciaEsperada']),
      efectivoEsperado: safeToDouble(json['efectivoEsperado']),
      totalIngresosCaja: safeToDouble(json['totalIngresosCaja']),
      fondoInicial: safeToDouble(json['fondoInicial']),
      comprasTransferencia: safeToDouble(json['comprasTransferencia']),
      ventasEfectivo: ventasEf,
      ventasTransferencia: ventasTrans,
      gastosEfectivo: safeToDouble(json['gastosEfectivo']),
      comprasEfectivo: safeToDouble(json['comprasEfectivo']),
    );
  }
}

class ResumenGastosCompleto {
  final Map<String, double> gastosPorTipo;
  final double totalGastos;
  final int totalRegistros;
  final double totalGastosIncluyendoFacturas;
  final double totalGastosDesdeCaja;
  final List<DetalleGasto> detallesGastos;
  final Map<String, double> gastosPorFormaPago;
  final double facturasPagadasDesdeCaja;
  final Map<String, int> cantidadPorTipo;

  ResumenGastosCompleto({
    required this.gastosPorTipo,
    required this.totalGastos,
    required this.totalRegistros,
    required this.totalGastosIncluyendoFacturas,
    required this.totalGastosDesdeCaja,
    required this.detallesGastos,
    required this.gastosPorFormaPago,
    required this.facturasPagadasDesdeCaja,
    required this.cantidadPorTipo,
  });

  factory ResumenGastosCompleto.fromJson(Map<String, dynamic> json) {
    double safeToDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    Map<String, double> safeMapToDouble(Map<String, dynamic>? map) {
      if (map == null) return {};
      final result = <String, double>{};
      map.forEach((key, value) {
        result[key] = safeToDouble(value);
      });
      return result;
    }

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

    return ResumenGastosCompleto(
      gastosPorTipo: safeMapToDouble(
        json['gastosPorTipo']?.cast<String, dynamic>(),
      ),
      totalGastos: safeToDouble(json['totalGastos']),
      totalRegistros: json['totalRegistros'] is int
          ? json['totalRegistros']
          : 0,
      totalGastosIncluyendoFacturas: safeToDouble(
        json['totalGastosIncluyendoFacturas'],
      ),
      totalGastosDesdeCaja: safeToDouble(json['totalGastosDesdeCaja']),
      detallesGastos:
          (json['detallesGastos'] as List<dynamic>?)
              ?.map((item) => DetalleGasto.fromJson(item))
              .toList() ??
          [],
      gastosPorFormaPago: safeMapToDouble(
        json['gastosPorFormaPago']?.cast<String, dynamic>(),
      ),
      facturasPagadasDesdeCaja: safeToDouble(json['facturasPagadasDesdeCaja']),
      cantidadPorTipo: safeMapToInt(
        json['cantidadPorTipo']?.cast<String, dynamic>(),
      ),
    );
  }
}

class ResumenComprasCompleto {
  final double totalComprasDesdeCaja;
  final int totalFacturasNoDesdeCaja;
  final List<DetalleCompra> detallesComprasNoDesdeCaja;
  final List<DetalleCompra> detallesComprasDesdeCaja;
  final Map<String, double> comprasPorFormaPago;
  final int totalFacturasDesdeCaja;
  final double totalComprasGenerales;
  final int totalFacturasGenerales;
  final double totalComprasNoDesdeCaja;

  ResumenComprasCompleto({
    required this.totalComprasDesdeCaja,
    required this.totalFacturasNoDesdeCaja,
    required this.detallesComprasNoDesdeCaja,
    required this.detallesComprasDesdeCaja,
    required this.comprasPorFormaPago,
    required this.totalFacturasDesdeCaja,
    required this.totalComprasGenerales,
    required this.totalFacturasGenerales,
    required this.totalComprasNoDesdeCaja,
  });

  factory ResumenComprasCompleto.fromJson(Map<String, dynamic> json) {
    double safeToDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    Map<String, double> safeMapToDouble(Map<String, dynamic>? map) {
      if (map == null) return {};
      final result = <String, double>{};
      map.forEach((key, value) {
        result[key] = safeToDouble(value);
      });
      return result;
    }

    return ResumenComprasCompleto(
      totalComprasDesdeCaja: safeToDouble(json['totalComprasDesdeCaja']),
      totalFacturasNoDesdeCaja: json['totalFacturasNoDesdeCaja'] is int
          ? json['totalFacturasNoDesdeCaja']
          : 0,
      detallesComprasNoDesdeCaja:
          (json['detallesComprasNoDesdeCaja'] as List<dynamic>?)
              ?.map((item) => DetalleCompra.fromJson(item))
              .toList() ??
          [],
      detallesComprasDesdeCaja:
          (json['detallesComprasDesdeCaja'] as List<dynamic>?)
              ?.map((item) => DetalleCompra.fromJson(item))
              .toList() ??
          [],
      comprasPorFormaPago: safeMapToDouble(
        json['comprasPorFormaPago']?.cast<String, dynamic>(),
      ),
      totalFacturasDesdeCaja: json['totalFacturasDesdeCaja'] is int
          ? json['totalFacturasDesdeCaja']
          : 0,
      totalComprasGenerales: safeToDouble(json['totalComprasGenerales']),
      totalFacturasGenerales: json['totalFacturasGenerales'] is int
          ? json['totalFacturasGenerales']
          : 0,
      totalComprasNoDesdeCaja: safeToDouble(json['totalComprasNoDesdeCaja']),
    );
  }
}

class CuadreInfoCompleto {
  final Map<String, double> fondoInicialDesglosado;
  final String? fechaCierre;
  final String estado;
  final bool cerrada;
  final String responsable;
  final String fechaApertura;
  final double fondoInicial;
  final String id;
  final String nombre;

  CuadreInfoCompleto({
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

  factory CuadreInfoCompleto.fromJson(Map<String, dynamic> json) {
    double safeToDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    Map<String, double> safeMapToDouble(Map<String, dynamic>? map) {
      if (map == null) return {};
      final result = <String, double>{};
      map.forEach((key, value) {
        result[key] = safeToDouble(value);
      });
      return result;
    }

    return CuadreInfoCompleto(
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

class ResumenVentasCompleto {
  final int totalPedidos;
  final List<DetallePedidoCompleto> detallesPedidos;
  final Map<String, double> ventasPorFormaPago;
  final double totalVentas;
  final Map<String, int> cantidadPorFormaPago;

  ResumenVentasCompleto({
    required this.totalPedidos,
    required this.detallesPedidos,
    required this.ventasPorFormaPago,
    required this.totalVentas,
    required this.cantidadPorFormaPago,
  });

  factory ResumenVentasCompleto.fromJson(Map<String, dynamic> json) {
    // Print the complete JSON for debugging
    print('📋 ResumenVentasCompleto.fromJson - Datos recibidos:');
    json.forEach((key, value) {
      print('  - $key: $value');
    });

    double safeToDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    Map<String, double> safeMapToDouble(Map<String, dynamic>? map) {
      if (map == null) return {};
      final result = <String, double>{};
      map.forEach((key, value) {
        result[key] = safeToDouble(value);
      });
      return result;
    }

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

    return ResumenVentasCompleto(
      totalPedidos: json['totalPedidos'] is int ? json['totalPedidos'] : 0,
      detallesPedidos:
          (json['detallesPedidos'] as List<dynamic>?)
              ?.map((item) => DetallePedidoCompleto.fromJson(item))
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

class DetalleGasto {
  final String id;
  final String concepto;
  final double monto;
  final String fecha;
  final String? proveedor;
  final String formaPago;
  final bool pagadoDesdeCaja;

  DetalleGasto({
    required this.id,
    required this.concepto,
    required this.monto,
    required this.fecha,
    this.proveedor,
    required this.formaPago,
    required this.pagadoDesdeCaja,
  });

  factory DetalleGasto.fromJson(Map<String, dynamic> json) {
    double safeToDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return DetalleGasto(
      id: json['id']?.toString() ?? '',
      concepto: json['concepto']?.toString() ?? '',
      monto: safeToDouble(json['monto']),
      fecha: json['fecha']?.toString() ?? '',
      proveedor: json['proveedor']?.toString(),
      formaPago: json['formaPago']?.toString() ?? '',
      pagadoDesdeCaja: json['pagadoDesdeCaja'] ?? false,
    );
  }
}

class DetalleCompra {
  final String fecha;
  final double total;
  final bool pagadoDesdeCaja;
  final String numero;
  final String observaciones;
  final String proveedor;
  final String id;
  final String medioPago;

  DetalleCompra({
    required this.fecha,
    required this.total,
    required this.pagadoDesdeCaja,
    required this.numero,
    required this.observaciones,
    required this.proveedor,
    required this.id,
    required this.medioPago,
  });

  factory DetalleCompra.fromJson(Map<String, dynamic> json) {
    double safeToDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return DetalleCompra(
      fecha: json['fecha']?.toString() ?? '',
      total: safeToDouble(json['total']),
      pagadoDesdeCaja: json['pagadoDesdeCaja'] ?? false,
      numero: json['numero']?.toString() ?? '',
      observaciones: json['observaciones']?.toString() ?? '',
      proveedor: json['proveedor']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
      medioPago: json['medioPago']?.toString() ?? '',
    );
  }
}

class DetallePedidoCompleto {
  final String id;
  final String mesa;
  final double total;
  final String formaPago;
  final String fecha;
  final String tipo;

  DetallePedidoCompleto({
    required this.id,
    required this.mesa,
    required this.total,
    required this.formaPago,
    required this.fecha,
    required this.tipo,
  });

  factory DetallePedidoCompleto.fromJson(Map<String, dynamic> json) {
    double safeToDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return DetallePedidoCompleto(
      id: json['id']?.toString() ?? '',
      mesa: json['mesa']?.toString() ?? '',
      total: safeToDouble(json['total']),
      formaPago: json['formaPago']?.toString() ?? '',
      fecha: json['fecha']?.toString() ?? '',
      tipo: json['tipo']?.toString() ?? '',
    );
  }
}
