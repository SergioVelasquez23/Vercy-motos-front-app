import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/cuenta_por_cobrar.dart';
import '../models/cuenta_por_pagar.dart';
import '../models/gasto_programado.dart';
import '../models/resumen_cartera.dart';
import '../models/api_response.dart';
import 'base_api_service.dart';

/// Servicio para gestión de cartera (cuentas por cobrar, por pagar y gastos programados)
class CarteraService {
  static final CarteraService _instance = CarteraService._internal();
  factory CarteraService() => _instance;
  CarteraService._internal();

  final BaseApiService _baseApiService = BaseApiService();

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
            body: json.encode(cuenta.toJson()),
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
      };

      final http.Response response = await _baseApiService.httpClient
          .post(Uri.parse(url), headers: headers, body: json.encode(body))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
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
        '$_baseEndpoint/alertas/verificar',
      );
      final Map<String, String> headers = await _baseApiService.getHeaders();

      final http.Response response = await _baseApiService.httpClient
          .post(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ApiResponse<String>(
          success: true,
          data: 'Alertas verificadas exitosamente',
          message: 'Las alertas han sido procesadas correctamente',
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
}
