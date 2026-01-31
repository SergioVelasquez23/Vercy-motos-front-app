# BACKEND - API de Bodegas/Ubicaciones de Inventario

## Descripción General

El frontend ahora tiene una pantalla completa para gestionar **ubicaciones de inventario** (bodegas, almacenes, puntos de venta, etc.). Esto permitirá que los traslados de inventario y el stock de productos se manejen por ubicación.

## Modelo de Datos

### Bodega.java

```java
@Document(collection = "bodegas")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Bodega {
    @Id
    private String id;
    
    private String nombre;        // Requerido: "BODEGA PRINCIPAL", "ALMACÉN NORTE", etc.
    private String codigo;        // Opcional: "BOD01", "ALM-N01"
    private String tipo;          // Enum: BODEGA, ALMACEN, PUNTO_VENTA, TALLER, DEPOSITO, OTRO
    private String descripcion;   // Descripción detallada
    private String direccion;     // Dirección física
    private String telefono;      // Teléfono de contacto
    private String responsable;   // Nombre del encargado
    private Boolean activa;       // true/false - Estado activo/inactivo
    
    private LocalDateTime fechaCreacion;
    private LocalDateTime fechaActualizacion;
}
```

### Tipos de Bodega (Enum sugerido)
```java
public enum TipoBodega {
    BODEGA,        // Bodega general
    ALMACEN,       // Almacén
    PUNTO_VENTA,   // Local de venta
    TALLER,        // Taller mecánico
    DEPOSITO,      // Depósito temporal
    OTRO           // Otro tipo
}
```

## Endpoints Requeridos

