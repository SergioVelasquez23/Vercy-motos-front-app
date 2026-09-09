# Plantilla de PRD — Vercy Motos

> Copia este archivo a `docs/prd/PRD_<slug-feature>.md` y rellena cada sección.
> Borra las notas en cursiva. Si una sección no aplica, escribe "N/A" y por qué.
> Mantén el PRD vivo: actualízalo cuando cambie el alcance.

---

## 0. Metadatos

| Campo | Valor |
|---|---|
| **Feature** | _Nombre corto y claro_ |
| **Slug** | _kebab-case, usado en ramas y archivos_ |
| **Autor(es)** | |
| **Estado** | Borrador · En revisión · Aprobado · En desarrollo · Entregado · Archivado |
| **Fecha creación** | _AAAA-MM-DD_ |
| **Última actualización** | _AAAA-MM-DD_ |
| **Épica / Issue** | _enlace_ |
| **Rama** | _feat/&lt;slug&gt;_ |

---

## 1. Resumen ejecutivo

_2–4 frases: qué se construye, para quién y por qué ahora. Un lector debería
entender la propuesta sin leer el resto del documento._

---

## 2. Problema y contexto

- **Problema:** _¿Qué duele hoy? Descríbelo desde el usuario/negocio, no desde la solución._
- **Evidencia:** _tickets, feedback, métricas, capturas, quejas recurrentes._
- **Estado actual:** _cómo se resuelve hoy (workaround, proceso manual, nada)._
- **Impacto de no hacerlo:** _qué pasa si lo dejamos como está._

---

## 3. Objetivos y métricas de éxito

### Objetivos
1. _Objetivo medible 1_
2. _Objetivo medible 2_

### Métricas / criterios de éxito
| Métrica | Valor actual | Meta | Cómo se mide |
|---|---|---|---|
| | | | |

### No-objetivos (fuera de alcance)
- _Lo que explícitamente NO se hace en esta iteración y por qué._

---

## 4. Usuarios y casos de uso

- **Perfiles afectados:** _admin, vendedor, mecánico, cliente…_
- **Caso de uso principal:**
  1. _paso_
  2. _paso_
- **Casos secundarios / borde:** _listar._

---

## 5. Requisitos funcionales

_Enumerados y verificables. Prioriza con MoSCoW (Must / Should / Could / Won't)._

| ID | Prioridad | Requisito | Notas |
|---|---|---|---|
| RF-1 | Must | El sistema debe… | |
| RF-2 | Should | | |
| RF-3 | Could | | |

---

## 6. Requisitos no funcionales

- **Rendimiento:** _tiempos de carga, tamaño de página, uso de caché._
- **Offline / conectividad:** _comportamiento sin red, reintentos, colas._
- **Seguridad y permisos:** _roles que pueden ver/hacer qué._
- **Accesibilidad / UX:** _estados de carga, error y vacío; feedback al usuario._
- **Compatibilidad:** _versiones de Android/iOS/web soportadas._
- **Observabilidad:** _logs, analytics, eventos que hay que registrar._

---

## 7. Diseño de la solución

### 7.1 Flujo de usuario
_Diagrama o lista de pantallas y transiciones. Enlaza mockups si existen._

### 7.2 UI / componentes
- _Pantallas nuevas o modificadas._
- _Componentes reutilizables involucrados._
- _Estados: cargando, vacío, error, éxito._

### 7.3 Frontend (Flutter)
- **Módulos / carpetas afectadas:** _lib/…_
- **Estado / gestión de datos:** _providers, servicios, caché en memoria._
- **Modelos nuevos o cambiados:** _clases, serialización._

### 7.4 Backend / API
| Endpoint | Método | Request | Response | Estado |
|---|---|---|---|---|
| `/…` | GET | | | Existe / Por crear / Por modificar |

- **Cambios de contrato:** _campos nuevos, paginación, filtros._
- **Migraciones de datos:** _N/A o describir._

### 7.5 Caché e invalidación
_Qué se cachea, TTL, y en qué eventos se invalida (crear, editar, emitir, cobrar…)._

---

## 8. Dependencias y riesgos

| Tipo | Descripción | Mitigación |
|---|---|---|
| Dependencia | _Requiere cambio en backend X_ | |
| Riesgo | _…_ | |
| Supuesto | _Asumimos que…_ | |

---

## 9. Plan de entrega

### Fases
- [ ] **Fase 1 — _nombre_:** _entregable_
- [ ] **Fase 2 — _nombre_:** _entregable_

### Feature flag / rollout
_¿Se lanza detrás de flag? ¿Rollout gradual? ¿Cómo se revierte?_

---

## 10. Pruebas y criterios de aceptación

### Criterios de aceptación (Given / When / Then)
1. **Dado** _contexto_, **cuando** _acción_, **entonces** _resultado esperado_.
2. …

### Cobertura de pruebas
- **Unitarias:** _qué lógica._
- **Widget / integración:** _qué flujos._
- **Manual / QA:** _checklist antes de mergear._

---

## 11. Impacto en documentación

- _Actualizar `docs/…`_
- _Notas de release / changelog._

---

## 12. Preguntas abiertas

- [ ] _Pregunta pendiente de resolver antes de aprobar._

---

## 13. Registro de cambios del PRD

| Fecha | Autor | Cambio |
|---|---|---|
| _AAAA-MM-DD_ | | Creación |
