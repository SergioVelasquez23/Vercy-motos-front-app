import '../config/constants.dart';
import '../utils/logger.dart';
import 'caja_websocket_service.dart';
import 'gasto_service.dart';

/// Conecta el canal /rt/caja (ver CajaWebSocketHandler en el backend) y, al
/// recibir un evento GASTO_*, invalida el caché de gastos del cuadre
/// afectado (GastoService.invalidarCacheCuadre) — así la próxima vez que
/// cualquier pantalla pida esos gastos (en este dispositivo o en otro), ve
/// el cambio al instante en vez de esperar hasta 2 minutos de TTL.
///
/// Singleton, igual que DatosCacheProvider con TrasladoWebSocketService:
/// una sola conexión para toda la app, arrancada desde AppShell (cubre
/// tanto el login normal como recargar el navegador ya en una ruta
/// protegida).
class CajaRealtimeService {
  CajaRealtimeService._internal();
  static final CajaRealtimeService instance = CajaRealtimeService._internal();

  final CajaWebSocketService _wsService = CajaWebSocketService();

  void iniciarEscuchaTiempoReal() {
    _wsService.connect(
      baseUrl: kDynamicBackendUrl,
      onEvent: (data) {
        final cuadreCajaId = data['cuadreCajaId']?.toString();
        if (cuadreCajaId == null || cuadreCajaId.isEmpty) return;

        switch (data['tipo']) {
          case 'GASTO_CREADO':
          case 'GASTO_ACTUALIZADO':
          case 'GASTO_ELIMINADO':
            GastoService.invalidarCacheCuadre(cuadreCajaId);
            appLog('💾 [CajaRealtime] Caché de gastos invalidado para cuadre $cuadreCajaId (${data['tipo']})');
            break;
        }
      },
    );
  }

  void detenerEscuchaTiempoReal() {
    _wsService.disconnect();
  }
}
