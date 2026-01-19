# Guía de Uso - Configuración DIAN para Facturación Electrónica

## 🎯 Descripción General

Se ha implementado un sistema completo para gestionar la configuración de facturación electrónica según los requisitos de la DIAN en Colombia. Esto incluye:

- ✅ Todos los campos de la resolución DIAN
- ✅ Información del software y PIN
- ✅ TestSetId para ambiente de pruebas
- ✅ Certificado digital
- ✅ Modo producción/pruebas
- ✅ Proveedor tecnológico (opcional)
- ✅ Persistencia en base de datos

## 📁 Archivos Creados/Modificados

### Frontend (Flutter)

1. **lib/models/configuracion_dian.dart** (NUEVO)
   - Modelo completo con todos los campos de configuración DIAN
   - Incluye: resolución, software, certificado, TestSetId, etc.

2. **lib/services/configuracion_facturacion_service.dart** (MODIFICADO)
   - Agregados métodos para guardar/obtener configuración completa
   - `guardarConfiguracionDian()`
   - `obtenerConfiguracionDian()`
   - `actualizarConsecutivoActual()`

3. **lib/screens/configuracion_dian_completa.dart** (NUEVO)
   - Pantalla con 4 pestañas para configurar todos los datos
   - Validación de formularios
   - Integración con el servicio de configuración

### Backend

4. **BACKEND_CONFIGURACION_DIAN.md** (NUEVO)
   - Documentación completa del schema de MongoDB
   - Endpoints necesarios
   - Ejemplos de controladores y rutas
   - Notas de implementación y seguridad

## 🚀 Cómo Usar

### 1. Navegar a la Pantalla de Configuración

```dart
// Desde cualquier parte de tu app
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const ConfiguracionDianCompleta(),
  ),
);
```

### 2. Integrar en el Menú Existente

Si ya tienes una pantalla de facturación (como `prueba_facturacion_screen.dart`), puedes agregar un botón:

```dart
// En el AppBar o en un FloatingActionButton
IconButton(
  icon: const Icon(Icons.settings),
  tooltip: 'Configuración DIAN',
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ConfiguracionDianCompleta(),
      ),
    );
  },
)
```

### 3. Llenar los Datos

La pantalla tiene 4 pestañas:

#### Pestaña 1: Empresa
- Razón social
- NIT y dígito de verificación
- Nombre comercial
- Régimen tributario
- Dirección completa
- Ciudad y departamento con códigos DANE
- Teléfono y email

#### Pestaña 2: Resolución DIAN
- **Clave técnica de resolución** (ejemplo de tu imagen: `d075145f255e7513efdeb638238fdd1765f8f4d179d038c290abdd8d10245770`)
- **Prefijo resolución** (ejemplo: `SC`)
- **Número resolución** (ejemplo: `18764101895165`)
- **Rangos de numeración** (inicial: `1`, final: `10000`)
- **Fechas válidas** (desde: `2025-11-21`, hasta: `2027-11-21`)
- **Número inicial de factura** (ejemplo: `1`)
- **Modo de operación** y fechas
- **Rango asignado** (prefijo: `SETP`, rango: `990000000` - `995000000`)

#### Pestaña 3: Software y Certificado
- **Software ID** (ejemplo de tu imagen: `66f373d2-a05a-407d-a079-fb2c`)
- **Nombre del software** (ejemplo: `Vercy Motos`)
- **Clave técnica del software** (ejemplo: `fc8eac422eba16e22ffd8c6f94b`)
- **PIN** (ejemplo: `77777`)
- **Certificado digital** (contenido o ruta)
- **Contraseña del certificado**
- **Fecha de vencimiento del certificado**
- **TestSetId** para pruebas (ejemplo: `03966238-b459-4231-baeb-95e4991c0784`)
- **Switch Modo Producción/Pruebas**

#### Pestaña 4: Adicional
- Datos del proveedor tecnológico (si aplica)
- URL del web service
- Notas adicionales

### 4. Guardar la Configuración

Al presionar el botón "Guardar":
1. Se validan todos los campos requeridos
2. Se guardan los datos del emisor
3. Se guarda la configuración DIAN completa
4. Todo se persiste en MongoDB
5. Se muestra un mensaje de confirmación

## 🔐 Seguridad

