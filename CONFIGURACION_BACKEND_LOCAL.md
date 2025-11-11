# Configuración Backend Local - Desarrollo

## ✅ Configuración Aplicada

### 🔧 URLs Configuradas:

- **Desarrollo (kDebugMode)**: `http://localhost:8080`
- **Producción**: `https://sopa-y-carbon.onrender.com`

### 📁 Archivos Modificados:

#### 1. `lib/config/constants.dart`

```dart
// URL dinámica que considera el entorno de desarrollo
String get kDynamicBackendUrl {
  if (kDebugMode) {
    print('🔧 Modo desarrollo detectado - usando backend local: $kLocalBackendUrl');
    return kLocalBackendUrl; // http://localhost:8080
  }
  print('🚀 Modo producción - usando backend: $kBackendUrl');
  return kBackendUrl; // https://sopa-y-carbon.onrender.com
}
```

#### 2. `lib/config/endpoints_config.dart`

```dart
// URL base por defecto (usa configuración dinámica)
static String get baseUrl => _instance._customBaseUrl ?? kDynamicBackendUrl;
```

#### 3. `lib/config/api_config_new.dart`

```dart
final fallbackUrls = {
  'development': 'http://localhost:8080',
  'staging': 'https://sopa-y-carbon.onrender.com',
  'production': 'https://sopa-y-carbon.onrender.com',
};
```

## 🎯 Cómo Verificar que Funciona

### 1. Revisar Consola de Flutter

En la consola de Flutter deberías ver:

```
🔧 Modo desarrollo detectado - usando backend local: http://localhost:8080
```

### 2. Revisar Developer Tools del Navegador

En Edge/Chrome, abre Developer Tools (F12) y revisa la pestaña Network:

- Las requests deben ir a `http://localhost:8080/api/...`
- No debe haber solicitudes a `sopa-y-carbon.onrender.com`

### 3. Verificar en Login

Al intentar hacer login, deberías ver en la consola:

```
🔄 Intentando iniciar sesión en: http://localhost:8080/api/public/security/login-no-auth
```

## ⚡ Comandos Útiles

### Ejecutar en Desarrollo:

```powershell
cd "d:\prueba sopa y carbon\serch-restapp"
flutter run -d edge --web-port=5300
```

### Hot Reload (si la app ya está ejecutándose):

```
Presiona 'r' en la terminal de Flutter
```

### Hot Restart (si hay cambios en configuración):

```
Presiona 'R' en la terminal de Flutter
```

## 🐛 Troubleshooting

### Si sigue usando producción:

1. Verifica que el backend local esté ejecutándose en `http://localhost:8080`
2. Haz Hot Restart (R) en la terminal de Flutter
3. Verifica la consola de Flutter para los mensajes de debug

### Si hay errores de conexión:

1. Asegúrate de que tu backend local tenga CORS configurado para `http://localhost:5300`
2. Verifica que el backend esté respondiendo en `http://localhost:8080`

## 📊 Flujo de Configuración

```
1. kDebugMode = true (modo desarrollo)
   ↓
2. kDynamicBackendUrl retorna "http://localhost:8080"
   ↓
3. EndpointsConfig.baseUrl usa kDynamicBackendUrl
   ↓
4. Todos los servicios (AuthService, ProductoService, etc.) usan EndpointsConfig.baseUrl
   ↓
5. Requests van a localhost:8080
```

¡Tu aplicación ahora está configurada para usar el backend local en desarrollo! 🎉
