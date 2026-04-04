# 🎯 INTEGRACIÓN DE WEBHOOKS MATIAS - FLUTTER

## ✅ IMPLEMENTACIÓN COMPLETADA

Se han creado los siguientes archivos:

### 📁 Archivos nuevos

1. **`lib/models/matias_webhook_event.dart`** 
   - DTO para eventos Matias
   - Serialización JSON automática

2. **`lib/models/matias_webhook_event.g.dart`**
   - Código generado para JSON (no editar manualmente)

3. **`lib/services/matias_webhook_service.dart`**
   - Servicio WebSocket singleton
   - Reconexión automática
   - Gestión de ciclo de vida

4. **`lib/services/WEBHOOK_BACKEND_REFERENCE.dart`**
   - Referencia de implementación backend (checklist)

### 🔄 Archivos modificados

1. **`pubspec.yaml`**
   - Agregadas dependencias: `json_annotation`, `json_serializable`, `build_runner`

2. **`lib/screens/documentos_pendientes_screen.dart`**
   - Integración de escucha de webhooks
   - Indicator de estado de conexión
   - Callbacks para eventos en tiempo real
   - Notificaciones automáticas

---

## 🚀 PASOS PRÓXIMOS (MUY IMPORTANTE)

### 1️⃣ Actualizar dependencias

```bash
cd c:\Users\sergi\OneDrive\Desktop\flutter_app_new
flutter pub get
```

### 2️⃣ Configurar URL de WebSocket

