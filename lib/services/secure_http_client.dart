import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config/api_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Cliente HTTP seguro con certificado pinning y otras medidas de seguridad
/// Esta clase ayuda a proteger las comunicaciones incluso cuando se usan direcciones IP
class SecureHttpClient extends http.BaseClient {
  final http.Client _inner;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  SecureHttpClient({bool checkCertificate = true})
    : _inner = _createClient(
        ApiConfig.instance.isDevelopment ? false : checkCertificate,
      );

  static http.Client _createClient(bool checkCertificate) {
    // En web, usamos el cliente http normal
    if (kIsWeb) {
      return http.Client();
    }

    // En móvil, configuramos un cliente seguro
    final httpClient = HttpClient()
      ..connectionTimeout = Duration(seconds: ApiConfig.requestTimeout)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        if (!checkCertificate) return true;

        // Certificate pinning - verificar que el certificado sea uno de confianza
        final fingerprint = _getCertificateFingerprint(cert);
        return ApiConfig.instance.isTrustedCertificate(fingerprint);
      };

    return IOClient(httpClient);
  }

  static String _getCertificateFingerprint(X509Certificate cert) {
    // Convierte el certificado a una huella digital para comparar
    final bytes = utf8.encode(cert.pem);
    final digest = sha256.convert(bytes).bytes;
    final fingerprint = digest
        .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
    return fingerprint;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Añadir headers de seguridad
    request.headers.addAll(ApiConfig.instance.getSecurityHeaders());

    // Añadir cabeceras de autenticación si existe un token
    final token = await _getStoredToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    // Añadir headers anti-replay
    final secureHeaders = ApiConfig.instance.getSecureHeaders(token: token);
    request.headers.addAll(secureHeaders);

    // Convertir la URL a HTTPS si es necesario
    if (ApiConfig.instance.useHttps && !kIsWeb) {
      final secureUrl = ApiConfig.instance.secureUrl(request.url.toString());
      request = _updateRequestUrl(request, secureUrl);
    }

    return _inner.send(request);
  }

  http.BaseRequest _updateRequestUrl(http.BaseRequest request, String newUrl) {
    final Uri uri = Uri.parse(newUrl);

    if (request is http.Request) {
      final newRequest = http.Request(request.method, uri)
        ..headers.addAll(request.headers)
        ..body = request.body
        ..encoding = request.encoding;
      return newRequest;
    } else if (request is http.MultipartRequest) {
      final newRequest = http.MultipartRequest(request.method, uri)
        ..headers.addAll(request.headers)
        ..fields.addAll(request.fields);

      for (final file in request.files) {
        newRequest.files.add(file);
      }
      return newRequest;
    } else {
      // Para otros tipos de solicitudes, crear una solicitud genérica
      final newRequest = http.Request(request.method, uri)
        ..headers.addAll(request.headers);
      return newRequest;
    }
  }

  Future<String?> _getStoredToken() async {
    try {
      if (kIsWeb) {
        // Para web usamos localStorage
        return null; // Implementa según necesites
      } else {
        // Para móvil usamos FlutterSecureStorage
        return await _storage.read(key: 'jwt_token');
      }
    } catch (e) {
      return null;
    }
  }

  @override
  void close() {
    _inner.close();
  }
}
