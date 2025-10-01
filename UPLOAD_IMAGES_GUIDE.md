# Guía para Subir Imágenes al Servidor

## Estado Actual

✅ Backend funcionando con ImageController  
✅ Directorios configurados correctamente  
❌ **0 imágenes disponibles en el servidor**

## Imágenes que Necesitan Subirse

Basado en los logs de errores 404, estas imágenes necesitan estar en el servidor:

```
9df0f6e1-d9f5-487a-84b2-7d9de4838523.png
2b23a164-5eff-4f4c-aeb9-ccb11ed30a6c.png
0a47bb8b-9251-4c5d-a27b-2c7d46168f13.jpg
03d871e6-c0ce-42ac-9167-26120b1e956d.jpg
```

## Opciones para Subir Imágenes

### Opción 1: API Upload Endpoint

```bash
# Usando curl para subir una imagen
curl -X POST \
  -F "file=@ruta/local/imagen.jpg" \
  https://sopa-y-carbon.onrender.com/api/images/upload

# Ejemplo con imagen específica
curl -X POST \
  -F "file=@./assets/images/productos/9df0f6e1-d9f5-487a-84b2-7d9de4838523.png" \
  https://sopa-y-carbon.onrender.com/api/images/upload
```

### Opción 2: Interfaz Web (si existe)

Si tienes una interfaz de administración en tu app, puedes usar el endpoint de upload desde allí.

### Opción 3: Subir Multiple Archivos

```bash
# Script para subir todas las imágenes
for file in assets/images/productos/*.{jpg,png,jpeg}; do
  if [ -f "$file" ]; then
    echo "Subiendo: $file"
    curl -X POST -F "file=@$file" https://sopa-y-carbon.onrender.com/api/images/upload
    echo ""
  fi
done
```

## Verificación Post-Subida

### 1. Verificar lista de imágenes:

```bash
curl https://sopa-y-carbon.onrender.com/api/images/list
```

### 2. Probar imagen específica:

```bash
curl -I https://sopa-y-carbon.onrender.com/images/platos/9df0f6e1-d9f5-487a-84b2-7d9de4838523.png
```

### 3. Verificar en la app web:

- Refrescar la aplicación
- Los errores 404 deberían desaparecer
- Las imágenes deberían cargar correctamente

## Estructura Esperada Después de la Subida

```
servidor/uploads/platos/
├── 9df0f6e1-d9f5-487a-84b2-7d9de4838523.png
├── 2b23a164-5eff-4f4c-aeb9-ccb11ed30a6c.png
├── 0a47bb8b-9251-4c5d-a27b-2c7d46168f13.jpg
├── 03d871e6-c0ce-42ac-9167-26120b1e956d.jpg
└── [otras imágenes...]
```

## Resultado Final Esperado

Después de subir las imágenes:

- ✅ Status 200 en lugar de 404
- ✅ Imágenes visibles en la aplicación
- ✅ Sin errores en la consola del navegador
- ✅ El endpoint `/api/images/list` mostrará las imágenes disponibles

## Nota Importante

Las imágenes deben tener **exactamente los mismos nombres** que aparecen en los errores 404 para que la aplicación las encuentre correctamente.
