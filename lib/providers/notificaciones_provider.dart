import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cuenta_por_cobrar.dart';
import '../models/cuenta_por_pagar.dart';
import '../models/gasto_programado.dart';
import '../models/resumen_cartera.dart';
import '../models/traslado.dart';
import '../services/cartera_service.dart';
import '../services/traslado_service.dart';
import '../utils/currency_utils.dart';
import '../utils/notification_sound.dart';

enum TipoNotificacion {
  cuentaVencida,
  cuentaProximaVencer,
  gastoProgramadoProximo,
  descuentoEnRiesgo,
  trasladoPendiente,
}

class NotificacionItem {
  final String id;
  final TipoNotificacion tipo;
  final String titulo;
  final String descripcion;
  final String ruta;
  final dynamic origen;
  final List<ItemTraslado>? itemsTraslado;

  const NotificacionItem({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.descripcion,
    required this.ruta,
    this.origen,
    this.itemsTraslado,
  });
}

class NotificacionesProvider extends ChangeNotifier {
  NotificacionesProvider({
    CarteraService? carteraService,
    TrasladoService? trasladoService,
  })  : _carteraService = carteraService ?? CarteraService(),
        _trasladoService = trasladoService ?? TrasladoService();

  static const _prefsKeyDescartados = 'notif_traslados_descartados';
  // Los traslados solo se muestran como notificación mientras sean recientes;
  // pasado este tiempo se asume que el equipo ya los vio en la pantalla de
  // Traslados y dejan de aparecer aquí (evita acumular historial viejo).
  static const _ventanaTraslados = Duration(hours: 48);

  // Solo el equipo de bodega necesita enterarse de los traslados pendientes
  // (son quienes los preparan); al resto de usuarios (asesores, admin, etc.)
  // no se les muestra ni suena esta notificación. Se compara contra email
  // Y nombre de usuario (no todos los JWT traen el claim "email") para que
  // baste con que uno de los dos matchee.
  static const _emailsNotificadosTraslado = {
    'bodegavercy@gmail.com',
    'francia@gmail.com',
    'diegoalek01@gmail.com',
  };
  static const _usuariosNotificadosTraslado = {
    'bodega',
    'francia',
    'diego',
  };

  final CarteraService _carteraService;
  final TrasladoService _trasladoService;

  ResumenCartera? _resumen;
  List<Traslado> _trasladosRecientes = [];
  Set<String> _trasladosDescartados = {};
  bool _isLoading = false;
  String? _error;
  DateTime? _lastRefresh;
  Timer? _autoRefreshTimer;

  // En el primer refresh de la sesión no se alerta de golpe por todo lo que
  // ya estaba pendiente de antes (sería ruido); a partir del segundo, si
  // sigue pendiente, se alerta y se repite en cada ciclo (ver
  // _detectarTrasladosNuevos).
  bool _primerRefresh = true;

  String? _emailUsuarioActual;
  String? _nombreUsuarioActual;

  /// Debe llamarse al iniciar sesión (ver AppShell) para que el proveedor
  /// sepa si el usuario actual debe recibir sonido/alerta de traslados.
  void configurarUsuario({String? email, String? nombre}) {
    _emailUsuarioActual = email?.trim().toLowerCase();
    _nombreUsuarioActual = nombre?.trim().toLowerCase();
    debugPrint(
      '🔔 [NotificacionesProvider] usuario configurado: '
      'email=$_emailUsuarioActual nombre=$_nombreUsuarioActual '
      'puedeVerTraslados=$_puedeVerTraslados',
    );
  }

  bool get _puedeVerTraslados =>
      (_emailUsuarioActual != null &&
          _emailsNotificadosTraslado.contains(_emailUsuarioActual)) ||
      (_nombreUsuarioActual != null &&
          _usuariosNotificadosTraslado.contains(_nombreUsuarioActual));

  ResumenCartera? get resumen => _resumen;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastRefresh => _lastRefresh;

