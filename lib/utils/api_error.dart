import 'dart:convert';

/// Mirrors the backend `ErrorCode` enum from `GlobalExceptionHandler.java`.
///
/// HTTP status → typical code:
///   400 → validationError / fieldValidation / invalidState
///   401 → invalidCredentials / tokenExpired
///   403 → forbidden / permissionDenied
///   404 → resourceNotFound
///   408 → timeoutError
///   409 → resourceConflict / cajaNoAbierta / pedidoEstadoInvalido
///   500 → internalError / databaseError
///   502 → matiasApiError / dianApiError
enum BackendErrorCode {
  // Validation
  validationError,
  fieldValidation,
  missingParameter,
  invalidJson,
  invalidFormat,
  // Business logic
  businessError,
  invalidState,
  resourceConflict,
  duplicateResource,
  resourceNotFound,
  // Domain-specific
  cupoInsuficiente,
  cajaNoAbierta,
  pedidoEstadoInvalido,
  inventoryError,
  // Auth
  invalidCredentials,
  tokenExpired,
  permissionDenied,
  // External services
  matiasApiError,
  dianApiError,
  externalServiceError,
  // HTTP-specific
  forbidden,
  unsupportedMediaType,
  methodNotAllowed,
  // Database
  databaseError,
  dataAccessError,
  duplicateKeyError,
  // Timing
  timeoutError,
  connectionTimeout,
  serviceUnavailable,
  // Generic
  internalError,
  unknownError,
}

BackendErrorCode _parseCode(String? raw) {
  switch (raw?.toUpperCase()) {
    case 'VALIDATION_ERROR':       return BackendErrorCode.validationError;
    case 'FIELD_VALIDATION':
    case 'FIELD_VALIDATION_ERROR': return BackendErrorCode.fieldValidation;
    case 'MISSING_PARAMETER':      return BackendErrorCode.missingParameter;
    case 'INVALID_JSON':           return BackendErrorCode.invalidJson;
    case 'INVALID_FORMAT':         return BackendErrorCode.invalidFormat;
    case 'BUSINESS_ERROR':         return BackendErrorCode.businessError;
    case 'INVALID_STATE':          return BackendErrorCode.invalidState;
    case 'RESOURCE_CONFLICT':
    case 'CONFLICT':               return BackendErrorCode.resourceConflict;
    case 'DUPLICATE_RESOURCE':     return BackendErrorCode.duplicateResource;
    case 'DUPLICATE_KEY_ERROR':    return BackendErrorCode.duplicateKeyError;
    case 'RESOURCE_NOT_FOUND':
    case 'NOT_FOUND':              return BackendErrorCode.resourceNotFound;
    case 'CUPO_INSUFICIENTE':      return BackendErrorCode.cupoInsuficiente;
    case 'CAJA_NO_ABIERTA':        return BackendErrorCode.cajaNoAbierta;
    case 'PEDIDO_ESTADO_INVALIDO': return BackendErrorCode.pedidoEstadoInvalido;
    case 'INVENTORY_ERROR':        return BackendErrorCode.inventoryError;
    case 'INVALID_CREDENTIALS':
    case 'UNAUTHORIZED':           return BackendErrorCode.invalidCredentials;
    case 'TOKEN_EXPIRED':          return BackendErrorCode.tokenExpired;
    case 'PERMISSION_DENIED':      return BackendErrorCode.permissionDenied;
    case 'MATIAS_API_ERROR':       return BackendErrorCode.matiasApiError;
    case 'DIAN_API_ERROR':         return BackendErrorCode.dianApiError;
    case 'EXTERNAL_SERVICE_ERROR': return BackendErrorCode.externalServiceError;
    case 'FORBIDDEN':              return BackendErrorCode.forbidden;
    case 'UNSUPPORTED_MEDIA_TYPE': return BackendErrorCode.unsupportedMediaType;
    case 'METHOD_NOT_ALLOWED':     return BackendErrorCode.methodNotAllowed;
    case 'DATABASE_ERROR':         return BackendErrorCode.databaseError;
    case 'DATA_ACCESS_ERROR':      return BackendErrorCode.dataAccessError;
    case 'INTERNAL_ERROR':         return BackendErrorCode.internalError;
    case 'TIMEOUT_ERROR':          return BackendErrorCode.timeoutError;
    case 'CONNECTION_TIMEOUT':     return BackendErrorCode.connectionTimeout;
    case 'SERVICE_UNAVAILABLE':    return BackendErrorCode.serviceUnavailable;
    default:                       return BackendErrorCode.unknownError;
  }
}

BackendErrorCode _inferFromStatus(int statusCode) {
  switch (statusCode) {
    case 400: return BackendErrorCode.validationError;
    case 401: return BackendErrorCode.invalidCredentials;
    case 403: return BackendErrorCode.forbidden;
    case 404: return BackendErrorCode.resourceNotFound;
    case 405: return BackendErrorCode.methodNotAllowed;
    case 408: return BackendErrorCode.timeoutError;
    case 409: return BackendErrorCode.resourceConflict;
    case 415: return BackendErrorCode.unsupportedMediaType;
    case 500: return BackendErrorCode.internalError;
    case 502: return BackendErrorCode.matiasApiError;
    case 503: return BackendErrorCode.serviceUnavailable;
    default:  return BackendErrorCode.unknownError;
  }
}