**EDITA ESTE ARCHIVO:** 
[lib/screens/documentos_pendientes_screen.dart](lib/screens/documentos_pendientes_screen.dart#L51)

Busca la línea ~51 y actualiza:

```dart
// ❌ CAMBIAR ESTO:
const String backendUrl = 'ws://localhost:8081';

// ✅ A TU URL REAL:
const String backendUrl = 'ws://tuserver.com'; // o wss:// para HTTPS
```

**Ejemplos según tu entorno:**

```dart
// Desarrollo local
const String backendUrl = 'ws://localhost:8081';

// Render.com (producción)
const String backendUrl = 'wss://vercy-motos-app.onrender.com';

// Railway
const String backendUrl = 'wss://tu-app-railway.railway.app';
```

### 3️⃣ Verificar endpoint en backend

Asegúrate de que tu backend Java Spring Boot tenga:

```
✅ POST /api/webhooks/matias          (recibe eventos)
✅ POST /api/webhooks/matias/test     (para testing)
✅ WebSocket /topic/matias-webhooks   (distribuye eventos)
✅ POST /api/matias/webhooks/register (registra webhook con Matias)
```

Ver checklist completo en: [WEBHOOK_BACKEND_REFERENCE.dart](lib/services/WEBHOOK_BACKEND_REFERENCE.dart)

---

## 🧪 TESTING LOCAL

### Terminal 1: Inicia el backend
```bash
cd tu-proyecto-backend
./mvnw spring-boot:run
```

### Terminal 2: Corre la app Flutter
```bash
cd c:\Users\sergi\OneDrive\Desktop\flutter_app_new
flutter run -d chrome  # o android/ios
```

### Terminal 3: Simula un evento

```bash
curl -X POST \
  http://localhost:8081/api/webhooks/matias/test \
  -H "Content-Type: application/json" \
  -d '{
    "event": "document.accepted",
    "timestamp": "2026-04-02T10:30:00",
    "data": {
      "document_number": "SETP00123",
      "status": "ACEPTADO",
      "total_amount": 150000
    }
  }'
```

### Resultado esperado:
- ✅ Notificación en la app: "✅ Factura aceptada por DIAN #SETP00123"
- ✅ Indicador en header cambia a "🔌 En línea"
- ✅ Lista se actualiza automáticamente
- ✅ Logs muestran: "📨 Evento recibido: document.accepted"

---

## 📊 TIPOS DE EVENTOS SOPORTADOS

| Evento | Acción en Flutter |
|--------|------------------|
| `document.created` | Muestra notificación + recarga |
| `document.accepted` | ✅ Aceptado por DIAN + recarga |
| `document.rejected` | ❌ Error + muestra motivo + recarga |
| `email.sent` | 📧 Notificación + destinatario |
| `payment.approved` | 💰 Notificación + monto |
| `payment.declined` | ⚠️ Error + sugerir otro método |
| `quota.limit_reached` | ⚠️ Alerta de cuota |

---

## 🚨 TROUBLESHOOTING

### ❌ "WebSocket connection refused"

```
✅ Verifica que el backend esté corriendo en http://localhost:8081
✅ Usa ws:// para HTTP, wss:// para HTTPS
✅ No incluyas /topic/matias-webhooks en la URL (se agrega automáticamente)
```

### ❌ "Eventos no llegan a Flutter"

```
✅ Ve a documentos_pendientes_screen.dart línea 67 (backendUrl)
✅ Verifica que el endpoint del webhook está registrado en Matias
✅ Abre DevTools y busca logs: "📨 Evento recibido"
✅ Intenta manualmente con /api/webhooks/matias/test
```

### ❌ "Conexión se desconecta continuamente"

```
✅ Verifica logs del backend para errores
✅ El servicio intenta reconectarse cada 5 segundos (normal)
✅ Si persiste, reinicia el backend
```

### ❌ "BuildRunner no genera el .g.dart"

```bash
flutter pub run build_runner build
# o
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## 📝 ESTRUCTURA DEL PROYECTO

```
lib/
├── models/
│   ├── matias_webhook_event.dart      ← DTO nuevo
│   └── matias_webhook_event.g.dart    ← Generado (no editar)
├── services/
│   ├── matias_webhook_service.dart    ← WebSocket nuevo
│   └── WEBHOOK_BACKEND_REFERENCE.dart ← Documentación
└── screens/
    └── documentos_pendientes_screen.dart ← Integrado
```

---

## ⚙️ CONFIGURACIÓN AVANZADA

### Cambiar URL dinámicamente en tiempo de ejecución

Si quieres permitir cambiar la URL desde UI:

```dart
// En documentos_pendientes_screen.dart, crea un TextField para la URL
String _currentBackendUrl = 'ws://localhost:8081';

// En un diálogo de configuración:
TextFormField(
  initialValue: _currentBackendUrl,
  onSaved: (value) {
    if (value != null && value.isNotEmpty) {
      _webkookService.disconnect();
      _currentBackendUrl = value;
      _setupWebhookListener();
    }
  },
)
```

### Loguear todos los eventos

Modifica `_handleWebhookEvent()` en documentos_pendientes_screen.dart:

```dart
void _handleWebhookEvent(MatiasWebhookEvent evento) {
  appLog('🔔 Evento: ${evento.event}');
  appLog('   Data: ${evento.data?.toJson()}');
  // ... resto del código
}
```

---

## 📞 SOPORTE

Si tienes problemas:

1. Verifica los logs en Flutter DevTools
2. Verifica los logs del backend
3. Intenta con `/api/webhooks/matias/test`
4. Comprueba que ambos (backend + frontend) están en HTTPS o ambos en HTTP

---

## ✨ CARACTERÍSTICAS INCLUIDAS

- ✅ Conexión WebSocket automática
- ✅ Reconexión con límite de intentos
- ✅ Indicador visual de estado (🔌 En línea / ⚠️ Desconectado)
- ✅ Notificaciones en tiempo real
- ✅ Actualización automática de lista
- ✅ Manejo de múltiples tipos de eventos
- ✅ Logging detallado
- ✅ Limpieza de recursos al salir

---

## 🎉 ¡LISTO!

La integración está completada. Solo necesitas:

1. `flutter pub get`
2. Actualizar URL en documentos_pendientes_screen.dart
3. `flutter run`

Disfruta de los webhooks en tiempo real! 🚀

