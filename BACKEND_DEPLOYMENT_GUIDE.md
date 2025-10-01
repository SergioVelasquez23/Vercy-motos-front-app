# Guía de Despliegue del Backend - ImageController

## 1. Implementar ImageController

### Archivo: `ImageController.java`

```java
// El código completo del ImageController que proporcionaste anteriormente
// Debe colocarse en: src/main/java/com/restaurant/controller/ImageController.java
```

## 2. Verificar Estructura de Directorios

### En el servidor (producción):

```
├── uploads/
│   └── platos/
│       ├── [archivos de imagen existentes]
│       └── ...
└── src/main/resources/static/images/platos/
    ├── [imágenes de respaldo]
    └── ...
```

## 3. Comandos de Despliegue

### Si usas Git para desplegar:

```bash
git add .
git commit -m "Implementar ImageController con endpoints GET para servir imágenes"
git push origin main
```

### Reiniciar servidor Spring Boot:

```bash
# En el servidor de producción
./mvnw spring-boot:stop
./mvnw spring-boot:run
# O el método que uses para reiniciar
```

## 4. Verificación Post-Despliegue

### Probar endpoints directamente:

```bash
# Lista de imágenes disponibles
curl https://sopa-y-carbon.onrender.com/api/images/list

# Verificar imagen específica
curl https://sopa-y-carbon.onrender.com/api/images/check/9df0f6e1-d9f5-487a-84b2-7d9de4838523.png

# Acceder a imagen
curl -I https://sopa-y-carbon.onrender.com/images/platos/9df0f6e1-d9f5-487a-84b2-7d9de4838523.png
```

## 5. Imágenes Detectadas que Necesitan Resolución

Basado en los logs, estas imágenes necesitan estar disponibles:

- `9df0f6e1-d9f5-487a-84b2-7d9de4838523.png`
- `2b23a164-5eff-4f4c-aeb9-ccb11ed30a6c.png`
- `0a47bb8b-9251-4c5d-a27b-2c7d46168f13.jpg`
- `03d871e6-c0ce-42ac-9167-26120b1e956d.jpg`

## 6. Resultados Esperados

Después del despliegue:

- ✅ Status 200 en lugar de 404
- ✅ Imágenes cargando correctamente
- ✅ Logs sin errores de red
- ✅ Iconos de fallback solo cuando realmente no existe la imagen

## 7. Debugging

Si persisten problemas:

1. Verificar logs del servidor Spring Boot
2. Confirmar que los archivos existen en `uploads/platos/`
3. Verificar permisos de lectura en directorios
4. Probar endpoints de debugging: `/api/images/list` y `/api/images/check/{filename}`
