# Auditoría del Frontend — Vercy Motos (Flutter)

**Fecha:** Julio 2026
**Alcance:** `lib/` del repositorio `Vercy-motos-front-app` (265 archivos Dart, ~134K líneas).
**Contexto:** Complemento de `AUDITORIA_SIN_FILTROS.md` del backend. Mismo tono: directo, con evidencia real del código.

---

## Veredicto en una frase

**El frontend está mejor de lo que el análisis viejo sugería, pero tiene una bomba de tiempo acoplada al backend:** el día que cierres la seguridad del backend (Paso 3 de la auditoría del backend), **~13 servicios de negocio dejan de funcionar** porque hacen llamadas HTTP sin token. No puedes cerrar el backend sin arreglar esto primero. Además, en la versión web —que es tu plataforma principal— el JWT vive en `localStorage` en texto plano.

---

## 🔴 LO CRÍTICO

### 1. El token no viaja en ~13 servicios → cerrar el backend los rompe

Esta es la conexión directa con la auditoría del backend, y es lo más importante de este documento.

**El dato:** hay **262 llamadas HTTP crudas** repartidas en **49 archivos**, pero solo **13 archivos** usan `BaseApiService` (la clase que sí adjunta el `Authorization: Bearer`). El resto arma sus propios headers a mano.

De esos, **13 servicios hacen llamadas HTTP sin token y sin pasar por `BaseApiService`** — verificado:

```
cliente_service.dart          bodega_service.dart
cotizacion_service.dart       documento_mesa_service.dart
factura_compra_service.dart   negocio_info_service.dart
resumen_cierre_service.dart   user_management_service.dart
impresion_service.dart        validacion_caja_util.dart
admin_panel_screen.dart       http_502_hard_reset.dart
main.dart
```