  List<NotificacionItem> get items {
    final List<NotificacionItem> result = [];

    for (final traslado in _puedeVerTraslados ? _trasladosRecientes : const <Traslado>[]) {
      if (traslado.id == null || _trasladosDescartados.contains(traslado.id)) {
        continue;
      }
      result.add(_construirItemTraslado(traslado));
    }

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
              '${cuenta.clienteNombre} · ${CurrencyUtils.format(cuenta.saldoPendiente)}',
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
              '${cuenta.proveedorNombre} · ahorro ${CurrencyUtils.format(cuenta.montoDescuento)}',
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
              '${gasto.nombre} · ${CurrencyUtils.format(gasto.montoEstimado)}',
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

    await _cargarDescartados();

    final response = await _carteraService.getResumenCartera();
    if (response.isSuccess && response.data != null) {
      _resumen = response.data;
    } else {
      _error = response.message;
    }

    try {
      final traslados = await _trasladoService.listarTraslados();
      final limite = DateTime.now().subtract(_ventanaTraslados);
      _trasladosRecientes = traslados.where((t) {
        final esDeBodega = t.tipo == null || t.tipo!.startsWith('BODEGA');
        final esReciente = t.fecha != null && t.fecha!.isAfter(limite);
        // Sin esto, un traslado ya descartado con "Marcar como visto" volvía a
        // entrar aquí en el siguiente refresh (el backend lo sigue devolviendo,
        // "descartar" es solo local) y _detectarTrasladosNuevos() lo veía como
        // pendiente otra vez, haciendo sonar la notificación de nuevo.
        final noDescartado = t.id == null || !_trasladosDescartados.contains(t.id);
        return esDeBodega && esReciente && noDescartado;
      }).toList();

      _detectarTrasladosNuevos();
    } catch (_) {
      // Si falla, simplemente no se muestran notificaciones de traslados
      // en este ciclo; no debe romper el resto del centro de notificaciones.
    }

    _lastRefresh = DateTime.now();
    _isLoading = false;
    notifyListeners();
  }

  /// Solo alerta (sonido) a los usuarios de bodega
  /// ([_emailsNotificadosTraslado]) y, mientras quede al menos un traslado
  /// sin marcar como visto, repite la alerta en cada ciclo de auto-refresh
  /// (no solo la primera vez que aparece) — así no se pasa desapercibida
  /// aunque nadie haya estado mirando la pantalla. Se detiene en cuanto
  /// alguien lo descarta con "Marcar como visto" ([descartarTraslado]).
  ///
  /// En el primer refresh de la sesión (recién abierta la app) NO se avisa
  /// de nada — todo lo que ya estaba pendiente sonaría de golpe, que es
  /// ruido, no una notificación real. A partir del segundo refresh sí repite.
  void _detectarTrasladosNuevos() {
    if (_primerRefresh) {
      _primerRefresh = false;
      return;
    }

    if (!_puedeVerTraslados) return;

    final hayPendientes = _trasladosRecientes.any((t) => t.id != null);
    if (!hayPendientes) return;

    playNotificationSound();
  }

  NotificacionItem _construirItemTraslado(Traslado traslado) {
    final cantidadTotal = traslado.items.fold<int>(0, (sum, i) => sum + i.cantidad);
    return NotificacionItem(
      id: 'traslado-${traslado.id}',
      tipo: TipoNotificacion.trasladoPendiente,
      titulo: 'Nuevo traslado por preparar',
      descripcion:
          '${traslado.asesor ?? 'Un asesor'} solicitó ${traslado.items.length} '
          'producto(s) · $cantidadTotal unidad(es) de bodega',
      ruta: '/traslados',
      origen: traslado,
      itemsTraslado: traslado.items,
    );
  }

  Future<void> _cargarDescartados() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _trasladosDescartados = (prefs.getStringList(_prefsKeyDescartados) ?? []).toSet();
    } catch (_) {
      // Si no hay almacenamiento local disponible, se asume nada descartado.
    }
  }

  Future<void> descartarTraslado(String trasladoId) async {
    _trasladosDescartados.add(trasladoId);
    _trasladosRecientes.removeWhere((t) => t.id == trasladoId);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKeyDescartados, _trasladosDescartados.toList());
    } catch (_) {
      // Ignorar: en el peor caso la notificación reaparecerá en el próximo refresh.
    }
  }

  void startAutoRefresh({Duration interval = const Duration(seconds: 60)}) {
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
