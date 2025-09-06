# 💰 Contador de Efectivo con Exportación Excel

## 📋 Funcionalidades Implementadas

### ✅ **Contador de Billetes y Monedas Colombianas**
- **Billetes soportados**: $100.000, $50.000, $20.000, $10.000, $5.000, $2.000, $1.000
- **Monedas soportadas**: $1.000, $500, $200, $100, $50
- **Cálculo automático** de subtotales por denominación
- **Totales separados** para billetes y monedas
- **Total general** con actualización en tiempo real

### ✅ **Integración con Cuadre de Caja**
- **Acceso directo** desde el formulario de cuadre (botón calculadora 🧮)
- **Autocompletado** del campo de efectivo con el total calculado
- **Menú principal** con opción "Contador de Efectivo"
- **Validación** de permisos de administrador

### ✅ **Exportación a Excel**
- **Archivo Excel completo** con formato profesional
- **Metadatos incluidos**: fecha, hora, usuario, observaciones
- **Separación por categorías**: billetes y monedas
- **Cálculos automáticos**: subtotales y total general
- **Estilos profesionales**: colores, fuentes, bordes

### ✅ **Funcionalidades adicionales**
- **Compartir archivo** via WhatsApp, email, etc.
- **Guardado local** en el dispositivo
- **Validación de permisos** de almacenamiento
- **Estados de loading** y manejo de errores
- **Interfaz intuitiva** con iconos diferenciados

## 🎯 **¿Cómo usar?**

### **Método 1: Desde el cuadre de caja**
1. Abrir un cuadre de caja en el formulario de ventas
2. Hacer clic en el ícono de calculadora (🧮) junto al campo "Efectivo"
3. Ingresar las cantidades de billetes y monedas
4. Presionar "Usar Total" para transferir el monto

### **Método 2: Desde el menú principal**
1. En la pantalla de cuadres, hacer clic en el menú ⋮
2. Seleccionar "Contador de Efectivo"
3. Usar independientemente para conteos rápidos

## 📊 **Exportación Excel**

### **Opciones disponibles:**
- **📱 Exportar desde la AppBar**: Botón de descarga en la barra superior
- **💾 Exportar desde botones**: Botón "Excel" en la parte inferior
- **✉️ Compartir automáticamente**: Opción para abrir menú de compartir
- **📝 Agregar observaciones**: Campo opcional para notas

### **Contenido del Excel:**
```
CONTADOR DE EFECTIVO

Fecha: 6/9/2025    Hora: 17:30
Usuario: Administrador
Observaciones: Arqueo de caja del turno nocturno

Tipo     | Denominación | Cantidad | Subtotal
---------|-------------|----------|----------
BILLETES
BILLETE  | $100.000    |    5     | $500.000
BILLETE  | $50.000     |    8     | $400.000
BILLETE  | $20.000     |   10     | $200.000
                      TOTAL BILLETES: $1.100.000

MONEDAS
MONEDA   | $1.000      |   15     |  $15.000
MONEDA   | $500        |   20     |  $10.000
                       TOTAL MONEDAS:   $25.000

                    TOTAL GENERAL: $1.125.000
```

## 🛠️ **Dependencias agregadas**
```yaml
dependencies:
  excel: ^4.0.6              # Generación de archivos Excel
  permission_handler: ^11.3.1 # Manejo de permisos de almacenamiento
```

## 📱 **Permisos requeridos**
- **Android**: Acceso a almacenamiento externo para guardar archivos
- **iOS**: Acceso a documentos de la aplicación
- **Compartir**: Acceso para enviar archivos via otras apps

## 🎨 **Características de UX/UI**
- **Colores diferenciados**: Verde para billetes, naranja para monedas
- **Iconos intuitivos**: 💵 billetes, 🪙 monedas, 🧮 calculadora, 📊 Excel
- **Feedback visual**: Loading, éxito, errores
- **Navegación fluida**: Integración natural con el flujo de trabajo
- **Responsive design**: Adaptable a diferentes pantallas

## 📈 **Casos de uso**
- **Arqueo de caja diario**: Conteo físico de dinero al final del turno
- **Apertura de caja**: Validación del fondo inicial
- **Auditorías**: Registro detallado de denominaciones
- **Reportes**: Exportar para análisis externo
- **Control interno**: Trazabilidad de movimientos

## ⚡ **Rendimiento**
- **Cálculo instantáneo**: Actualización en tiempo real
- **Archivos ligeros**: Excel optimizado sin datos redundantes
- **Validación eficiente**: Solo denominaciones con cantidad > 0
- **Gestión de memoria**: Limpieza automática de controladores

## 🔐 **Seguridad**
- **Control de acceso**: Solo usuarios administradores
- **Validación de entrada**: Solo números enteros positivos
- **Manejo de errores**: Estados controlados para todos los procesos
- **Permisos granulares**: Solicitud específica según plataforma

---

## 🚀 **¡Listo para usar!**

El contador de efectivo está completamente integrado y funcional. Los usuarios pueden:
1. ✅ **Contar dinero** de forma organizada y precisa
2. ✅ **Exportar reportes** a Excel con un clic
3. ✅ **Compartir archivos** con contadores, gerentes o auditores
4. ✅ **Integrar con cuadres** para flujo de trabajo completo

**¡Perfecto para restaurantes, cafeterías y pequeños negocios que manejan efectivo!** 💪