Ejemplo real, [cliente_service.dart:58](../lib/services/cliente_service.dart#L58):
```dart
final response = await http.get(Uri.parse('$baseUrl/$id')).timeout(_timeout);
// ↑ ni headers, ni token
```

**Hoy funciona** porque el backend tiene `permitAll()` (acepta todo sin token). El día que cierres el backend con `.anyRequest().authenticated()`, **todas estas llamadas devuelven 401** y las pantallas de clientes, bodegas, cotizaciones, facturas de compra, configuración del negocio, cierres y gestión de usuarios se rompen.

**Conclusión operativa:** la rama de "cerrar el backend" y la rama de "unificar el cliente HTTP del frontend" **deben desplegarse juntas**, o el frontend primero. No hay forma de hacer uno sin el otro.

**La buena noticia:** ya tienes la solución construida. `BaseApiService.getHeaders()` ([base_api_service.dart:70](../lib/services/base_api_service.dart#L70)) hace exactamente lo correcto. El trabajo es **migrar los 13 servicios a que la usen**, no inventar nada nuevo.

### 2. En web, el JWT está en `localStorage` (texto plano, legible por cualquier XSS)

El proyecto usa `flutter_secure_storage` (bien) para móvil, pero en web hace fallback a `localStorage`. Verificado en varios sitios, [base_api_service.dart:37-39](../lib/services/base_api_service.dart#L37-L39):
```dart
if (kIsWeb) {
  return html.window.localStorage['jwt_token'];   // ← texto plano
} else {
  return await _storage.read(key: 'jwt_token');
}
```

Y también en `user_provider.dart:71/122/145` y `auth_service.dart:216`. Como tu despliegue principal es web (Firebase Hosting: `vercy-motos.web.app`), en la práctica **el JWT de tus usuarios está sin cifrar** en el navegador. Cualquier script malicioso inyectado (o una extensión comprometida) lo lee.

Esto no tiene solución perfecta en Flutter web (localStorage es lo que hay sin backend de sesiones con cookies httpOnly), pero **mitiga mucho** el punto 4 del backend (bajar la expiración del JWT de 29 días a horas): un token robado que caduca en 8h hace mucho menos daño que uno que dura un mes.

### 3. Múltiples fuentes de verdad para el token → bugs de sesión

El token se lee y escribe en **al menos 3 lugares distintos con lógica duplicada**: `auth_service.dart`, `base_api_service.dart`, `user_provider.dart`, más `pedido_service.dart` y `matias_service.dart` que tienen su propio `_getToken()`. Cada uno reimplementa el "si web localStorage, si no secure storage". El día que cambies dónde/cómo guardas el token (ej. para arreglar el punto 2), tienes que acordarte de los 5 sitios. Esto es exactamente cómo aparecen los bugs de "me deslogueó solo" / "quedó logueado con token viejo".

---

## 🟠 LO MAL

### 4. Archivos `.zip` commiteados dentro de `lib/`

```
lib/front.zip              (822 KB)
lib/front (Copia 1).zip    (822 KB)
```

Están **trackeados en git** (`git ls-files` los lista) y `.gitignore` no ignora zips. Es 1.6 MB de código comprimido viviendo dentro de tu carpeta de código fuente, versionado para siempre. Un `lib/` es para `.dart`, no para backups. Bórralos del repo y agrega `*.zip` al `.gitignore`. Si son un respaldo, no es el lugar.

### 5. Archivos de pantalla gigantes

`lib/screens/` son **54 archivos que suman ~76K líneas** (el 57% de todo el código). Los peores:

| Archivo | Líneas |
|---------|--------|
| `facturacion_screen.dart` | **5,952** |
| `productos_screen.dart` | 4,815 |
| `crear_factura_compra_screen.dart` | 4,132 |
| `asesor_pedidos_screen.dart` | 3,770 |
| `productos_list_screen.dart` | 3,687 |

Una pantalla de casi **6,000 líneas** es el equivalente Flutter de tus God Controllers. Mezcla UI + estado + llamadas de red + lógica de negocio en un solo `State`. Es intesteable, imposible de revisar en un PR, y cada cambio arriesga romper algo lejano. La UI de facturación —la más crítica— es la más grande.

### 6. Sin arquitectura de estado consistente

Usas `provider` (bien), pero conviven con `setState` masivo dentro de las pantallas gigantes y servicios que se instancian a mano. No hay una capa clara de "estado de facturación" o "estado de caja". El `_NegocioTab` que el análisis viejo elogia es la excepción, no la regla. Esto no es urgente, pero es la raíz de por qué las pantallas crecen sin control.

### 7. Servicios "de utilidad" que delatan parches sobre parches

`http_502_hard_reset.dart`, `keep_alive_service.dart`, `network_discovery_service.dart`, `auth_diagnostic_service.dart`, `monitored_http_client.dart`. Estos nombres cuentan una historia: el free tier de Render se duerme (502, cold start), y el frontend acumuló mecanismos para pelear con eso —"hard reset", "keep alive"—. **Son síntomas del punto 8 del backend** (plan gratuito). Cuando pases Render a un plan pago, buena parte de este código se vuelve innecesario y lo puedes borrar.

---

## ✅ LO QUE ESTÁS HACIENDO BIEN

1. **`BaseApiService` está bien diseñado.** Centraliza token, headers, `buildUrl`, timeouts y manejo de errores. El problema no es la herramienta —es que solo 13 de 49 archivos la usan. Ya tienes la meta construida; falta migrar.
2. **`flutter_secure_storage` ya está integrado** para móvil. La mitad del trabajo del "punto MEDIO: migrar JWT a secure storage" del análisis viejo **ya está hecho**. Falta solo el caso web (que es más limitación de la plataforma que descuido).
3. **Los bugs DIAN del Documento Soporte parecen corregidos.** Verifiqué `matias_service.dart`: el DS ahora usa `type_document_id: 11` ([línea 271](../lib/services/matias_service.dart#L271)) y `payable_amount` se envía como String ([línea 474](../lib/services/matias_service.dart#L474)). Los 4 bugs críticos que documentaste ya no están en el estado que describía el plan. Bien ahí.
4. **`go_router` para navegación** — decisión correcta y moderna, mejor que Navigator 1.0 a mano.
5. **Manejo de web y móvil desde un solo código** (imports condicionales `dart:html` / stub). Es más trabajo y lo hiciste bien.
6. **Dependencias sanas y actualizadas**: `fl_chart`, `mobile_scanner`, `pdf`/`printing`, `excel`, `provider`. Nada exótico ni abandonado.

---

## 📋 PLAN DE ACCIÓN — en ramas progresivas

Creé 4 ramas en este repo, en orden de prioridad. Trabaja una, pruébala, mézclala, sigue con la siguiente.

### Rama 1 — `fix/http-token-unificado` (BLOQUEANTE, va con el cierre del backend)
- Migrar los 13 servicios sin token a usar `BaseApiService` (o al menos `getHeaders()`).
- Objetivo concreto: que **cero** llamadas HTTP salgan sin `Authorization` cuando hay sesión.
- **Probar contra un backend con seguridad ACTIVADA** (levanta el backend local con la rama `refactor/...` cerrada). Si una pantalla da 401, falta migrar ese servicio.
- Esta rama y el cierre del backend se despliegan juntas o el front primero.

### Rama 2 — `fix/jwt-storage-y-sesion` (seguridad)
- Unificar la lectura/escritura del token en **un solo lugar** (extender `BaseApiService` o un `TokenStorage` único); eliminar los `_getToken()` duplicados de `pedido_service`, `matias_service`, `user_provider`, `auth_service`.
- Coordinar con el backend la bajada de expiración del JWT (mitiga el localStorage en web).
- Asegurar que al hacer logout se borra el token de **todas** las fuentes.

### Rama 3 — `chore/limpieza-repo` (rápida, higiene)
- `git rm lib/front.zip "lib/front (Copia 1).zip"` y agregar `*.zip` al `.gitignore`.
- Borrar la rama muerta `worktree-agent-...` si no se usa.
- Revisar servicios de parcheo (`http_502_hard_reset`, `keep_alive_service`) para retirarlos cuando el backend salga del free tier.

### Rama 4 — `refactor/pantallas-grandes` (largo plazo, calidad)
- Empezar por `facturacion_screen.dart` (5,952 líneas): extraer la lógica de red a servicios y el estado a un provider/notifier.
- No hacer todas de golpe. Una pantalla por PR, la más crítica primero.
- Prerequisito para poder escribir los widget tests / BLoC tests que menciona el análisis.

---

## La conexión entre los dos repos

El hallazgo más importante de esta auditoría no es del frontend solo: es que **el backend y el frontend están acoplados por la ausencia de seguridad**. Hoy "funciona" porque ninguno de los dos exige token. El plan correcto es:

1. Primero: **Rama 1 del frontend** (que todas las llamadas manden token).
2. Luego, coordinado: **cerrar el backend** (Paso 3 de su auditoría) + desplegar el frontend.
3. Probar el flujo completo end-to-end: login → crear pedido → pagar → emitir factura → cierre de caja.

Si cierras el backend sin la Rama 1, rompes la app en producción. Ese es el único orden seguro.
