import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart' as prefs;

/// Utilidades para encriptar y proteger datos sensibles
class SecurityUtils {
  // Instancia del almacenamiento seguro
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: const AndroidOptions(encryptedSharedPreferences: true),
    webOptions: const WebOptions(
      dbName: 'sopa_carbon_security',
      publicKey: 'sopa_carbon_app_key',
    ),
  );
  static final Random _random = Random.secure();
  static const String _securityKeyName = 'app_encryption_key';
  static const String _webSecurityKeyName = 'app_web_encryption_key';
  static late encrypt.Key _encryptionKey;
  static late encrypt.IV _iv;
  static bool _isInitialized = false;

  // Clave de respaldo para usar si hay errores en la plataforma web
  static final encrypt.Key _fallbackWebKey = encrypt.Key.fromUtf8(
    'sopa_carbon_secure_key_2025_fallback_web',
  );
  static final encrypt.IV _fallbackWebIV = encrypt.IV.fromUtf8(
    'sopacarbonfixed',
  );

  /// Genera una clave segura para entornos web
  /// Esto evita problemas con WebCrypto API
  static Future<String> _generateWebKey() async {
    // En la web, usamos una combinación de timestamp y valor aleatorio para generar una clave
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final randomPart = List<int>.generate(16, (_) => _random.nextInt(256));
    final combinedBytes = utf8.encode('sopacarbon_$timestamp') + randomPart;
    final digest = sha256.convert(combinedBytes);
    final webKey = base64.encode(digest.bytes);

    // Guardar la clave en SharedPreferences para la web
    try {
      final sharedPrefs = await prefs.SharedPreferences.getInstance();
      await sharedPrefs.setString(_webSecurityKeyName, webKey);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error al guardar clave web: $e');
      }
    }

    return webKey;
  }

  /// Recupera una clave web guardada previamente
  static Future<String?> _getStoredWebKey() async {
    try {
      final sharedPrefs = await prefs.SharedPreferences.getInstance();
      return sharedPrefs.getString(_webSecurityKeyName);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error al recuperar clave web: $e');
      }
      return null;
    }
  }

  /// Inicializa las claves de seguridad
  static Future<void> initializeSecurity() async {
    if (_isInitialized) return;

    try {
      String? storedKey;

      if (kIsWeb) {
        // En la web, primero intentamos recuperar una clave guardada
        if (kDebugMode) {
          print('🌐 Usando modo web para seguridad');
        }
        storedKey = await _getStoredWebKey();

        if (storedKey == null) {
          // Si no existe, generamos una nueva
          storedKey = await _generateWebKey();
        }
      } else {
        // En dispositivos móviles, usamos el enfoque normal con almacenamiento seguro
        if (kDebugMode) {
          print('📱 Usando modo móvil para seguridad');
        }

        try {
          storedKey = await _secureStorage.read(key: _securityKeyName);
          if (storedKey == null) {
            // Generar una nueva clave y guardarla
            final keyBytes = List<int>.generate(
              32,
              (_) => _random.nextInt(256),
            );
            storedKey = base64.encode(keyBytes);
            await _secureStorage.write(key: _securityKeyName, value: storedKey);
          }
        } catch (secureStorageError) {
          if (kDebugMode) {
            print('⚠️ Error con almacenamiento seguro: $secureStorageError');
          }

          // Si falla el almacenamiento seguro, generamos una clave temporal
          final keyBytes = List<int>.generate(32, (_) => _random.nextInt(256));
          storedKey = base64.encode(keyBytes);
        }
      }

      // Configurar la clave de encriptación y el vector de inicialización
      _encryptionKey = encrypt.Key.fromBase64(storedKey);
      _iv = encrypt.IV.fromLength(16);
      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error al inicializar seguridad: $e');
        print('⚠️ Usando clave de respaldo para emergencias');
      }
      // En caso de error grave, usar clave de respaldo
      _encryptionKey = _fallbackWebKey;
      _iv = _fallbackWebIV;
      _isInitialized = true;
    }
  }

  /// Encripta datos sensibles
  static Future<String> encryptData(String plainText) async {
    await _ensureInitialized();

    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey));
      final encrypted = encrypter.encrypt(plainText, iv: _iv);
      return encrypted.base64;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error al encriptar datos: $e');
      }
      // En caso de error, usamos un enfoque simplificado
      final bytes = utf8.encode(plainText);
      final digest = sha256.convert(bytes);
      return base64.encode(digest.bytes);
    }
  }

  /// Desencripta datos sensibles
  static Future<String> decryptData(String encryptedText) async {
    await _ensureInitialized();

    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey));
      final encrypted = encrypt.Encrypted.fromBase64(encryptedText);
      return encrypter.decrypt(encrypted, iv: _iv);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error al desencriptar datos: $e');
      }
      // En caso de error, devolvemos el texto cifrado (no es ideal, pero evita bloqueos)
      return "DECRYPT_ERROR";
    }
  }

  /// Genera un hash seguro para contraseñas
  static String hashPassword(String password, {String? salt}) {
    final saltValue = salt ?? _generateSalt();
    final bytes = utf8.encode('$password$saltValue');
    final digest = sha256.convert(bytes);
    return '$digest:$saltValue';
  }

  /// Verifica una contraseña con su hash
  static bool verifyPassword(String password, String hashedPassword) {
    final parts = hashedPassword.split(':');
    if (parts.length != 2) return false;

    final salt = parts[1];
    final hashedInput = hashPassword(password, salt: salt);
    return hashedInput == hashedPassword;
  }

  /// Genera una clave API segura para solicitudes
  static String generateApiKey() {
    final keyBytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return base64Url.encode(keyBytes).replaceAll('=', '');
  }

  /// Valida un número de tarjeta de crédito usando el algoritmo de Luhn
  static bool isValidCreditCard(String cardNumber) {
    // Eliminar espacios y guiones
    final cleanNumber = cardNumber.replaceAll(RegExp(r'[\s-]'), '');

    // Verificar que solo contenga dígitos y tenga longitud válida
    if (!RegExp(r'^\d{13,19}$').hasMatch(cleanNumber)) {
      return false;
    }

    // Algoritmo de Luhn
    int sum = 0;
    bool alternate = false;
    for (int i = cleanNumber.length - 1; i >= 0; i--) {
      int digit = int.parse(cleanNumber[i]);

      if (alternate) {
        digit *= 2;
        if (digit > 9) {
          digit -= 9;
        }
      }

      sum += digit;
      alternate = !alternate;
    }

    return sum % 10 == 0;
  }

  /// Enmascara un número de tarjeta de crédito
  static String maskCreditCard(String cardNumber) {
    final cleanNumber = cardNumber.replaceAll(RegExp(r'[\s-]'), '');
    if (cleanNumber.length < 4) return cleanNumber;

    final lastFour = cleanNumber.substring(cleanNumber.length - 4);
    final masked = '*' * (cleanNumber.length - 4);
    return '$masked$lastFour';
  }

  /// Asegura que el sistema de seguridad esté inicializado
  static Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initializeSecurity();
    }
  }

  /// Genera un salt aleatorio
  static String _generateSalt() {
    final saltBytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64.encode(saltBytes);
  }
}
