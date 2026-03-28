import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/cuenta_por_cobrar.dart';
import '../models/cuenta_por_pagar.dart';
import '../models/gasto_programado.dart';
import '../models/resumen_cartera.dart';
import '../models/api_response.dart';
import 'base_api_service.dart';
import 'alertas_service.dart';
import '../utils/logger.dart';

/// Servicio para gestión de cartera (cuentas por cobrar, por pagar y gastos programados)
class CarteraService {
  static final CarteraService _instance = CarteraService._internal();
  factory CarteraService() => _instance;
  CarteraService._internal();

  final BaseApiService _baseApiService = BaseApiService();
  final AlertasService _alertasService = AlertasService();

  static const String _baseEndpoint = '/cartera';

  /// Obtiene todas las cuentas por cobrar
  Future<ApiResponse<List<CuentaPorCobrar>>> getCuentasPorCobrar() async {
    try {
      final String url = _baseApiService.buildUrl(
        '$_baseEndpoint/cuentas-por-cobrar',
      );
      final Map<String, String> headers = await _baseApiService.getHeaders();

      final http.Response response = await _baseApiService.httpClient
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final List<CuentaPorCobrar> cuentas = data
            .map((json) => CuentaPorCobrar.fromJson(json))
            .toList();
        return ApiResponse<List<CuentaPorCobrar>>(
          success: true,
          data: cuentas,
          message: 'Cuentas por cobrar obtenidas exitosamente',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      return ApiResponse<List<CuentaPorCobrar>>(
        success: false,
        data: null,
        message: 'Error ${response.statusCode}: ${response.body}',
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<List<CuentaPorCobrar>>(
        success: false,
        data: null,
        message: 'Error de conectividad: $e',
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Obtiene cuentas por cobrar por estado
  Future<ApiResponse<List<CuentaPorCobrar>>> getCuentasPorEstado(
    EstadoCuenta estado,
  ) async {
    try {
      final String estadoStr = estado.toString().split('.').last;
      final String url = _baseApiService.buildUrl(
        '$_baseEndpoint/cuentas-por-cobrar/estado/$estadoStr',
      );
      final Map<String, String> headers = await _baseApiService.getHeaders();

      final http.Response response = await _baseApiService.httpClient
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final List<CuentaPorCobrar> cuentas = data
            .map((json) => CuentaPorCobrar.fromJson(json))
            .toList();
        return ApiResponse<List<CuentaPorCobrar>>(
          success: true,
          data: cuentas,
          message: 'Cuentas filtradas por estado obtenidas exitosamente',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      return ApiResponse<List<CuentaPorCobrar>>(
        success: false,
        data: null,
        message: 'Error ${response.statusCode}: ${response.body}',
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<List<CuentaPorCobrar>>(
        success: false,
        data: null,
        message: 'Error de conectividad: $e',
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Obtiene cuentas por cobrar vencidas
  Future<ApiResponse<List<CuentaPorCobrar>>> getCuentasVencidas() async {
    try {
      final String url = _baseApiService.buildUrl(
        '$_baseEndpoint/cuentas-por-cobrar/vencidas',
      );
      final Map<String, String> headers = await _baseApiService.getHeaders();

      final http.Response response = await _baseApiService.httpClient
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final List<CuentaPorCobrar> cuentas = data
            .map((json) => CuentaPorCobrar.fromJson(json))
            .toList();
        return ApiResponse<List<CuentaPorCobrar>>(
          success: true,
          data: cuentas,
          message: 'Cuentas vencidas obtenidas exitosamente',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      return ApiResponse<List<CuentaPorCobrar>>(
        success: false,
        data: null,
        message: 'Error ${response.statusCode}: ${response.body}',
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<List<CuentaPorCobrar>>(
        success: false,
        data: null,
        message: 'Error de conectividad: $e',
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Registra un abono a una cuenta por cobrar
  Future<ApiResponse<String>> registrarAbonoCuentaPorCobrar({
    required String cuentaId,
    required double montoAbono,
    required String observaciones,
  }) async {
    try {
      final String url = _baseApiService.buildUrl(
        '$_baseEndpoint/cuentas-por-cobrar/$cuentaId/abono',
      );
      final Map<String, String> headers = await _baseApiService.getHeaders();

      final Map<String, dynamic> body = {
        'monto_abono': montoAbono,
        'observaciones': observaciones,
        'fecha_abono': DateTime.now().toIso8601String(),
      };

      final http.Response response = await _baseApiService.httpClient
          .post(Uri.parse(url), headers: headers, body: json.encode(body))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse<String>(
          success: true,
          data: 'Abono registrado exitosamente',
          message: 'El abono ha sido registrado correctamente',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      return ApiResponse<String>(
        success: false,
        data: null,
        message: 'Error ${response.statusCode}: ${response.body}',
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<String>(
        success: false,
        data: null,
        message: 'Error de conectividad: $e',
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Obtiene todas las cuentas por pagar
  Future<ApiResponse<List<CuentaPorPagar>>> getCuentasPorPagar() async {
    try {
      final String url = _baseApiService.buildUrl(
        '$_baseEndpoint/cuentas-por-pagar',
      );
      final Map<String, String> headers = await _baseApiService.getHeaders();

      final http.Response response = await _baseApiService.httpClient
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final List<CuentaPorPagar> cuentas = data
            .map((json) => CuentaPorPagar.fromJson(json))
            .toList();
        return ApiResponse<List<CuentaPorPagar>>(
          success: true,
          data: cuentas,
          message: 'Cuentas por pagar obtenidas exitosamente',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      return ApiResponse<List<CuentaPorPagar>>(
        success: false,
        data: null,
        message: 'Error ${response.statusCode}: ${response.body}',
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<List<CuentaPorPagar>>(
        success: false,
        data: null,
        message: 'Error de conectividad: $e',
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Crea una nueva cuenta por pagar
  Future<ApiResponse<CuentaPorPagar>> crearCuentaPorPagar(
    CuentaPorPagar cuenta,
  ) async {
    try {
      final String url = _baseApiService.buildUrl(
        '$_baseEndpoint/cuentas-por-pagar',
      );
      final Map<String, String> headers = await _baseApiService.getHeaders();

      final http.Response response = await _baseApiService.httpClient
          .post(
            Uri.parse(url),
            headers: headers,
            body: json.encode(cuenta.toCreateJson()),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        final CuentaPorPagar nuevaCuenta = CuentaPorPagar.fromJson(data);
        return ApiResponse<CuentaPorPagar>(
          success: true,
          data: nuevaCuenta,
          message: 'Cuenta por pagar creada exitosamente',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      return ApiResponse<CuentaPorPagar>(
        success: false,
        data: null,
        message: 'Error ${response.statusCode}: ${response.body}',
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<CuentaPorPagar>(
        success: false,
        data: null,
        message: 'Error de conectividad: $e',
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Registra un pago a una cuenta por pagar
  Future<ApiResponse<String>> registrarPagoCuentaPorPagar({
    required String cuentaId,
    required double montoPago,
    required String observaciones,
    String? numeroFactura,
    String? proveedorNombre,
  }) async {
    try {
      // Endpoint explícito sin variables para mayor claridad
      final String endpoint = '/cartera/cuentas-por-pagar/$cuentaId/pago';
      final String url = _baseApiService.buildUrl(endpoint);

      appLog('\n💰 [SERVICIO] registrarPagoCuentaPorPagar()');
      appLog('📤 Enviando request al backend:');
      appLog('   🌐 URL: $url');
      appLog('   🆔 cuentaId: $cuentaId');
      appLog('   💵 montoPago: $montoPago');
      appLog('   📝 observaciones: $observaciones');
      appLog('   🏢 proveedor (si se pasó): $proveedorNombre');
      appLog('   📄 numeroFactura (si se pasó): $numeroFactura');

      final Map<String, String> headers = await _baseApiService.getHeaders();

      final Map<String, dynamic> body = {
        'monto_pago': montoPago,
        'observaciones': observaciones,
        'fecha_pago': DateTime.now().toIso8601String(),
      };

      appLog('   📦 Body JSON: ${json.encode(body)}');

      final http.Response response = await _baseApiService.httpClient
          .post(Uri.parse(url), headers: headers, body: json.encode(body))
          .timeout(const Duration(seconds: 30));

      appLog('\n📥 [SERVICIO] Respuesta del backend:');
      appLog('   ✅ Status Code: ${response.statusCode}');
      appLog('   📄 Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          appLog(
            '\n🔍 [AUTO-ALERTA] Analizando respuesta para enviar alerta automática...',
          );

          // Parsear respuesta del backend para obtener datos de la cuenta
          final Map<String, dynamic> responseData = json.decode(response.body);
          final Map<String, dynamic>? cuenta =
              responseData['cuenta'] as Map<String, dynamic>?;

          if (cuenta != null) {
            appLog('📊 [AUTO-ALERTA] Datos de la cuenta en respuesta:');
            appLog('   ${json.encode(cuenta)}');

            final String? facturaBackend = cuenta['numeroFactura'] as String?;
            final String? proveedorBackend =
                cuenta['proveedorNombre'] as String?;
            final String? proveedorIdBackend = cuenta['proveedorId'] as String?;
            final double? saldoPendienteBackend =
                (cuenta['saldoPendiente'] as num?)?.toDouble();

            // Usar datos pasados por parámetro o extraer del backend
            final String numFactura = numeroFactura ?? facturaBackend ?? 'S/N';
            final String? nomProveedor = proveedorNombre ?? proveedorBackend;
            final double montoTotal =
                (cuenta['montoTotal'] as num?)?.toDouble() ?? montoPago;
            final double saldoPendiente = saldoPendienteBackend ?? 0.0;

            // Determinar si es abono parcial o pago completo
            final bool esPagoCompleto = saldoPendiente <= 0;

            // Solo enviar alerta si hay un proveedor válido
            if (nomProveedor != null &&
                nomProveedor.isNotEmpty &&
                numFactura != 'S/N' &&
                (proveedorIdBackend != null && proveedorIdBackend.isNotEmpty)) {
              
              if (esPagoCompleto) {
                // Enviar alerta de cuenta pagada completamente
                appLog(
                  '📤 [AUTO-ALERTA] Enviando alerta de cuenta PAGADA COMPLETAMENTE:',
                );
                appLog('   🏢 Proveedor: $nomProveedor');
                appLog('   📄 Número Factura: $numFactura');
                appLog('   💰 Monto Total: $montoTotal');
                appLog('   🆔 Proveedor ID: $proveedorIdBackend');

                _alertasService.enviarAlertaCuentaPagada(
                  proveedor: nomProveedor,
                  numeroFactura: numFactura,
                  montoTotal: montoTotal,
                  cuentaId: cuentaId,
                );
              } else {
                // Enviar alerta de abono parcial
                appLog('📤 [AUTO-ALERTA] Enviando alerta de ABONO PARCIAL:');
                appLog('   🏢 Proveedor: $nomProveedor');
                appLog('   📄 Número Factura: $numFactura');
                appLog('   💵 Monto Abono: $montoPago');
                appLog('   💰 Saldo Pendiente: $saldoPendiente');
                appLog('   🆔 Proveedor ID: $proveedorIdBackend');

                _alertasService.enviarAlertaAbonoRealizado(
                  proveedor: nomProveedor,
                  numeroFactura: numFactura,
                  montoAbono: montoPago,
                  saldoPendiente: saldoPendiente,
                );
              }
            } else {
              appLog('⚠️ [AUTO-ALERTA] Datos incompletos para enviar alerta:');
              appLog('   - Proveedor: ${nomProveedor ?? "NULL"}');
              appLog('   - Número Factura: $numFactura');
              appLog('   - Proveedor ID: ${proveedorIdBackend ?? "NULL"}');
              appLog(
                '   ℹ️  La cuenta debe tener un proveedor válido para enviar alertas\n',
              );
            }
          } else {
            appLog(
              '⚠️ [AUTO-ALERTA] No hay datos de cuenta en la respuesta, no se envía alerta\n',
            );
          }
        } catch (e) {
          appLog('❌ [AUTO-ALERTA] Error al procesar/enviar alerta: $e\n');
        }
        
        return ApiResponse<String>(
          success: true,
          data: 'Pago registrado exitosamente',
          message: 'El pago ha sido registrado correctamente',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      return ApiResponse<String>(
        success: false,
        data: null,
        message: 'Error ${response.statusCode}: ${response.body}',
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      appLog('❌ Error registrando pago: $e');
      return ApiResponse<String>(
        success: false,
        data: null,
        message: 'Error de conectividad: $e',
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Obtiene todos los gastos programados
  Future<ApiResponse<List<GastoProgramado>>> getGastosProgramados() async {
    try {
      final String url = _baseApiService.buildUrl(
        '$_baseEndpoint/gastos-programados',
      );
      final Map<String, String> headers = await _baseApiService.getHeaders();

      final http.Response response = await _baseApiService.httpClient
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final List<GastoProgramado> gastos = data
            .map((json) => GastoProgramado.fromJson(json))
            .toList();
        return ApiResponse<List<GastoProgramado>>(
          success: true,
          data: gastos,
          message: 'Gastos programados obtenidos exitosamente',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      return ApiResponse<List<GastoProgramado>>(
        success: false,
        data: null,
        message: 'Error ${response.statusCode}: ${response.body}',
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<List<GastoProgramado>>(
        success: false,
        data: null,
        message: 'Error de conectividad: $e',
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Crea un nuevo gasto programado
  Future<ApiResponse<GastoProgramado>> crearGastoProgramado(
    GastoProgramado gasto,
  ) async {
    try {
      final String url = _baseApiService.buildUrl(
        '$_baseEndpoint/gastos-programados',
      );
      final Map<String, String> headers = await _baseApiService.getHeaders();

      final http.Response response = await _baseApiService.httpClient
          .post(
            Uri.parse(url),
            headers: headers,
            body: json.encode(gasto.toJson()),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        final GastoProgramado nuevoGasto = GastoProgramado.fromJson(data);
        return ApiResponse<GastoProgramado>(
          success: true,
          data: nuevoGasto,
          message: 'Gasto programado creado exitosamente',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      return ApiResponse<GastoProgramado>(
        success: false,
        data: null,
        message: 'Error ${response.statusCode}: ${response.body}',
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<GastoProgramado>(
        success: false,
        data: null,
        message: 'Error de conectividad: $e',
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Marca un gasto programado como pagado
  Future<ApiResponse<String>> marcarGastoComoPagado(
    String gastoId,
    double montoReal,
  ) async {
    try {
      final String url = _baseApiService.buildUrl(
        '$_baseEndpoint/gastos-programados/$gastoId/pagar',
      );
      final Map<String, String> headers = await _baseApiService.getHeaders();

      final Map<String, dynamic> body = {
        'fecha_pago': DateTime.now().toIso8601String(),
        'monto_real': montoReal,
      };

      final http.Response response = await _baseApiService.httpClient
          .post(Uri.parse(url), headers: headers, body: json.encode(body))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse<String>(
          success: true,
          data: 'Gasto marcado como pagado',
          message: 'El gasto ha sido marcado como pagado exitosamente',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      return ApiResponse<String>(
        success: false,
        data: null,
        message: 'Error ${response.statusCode}: ${response.body}',
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<String>(
        success: false,
        data: null,
        message: 'Error de conectividad: $e',
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Obtiene el resumen general de la cartera
  Future<ApiResponse<ResumenCartera>> getResumenCartera() async {
    try {
      final String url = _baseApiService.buildUrl('$_baseEndpoint/resumen');
      final Map<String, String> headers = await _baseApiService.getHeaders();

      final http.Response response = await _baseApiService.httpClient
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final ResumenCartera resumen = ResumenCartera.fromJson(data);
        return ApiResponse<ResumenCartera>(
          success: true,
          data: resumen,
          message: 'Resumen de cartera obtenido exitosamente',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      return ApiResponse<ResumenCartera>(
        success: false,
        data: null,
        message: 'Error ${response.statusCode}: ${response.body}',
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<ResumenCartera>(
        success: false,
        data: null,
        message: 'Error de conectividad: $e',
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Verifica alertas pendientes y las procesa
  Future<ApiResponse<String>> verificarAlertas() async {
    try {
      final String url = _baseApiService.buildUrl(
        '$_baseEndpoint/verificar-alertas',
      );
      
      appLog('\n🔔 [ALERTAS] Verificando todas las alertas del sistema...');
      appLog('🌐 URL: $url');
      
      final Map<String, String> headers = await _baseApiService.getHeaders();

      final http.Response response = await _baseApiService.httpClient
          .post(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 30));

      appLog('📨 Response status: ${response.statusCode}');
      appLog('📦 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        appLog('✅ [ALERTAS] Verificación completada exitosamente\n');
        return ApiResponse<String>(
          success: true,
          data: 'Alertas verificadas exitosamente',
          message: 'Las alertas han sido procesadas correctamente',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      appLog('❌ [ALERTAS] Error en verificación\n');
      return ApiResponse<String>(
        success: false,
        data: null,
        message: 'Error ${response.statusCode}: ${response.body}',
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      appLog('💥 [ALERTAS] Excepción en verificarAlertas: $e\n');
      return ApiResponse<String>(
        success: false,
        data: null,
        message: 'Error de conectividad: $e',
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  // ============================================================
  // === CUENTAS POR PAGAR RECURRENTES ===
  // ============================================================

  /// Registra un pago en una cuenta recurrente.
  /// NO elimina la cuenta; actualiza ultimoPago, totalPagosRealizados,
  /// y calcula el próximo vencimiento.
  Future<ApiResponse<String>> registrarPagoRecurrente({
    required String cuentaId,
    required double montoPago,
    required String observaciones,
  }) async {
    try {
      final String url = _baseApiService.buildUrl(
        '$_baseEndpoint/cuentas-por-pagar/$cuentaId/pago',
      );
      final Map<String, String> headers = await _baseApiService.getHeaders();

      final Map<String, dynamic> body = {
        'monto_pago': montoPago,
        'observaciones': observaciones,
        'fecha_pago': DateTime.now().toIso8601String(),
        'es_pago_recurrente': true,
      };

      final http.Response response = await _baseApiService.httpClient
          .post(Uri.parse(url), headers: headers, body: json.encode(body))
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Enviar alerta de pago registrado por Telegram
        _enviarAlertaPagoCxP(montoPago, observaciones);
        return ApiResponse<String>(
          success: true,
          data: 'Pago registrado exitosamente',
          message:
              'Pago registrado. La cuenta se renovará para el próximo periodo.',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      return ApiResponse<String>(
        success: false,
        data: null,
        message: 'Error ${response.statusCode}: ${response.body}',
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<String>(
        success: false,
        data: null,
        message: 'Error de conectividad: $e',
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Actualiza una cuenta por pagar existente
  Future<ApiResponse<CuentaPorPagar>> actualizarCuentaPorPagar(
    String cuentaId,
    CuentaPorPagar cuenta,
  ) async {
    try {
      final String url = _baseApiService.buildUrl(
        '$_baseEndpoint/cuentas-por-pagar/$cuentaId',
      );
      final Map<String, String> headers = await _baseApiService.getHeaders();

      final http.Response response = await _baseApiService.httpClient
          .put(
            Uri.parse(url),
            headers: headers,
            body: json.encode(cuenta.toJson()),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final CuentaPorPagar cuentaActualizada = CuentaPorPagar.fromJson(data);
        return ApiResponse<CuentaPorPagar>(
          success: true,
          data: cuentaActualizada,
          message: 'Cuenta por pagar actualizada exitosamente',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      return ApiResponse<CuentaPorPagar>(
        success: false,
        data: null,
        message: 'Error ${response.statusCode}: ${response.body}',
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<CuentaPorPagar>(
        success: false,
        data: null,
        message: 'Error de conectividad: $e',
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Desactiva una cuenta recurrente (no la elimina)
  Future<ApiResponse<String>> desactivarCuentaPorPagar(String cuentaId) async {
    try {
      final String url = _baseApiService.buildUrl(
        '$_baseEndpoint/cuentas-por-pagar/$cuentaId/desactivar',
      );
      final Map<String, String> headers = await _baseApiService.getHeaders();

      final http.Response response = await _baseApiService.httpClient
          .put(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return ApiResponse<String>(
          success: true,
          data: 'Cuenta desactivada',
          message: 'La cuenta ha sido desactivada (no eliminada)',
          timestamp: DateTime.now().toIso8601String(),
        );
      }

      return ApiResponse<String>(
        success: false,
        data: null,
        message: 'Error ${response.statusCode}: ${response.body}',
        timestamp: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      return ApiResponse<String>(
        success: false,
        data: null,
        message: 'Error de conectividad: $e',
        timestamp: DateTime.now().toIso8601String(),
      );
    }
  }

  // ============================================================
  // === ALERTAS TELEGRAM PARA CUENTAS POR PAGAR ===
  // ============================================================

  /// Revisa todas las CxP y envía alertas Telegram por las próximas a vencer
  Future<void> verificarAlertasCxP() async {
    try {
      final response = await getCuentasPorPagar();
      if (!response.isSuccess || response.data == null) return;

      for (final cuenta in response.data!) {
        if (!cuenta.activa) continue;

        // ⛔ ALERTAS AUTOMÁTICAS DE TELEGRAM DESHABILITADAS
        // // Alerta: próxima a vencer (5 días o menos)
        // if (cuenta.requiereAtencionPronto && !cuenta.alertaEnviada) {
        //   await enviarAlertaCxPProximaVencer(cuenta);
        // }

        // // Alerta: vencida sin pagar
        // if (cuenta.estaVencidaSinPagar) {
        //   await enviarAlertaCxPVencida(cuenta);
        // }

        // // Alerta: descuento próximo a perderse
        // if (cuenta.proximoAPerderDescuento) {
        //   await enviarAlertaCxPDescuentoRiesgo(cuenta);
        // }
      }
    } catch (e) {
      appLog('Error verificando alertas CxP: $e');
    }
  }

  /// Envía alerta Telegram cuando una CxP está próxima a vencer
  Future<void> enviarAlertaCxPProximaVencer(CuentaPorPagar cuenta) async {
    try {
      appLog('\n🔔 [SERVICIO] enviarAlertaCxPProximaVencer()');
      appLog('📦 Validando datos de la cuenta:');
      appLog('   📄 numeroFactura: ${cuenta.numeroFactura}');
      appLog('   💰 monto: ${cuenta.montoTotal}');
      appLog('   📅 diasRestantes: ${cuenta.diasRestantes}');
      appLog('   🆔 cuentaId: ${cuenta.id}');
      appLog('   🏢 proveedor: ${cuenta.proveedorNombre}');
      appLog('   🆔 proveedorId: ${cuenta.proveedorId}');

      // Validar que tenga proveedor válido
      if (cuenta.proveedorNombre == null ||
          cuenta.proveedorNombre.isEmpty ||
          (cuenta.proveedorId?.isEmpty ?? true)) {
        appLog(
          '⚠️ [SERVICIO] Cuenta sin proveedor válido, no se envía alerta\n',
        );
        return;
      }

      // ⛔ ALERTAS DE TELEGRAM DESHABILITADAS
      // await _alertasService.enviarAlertaCxPProximaVencer(
      //   numeroFactura: cuenta.numeroFactura,
      //   monto: cuenta.montoTotal,
      //   diasRestantes: cuenta.diasRestantes,
      //   cuentaId: cuenta.id,
      // );

      appLog('ℹ️ [SERVICIO] Alertas deshabilitadas\n');
    } catch (e) {
      appLog('❌ [SERVICIO] Error al enviar alerta próxima vencer: $e\n');
    }
  }

  /// Envía alerta Telegram cuando una CxP está vencida
  Future<void> enviarAlertaCxPVencida(CuentaPorPagar cuenta) async {
    try {
      appLog('\n🚨 [SERVICIO] enviarAlertaCxPVencida()');
      appLog('📦 Validando datos de la cuenta:');
      appLog('   📄 numeroFactura: ${cuenta.numeroFactura}');
      appLog('   💸 montoVencido: ${cuenta.saldoPendiente}');
      appLog('   ⏰ diasVencida: ${cuenta.diasRestantes.abs()}');
      appLog('   🆔 cuentaId: ${cuenta.id}');
      appLog('   🏢 proveedor: ${cuenta.proveedorNombre}');
      appLog('   🆔 proveedorId: ${cuenta.proveedorId}');

      // Validar que tenga proveedor válido
      if (cuenta.proveedorNombre == null ||
          cuenta.proveedorNombre.isEmpty ||
          (cuenta.proveedorId?.isEmpty ?? true)) {
        appLog(
          '⚠️ [SERVICIO] Cuenta sin proveedor válido, no se envía alerta\n',
        );
        return;
      }

      // ⛔ ALERTAS DE TELEGRAM DESHABILITADAS
      // await _alertasService.enviarAlertaCxPVencida(
      //   numeroFactura: cuenta.numeroFactura,
      //   montoVencido: cuenta.saldoPendiente,
      //   diasVencida: cuenta.diasRestantes.abs(),
      //   cuentaId: cuenta.id,
      // );

      appLog('ℹ️ [SERVICIO] Alertas deshabilitadas\n');
    } catch (e) {
      appLog('❌ [SERVICIO] Error al enviar alerta vencida: $e\n');
    }
  }

  /// Envía alerta Telegram cuando un descuento está próximo a perderse
  Future<void> enviarAlertaCxPDescuentoRiesgo(CuentaPorPagar cuenta) async {
    try {
      appLog('\n💸 [SERVICIO] enviarAlertaCxPDescuentoRiesgo()');
      appLog('📦 Validando datos de la cuenta:');
      appLog('   📄 numeroFactura: ${cuenta.numeroFactura}');
      appLog('   💰 montoSinDescuento: ${cuenta.montoTotal}');
      appLog('   🎁 montoConDescuento: ${cuenta.montoConDescuento}');
      appLog('   💵 ahorro: ${cuenta.montoDescuento}');
      appLog('   ⏳ diasRestantes: ${cuenta.diasParaPerderDescuento}');
      appLog('   🆔 cuentaId: ${cuenta.id}');
      appLog('   🏢 proveedor: ${cuenta.proveedorNombre}');
      appLog('   🆔 proveedorId: ${cuenta.proveedorId}');

      // Validar que tenga proveedor válido
      if (cuenta.proveedorNombre == null ||
          cuenta.proveedorNombre.isEmpty ||
          (cuenta.proveedorId?.isEmpty ?? true)) {
        appLog(
          '⚠️ [SERVICIO] Cuenta sin proveedor válido, no se envía alerta\n',
        );
        return;
      }

      // ⛔ ALERTAS DE TELEGRAM DESHABILITADAS
      // await _alertasService.enviarAlertaDescuentoProximoVencer(
      //   numeroFactura: cuenta.numeroFactura,
      //   montoSinDescuento: cuenta.montoTotal,
      //   montoConDescuento: cuenta.montoConDescuento,
      //   ahorro: cuenta.montoDescuento,
      //   diasRestantes: cuenta.diasParaPerderDescuento,
      //   cuentaId: cuenta.id,
      // );

      appLog('ℹ️ [SERVICIO] Alertas deshabilitadas\n');
    } catch (e) {
      appLog('❌ [SERVICIO] Error al enviar alerta descuento riesgo: $e\n');
    }
  }

  /// Envía alerta Telegram en segundo plano al registrar un pago
  void _enviarAlertaPagoCxP(double monto, String observaciones) {
    Future.microtask(() async {
      try {
        // Este método se puede usar cuando tenemos los detalles de la cuenta
        // Por ahora es un placeholder, necesitarías pasar más datos
        // await _alertasService.enviarAlertaAbonoRealizado(
        //   proveedor: '',
        //   numeroFactura: '',
        //   montoAbono: monto,
        //   saldoPendiente: 0,
        // );
      } catch (_) {}
    });
  }
}
