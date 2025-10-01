# Backend - Endpoint Requerido para Servir Imágenes

## Problema Actual

Las URLs de imágenes como `https://sopa-y-carbon.onrender.com/images/platos/arepa_pollo.jpg` están retornando error **500** porque el backend no tiene un endpoint GET para servir las imágenes almacenadas.

## Solución - Implementación del Endpoint

### Agregar al ImageController.java

```java
@RestController
@RequestMapping("/api")
@CrossOrigin(origins = "*")
public class ImageController {

    // ... métodos existentes para upload ...

    /**
     * Endpoint para servir imágenes de productos
     * GET /api/images/platos/{filename}
     */
    @GetMapping("/images/platos/{filename}")
    public ResponseEntity<Resource> getImage(@PathVariable String filename) {
        try {
            // Ruta donde se almacenan las imágenes (ajustar según tu configuración)
            Path imagePath = Paths.get("uploads/platos").resolve(filename).normalize();

            // Verificar que el archivo existe
            if (!Files.exists(imagePath)) {
                return ResponseEntity.notFound().build();
            }

            // Crear recurso del archivo
            Resource resource = new UrlResource(imagePath.toUri());

            if (!resource.exists() || !resource.isReadable()) {
                return ResponseEntity.notFound().build();
            }

            // Detectar el tipo de contenido
            String contentType = Files.probeContentType(imagePath);
            if (contentType == null) {
                contentType = "application/octet-stream";
            }

            return ResponseEntity.ok()
                    .contentType(MediaType.parseMediaType(contentType))
                    .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"" + filename + "\"")
                    .body(resource);

        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.internalServerError().build();
        }
    }
}
```

### Imports Necesarios

```java
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
```

## Configuración del Directorio de Uploads

### Opción 1: Directorio Local (Desarrollo)

```java
// En application.properties
upload.dir=uploads/platos

// En el controller
@Value("${upload.dir}")
private String uploadDir;

Path imagePath = Paths.get(uploadDir).resolve(filename).normalize();
```

### Opción 2: Directorio Absoluto (Producción)

```java
// Para servidores como Render, usar directorio absoluto
Path imagePath = Paths.get("/app/uploads/platos").resolve(filename).normalize();
```

## URLs Que Funcionarán

Después de implementar este endpoint, estas URLs funcionarán correctamente:

- `https://sopa-y-carbon.onrender.com/api/images/platos/arepa_pollo.jpg`
- `https://sopa-y-carbon.onrender.com/api/images/platos/carne_mechada.jpg`
- `https://sopa-y-carbon.onrender.com/api/images/platos/[cualquier-imagen].jpg`

## Consideraciones de Seguridad

1. **Validación de Archivo**: El código valida que el archivo existe y es legible
2. **Path Traversal Protection**: Se usa `normalize()` para prevenir ataques de path traversal
3. **CORS**: Ya configurado con `@CrossOrigin(origins = "*")`

## Configuración Adicional (Opcional)

### Cache Headers para Mejor Performance

```java
return ResponseEntity.ok()
        .contentType(MediaType.parseMediaType(contentType))
        .header(HttpHeaders.CACHE_CONTROL, "max-age=3600") // Cache por 1 hora
        .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"" + filename + "\"")
        .body(resource);
```

### Logging para Debugging

```java
@GetMapping("/images/platos/{filename}")
public ResponseEntity<Resource> getImage(@PathVariable String filename) {
    System.out.println("🖼️ Solicitando imagen: " + filename);

    try {
        Path imagePath = Paths.get("uploads/platos").resolve(filename).normalize();
        System.out.println("📁 Ruta de imagen: " + imagePath.toString());

        if (!Files.exists(imagePath)) {
            System.out.println("❌ Archivo no encontrado: " + filename);
            return ResponseEntity.notFound().build();
        }

        System.out.println("✅ Sirviendo imagen: " + filename);
        // ... resto del código
    } catch (Exception e) {
        System.out.println("🔥 Error sirviendo imagen: " + e.getMessage());
        e.printStackTrace();
        return ResponseEntity.internalServerError().build();
    }
}
```

## Resultado Esperado

✅ **Antes**: Error 500  
✅ **Después**: Imagen se carga correctamente  
✅ **Frontend**: Los productos mostrarán sus imágenes reales en lugar del ícono por defecto
