# Instrucciones para Cargar Productos de Bebidas Frías

## Información de la Categoría
- **Nombre**: Bebidas frías  
- **ID de Categoría**: `688e55225b11ec6a26b76f93`

## Archivos Creados
1. **productos_bebidas_frias.json** - Contiene 10 productos de bebidas frías

## Cómo cargar en Postman

### 1. Abrir Postman
- Abre Postman en tu computadora

### 2. Configurar la Solicitud
- **Método**: `POST`
- **URL**: `http://192.168.1.44:8081/api/productos/batch`
- **Headers**: 
  - `Content-Type`: `application/json`

### 3. Cargar el JSON
- Ve a la pestaña **Body**
- Selecciona **raw**
- Asegúrate que esté seleccionado **JSON**
- Copia y pega todo el contenido del archivo `productos_bebidas_frias.json`

### 4. Enviar la Solicitud
- Haz clic en **Send**
- Verifica que recibas una respuesta exitosa

## Productos Incluidos
1. **Agua Mineral Sin Gas 500ml** - $2,500
2. **Agua Mineral Con Gas 500ml** - $2,800
3. **Coca Cola 350ml** - $3,500
4. **Pepsi 350ml** - $3,500
5. **Jugo de Naranja Natural 300ml** - $4,500
6. **Limonada Natural 400ml** - $3,500
7. **Té Helado de Limón 500ml** - $4,000
8. **Smoothie de Frutas Tropicales 400ml** - $6,500
9. **Jugo de Mora 350ml** - $4,800
10. **Cerveza Nacional 330ml** - $4,500

## Notas Importantes
- El ID de categoría (`688e55225b11ec6a26b76f93`) corresponde exactamente a "Bebidas frías" en tu base de datos
- Las imágenes están configuradas como placeholders. Puedes reemplazar los `imagen_url` con las imágenes reales
- Todos los productos incluyen información nutricional completa
- Los precios están en pesos colombianos

## Si necesitas modificar algo
1. Edita el archivo `productos_bebidas_frias.json`
2. Guarda los cambios
3. Vuelve a hacer la solicitud POST en Postman

## Verificar la carga
Después de cargar, puedes verificar que los productos se cargaron correctamente haciendo una solicitud GET a:
`http://192.168.1.44:8081/api/productos`
