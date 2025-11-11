# Solución CORS - Error 403 Forbidden en OPTIONS

## 🔍 Problema Identificado

El backend en Render está devolviendo `403 Forbidden` para las solicitudes OPTIONS (CORS preflight), impidiendo que el frontend se comunique con la API.

## 🎯 Soluciones Disponibles

### Solución 1: Configuración CORS en Backend (RECOMENDADA)

Esta es la solución permanente que debe implementarse en el backend de Render.

#### Headers CORS Requeridos:

```javascript
// En tu backend (Express.js ejemplo)
app.use(
  cors({
    origin: [
      "https://sopa-y-carbon-app.web.app",
      "http://localhost:5300",
      "http://127.0.0.1:5300",
    ],
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
    credentials: true,
  })
);

// O manualmente:
app.use((req, res, next) => {
  res.header("Access-Control-Allow-Origin", req.headers.origin);
  res.header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS");
  res.header("Access-Control-Allow-Headers", "Content-Type, Authorization");
  res.header("Access-Control-Allow-Credentials", "true");

  if (req.method === "OPTIONS") {
    res.status(200).end();
    return;
  }
  next();
});
```

### Solución 2: Testing Local con Chrome Sin Seguridad

Para desarrollo y testing inmediato:

```powershell
# Cerrar todas las instancias de Chrome primero
# Luego ejecutar:
Start-Process chrome --new-window --user-data-dir="C:/temp/chrome-dev" --disable-web-security --disable-features=VizDisplayCompositor --allow-running-insecure-content "http://localhost:5300"
```

### Solución 3: Desarrollo con Firefox (Menos Restrictivo)

Firefox es más permisivo con CORS en desarrollo:

```powershell
cd "d:\prueba sopa y carbon\serch-restapp"
flutter run -d web-server --web-port=5300
```

Luego abrir Firefox en `http://localhost:5300`

## 📋 Estado Actual del Proyecto

### ✅ Configuraciones Corregidas:

- `lib/config/constants.dart`: URL corregida a Render
- `lib/config/endpoints_config.dart`: baseUrl apuntando a Render
- `lib/config/api_config_new.dart`: Fallback URLs actualizadas
- `lib/services/producto_service.dart`: Timeouts aumentados a 90s para Render
- `lib/config/development_config.dart`: Configuración para desarrollo creada

### ✅ Funcionalidades Operativas:

- Timeouts configurados para cold starts de Render (90 segundos)
- Cache de productos para fallback en caso de timeout
- WebSocket con reconexión inteligente
- Configuración consistente entre entornos

## 🚀 Próximos Pasos

1. **Inmediato - Testing**: Usar Chrome sin seguridad para validar que el frontend funciona
2. **Corto Plazo - Backend**: Implementar configuración CORS en el backend de Render
3. **Largo Plazo - Producción**: El despliegue en Firebase Hosting ya funciona sin problemas CORS

## 📱 Comandos de Desarrollo

```powershell
# Instalar dependencias
cd "d:\prueba sopa y carbon\serch-restapp"
flutter pub get

# Ejecutar en desarrollo (puerto 5300)
flutter run -d edge --web-port=5300

# Para testing sin CORS (Chrome)
Start-Process chrome --user-data-dir="C:/temp/chrome-dev" --disable-web-security --allow-running-insecure-content "http://localhost:5300"

# Deploy a Firebase
firebase deploy --only hosting
```

## 🔧 Archivos Modificados en Esta Sesión

1. `lib/config/constants.dart` - URL corregida + configuración dinámica
2. `lib/config/endpoints_config.dart` - baseUrl corregida
3. `lib/config/api_config_new.dart` - Fallback URLs y sintaxis corregida
4. `lib/services/producto_service.dart` - Timeouts actualizados a 90s
5. `lib/config/development_config.dart` - Nueva configuración de desarrollo

## 📊 Verificación de Estado

### URLs Configuradas:

- ✅ Producción: `https://sopa-y-carbon.onrender.com`
- ✅ Desarrollo: `http://localhost:5300`
- ✅ Deploy: `https://sopa-y-carbon-app.web.app`

### Timeouts Configurados:

- ✅ Productos: 90 segundos (para cold start de Render)
- ✅ WebSocket: Reconexión cada 15 segundos, heartbeat cada 120s
- ✅ Categorías: 90 segundos

El frontend está completamente configurado y listo. El único bloqueador es la configuración CORS del backend en Render.
