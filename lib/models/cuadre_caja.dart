class CuadreCaja {
  final String? id;
  final String? nombre;
  final DateTime? fechaCierre;
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final String responsable;
  final double fondoInicial;
  final double efectivoInicial;
  final double transferenciasIniciales;
  final double totalInicial;
  final double ventasEfectivo;
  final double ventasTransferencias;
  final double ventasTarjetas;
  final double totalVentas;
  final double totalPropinas;
  final double totalGastos;
  final double deboTener;
  final int cantidadFacturas;
  final int cantidadPedidos;
  final String? observaciones;
  final String estado;

  CuadreCaja({
    this.id,
    this.nombre,
    this.fechaCierre,
    this.fechaInicio,
    this.fechaFin,
    required this.responsable,
    required this.fondoInicial,
    required this.efectivoInicial,
    required this.transferenciasIniciales,
    required this.totalInicial,
    required this.ventasEfectivo,
    required this.ventasTransferencias,
    required this.ventasTarjetas,
    required this.totalVentas,
    required this.totalPropinas,
    required this.totalGastos,
    required this.deboTener,
    required this.cantidadFacturas,
    required this.cantidadPedidos,
    this.observaciones,
    required this.estado,
  });

  factory CuadreCaja.fromJson(Map<String, dynamic> json) {
    return CuadreCaja(
      id: json['_id'],
      nombre: json['nombre'],
      fechaCierre: json['fechaCierre'] != null
          ? DateTime.parse(json['fechaCierre'])
          : null,
      fechaInicio: json['fechaInicio'] != null
          ? DateTime.parse(json['fechaInicio'])
          : null,
      fechaFin: json['fechaFin'] != null
          ? DateTime.parse(json['fechaFin'])
          : null,
      responsable: json['responsable'] ?? '',
      fondoInicial: (json['fondoInicial'] ?? 0.0).toDouble(),
      efectivoInicial: (json['efectivoInicial'] ?? 0.0).toDouble(),
      transferenciasIniciales: (json['transferenciasIniciales'] ?? 0.0)
          .toDouble(),
      totalInicial: (json['totalInicial'] ?? 0.0).toDouble(),
      ventasEfectivo: (json['ventasEfectivo'] ?? 0.0).toDouble(),
      ventasTransferencias: (json['ventasTransferencias'] ?? 0.0).toDouble(),
      ventasTarjetas: (json['ventasTarjetas'] ?? 0.0).toDouble(),
      totalVentas: (json['totalVentas'] ?? 0.0).toDouble(),
      totalPropinas: (json['totalPropinas'] ?? 0.0).toDouble(),
      totalGastos: (json['totalGastos'] ?? 0.0).toDouble(),
      deboTener: (json['deboTener'] ?? 0.0).toDouble(),
      cantidadFacturas: (json['cantidadFacturas'] ?? 0),
      cantidadPedidos: (json['cantidadPedidos'] ?? 0),
      observaciones: json['observaciones'],
      estado: json['estado'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      if (nombre != null) 'nombre': nombre,
      if (fechaCierre != null) 'fechaCierre': fechaCierre!.toIso8601String(),
      if (fechaInicio != null) 'fechaInicio': fechaInicio!.toIso8601String(),
      if (fechaFin != null) 'fechaFin': fechaFin!.toIso8601String(),
      'responsable': responsable,
      'fondoInicial': fondoInicial,
      'efectivoInicial': efectivoInicial,
      'transferenciasIniciales': transferenciasIniciales,
      'totalInicial': totalInicial,
      'ventasEfectivo': ventasEfectivo,
      'ventasTransferencias': ventasTransferencias,
      'ventasTarjetas': ventasTarjetas,
      'totalVentas': totalVentas,
      'totalPropinas': totalPropinas,
      'totalGastos': totalGastos,
      'deboTener': deboTener,
      'cantidadFacturas': cantidadFacturas,
      'cantidadPedidos': cantidadPedidos,
      if (observaciones != null) 'observaciones': observaciones,
      'estado': estado,
    };
  }
}
