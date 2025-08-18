class User {
  final String? id;
  final String? nombre; // "name" en el backend
  final String email;
  final String? password;
  final bool activo;
  final DateTime? fechaCreacion;
  final DateTime? fechaActualizacion;
  final int? numeroDeSesiones;
  final List<String>? roles;

  User({
    this.id,
    this.nombre,
    required this.email,
    this.password,
    this.activo = true,
    this.fechaCreacion,
    this.fechaActualizacion,
    this.numeroDeSesiones,
    this.roles,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'],
      nombre: json['name'] ?? json['nombre'],
      email: json['email'] ?? '',
      password: json['password'],
      activo: json['activo'] ?? true,
      fechaCreacion: json['fechaCreacion'] != null
          ? DateTime.parse(json['fechaCreacion'])
          : null,
      fechaActualizacion: json['fechaActualizacion'] != null
          ? DateTime.parse(json['fechaActualizacion'])
          : null,
      numeroDeSesiones: json['numeroDeSesiones'],
      roles: json['roles'] != null ? List<String>.from(json['roles']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': nombre,
      'email': email,
      'password': password,
      'activo': activo,
      'fechaCreacion': fechaCreacion?.toIso8601String(),
      'fechaActualizacion': fechaActualizacion?.toIso8601String(),
      'numeroDeSesiones': numeroDeSesiones,
      'roles': roles,
    };
  }

  Map<String, dynamic> toJsonCreate() {
    return {'name': nombre, 'email': email, 'password': password};
  }

  Map<String, dynamic> toJsonUpdate() {
    final Map<String, dynamic> json = {'name': nombre, 'email': email};

    // Solo incluir password si no está vacía
    if (password != null && password!.isNotEmpty) {
      json['password'] = password;
    }

    return json;
  }

  String get displayName {
    if (nombre != null && nombre!.isNotEmpty) {
      return nombre!;
    } else {
      return email;
    }
  }

  User copyWith({
    String? id,
    String? nombre,
    String? email,
    String? password,
    bool? activo,
    DateTime? fechaCreacion,
    DateTime? fechaActualizacion,
    int? numeroDeSesiones,
    List<String>? roles,
  }) {
    return User(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      email: email ?? this.email,
      password: password ?? this.password,
      activo: activo ?? this.activo,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
      numeroDeSesiones: numeroDeSesiones ?? this.numeroDeSesiones,
      roles: roles ?? this.roles,
    );
  }
}