### Base URL: `/api/bodegas`

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/api/bodegas` | Listar todas las bodegas |
| GET | `/api/bodegas/{id}` | Obtener bodega por ID |
| POST | `/api/bodegas` | Crear nueva bodega |
| PUT | `/api/bodegas/{id}` | Actualizar bodega existente |
| DELETE | `/api/bodegas/{id}` | Eliminar bodega |
| PATCH | `/api/bodegas/{id}/toggle-activa` | Activar/Desactivar bodega |
| GET | `/api/bodegas/{id}/stock` | Obtener stock por bodega |

---

## Detalle de Endpoints

### 1. Listar Bodegas
```
GET /api/bodegas
```

**Query Parameters (opcionales):**
- `activa`: boolean - Filtrar solo activas/inactivas
- `tipo`: string - Filtrar por tipo de bodega

**Response 200:**
```json
[
  {
    "id": "BOD001",
    "nombre": "BODEGA PRINCIPAL",
    "codigo": "BOD01",
    "tipo": "BODEGA",
    "descripcion": "Bodega principal de almacenamiento",
    "direccion": "Calle 123 #45-67",
    "telefono": "300 123 4567",
    "responsable": "Juan Pérez",
    "activa": true,
    "fechaCreacion": "2024-01-15T10:30:00",
    "fechaActualizacion": "2024-01-20T15:45:00"
  },
  {
    "id": "ALM001",
    "nombre": "ALMACÉN",
    "codigo": "ALM01",
    "tipo": "ALMACEN",
    "descripcion": "Almacén de repuestos",
    "direccion": null,
    "telefono": null,
    "responsable": "María García",
    "activa": true,
    "fechaCreacion": "2024-01-15T10:30:00",
    "fechaActualizacion": "2024-01-20T15:45:00"
  }
]
```

---

### 2. Obtener Bodega por ID
```
GET /api/bodegas/{id}
```

**Response 200:**
```json
{
  "id": "BOD001",
  "nombre": "BODEGA PRINCIPAL",
  "codigo": "BOD01",
  "tipo": "BODEGA",
  "descripcion": "Bodega principal de almacenamiento",
  "direccion": "Calle 123 #45-67",
  "telefono": "300 123 4567",
  "responsable": "Juan Pérez",
  "activa": true,
  "fechaCreacion": "2024-01-15T10:30:00",
  "fechaActualizacion": "2024-01-20T15:45:00"
}
```

**Response 404:**
```json
{
  "error": "Bodega no encontrada"
}
```

---

### 3. Crear Bodega
```
POST /api/bodegas
Content-Type: application/json
```

**Request Body:**
```json
{
  "nombre": "BODEGA NUEVA",
  "codigo": "BOD02",
  "tipo": "BODEGA",
  "descripcion": "Nueva bodega de almacenamiento",
  "direccion": "Carrera 45 #12-34",
  "telefono": "311 987 6543",
  "responsable": "Carlos López",
  "activa": true
}
```

**Validaciones:**
- `nombre`: Requerido, no puede estar vacío
- `tipo`: Debe ser uno de los valores válidos del enum
- `codigo`: Si se proporciona, debe ser único

**Response 201:**
```json
{
  "id": "BOD002",
  "nombre": "BODEGA NUEVA",
  "codigo": "BOD02",
  "tipo": "BODEGA",
  "descripcion": "Nueva bodega de almacenamiento",
  "direccion": "Carrera 45 #12-34",
  "telefono": "311 987 6543",
  "responsable": "Carlos López",
  "activa": true,
  "fechaCreacion": "2024-01-25T14:00:00",
  "fechaActualizacion": "2024-01-25T14:00:00"
}
```

**Response 400:**
```json
{
  "error": "El nombre es requerido"
}
```

---

### 4. Actualizar Bodega
```
PUT /api/bodegas/{id}
Content-Type: application/json
```

**Request Body:**
```json
{
  "nombre": "BODEGA PRINCIPAL ACTUALIZADA",
  "codigo": "BOD01",
  "tipo": "BODEGA",
  "descripcion": "Bodega principal - Actualizada",
  "direccion": "Nueva dirección 123",
  "telefono": "300 111 2222",
  "responsable": "Pedro Martínez",
  "activa": true
}
```

**Response 200:**
```json
{
  "id": "BOD001",
  "nombre": "BODEGA PRINCIPAL ACTUALIZADA",
  "codigo": "BOD01",
  "tipo": "BODEGA",
  "descripcion": "Bodega principal - Actualizada",
  "direccion": "Nueva dirección 123",
  "telefono": "300 111 2222",
  "responsable": "Pedro Martínez",
  "activa": true,
  "fechaCreacion": "2024-01-15T10:30:00",
  "fechaActualizacion": "2024-01-25T16:00:00"
}
```

---

### 5. Eliminar Bodega
```
DELETE /api/bodegas/{id}
```

**Validaciones antes de eliminar:**
- No debe tener productos con stock asociado
- No debe tener traslados pendientes asociados

**Response 200:**
```json
{
  "message": "Bodega eliminada correctamente"
}
```

**Response 400:**
```json
{
  "error": "No se puede eliminar la bodega porque tiene productos asociados"
}
```

---

### 6. Toggle Activa/Inactiva
```
PATCH /api/bodegas/{id}/toggle-activa
```

**Request Body:**
```json
{
  "activa": false
}
```

**Response 200:**
```json
{
  "id": "BOD001",
  "nombre": "BODEGA PRINCIPAL",
  "activa": false,
  ...
}
```

---

### 7. Obtener Stock por Bodega (Opcional)
```
GET /api/bodegas/{id}/stock
```

**Response 200:**
```json
{
  "bodegaId": "BOD001",
  "bodegaNombre": "BODEGA PRINCIPAL",
  "totalProductos": 150,
  "totalUnidades": 5430,
  "productos": [
    {
      "productoId": "PROD001",
      "nombre": "Aceite 10W40",
      "cantidad": 50,
      "ultimoMovimiento": "2024-01-20T10:00:00"
    },
    ...
  ]
}
```

---

## Implementación Sugerida

### BodegaController.java

```java
@RestController
@RequestMapping("/api/bodegas")
@CrossOrigin(origins = "*")
public class BodegaController {

    @Autowired
    private BodegaService bodegaService;

    @GetMapping
    public ResponseEntity<List<Bodega>> listarBodegas(
            @RequestParam(required = false) Boolean activa,
            @RequestParam(required = false) String tipo) {
        List<Bodega> bodegas = bodegaService.listarBodegas(activa, tipo);
        return ResponseEntity.ok(bodegas);
    }

    @GetMapping("/{id}")
    public ResponseEntity<?> obtenerBodega(@PathVariable String id) {
        try {
            Bodega bodega = bodegaService.obtenerPorId(id);
            return ResponseEntity.ok(bodega);
        } catch (NotFoundException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(Map.of("error", e.getMessage()));
        }
    }

