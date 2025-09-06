# 📸🍽️ Generador de JSON para Productos desde Fotos

## 🎯 Objetivo
Convertir datos de productos de una foto en JSON listo para enviar por Postman a tu API.

## 📋 Campos de tu Modelo (Solo los necesarios)
```json
{
  "nombre": "string (REQUERIDO)",
  "precio": "number (REQUERIDO)", 
  "costo": "number (REQUERIDO)",
  "utilidad": "number (REQUERIDO)",
  "categoriaId": "string (REQUERIDO - obtenido de la consulta)",
  "descripcion": "string (OPCIONAL)",
  "estado": "string (default: 'Activo')",
  "tieneVariantes": "boolean (default: false)",
  "tieneIngredientes": "boolean (default: false)", 
  "tipoProducto": "string (default: 'individual')"
}
```

## 🗂️ PASO 1: Obtener IDs de Categorías

### Endpoint GET para obtener categorías:
```
GET {{tu_servidor}}/api/categorias
Authorization: Bearer {{tu_token}}
```

### 📋 IDs de Categorías Comunes (Actualizar con los reales):
```json
{
  "Platos Principales": "ID_AQUI",
  "Aperitivos": "ID_AQUI", 
  "Bebidas": "ID_AQUI",
  "Postres": "ID_AQUI",
  "Sopas": "ID_AQUI",
  "Carnes": "ID_AQUI",
  "Pollo": "ID_AQUI",
  "Pescados": "ID_AQUI",
  "Vegetariano": "ID_AQUI",
  "Acompañamientos": "ID_AQUI"
}
```

## 📦 PASO 2: Endpoint para Crear Producto

### Método: POST
```
POST {{tu_servidor}}/api/productos
Content-Type: application/json
Authorization: Bearer {{tu_token}}
```

### 📝 Template JSON para UN producto:
```json
{
  "nombre": "NOMBRE_DEL_PRODUCTO",
  "precio": 0000,
  "costo": 0000,
  "utilidad": 0000,
  "categoriaId": "ID_DE_LA_CATEGORIA",
  "descripcion": "Descripción opcional",
  "estado": "Activo",
  "tieneVariantes": false,
  "tieneIngredientes": false,
  "tipoProducto": "individual"
}
```

## 🚀 PASO 3: Carga Masiva (Endpoint para múltiples productos)

Si tu backend soporta carga masiva, usa:
```
POST {{tu_servidor}}/api/productos/bulk
```

### Template para múltiples productos:
```json
[
  {
    "nombre": "Producto 1",
    "precio": 15000,
    "costo": 8000,
    "utilidad": 7000,
    "categoriaId": "ID_CATEGORIA_1",
    "descripcion": "Descripción producto 1"
  },
  {
    "nombre": "Producto 2", 
    "precio": 18000,
    "costo": 10000,
    "utilidad": 8000,
    "categoriaId": "ID_CATEGORIA_1",
    "descripcion": "Descripción producto 2"
  }
]
```

---

## 📸 Instrucciones para Procesar Foto:

### 1. **Toma una foto clara** de los datos del producto
### 2. **Dime la categoría** (ej: "Platos Principales")
### 3. **Yo busco el ID** de esa categoría  
### 4. **Genero el JSON** listo para Postman
### 5. **Copias y pegas** directo en Postman

---

## 📋 Template Rápido - Copia y Personaliza:

### Para Platos Principales:
```json
{
  "nombre": "",
  "precio": 0,
  "costo": 0,
  "utilidad": 0,
  "categoriaId": "ID_PLATOS_PRINCIPALES",
  "descripcion": "",
  "estado": "Activo",
  "tieneIngredientes": false,
  "tipoProducto": "individual"
}
```

### Para Bebidas:
```json
{
  "nombre": "",
  "precio": 0,
  "costo": 0,
  "utilidad": 0,
  "categoriaId": "ID_BEBIDAS",
  "descripcion": "",
  "estado": "Activo",
  "tieneIngredientes": false,
  "tipoProducto": "individual"  
}
```

### Para Postres:
```json
{
  "nombre": "",
  "precio": 0,
  "costo": 0,
  "utilidad": 0,
  "categoriaId": "ID_POSTRES",
  "descripcion": "",
  "estado": "Activo",
  "tieneIngredientes": false,
  "tipoProducto": "individual"
}
```

---

## 🎯 Ejemplo de Flujo Completo:

### 1. Obtienes IDs de categorías:
```bash
curl -X GET "{{tu_servidor}}/api/categorias" \
  -H "Authorization: Bearer {{token}}"
```

### 2. Me mandas foto con productos de "Platos Principales"

### 3. Yo genero JSON como:
```json
[
  {
    "nombre": "Bandeja Paisa",
    "precio": 28000,
    "costo": 15000,
    "utilidad": 13000,
    "categoriaId": "6507f4a1b2c8d90123456789",
    "descripcion": "Plato tradicional con frijoles, arroz, carne, chicharrón, huevo y arepa"
  },
  {
    "nombre": "Sancocho de Gallina", 
    "precio": 25000,
    "costo": 14000,
    "utilidad": 11000,
    "categoriaId": "6507f4a1b2c8d90123456789",
    "descripcion": "Sancocho tradicional con gallina criolla y verduras"
  }
]
```

### 4. Copias y pegas en Postman, cambias a POST, y envías

---

## 🤖 Instrucciones para Mí:
1. **Tu me das una foto** con productos
2. **Me dices la categoría** (ej: "Platos Principales", "Bebidas")
3. **Yo busco el ID** de esa categoría en tus datos
4. **Genero JSON perfecto** con todos los productos de la foto
5. **Listo para copiar/pegar** en Postman

### Formato de respuesta que daré:
```
🗂️ CATEGORÍA: [Nombre de categoría]
🆔 ID: [ID de la categoría]

📦 JSON PARA POSTMAN:
[JSON listo para usar]

📝 INSTRUCCIONES:
1. Copiar JSON
2. Postman → POST {{servidor}}/api/productos 
3. Headers: Authorization: Bearer {{token}}
4. Body → raw → JSON → Pegar
5. Send
```

¿Listo? ¡Mándame la primera foto! 📸
