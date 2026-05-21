import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/cuenta_por_cobrar.dart';
import '../models/cuenta_por_pagar.dart';
import '../models/gasto_programado.dart';
import '../models/resumen_cartera.dart';
import '../services/cartera_service.dart';

enum TipoNotificacion {
  cuentaVencida,
  cuentaProximaVencer,
  gastoProgramadoProximo,
  descuentoEnRiesgo,
}

class NotificacionItem {
  final String id;
  final TipoNotificacion tipo;
  final String titulo;
  final String descripcion;
  final String ruta;
  final dynamic origen;

  const NotificacionItem({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.descripcion,
    required this.ruta,
    this.origen,
  });
}

class NotificacionesProvider extends ChangeNotifier {
  NotificacionesProvider({CarteraService? carteraService})
    : _carteraService = carteraService ?? CarteraService();

  final CarteraService _carteraService;

  ResumenCartera? _resumen;
  bool _isLoading = false;
  String? _error;
  DateTime? _lastRefresh;
  Timer? _autoRefreshTimer;

  ResumenCartera? get resumen => _resumen;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastRefresh => _lastRefresh;

  List<NotificacionItem> get items {
    final List<NotificacionItem> result = [];
    final resumen = _resumen;
    if (resumen == null) return result;

    for (final cuenta in resumen.cuentasProximasVencer ?? <CuentaPorCobrar>[]) {
      final bool vencida = cuenta.estaVencida;
      result.add(
        NotificacionItem(
          id: 'cxc-${cuenta.id ?? cuenta.facturaId}',
          tipo: vencida
              ? TipoNotificacion.cuentaVencida
              : TipoNotificacion.cuentaProximaVencer,
          titulo: vencida
              ? 'Cuenta vencida'
              : 'Cuenta por cobrar próxima a vencer',
          descripcion:
              '${cuenta.clienteNombre} · \$${cuenta.saldoPendiente.toStringAsFixed(0)}',
          ruta: vencida ? '/cuentas-por-cobrar' : '/cuentas-por-cobrar',
          origen: cuenta,
        ),
      );
    }

    for (final cuenta in resumen.proveedoresConDescuento ?? <CuentaPorPagar>[]) {
      result.add(
        NotificacionItem(
          id: 'cxp-desc-${cuenta.id ?? cuenta.numeroFactura}',
          tipo: TipoNotificacion.descuentoEnRiesgo,
          titulo: 'Descuento próximo a perderse',
          descripcion:
              '${cuenta.proveedorNombre} · ahorro \$${cuenta.montoDescuento.toStringAsFixed(0)}',
          ruta: '/cuentas-por-pagar',
          origen: cuenta,
        ),
      );
    }

    for (final gasto in resumen.gastosProximosPagar ?? <GastoProgramado>[]) {
      result.add(
        NotificacionItem(
          id: 'gp-${gasto.id ?? gasto.nombre}',
          tipo: TipoNotificacion.gastoProgramadoProximo,
          titulo: 'Gasto programado próximo',
          descripcion:
              '${gasto.nombre} · \$${gasto.montoEstimado.toStringAsFixed(0)}',
          ruta: '/gastos-programados',
          origen: gasto,
        ),
      );
    }

    return result;
  }

  int get totalNotificaciones => items.length;

  bool get tieneNotificaciones => totalNotificaciones > 0;

  Future<void> refresh() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    final response = await _carteraService.getResumenCartera();
    if (response.isSuccess && response.data != null) {
      _resumen = response.data;
    } else {
      _error = response.message;
    }
    _lastRefresh = DateTime.now();
    _isLoading = false;
    notifyListeners();
  }

  void startAutoRefresh({Duration interval = const Duration(minutes: 5)}) {
    stopAutoRefresh();
    _autoRefreshTimer = Timer.periodic(interval, (_) => refresh());
  }

  void stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
  }
}
