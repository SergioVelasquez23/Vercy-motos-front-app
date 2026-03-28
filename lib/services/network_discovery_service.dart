import 'dart:io';
import 'package:http/http.dart' as http;

/// Servicio para detectar automáticamente la IP del servidor backend
///
/// Este servicio elimina la necesidad de hardcodear IPs y permite
/// que la aplicación funcione automáticamente en diferentes redes.
class NetworkDiscoveryService {
  static final NetworkDiscoveryService _instance =
      NetworkDiscoveryService._internal();
  factory NetworkDiscoveryService() => _instance;
  NetworkDiscoveryService._internal();

  // Cache de la última IP válida encontrada
  String? _cachedServerIp;
  DateTime? _lastDiscoveryTime;
  static const Duration _cacheValidTime = Duration(minutes: 5);

  // Puertos comunes donde puede estar el backend
  static const List<int> _commonPorts = [8081, 8080, 3000, 8000];

  // Timeout para cada intento de conexión
  static const Duration _connectionTimeout = Duration(seconds: 2);

  /// Obtiene la IP del servidor backend automáticamente
  ///
  /// Estrategia de búsqueda:
  /// 1. Si hay cache válido, lo retorna
  /// 2. Obtiene la IP local del dispositivo
  /// 3. Escanea la red local buscando el servidor
  /// 4. Prueba conexión en puertos comunes
  /// 5. Retorna la primera IP que responda correctamente
  Future<String?> discoverServerIp() async {
    try {
        

      // 1. Verificar cache válido
      if (_isCacheValid()) {
          
        return _cachedServerIp;
      }

      // 2. Obtener IP local del dispositivo
      final localIp = await _getLocalIp();
      if (localIp == null) {
          
        return null;
      }

        

      // 3. Extraer segmento de red (ej: 192.168.1.x)
      final networkSegment = _extractNetworkSegment(localIp);
      if (networkSegment == null) {
          
        return null;
      }

        

      // 4. Buscar servidor en la red local
      final serverIp = await _scanNetworkForServer(networkSegment);

      if (serverIp != null) {
        _cachedServerIp = serverIp;
        _lastDiscoveryTime = DateTime.now();
          
        return serverIp;
      }

        
      return null;
    } catch (e) {
        
      return null;
    }
  }

  /// Obtiene la URL base completa del servidor
  Future<String?> getServerBaseUrl() async {
    final ip = await discoverServerIp();
    if (ip == null) return null;

    // Determinar el puerto correcto
    for (final port in _commonPorts) {
      final baseUrl = 'http://$ip:$port';
      if (await _testServerConnection(baseUrl)) {
          
        return baseUrl;
      }
    }

    // Si no funciona con puertos comunes, usar el primero por defecto
    final defaultUrl = 'http://$ip:${_commonPorts.first}';
      
    return defaultUrl;
  }

  /// Obtiene la IP local del dispositivo
  Future<String?> _getLocalIp() async {
    try {
      // Método 1: Usar NetworkInterface
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.address.startsWith('192.168.') ||
              addr.address.startsWith('10.') ||
              addr.address.startsWith('172.')) {
            return addr.address;
          }
        }
      }

      // Método 2: Fallback usando socket
      final socket = await Socket.connect('8.8.8.8', 80);
      final localIp = socket.address.address;
      socket.destroy();
      return localIp;
    } catch (e) {
        
      return null;
    }
  }

  /// Extrae el segmento de red de una IP (ej: 192.168.1.100 → 192.168.1)
  String? _extractNetworkSegment(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return null;
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  /// Escanea la red local buscando el servidor
  Future<String?> _scanNetworkForServer(String networkSegment) async {
      

    // Lista de IPs comunes donde suele estar el servidor
    final commonServerIps = [
      '$networkSegment.1', // Gateway/Router
      '$networkSegment.100', // IP común de servidor
      '$networkSegment.101',
      '$networkSegment.231', // La IP actual hardcodeada
      '$networkSegment.10',
      '$networkSegment.20',
    ];

    // Primero probar IPs comunes
    for (final ip in commonServerIps) {
        
      if (await _testServerConnection('http://$ip:8081')) {
        return ip;
      }
    }

    // Si no funciona, escanear rango más amplio (pero limitado)
      
    for (int i = 1; i <= 254; i += 10) {
      // Saltos de 10 para ser más rápido
      final ip = '$networkSegment.$i';
      if (await _testServerConnection('http://$ip:8081')) {
        return ip;
      }
    }

    return null;
  }

  /// Prueba la conexión con el servidor
  Future<bool> testServerConnection(String baseUrl) async {
    return await _testServerConnection(baseUrl);
  }

  /// Prueba la conexión con el servidor (método interno)
  Future<bool> _testServerConnection(String baseUrl) async {
    try {
      // Intentar endpoint de health check o login
      final testEndpoints = [
        '$baseUrl/api/public/security/login-no-auth',
        '$baseUrl/api/health',
        '$baseUrl/actuator/health',
        baseUrl,
      ];

      for (final endpoint in testEndpoints) {
        try {
          final response = await http
              .get(Uri.parse(endpoint), headers: {'Accept': 'application/json'})
              .timeout(_connectionTimeout);

          // Considerar válido si responde (aunque sea con error)
          if (response.statusCode < 500) {
              
            return true;
          }
        } catch (e) {
          // Continuar con el siguiente endpoint
          continue;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Verifica si el cache es aún válido
  bool _isCacheValid() {
    if (_cachedServerIp == null || _lastDiscoveryTime == null) {
      return false;
    }

    final now = DateTime.now();
    return now.difference(_lastDiscoveryTime!) < _cacheValidTime;
  }

  /// Limpia el cache forzando nueva detección
  void clearCache() {
    _cachedServerIp = null;
    _lastDiscoveryTime = null;
      
  }

  /// Fuerza una nueva búsqueda ignorando el cache
  Future<String?> forceRediscover() async {
    clearCache();
    return await discoverServerIp();
  }

  /// Retorna la última IP encontrada (sin nueva búsqueda)
  String? get lastKnownServerIp => _cachedServerIp;

  /// Indica si hay una IP válida en cache
  bool get hasValidCache => _isCacheValid();
}
