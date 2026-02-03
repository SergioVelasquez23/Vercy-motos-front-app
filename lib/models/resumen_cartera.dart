import 'cuenta_por_cobrar.dart';
import 'cuenta_por_pagar.dart';
import 'gasto_programado.dart';


class ResumenCartera {
  final double totalPorCobrar;
  final double totalPorPagar;
  final double gastosProgramadosMes;
  final double flujoNetoEstimado;
  final int cuentasVencidas;
  final int proveedoresDescuentoRiesgo;
  final DateTime fechaGeneracion;
  final List<CuentaPorCobrar>? cuentasProximasVencer;
  final List<CuentaPorPagar>? proveedoresConDescuento;
  final List<GastoProgramado>? gastosProximosPagar;

  ResumenCartera({
    required this.totalPorCobrar,
    required this.totalPorPagar,
    required this.gastosProgramadosMes,
    required this.flujoNetoEstimado,
    required this.cuentasVencidas,
    required this.proveedoresDescuentoRiesgo,
    required this.fechaGeneracion,
    this.cuentasProximasVencer,
    this.proveedoresConDescuento,
    this.gastosProximosPagar,
  });

  factory ResumenCartera.fromJson(Map<String, dynamic> json) {
    return ResumenCartera(
      totalPorCobrar: (json['total_por_cobrar'] ?? 0).toDouble(),
      totalPorPagar: (json['total_por_pagar'] ?? 0).toDouble(),
      gastosProgramadosMes: (json['gastos_programados_mes'] ?? 0).toDouble(),
      flujoNetoEstimado: (json['flujo_neto_estimado'] ?? 0).toDouble(),
      cuentasVencidas: json['cuentas_vencidas'] ?? 0,
      proveedoresDescuentoRiesgo: json['proveedores_descuento_riesgo'] ?? 0,
      fechaGeneracion: json['fecha_generacion'] != null 
          ? DateTime.parse(json['fecha_generacion'])
          : DateTime.now(),
      cuentasProximasVencer: json['cuentas_proximas_vencer'] != null
          ? (json['cuentas_proximas_vencer'] as List)
              .map((item) => CuentaPorCobrar.fromJson(item))
              .toList()
          : null,
      proveedoresConDescuento: json['proveedores_con_descuento'] != null
          ? (json['proveedores_con_descuento'] as List)
              .map((item) => CuentaPorPagar.fromJson(item))
              .toList()
          : null,
      gastosProximosPagar: json['gastos_proximos_pagar'] != null
          ? (json['gastos_proximos_pagar'] as List)
              .map((item) => GastoProgramado.fromJson(item))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_por_cobrar': totalPorCobrar,
      'total_por_pagar': totalPorPagar,
      'gastos_programados_mes': gastosProgramadosMes,
      'flujo_neto_estimado': flujoNetoEstimado,
      'cuentas_vencidas': cuentasVencidas,
      'proveedores_descuento_riesgo': proveedoresDescuentoRiesgo,
      'fecha_generacion': fechaGeneracion.toIso8601String(),
      if (cuentasProximasVencer != null)
        'cuentas_proximas_vencer': cuentasProximasVencer!.map((e) => e.toJson()).toList(),
      if (proveedoresConDescuento != null)
        'proveedores_con_descuento': proveedoresConDescuento!.map((e) => e.toJson()).toList(),
      if (gastosProximosPagar != null)
        'gastos_proximos_pagar': gastosProximosPagar!.map((e) => e.toJson()).toList(),
    };
  }

  bool get flujoPositivo => flujoNetoEstimado >= 0;
  bool get tieneAlertas => cuentasVencidas > 0 || proveedoresDescuentoRiesgo > 0;
  double get liquidezEstimada => totalPorCobrar - totalPorPagar - gastosProgramadosMes;
}
