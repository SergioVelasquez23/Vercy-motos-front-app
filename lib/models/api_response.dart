class ApiResponse<T> {
  /// Representa una respuesta genérica de una API.
  final bool success; // Indica si la solicitud fue exitosa
  final T? data; // Contiene los datos de la respuesta
  final String message; // Mensaje de error o éxito
  final String timestamp; // Marca de tiempo de la respuesta

  /// Constructor de la clase ApiResponse
  ApiResponse({
    required this.success,
    this.data,
    required this.message,
    required this.timestamp,
  });

  /// Factory constructor para crear una instancia de ApiResponse a partir de un JSON.
  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    return ApiResponse<T>(
      success: json['success'] ?? false,
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : json['data'],
      message: json['message'] ?? '',
      timestamp: json['timestamp'] ?? '',
    );
  }

  /// Método para convertir la respuesta a JSON
  Map<String, dynamic> toJson(dynamic Function(T)? toJsonT) {
    return {
      'success': success,
      'data': data != null && toJsonT != null ? toJsonT(data as T) : data,
      'message': message,
      'timestamp': timestamp,
    };
  }

  // Método de conveniencia para manejar listas
  static ApiResponse<List<T>> fromJsonList<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return ApiResponse<List<T>>(
      success: json['success'] ?? false,
      data: json['data'] != null
          ? (json['data'] as List).map((item) => fromJsonT(item)).toList()
          : null,
      message: json['message'] ?? '',
      timestamp: json['timestamp'] ?? '',
    );
  }

  // Método para verificar si la respuesta es exitosa
  bool get isSuccess => success && data != null;

  // Método para obtener el error si no es exitosa
  String get errorMessage => success ? '' : message;
}
