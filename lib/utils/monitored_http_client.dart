import 'dart:convert';
import 'package:http/http.dart' as http;
import './request_monitor.dart';

class MonitoredHttpClient {
  static final MonitoredHttpClient _instance = MonitoredHttpClient._internal();
  factory MonitoredHttpClient() => _instance;
  MonitoredHttpClient._internal();

  final RequestMonitor _monitor = RequestMonitor();
  final http.Client _client = http.Client();

  // GET con monitoreo
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    await _monitor.logRequest(url.toString(), 'GET');
    return await _client.get(url, headers: headers);
  }

  // POST con monitoreo
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    await _monitor.logRequest(url.toString(), 'POST');
    return await _client.post(
      url,
      headers: headers,
      body: body,
      encoding: encoding,
    );
  }

  // PUT con monitoreo
  Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    await _monitor.logRequest(url.toString(), 'PUT');
    return await _client.put(
      url,
      headers: headers,
      body: body,
      encoding: encoding,
    );
  }

  // DELETE con monitoreo
  Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    await _monitor.logRequest(url.toString(), 'DELETE');
    return await _client.delete(
      url,
      headers: headers,
      body: body,
      encoding: encoding,
    );
  }

  // Obtener estadísticas
  RequestStats getStats() => _monitor.getStats();

  // Cerrar cliente
  void close() => _client.close();
}
