class DashboardData {
  final String fecha;
  final VentasPeriodo ventas7Dias;
  final VentasPeriodo ventas30Dias;
  final Facturacion facturacion;
  final VentasPeriodo ventasAnio;
  final VentasHoy ventasHoy;
  final Inventario inventario;
  final PedidosHoy pedidosHoy;

  DashboardData({
    required this.fecha,
    required this.ventas7Dias,
    required this.ventas30Dias,
    required this.facturacion,
    required this.ventasAnio,
    required this.ventasHoy,
    required this.inventario,
    required this.pedidosHoy,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    print('🔄 Parseando JSON a DashboardData: ${json.keys}');

    // Verificar keys esperadas
    final expectedKeys = [
      'fecha',
      'ventasSemana',
      'ventasMes',
      'facturacion',
      'ventasAño',
      'ventasHoy',
      'inventario',
      'pedidosHoy',
    ];
    final missingKeys = expectedKeys
        .where((key) => !json.containsKey(key))
        .toList();

    if (missingKeys.isNotEmpty) {
      print('⚠️ Faltan claves en la respuesta: $missingKeys');
    }

    return DashboardData(
      fecha: json['fecha'] ?? '',
      ventas7Dias: VentasPeriodo.fromJson(json['ventasSemana'] ?? {}),
      ventas30Dias: VentasPeriodo.fromJson(json['ventasMes'] ?? {}),
      facturacion: Facturacion.fromJson(json['facturacion'] ?? {}),
      ventasAnio: VentasPeriodo.fromJson(json['ventasAño'] ?? {}),
      ventasHoy: VentasHoy.fromJson(json['ventasHoy'] ?? {}),
      inventario: Inventario.fromJson(json['inventario'] ?? {}),
      pedidosHoy: PedidosHoy.fromJson(json['pedidosHoy'] ?? {}),
    );
  }
}

class VentasPeriodo {
  final double objetivo;
  final double total;
  final double porcentaje;

  VentasPeriodo({
    required this.objetivo,
    required this.total,
    required this.porcentaje,
  });

  factory VentasPeriodo.fromJson(Map<String, dynamic> json) {
    // Buscar el campo que tenga datos reales de dinero
    double totalVentas = 0.0;

    // Intentar múltiples campos hasta encontrar uno con valor
    totalVentas = (json['totalFacturas'] ?? 0).toDouble();
    if (totalVentas == 0) {
      totalVentas = (json['total'] ?? 0).toDouble();
    }
    if (totalVentas == 0) {
      totalVentas = (json['totalPedidos'] ?? 0).toDouble();
    }

    print('🏗️ VentasPeriodo.fromJson - Total calculado: $totalVentas');
    print(
      '   Campos disponibles: totalFacturas=${json['totalFacturas']}, total=${json['total']}, totalPedidos=${json['totalPedidos']}',
    );

    return VentasPeriodo(
      objetivo: (json['objetivo'] ?? 0).toDouble(),
      total: totalVentas,
      porcentaje: (json['porcentaje'] ?? 0).toDouble(),
    );
  }
}

class VentasHoy {
  final double objetivo;
  final double total;
  final int facturas;
  final int cantidad;
  final double porcentaje;
  final int pedidosPagados;

  VentasHoy({
    required this.objetivo,
    required this.total,
    required this.facturas,
    required this.cantidad,
    required this.porcentaje,
    required this.pedidosPagados,
  });

  factory VentasHoy.fromJson(Map<String, dynamic> json) {
    // Buscar el campo que tenga datos reales de dinero
    double totalVentas = 0.0;

    // Intentar múltiples campos hasta encontrar uno con valor
    totalVentas = (json['totalFacturas'] ?? 0).toDouble();
    if (totalVentas == 0) {
      totalVentas = (json['total'] ?? 0).toDouble();
    }
    if (totalVentas == 0) {
      totalVentas = (json['totalPedidos'] ?? 0).toDouble();
    }

    print('🏗️ VentasHoy.fromJson - Total calculado: $totalVentas');
    print(
      '   Campos disponibles: totalFacturas=${json['totalFacturas']}, total=${json['total']}, totalPedidos=${json['totalPedidos']}',
    );

    return VentasHoy(
      objetivo: (json['objetivo'] ?? 0).toDouble(),
      total: totalVentas,
      facturas:
          json['cantidadFacturas'] ??
          json['facturas'] ??
          0, // Usar cantidadFacturas del backend
      cantidad:
          json['cantidadTotal'] ??
          json['cantidad'] ??
          0, // Usar cantidadTotal del backend
      porcentaje: (json['porcentaje'] ?? 0).toDouble(),
      pedidosPagados:
          json['cantidadPedidos'] ??
          json['pedidosPagados'] ??
          0, // Usar cantidadPedidos del backend
    );
  }
}

class Facturacion {
  final double montoPendiente;
  final int pendientesPago;

  Facturacion({required this.montoPendiente, required this.pendientesPago});

  factory Facturacion.fromJson(Map<String, dynamic> json) {
    return Facturacion(
      montoPendiente: (json['montoPendiente'] ?? 0).toDouble(),
      pendientesPago: json['pendientesPago'] ?? 0,
    );
  }
}

class Inventario {
  final int alertas;
  final int stockBajo;
  final int agotados;

  Inventario({
    required this.alertas,
    required this.stockBajo,
    required this.agotados,
  });

  factory Inventario.fromJson(Map<String, dynamic> json) {
    return Inventario(
      alertas: json['alertas'] ?? 0,
      stockBajo: json['stockBajo'] ?? 0,
      agotados: json['agotados'] ?? 0,
    );
  }
}

class PedidosHoy {
  final int total;
  final int completados;
  final int pendientes;

  PedidosHoy({
    required this.total,
    required this.completados,
    required this.pendientes,
  });

  factory PedidosHoy.fromJson(Map<String, dynamic> json) {
    return PedidosHoy(
      total: json['total'] ?? 0,
      completados: json['completados'] ?? 0,
      pendientes: json['pendientes'] ?? 0,
    );
  }
}
