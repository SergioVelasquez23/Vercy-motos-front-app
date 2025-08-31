# Guía de Migración al BaseApiService

## 🎯 Objetivo

Migrar todos los servicios HTTP existentes para usar el nuevo `BaseApiService`, eliminando la duplicación masiva de código y mejorando el mantenimiento.

## 📊 Estado Actual

### ✅ Servicios Migrados (Ejemplos)
- `UserService` → `user_service_new.dart`
- `RoleService` → `role_service_new.dart` 
- `PedidoService` → `pedido_service_new.dart` (parcial)

### 🔄 Servicios Pendientes de Migrar
- `auth_service.dart`
- `producto_service.dart`
- `factura_service.dart`
- `gasto_service.dart`
- `cuadre_caja_service.dart`
- `documento_mesa_service.dart`
- `ingrediente_service.dart`
- `inventario_service.dart`
- `mesa_service.dart`
- `proveedor_service.dart`
- `reportes_service.dart`
- `factura_compra_service.dart`
- `impresion_service.dart`
- `user_role_service.dart`
- `resumen_cierre_service.dart`
- `negocio_info_service.dart`

## 🔧 Proceso de Migración

### Paso 1: Preparación

1. **Respalda el servicio original:**
```bash
cp lib/services/service_name.dart lib/services/service_name_backup.dart
```

2. **Identifica patrones duplicados:**
   - Método `_getHeaders()` o similar
   - Lógica de parsing de respuestas
   - Manejo de errores HTTP

### Paso 2: Estructura Base

```dart
import '../models/your_model.dart';
import 'base/http_api_service.dart';
import 'base/base_api_service.dart';

class YourService {
  static final YourService _instance = YourService._internal();
  factory YourService() => _instance;
  YourService._internal();

  final BaseApiService _apiService = HttpApiService();

  // Métodos públicos aquí
}
```

### Paso 3: Migrar Métodos GET

**ANTES:**
```dart
Future<List<Model>> getModels() async {
  try {
    final token = await storage.read(key: 'jwt_token');
    final response = await http.get(
      Uri.parse('$baseUrl/api/models'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Model.fromJson(json)).toList();
    } else {
      throw Exception('Error al cargar models: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Error de conexión: $e');
  }
}
```

**DESPUÉS:**
```dart
Future<List<Model>> getModels() async {
  try {
    final data = await _apiService.get<List<dynamic>>(
      '/api/models',
      parser: (responseData) {
        if (responseData is List) return responseData;
        if (responseData is Map && responseData.containsKey('data')) {
          return responseData['data'] as List<dynamic>;
        }
        return responseData as List<dynamic>;
      },
    );

    return data.map((json) => Model.fromJson(json)).toList();
  } on ApiException {
    rethrow;
  }
}
```

### Paso 4: Migrar Métodos POST

**ANTES:**
```dart
Future<Model> createModel(Model model) async {
  try {
    final token = await storage.read(key: 'jwt_token');
    final response = await http.post(
      Uri.parse('$baseUrl/api/models'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: json.encode(model.toJson()),
    );

    if (response.statusCode == 201) {
      return Model.fromJson(json.decode(response.body));
    } else {
      throw Exception('Error al crear model: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Error al crear model: $e');
  }
}
```

**DESPUÉS:**
```dart
Future<Model> createModel(Model model) async {
  try {
    final data = await _apiService.post<Map<String, dynamic>>(
      '/api/models',
      body: model.toJson(),
    );
    return Model.fromJson(data);
  } on ApiException {
    rethrow;
  }
}
```

### Paso 5: Migrar Métodos PUT

**DESPUÉS:**
```dart
Future<Model> updateModel(Model model) async {
  try {
    final data = await _apiService.put<Map<String, dynamic>>(
      '/api/models/${model.id}',
      body: model.toJson(),
    );
    return Model.fromJson(data);
  } on ApiException {
    rethrow;
  }
}
```

### Paso 6: Migrar Métodos DELETE

**DESPUÉS:**
```dart
Future<bool> deleteModel(String id) async {
  try {
    await _apiService.delete<void>('/api/models/$id');
    return true;
  } on ApiException catch (e) {
    if (e.statusCode == 200 || e.statusCode == 204) {
      return true;
    }
    return false;
  }
}
```

## 🎯 Patrones Específicos

### Manejo de Query Parameters