/// Structured exception carrying the full backend `ApiResponse` error payload.
///
/// Implements [Exception] so existing `catch (e)` / `on Exception` clauses
/// still catch it without modification.
class BackendException implements Exception {
  final int statusCode;
  final BackendErrorCode errorCode;

  /// Raw string value of `code` from the backend JSON (e.g. `"CAJA_NO_ABIERTA"`).
  final String rawCode;
  final String message;

  /// Contents of the `meta` map from the backend response, if present.
  final Map<String, dynamic>? meta;

  /// Optional context label prepended to [message] in [displayMessage].
  final String? prefix;

  const BackendException({
    required this.statusCode,
    required this.errorCode,
    required this.rawCode,
    required this.message,
    this.meta,
    this.prefix,
  });

  // ── Convenience getters ────────────────────────────────────────────────────

  bool get isAuthError =>
      errorCode == BackendErrorCode.invalidCredentials ||
      errorCode == BackendErrorCode.tokenExpired ||
      errorCode == BackendErrorCode.forbidden ||
      errorCode == BackendErrorCode.permissionDenied;

  bool get isNotFound => errorCode == BackendErrorCode.resourceNotFound;

  bool get isConflict =>
      errorCode == BackendErrorCode.resourceConflict ||
      errorCode == BackendErrorCode.cajaNoAbierta ||
      errorCode == BackendErrorCode.pedidoEstadoInvalido;

  bool get isValidation =>
      errorCode == BackendErrorCode.validationError ||
      errorCode == BackendErrorCode.fieldValidation ||
      errorCode == BackendErrorCode.missingParameter ||
      errorCode == BackendErrorCode.invalidJson ||
      errorCode == BackendErrorCode.invalidFormat;

  bool get isServerError => statusCode >= 500;

  bool get isExternalServiceError =>
      errorCode == BackendErrorCode.matiasApiError ||
      errorCode == BackendErrorCode.dianApiError ||
      errorCode == BackendErrorCode.externalServiceError;

  bool get isCajaNoAbierta => errorCode == BackendErrorCode.cajaNoAbierta;

  /// User-facing message, including the optional [prefix].
  String get displayMessage =>
      prefix != null ? '$prefix: $message' : message;

  /// Returns [displayMessage] so that wrapping via
  /// `Exception('... $e')` still produces a readable string.
  @override
  String toString() => displayMessage;
}

// ── Internal factory ──────────────────────────────────────────────────────────

BackendException _build(String body, int statusCode, {String? prefix}) {
  String message = 'Error $statusCode';
  String rawCode = '';
  Map<String, dynamic>? meta;

  try {
    final data = json.decode(body) as Map<String, dynamic>;
    final msg = data['message'];
    if (msg is String && msg.trim().isNotEmpty) message = msg.trim();
    rawCode = (data['code'] as String?) ?? '';
    final rawMeta = data['meta'];
    if (rawMeta is Map<String, dynamic>) {
      meta = rawMeta;
      // Some handlers put errorCode inside meta when top-level code is missing.
      if (rawCode.isEmpty) rawCode = (meta['errorCode'] as String?) ?? '';
    }
  } catch (_) {}

  final errorCode = rawCode.isNotEmpty
      ? _parseCode(rawCode)
      : _inferFromStatus(statusCode);

  return BackendException(
    statusCode: statusCode,
    errorCode: errorCode,
    rawCode: rawCode,
    message: message,
    meta: meta,
    prefix: prefix,
  );
}

// ── Public API ────────────────────────────────────────────────────────────────

/// Parses the backend `ApiResponse` error body and returns a [BackendException].
BackendException parseBackendException(
  String body,
  int statusCode, {
  String? prefix,
}) =>
    _build(body, statusCode, prefix: prefix);

/// Extracts just the error message string (backward-compatible helper).
String parseBackendError(String body, int statusCode) =>
    _build(body, statusCode).message;

/// Throws a typed [BackendException] built from the backend response.
///
/// Use in the `else` branch after checking `response.statusCode`:
/// ```dart
/// throwBackendError(response.body, response.statusCode, prefix: 'Error al crear pedido');
/// ```
Never throwBackendError(String body, int statusCode, {String? prefix}) =>
    throw _build(body, statusCode, prefix: prefix);

/// Use in catch blocks **instead of** `throw Exception('Error de conexión: $e')`.
///
/// Re-throws a [BackendException] unchanged so callers can inspect its type;
/// wraps any other error (network, timeout, etc.) in a plain [Exception].
///
/// ```dart
/// } catch (e) {
///   wrapOrThrow(e, context: 'Error al crear pedido');
/// }
/// ```
Never wrapOrThrow(Object e, {String context = 'Error de conexión'}) {
  if (e is BackendException) throw e;
  throw Exception('$context: $e');
}

/// Extracts the user-facing message from any exception.
///
/// Handles [BackendException] natively; strips the `"Exception: "` prefix
/// from plain [Exception] strings.
String errorMessage(Object e) {
  if (e is BackendException) return e.displayMessage;
  final s = e.toString();
  if (s.startsWith('Exception: ')) return s.substring(11);
  return s;
}
