# Configuración CORS para Backend Local

## ✅ Estado Actual

Tu aplicación Flutter **YA ESTÁ** configurada correctamente para usar el backend local:

```
🔧 Modo desarrollo detectado - usando backend local: http://localhost:8080
```

Las requests están llegando correctamente a: `http://localhost:8080/api/public/security/login-no-auth`

## ❌ Problema CORS en Backend Local

El backend local necesita configurar CORS para permitir requests desde `http://localhost:5300`.

Error actual:

```
Access to fetch at 'http://localhost:8080/api/public/security/login-no-auth'
from origin 'http://localhost:5300' has been blocked by CORS policy:
Response to preflight request doesn't pass access control check:
No 'Access-Control-Allow-Origin' header is present on the requested resource.
```

## 🔧 Solución: Configurar CORS en Backend

### Para Spring Boot (Java)

Agrega esta configuración en tu backend:

```java
@Configuration
@EnableWebMvc
public class WebConfig implements WebMvcConfigurer {

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
                .allowedOrigins(
                    "http://localhost:5300",
                    "http://127.0.0.1:5300",
                    "https://sopa-y-carbon-app.web.app"
                )
                .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
                .allowedHeaders("*")
                .allowCredentials(true)
                .maxAge(3600);
    }
}
```

### Para Express.js (Node.js)

```javascript
const cors = require("cors");

app.use(
  cors({
    origin: [
      "http://localhost:5300",
      "http://127.0.0.1:5300",
      "https://sopa-y-carbon-app.web.app",
    ],
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
    credentials: true,
  })
);

// Manejar OPTIONS requests explícitamente
app.options("*", cors());
```

### Para .NET Core

```csharp
// En Startup.cs o Program.cs
services.AddCors(options =>
{
    options.AddDefaultPolicy(builder =>
    {
        builder.WithOrigins(
                "http://localhost:5300",
                "http://127.0.0.1:5300",
                "https://sopa-y-carbon-app.web.app"
            )
            .AllowAnyMethod()
            .AllowAnyHeader()
            .AllowCredentials();
    });
});

// En el pipeline
app.UseCors();
```

## 🚀 Pasos para Resolver

1. **Agregar configuración CORS** en tu backend local según el framework que uses
2. **Reiniciar tu servidor backend** local
3. **Refresh la página** en el navegador (F5)
4. **Intentar login** nuevamente

## 🔍 Verificar que Funciona

Después de configurar CORS, deberías ver en la consola del navegador:

✅ **Sin errores CORS**
✅ **Requests exitosas** a `localhost:8080`
✅ **Respuesta del backend** con datos de login

## 📋 Otras Consideraciones

### Errores de Fonts (No críticos):

```
Font family Roboto not found (404) at assets/assets/fonts/Roboto-Regular.ttf
```

- Estos son errores cosméticos que no afectan la funcionalidad
- Se pueden ignorar durante el desarrollo

### CORS del Icon (No crítico):

```
Access to XMLHttpRequest at 'https://sopa-y-carbon-app.web.app/icons/Icon-192.png'
```

- Error menor de carga de ícono desde Firebase
- No afecta la funcionalidad principal

## ✅ Configuración Frontend Completada

Tu Flutter app **YA ESTÁ LISTA** y configurada correctamente:

- ✅ Detecta modo desarrollo automáticamente
- ✅ Usa `localhost:8080` en desarrollo
- ✅ Mantiene producción en Render
- ✅ Logs claros para debugging

**Solo falta configurar CORS en tu backend local.**