```dart
Future<List<Model>> getModelsByType(String type) async {
  final data = await _apiService.get<List<dynamic>>(
    '/api/models',
    queryParams: {'type': type},
  );
  return data.map((json) => Model.fromJson(json)).toList();
}
```

### Parsers Personalizados para Respuestas Complejas

```dart
Future<ComplexResponse> getComplexData() async {
  final data = await _apiService.get<Map<String, dynamic>>(
    '/api/complex',
    parser: (responseData) {
      // Lógica específica para esta respuesta
      if (responseData['success'] == true) {
        return responseData['data'];
      }
      throw ApiException('Response format error');
    },
  );
  return ComplexResponse.fromJson(data);
}
```

### Manejo de Errores Específicos

```dart
Future<Model?> getModelById(String id) async {
  try {
    final data = await _apiService.get<Map<String, dynamic>>('/api/models/$id');
    return Model.fromJson(data);
  } on ApiException catch (e) {
    if (e.statusCode == 404) {
      return null; // Modelo no encontrado
    }
    rethrow; // Otros errores se propagan
  }
}
```

## ✅ Lista de Verificación por Servicio

Para cada servicio migrado, verifica:

- [ ] ❌ Eliminar imports innecesarios (`dart:convert`, `http`, `flutter_secure_storage`)
- [ ] ✅ Importar `base/http_api_service.dart` y `base/base_api_service.dart`
- [ ] ❌ Eliminar `_getHeaders()` o métodos similares duplicados
- [ ] ❌ Eliminar `FlutterSecureStorage storage`
- [ ] ❌ Eliminar `baseUrl` hardcodeado
- [ ] ✅ Reemplazar todas las llamadas HTTP con `_apiService.*`
- [ ] ✅ Manejar errores con `ApiException`
- [ ] ✅ Mantener lógica de negocio específica
- [ ] ✅ Preservar métodos públicos existentes
- [ ] ✅ Probar funcionalidad básica

## 📈 Beneficios Esperados

### Por Servicio Migrado:
- **50-70% menos líneas de código**
- **Eliminación completa de código duplicado HTTP**
- **Manejo de errores consistente**
- **Logging automático en desarrollo**
- **Mejor separation of concerns**

### A Nivel de Aplicación:
- **~1000+ líneas de código eliminadas**
- **Mantenimiento más fácil**
- **Testing más simple**
- **Consistency en toda la app**

## 🚀 Plan de Implementación

### Semana 1: Servicios Críticos
1. `auth_service.dart` - Base de autenticación
2. `producto_service.dart` - Core business logic
3. `factura_service.dart` - Funcionalidad principal

### Semana 2: Servicios de Soporte
4. `gasto_service.dart`
5. `cuadre_caja_service.dart`
6. `documento_mesa_service.dart`
7. `ingrediente_service.dart`

### Semana 3: Servicios Especializados
8. `inventario_service.dart`
9. `mesa_service.dart`
10. `proveedor_service.dart`
11. `reportes_service.dart`

### Semana 4: Servicios Complementarios
12. `factura_compra_service.dart`
13. `impresion_service.dart`
14. `user_role_service.dart`
15. `resumen_cierre_service.dart`
16. `negocio_info_service.dart`

## 🧪 Testing

Después de cada migración:

1. **Ejecutar pruebas unitarias** (si existen)
2. **Probar funcionalidad manualmente**
3. **Verificar que no se rompe la UI**
4. **Validar el manejo de errores**

## 📝 Notas Importantes

1. **No cambiar interfaces públicas** - Los métodos deben mantener la misma signatura
2. **Preservar lógica de negocio** - Solo migrar la lógica HTTP
3. **Mantener compatibilidad** - Código existente debe seguir funcionando
4. **Probar gradualmente** - Migrar un servicio a la vez
5. **Hacer backup** - Mantener servicios originales hasta verificar

## 🆘 Resolución de Problemas

### Error: "ApiException not handled"
**Solución**: Agregar `on ApiException` catch blocks

### Error: "Type mismatch in parser"
**Solución**: Verificar el tipo de retorno del parser

### Error: "Endpoint not found"
**Solución**: Verificar que el endpoint en BaseApiService sea correcto

### Error: "Headers not working"
**Solución**: El BaseApiService maneja headers automáticamente

---

**¿Necesitas ayuda con la migración de algún servicio específico?** Crear un issue o pregunta en el equipo de desarrollo.
