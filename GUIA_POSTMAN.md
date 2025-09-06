# 📚 Guía de Uso - Postman Collection para Productos

## 📋 Configuración Inicial

### 1. Importar la Colección
1. Abre Postman
2. Haz clic en "Import"
3. Selecciona el archivo `Postman_Collection_Productos.json`
4. La colección "Sopa y Carbón - Productos API" aparecerá en tu workspace

### 2. Configurar Variables
La colección incluye 2 variables que debes configurar:

- `base_url`: Ya está configurada como `http://192.168.1.44:8081`
- `jwt_token`: Debes obtener tu token de autenticación

Para configurar el token JWT:
1. Ejecuta tu login endpoint para obtener el token
2. Copia el token (sin "Bearer ")
3. Ve a la colección → Variables → Edita `jwt_token` → Pega tu token

## 🚀 Flujo Recomendado de Uso

### Paso 1: Obtener IDs de Categorías
```
🗂️ Obtener Categorías
```
Ejecuta este request para obtener todas las categorías con sus IDs. Necesitarás estos IDs para asignar productos a categorías.

### Paso 2: Crear Productos
Tienes varias opciones:

#### Opción A: Producto Individual
```
📦 Crear Producto Individual
```
Modifica el JSON con los datos de tu producto.

#### Opción B: Usando Templates por Categoría
Usa los templates específicos según el tipo de producto:
- `🍽️ Template Platos Principales` - Para platos fuertes
- `🥤 Template Bebidas` - Para jugos, gaseosas, etc.
- `🍰 Template Postres` - Para dulces y postres
- `🍲 Template Sopas` - Para sopas y caldos

#### Opción C: Carga Masiva
```
📦 Carga Masiva de Productos
```
Para cargar múltiples productos de una vez usando el endpoint batch.

### Paso 3: Verificar
```
📋 Obtener Todos los Productos
```
Ejecuta este request para ver todos los productos creados.

## 📝 Campos del Modelo Producto

```json
{
  "nombre": "Nombre del producto",
  "precio": 15000,                 // Precio de venta
  "costo": 8000,                   // Costo de producción  
  "utilidad": 7000,                // precio - costo
  "categoriaId": "ID_CATEGORIA",   // ID de la categoría
  "descripcion": "Descripción",
  "estado": "Activo",              // Activo/Inactivo
  "tieneVariantes": false,         // true si tiene variantes
  "tieneIngredientes": false,      // true si maneja ingredientes
  "tipoProducto": "individual"     // individual/combo/etc
}
```

## 🎯 Tips de Uso

### 1. Precios Sugeridos por Categoría
- **Sopas**: $15,000 - $25,000
- **Platos Principales**: $20,000 - $35,000  
- **Bebidas**: $3,000 - $8,000
- **Postres**: $5,000 - $12,000
- **Entradas**: $8,000 - $15,000

### 2. Cálculo de Utilidad
```
utilidad = precio - costo
```
Recomendación: Mantener margen de utilidad del 40-60%.

### 3. Estados
- `"Activo"` - Producto disponible en el menú
- `"Inactivo"` - Producto no disponible temporalmente

### 4. Tipos de Producto
- `"individual"` - Producto simple
- `"combo"` - Combinación de productos
- `"promocion"` - Ofertas especiales

## 🔧 Personalización de Templates

Puedes modificar los templates según tus necesidades:

1. **Platos Principales**: Ajusta precios para platos de mayor tamaño
2. **Bebidas**: Incluye variantes como tamaños (pequeño/mediano/grande)
3. **Sopas**: Marca `tieneIngredientes: true` si manejas inventario detallado
4. **Postres**: Considera productos con menor costo de ingredientes

## 📊 Workflow Completo de Carga

```
1. Obtener Categorías → Copiar IDs necesarios
2. Preparar lista de productos con sus categorías
3. Para cada producto:
   - Seleccionar template apropiado
   - Modificar datos (nombre, precio, costo, categoriaId)
   - Ejecutar request
4. Verificar con "Obtener Todos los Productos"
```

## 🛠️ Solución de Problemas

### Token Expirado
Si recibes error 401:
1. Renueva tu token JWT
2. Actualiza la variable `jwt_token`

### Categoría No Existe
Si recibes error de categoría:
1. Verifica que el `categoriaId` existe
2. Ejecuta "Obtener Categorías" para confirmar IDs

### Campos Faltantes
Si recibes error de validación:
1. Revisa que todos los campos requeridos estén presentes
2. Verifica tipos de datos (números como números, no strings)

## 🎨 Personalización Adicional

### Agregar Nuevos Templates
1. Duplica un template existente
2. Modifica el nombre y description
3. Ajusta el JSON body según tus necesidades

### Variables Adicionales
Puedes agregar más variables útiles:
- `categoria_bebidas_id`
- `categoria_platos_id`
- `categoria_postres_id`

Esto evita tener que recordar los IDs específicos.

## 📞 Endpoints Disponibles

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/api/categorias` | Obtener todas las categorías |
| GET | `/api/productos` | Obtener todos los productos |
| POST | `/api/productos` | Crear producto individual |
| POST | `/api/productos/batch` | Carga masiva |

¡Con esta colección de Postman podrás cargar todos tus productos de forma rápida y organizada! 🚀