    @PostMapping
    public ResponseEntity<?> crearBodega(@RequestBody Bodega bodega) {
        try {
            Bodega nueva = bodegaService.crearBodega(bodega);
            return ResponseEntity.status(HttpStatus.CREATED).body(nueva);
        } catch (ValidationException e) {
            return ResponseEntity.badRequest()
                .body(Map.of("error", e.getMessage()));
        }
    }

    @PutMapping("/{id}")
    public ResponseEntity<?> actualizarBodega(
            @PathVariable String id, 
            @RequestBody Bodega bodega) {
        try {
            Bodega actualizada = bodegaService.actualizarBodega(id, bodega);
            return ResponseEntity.ok(actualizada);
        } catch (NotFoundException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(Map.of("error", e.getMessage()));
        } catch (ValidationException e) {
            return ResponseEntity.badRequest()
                .body(Map.of("error", e.getMessage()));
        }
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> eliminarBodega(@PathVariable String id) {
        try {
            bodegaService.eliminarBodega(id);
            return ResponseEntity.ok(Map.of("message", "Bodega eliminada correctamente"));
        } catch (NotFoundException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(Map.of("error", e.getMessage()));
        } catch (BusinessException e) {
            return ResponseEntity.badRequest()
                .body(Map.of("error", e.getMessage()));
        }
    }

    @PatchMapping("/{id}/toggle-activa")
    public ResponseEntity<?> toggleActiva(
            @PathVariable String id,
            @RequestBody Map<String, Boolean> request) {
        try {
            Boolean activa = request.get("activa");
            Bodega bodega = bodegaService.toggleActiva(id, activa);
            return ResponseEntity.ok(bodega);
        } catch (NotFoundException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/{id}/stock")
    public ResponseEntity<?> obtenerStockPorBodega(@PathVariable String id) {
        try {
            Map<String, Object> stock = bodegaService.obtenerStockPorBodega(id);
            return ResponseEntity.ok(stock);
        } catch (NotFoundException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(Map.of("error", e.getMessage()));
        }
    }
}
```

### BodegaService.java

```java
@Service
public class BodegaService {

    @Autowired
    private BodegaRepository bodegaRepository;
    
    @Autowired
    private InventarioBodegaRepository inventarioBodegaRepository;

    public List<Bodega> listarBodegas(Boolean activa, String tipo) {
        if (activa != null && tipo != null) {
            return bodegaRepository.findByActivaAndTipo(activa, tipo);
        } else if (activa != null) {
            return bodegaRepository.findByActiva(activa);
        } else if (tipo != null) {
            return bodegaRepository.findByTipo(tipo);
        }
        return bodegaRepository.findAll();
    }

    public Bodega obtenerPorId(String id) {
        return bodegaRepository.findById(id)
            .orElseThrow(() -> new NotFoundException("Bodega no encontrada"));
    }

    public Bodega crearBodega(Bodega bodega) {
        // Validaciones
        if (bodega.getNombre() == null || bodega.getNombre().trim().isEmpty()) {
            throw new ValidationException("El nombre es requerido");
        }
        
        // Verificar código único si se proporciona
        if (bodega.getCodigo() != null && !bodega.getCodigo().trim().isEmpty()) {
            if (bodegaRepository.existsByCodigo(bodega.getCodigo())) {
                throw new ValidationException("Ya existe una bodega con ese código");
            }
        }
        
        bodega.setFechaCreacion(LocalDateTime.now());
        bodega.setFechaActualizacion(LocalDateTime.now());
        
        if (bodega.getActiva() == null) {
            bodega.setActiva(true);
        }
        
        return bodegaRepository.save(bodega);
    }

    public Bodega actualizarBodega(String id, Bodega bodegaData) {
        Bodega bodega = obtenerPorId(id);
        
        if (bodegaData.getNombre() != null) {
            bodega.setNombre(bodegaData.getNombre());
        }
        bodega.setCodigo(bodegaData.getCodigo());
        bodega.setTipo(bodegaData.getTipo());
        bodega.setDescripcion(bodegaData.getDescripcion());
        bodega.setDireccion(bodegaData.getDireccion());
        bodega.setTelefono(bodegaData.getTelefono());
        bodega.setResponsable(bodegaData.getResponsable());
        
        if (bodegaData.getActiva() != null) {
            bodega.setActiva(bodegaData.getActiva());
        }
        
        bodega.setFechaActualizacion(LocalDateTime.now());
        
        return bodegaRepository.save(bodega);
    }

    public void eliminarBodega(String id) {
        Bodega bodega = obtenerPorId(id);
        
        // Verificar que no tenga inventario asociado
        long countInventario = inventarioBodegaRepository.countByBodegaId(id);
        if (countInventario > 0) {
            throw new BusinessException(
                "No se puede eliminar la bodega porque tiene " + countInventario + " productos asociados"
            );
        }
        
        bodegaRepository.delete(bodega);
    }

    public Bodega toggleActiva(String id, Boolean activa) {
        Bodega bodega = obtenerPorId(id);
        bodega.setActiva(activa);
        bodega.setFechaActualizacion(LocalDateTime.now());
        return bodegaRepository.save(bodega);
    }

    public Map<String, Object> obtenerStockPorBodega(String id) {
        Bodega bodega = obtenerPorId(id);
        
        List<InventarioBodega> inventario = inventarioBodegaRepository.findByBodegaId(id);
        
        int totalProductos = inventario.size();
        int totalUnidades = inventario.stream()
            .mapToInt(InventarioBodega::getCantidad)
            .sum();
        
        return Map.of(
            "bodegaId", bodega.getId(),
            "bodegaNombre", bodega.getNombre(),
            "totalProductos", totalProductos,
            "totalUnidades", totalUnidades,
            "productos", inventario
        );
    }
}
```

### BodegaRepository.java

```java
@Repository
public interface BodegaRepository extends MongoRepository<Bodega, String> {
    
    List<Bodega> findByActiva(Boolean activa);
    
    List<Bodega> findByTipo(String tipo);
    
    List<Bodega> findByActivaAndTipo(Boolean activa, String tipo);
    
    boolean existsByCodigo(String codigo);
    
    Optional<Bodega> findByCodigo(String codigo);
}
```

---

## Datos Iniciales (Migración)

Para mantener compatibilidad con los datos existentes, crear las siguientes bodegas por defecto:

```javascript
// MongoDB Script
db.bodegas.insertMany([
  {
    _id: "BODEGA",
    nombre: "BODEGA",
    codigo: "BOD",
    tipo: "BODEGA",
    descripcion: "Bodega principal de inventario",
    activa: true,
    fechaCreacion: new Date(),
    fechaActualizacion: new Date()
  },
  {
    _id: "ALMACEN",
    nombre: "ALMACÉN",
    codigo: "ALM",
    tipo: "ALMACEN",
    descripcion: "Almacén secundario",
    activa: true,
    fechaCreacion: new Date(),
    fechaActualizacion: new Date()
  }
]);
```

---

## Integración con Traslados

El servicio de traslados ya existente debe usar estas bodegas dinámicamente. Actualizar el frontend de traslados para cargar las bodegas desde `/api/bodegas` en lugar de usar la lista hardcodeada actual.

---

## Notas Importantes

1. **Compatibilidad**: Mantener los IDs "BODEGA" y "ALMACEN" para no romper traslados existentes
2. **Fallback**: El frontend tiene un fallback que usa las bodegas hardcodeadas si el endpoint falla
3. **Validación de eliminación**: No permitir eliminar bodegas que tengan inventario asociado
4. **Stock por bodega**: El endpoint `/api/bodegas/{id}/stock` es opcional pero muy útil para mostrar el inventario por ubicación

---

## Testing Manual

```bash
# Listar todas las bodegas
curl -X GET "https://vercy-motos-app.onrender.com/api/bodegas"

# Crear nueva bodega
curl -X POST "https://vercy-motos-app.onrender.com/api/bodegas" \
  -H "Content-Type: application/json" \
  -d '{"nombre": "PUNTO DE VENTA", "tipo": "PUNTO_VENTA", "activa": true}'

# Actualizar bodega
curl -X PUT "https://vercy-motos-app.onrender.com/api/bodegas/BOD001" \
  -H "Content-Type: application/json" \
  -d '{"nombre": "BODEGA ACTUALIZADA", "tipo": "BODEGA"}'

# Toggle activa
curl -X PATCH "https://vercy-motos-app.onrender.com/api/bodegas/BOD001/toggle-activa" \
  -H "Content-Type: application/json" \
  -d '{"activa": false}'

# Eliminar bodega
curl -X DELETE "https://vercy-motos-app.onrender.com/api/bodegas/BOD001"
```