La información sensible (PIN, certificado, contraseña) se envía de forma segura:
- Conexión HTTPS
- Autenticación JWT
- Debe encriptarse en el backend

## 📊 Uso en Facturas Electrónicas

Una vez configurado, estos datos se usan automáticamente al generar facturas:

```dart
// El servicio de facturación usará la configuración guardada
final config = await ConfiguracionFacturacionService().obtenerConfiguracionDian();

// Generar factura con los datos configurados
final factura = await FacturaElectronicaService.generarFacturaDesdeDocumentoMesa(
  documentoMesa: documento,
  // Los datos de configuración se toman automáticamente
);
```

## 📝 Campos Importantes según la DIAN

### Para Envío XML:
Cada envío de factura electrónica requiere:
1. ✅ **XML UBL** (generado automáticamente)
2. ✅ **Firma digital** (usando el certificado configurado)
3. ✅ **TestSetId** (durante habilitación) o sin él (en producción)
4. ✅ **SoftwareID** (configurado en la pestaña 3)
5. ✅ **PIN** (configurado en la pestaña 3)
6. ✅ **Certificado** (configurado en la pestaña 3)

### Proceso de Habilitación:
1. Configurar con `esModoProduccion = false`
2. Agregar el `TestSetId` que proporciona la DIAN
3. Generar facturas de prueba
4. Una vez aprobado por la DIAN, cambiar `esModoProduccion = true`
5. Quitar el `TestSetId`

## 🔄 Actualización del Consecutivo

El consecutivo de facturación se actualiza automáticamente, pero también puedes actualizarlo manualmente:

```dart
await ConfiguracionFacturacionService().actualizarConsecutivoActual('150');
```

## ⚠️ Notas Importantes

1. **Clave Técnica Resolución**: Es un hash SHA-384 largo que proporciona la DIAN
2. **TestSetId**: Solo se usa durante el proceso de habilitación (pruebas)
3. **Certificado**: Puede ser el contenido en base64 o la ruta al archivo
4. **PIN**: Es el código de seguridad del software registrado ante la DIAN
5. **Modo Producción**: Asegúrate de estar en pruebas hasta que la DIAN apruebe tu habilitación

## 🐛 Troubleshooting

### Error: "No se encontró configuración"
- Asegúrate de haber guardado la configuración al menos una vez
- Verifica que el backend tenga el endpoint `/api/configuracion/facturacion/dian`

### Error al guardar
- Verifica la conexión con el backend
- Revisa que todos los campos requeridos (*) estén llenos
- Verifica los logs del backend

### Campos vacíos al abrir la pantalla
- Es normal la primera vez
- Después de guardar, los datos se cargarán automáticamente

## 📱 Ejemplo de Integración Completa

```dart
// En tu menú principal o pantalla de facturación
class PruebaFacturacionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Facturación Electrónica'),
        actions: [
          // Botón para abrir configuración
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configuración DIAN',
            onPressed: () async {
              final resultado = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ConfiguracionDianCompleta(),
                ),
              );
              
              if (resultado == true) {
                // Configuración guardada exitosamente
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Configuración actualizada'),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: // ... tu contenido ...
    );
  }
}
```

## 🎨 Personalización

Puedes personalizar los colores y estilos de la pantalla modificando:
- Los colores de los `_buildInfoCard()`
- Los iconos de los campos
- El número y contenido de las pestañas

## 📞 Soporte

Si tienes dudas sobre qué datos específicos debes ingresar:
1. Consulta la resolución que te proporcionó la DIAN
2. Revisa el portal de la DIAN en tu cuenta de facturación electrónica
3. Contacta al soporte técnico de la DIAN

## ✅ Checklist de Configuración

- [ ] Datos de la empresa completados
- [ ] Clave técnica de resolución ingresada
- [ ] Prefijo y número de resolución correctos
- [ ] Rangos de numeración configurados
- [ ] Fechas de validez de la resolución
- [ ] Software ID registrado ante la DIAN
- [ ] PIN del software correcto
- [ ] Certificado digital cargado
- [ ] TestSetId (si estás en pruebas)
- [ ] Modo producción/pruebas correctamente configurado
- [ ] Configuración guardada exitosamente
- [ ] Prueba generando una factura para verificar
