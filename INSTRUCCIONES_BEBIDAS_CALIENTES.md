# 🔥 Carga de Bebidas Calientes - Instrucciones

## 📋 Productos a Cargar

Basándome en tu imagen, he preparado el JSON con estos 5 productos:

1. **Aromática** - $2,000
2. **Café con Leche** - $3,500  
3. **Chocolate** - $5,500
4. **Milo Caliente** - $4,500
5. **Tinto** - $2,000

## 🚀 Pasos para Cargar en Postman

### Paso 1: Obtener el ID de "Bebidas Calientes"
1. En Postman, ejecuta: `🗂️ Obtener Categorías`
2. Busca en la respuesta la categoría "Bebidas Calientes" 
3. Copia su ID (algo como: `"672abc123def456789012345"`)

### Paso 2: Actualizar el JSON
1. Abre el archivo `JSON_Bebidas_Calientes.json`
2. Reemplaza **TODOS** los `"ID_BEBIDAS_CALIENTES"` con el ID real
3. Ejemplo: Cambiar `"ID_BEBIDAS_CALIENTES"` por `"672abc123def456789012345"`

### Paso 3: Cargar los Productos

#### Opción A: Carga Masiva (Recomendada)
1. En Postman, selecciona: `📦 Carga Masiva de Productos`
2. En el Body, reemplaza todo el contenido con el JSON del archivo
3. Clic en "Send"
4. ¡Listo! Los 5 productos se cargarán de una vez

#### Opción B: Individual (Si la carga masiva no funciona)
1. Usa: `📦 Crear Producto Individual`
2. Copia y pega cada producto uno por uno del JSON
3. Ejecuta 5 veces, una por cada producto

### Paso 4: Verificar
1. Ejecuta: `📋 Obtener Todos los Productos`
2. Confirma que aparezcan las 5 bebidas calientes

## 🔧 JSON Listo para Copiar

El archivo `JSON_Bebidas_Calientes.json` contiene el array completo.
Solo necesitas reemplazar `ID_BEBIDAS_CALIENTES` con el ID real.

## 💡 Notas Importantes

- **Costos en $0**: Puedes ajustarlos después si manejas costos específicos
- **Precios**: Basados en la imagen que proporcionaste
- **Descripciones**: Agregué descripciones atractivas para el menú
- **Estado**: Todos están marcados como "Activo"

## ⚡ Resultado Esperado

Después de la carga exitosa, tendrás:
- ✅ 5 nuevas bebidas calientes en tu base de datos
- ✅ Precios configurados según tu imagen
- ✅ Productos listos para aparecer en tu app

¡Con esto completarás la sección de Bebidas Calientes! ☕🔥
