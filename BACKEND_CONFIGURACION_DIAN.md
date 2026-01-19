# Backend - Configuración de Facturación Electrónica DIAN

## Endpoints Necesarios

### 1. Guardar/Actualizar Configuración DIAN Completa
```
POST /api/configuracion/facturacion/dian
```

**Body (JSON):**
```json
{
  "claveTecnicaResolucion": "d075145f255e7513efdeb638238fdd1765f8f4d179d038c290abdd8d10245770",
  "prefijoResolucion": "SC",
  "numeroResolucion": "18764101895165",
  "rangoNumeracionInicial": "1",
  "rangoNumeracionFinal": "10000",
  "resolucionValidaDesde": "2025-11-21",
  "resolucionValidaHasta": "2027-11-21",
  "iniciarNumeroFacturaDesde": "1",
  "modoOperacion": "Software propio",
  "descripcionModoOperacion": "Set SW Propio",
  "fechaInicioModoOperacion": "2019-03-14",
  "fechaTerminoModoOperacion": "2019-06-14",
  "prefijoRango": "SETP",
  "numeroResolucionRango": "18760000001",
  "rangoDesde": "990000000",
  "rangoHasta": "995000000",
  "fechaDesdeRango": "2019-01-19",
  "fechaHastaRango": "2030-01-19",
  "softwareId": "66f373d2-a05a-407d-a079-fb2c",
  "nombreSoftware": "Vercy Motos",
  "claveTecnicaSoftware": "fc8eac422eba16e22ffd8c6f94b",
  "pin": "77777",
  "certificado": "base64_encoded_certificate_or_path",
  "certificadoPassword": "password",
  "certificadoVencimiento": "2026-12-31",
  "testSetId": "03966238-b459-4231-baeb-95e4991c0784",
  "esModoProduccion": false,
  "proveedorTecnologicoNit": "900123456",
  "proveedorTecnologicoNombre": "Proveedor XYZ",
  "urlWebService": "https://api.dian.gov.co/...",
  "notas": "Información adicional"
}
```

**Response Success (200/201):**
```json
{
  "success": true,
  "message": "Configuración DIAN guardada correctamente",
  "data": {
    "_id": "mongodb_id",
    ...todos los campos guardados...
  }
}
```

### 2. Obtener Configuración DIAN Completa
```
GET /api/configuracion/facturacion/dian
```

**Response Success (200):**
```json
{
  "success": true,
  "data": {
    "data": {
      "_id": "mongodb_id",
      "claveTecnicaResolucion": "...",
      "prefijoResolucion": "SC",
      ...todos los campos...
    }
  }
}
```

**Response Not Found (404):**
```json
{
  "success": false,
  "message": "No se encontró configuración DIAN"
}
```

### 3. Actualizar Solo Consecutivo Actual
```
PATCH /api/configuracion/facturacion/dian/consecutivo
```

**Body:**
```json
{
  "iniciarNumeroFacturaDesde": "150"
}
```

**Response Success (200):**
```json
{
  "success": true,
  "message": "Consecutivo actualizado correctamente"
}
```

## Schema de MongoDB

```javascript
// models/ConfiguracionDian.js
const mongoose = require('mongoose');

const configuracionDianSchema = new mongoose.Schema({
  // Datos de la Resolución DIAN
  claveTecnicaResolucion: {
    type: String,
    required: true,
    trim: true
  },
  prefijoResolucion: {
    type: String,
    required: true,
    trim: true
  },
  numeroResolucion: {
    type: String,
    required: true,
    trim: true
  },
  rangoNumeracionInicial: {
    type: String,
    required: true,
    trim: true
  },
  rangoNumeracionFinal: {
    type: String,
    required: true,
    trim: true
  },
  resolucionValidaDesde: {
    type: String,
    required: true,
    trim: true
  },
  resolucionValidaHasta: {
    type: String,
    required: true,
    trim: true
  },
  iniciarNumeroFacturaDesde: {
    type: String,
    required: true,
    default: '1',
    trim: true
  },

  // Modo de Operación
  modoOperacion: {
    type: String,
    required: true,
    default: 'Software propio',
    trim: true
  },
  descripcionModoOperacion: {
    type: String,
    trim: true
  },
  fechaInicioModoOperacion: {
    type: String,
    trim: true
  },
  fechaTerminoModoOperacion: {
    type: String,
    trim: true
  },

  // Rango de Numeración Asignado
  prefijoRango: {
    type: String,
    trim: true
  },
  numeroResolucionRango: {
    type: String,
    trim: true
  },
  rangoDesde: {
    type: String,
    trim: true
  },
  rangoHasta: {
    type: String,
    trim: true
  },
  fechaDesdeRango: {
    type: String,
    trim: true
  },
  fechaHastaRango: {
    type: String,
    trim: true
  },

  // Información del Software
  softwareId: {
    type: String,
    required: true,
    trim: true
  },
  nombreSoftware: {
    type: String,
    trim: true
  },
  claveTecnicaSoftware: {
    type: String,
    trim: true
  },
  pin: {
    type: String,
    required: true,
    trim: true
  },

  // Certificado Digital
  certificado: {
    type: String,
    trim: true
  },
  certificadoPassword: {
    type: String,
    trim: true
  },
  certificadoVencimiento: {
    type: String,
    trim: true
  },

  // Ambiente de Pruebas
  testSetId: {
    type: String,
    trim: true
  },
  esModoProduccion: {
    type: Boolean,
    default: false
  },

  // Proveedor Tecnológico
  proveedorTecnologicoNit: {
    type: String,
    trim: true
  },
  proveedorTecnologicoNombre: {
    type: String,
    trim: true
  },

  // Configuración Adicional
  urlWebService: {
    type: String,
    trim: true
  },
  notas: {
    type: String,
    trim: true
  },

  // Control de fechas
  fechaCreacion: {
    type: Date,
    default: Date.now
  },
  fechaActualizacion: {
    type: Date,
    default: Date.now
  }
}, {
  timestamps: true
});

// Actualizar fechaActualizacion automáticamente
configuracionDianSchema.pre('save', function(next) {
  this.fechaActualizacion = new Date();
  next();
});

module.exports = mongoose.model('ConfiguracionDian', configuracionDianSchema);
```

## Controlador de Ejemplo

```javascript
// controllers/configuracionDianController.js
const ConfiguracionDian = require('../models/ConfiguracionDian');

// Guardar o actualizar configuración DIAN
exports.guardarConfiguracionDian = async (req, res) => {
  try {
    // Buscar si ya existe una configuración
    let configuracion = await ConfiguracionDian.findOne();

    if (configuracion) {
      // Actualizar configuración existente
      Object.assign(configuracion, req.body);
      configuracion.fechaActualizacion = new Date();
      await configuracion.save();
    } else {
      // Crear nueva configuración
      configuracion = new ConfiguracionDian(req.body);
      await configuracion.save();
    }

    res.status(200).json({
      success: true,
      message: 'Configuración DIAN guardada correctamente',
      data: configuracion
    });
  } catch (error) {
    console.error('Error guardando configuración DIAN:', error);
    res.status(500).json({
      success: false,
      message: 'Error al guardar la configuración DIAN',
      error: error.message
    });
  }
};

// Obtener configuración DIAN
exports.obtenerConfiguracionDian = async (req, res) => {
  try {
    const configuracion = await ConfiguracionDian.findOne();

    if (!configuracion) {
      return res.status(404).json({
        success: false,
        message: 'No se encontró configuración DIAN'
      });
    }

    res.status(200).json({
      success: true,
      data: {
        data: configuracion
      }
    });
  } catch (error) {
    console.error('Error obteniendo configuración DIAN:', error);
    res.status(500).json({
      success: false,
      message: 'Error al obtener la configuración DIAN',
      error: error.message
    });
  }
};

// Actualizar solo el consecutivo actual
exports.actualizarConsecutivo = async (req, res) => {
  try {
    const { iniciarNumeroFacturaDesde } = req.body;

    const configuracion = await ConfiguracionDian.findOne();

    if (!configuracion) {
      return res.status(404).json({
        success: false,
        message: 'No se encontró configuración DIAN'
      });
    }

    configuracion.iniciarNumeroFacturaDesde = iniciarNumeroFacturaDesde;
    configuracion.fechaActualizacion = new Date();
    await configuracion.save();

    res.status(200).json({
      success: true,
      message: 'Consecutivo actualizado correctamente'
    });
  } catch (error) {
    console.error('Error actualizando consecutivo:', error);
    res.status(500).json({
      success: false,
      message: 'Error al actualizar el consecutivo',
      error: error.message
    });
  }
};
```

## Rutas de Ejemplo

```javascript
// routes/configuracionDian.js
const express = require('express');
const router = express.Router();
const configuracionDianController = require('../controllers/configuracionDianController');
const auth = require('../middleware/auth'); // Middleware de autenticación

// Rutas protegidas
router.post(
  '/api/configuracion/facturacion/dian',
  auth,
  configuracionDianController.guardarConfiguracionDian
);

router.get(
  '/api/configuracion/facturacion/dian',
  auth,
  configuracionDianController.obtenerConfiguracionDian
);

router.patch(
  '/api/configuracion/facturacion/dian/consecutivo',
  auth,
  configuracionDianController.actualizarConsecutivo
);

module.exports = router;
```

## Notas de Implementación

1. **Seguridad**: 
   - Todos los endpoints deben estar protegidos con autenticación JWT
   - El certificado y su contraseña deben estar encriptados en la base de datos
   - Solo usuarios con rol de administrador deben poder modificar esta configuración

2. **Validación**:
   - Validar que los campos requeridos estén presentes
   - Validar formatos de fecha (yyyy-MM-dd)
   - Validar que los rangos numéricos sean consistentes

3. **Caché**:
   - Implementar caché en Redis para evitar consultas frecuentes a MongoDB
   - Invalidar caché al actualizar la configuración

4. **Auditoría**:
   - Registrar todos los cambios en un log de auditoría
   - Incluir usuario que realizó el cambio y timestamp

5. **Backup**:
   - Hacer backup de la configuración anterior antes de actualizar
   - Mantener historial de cambios

## Uso desde Flutter

```dart
// Ejemplo de uso desde Flutter
final service = ConfiguracionFacturacionService();

// Guardar configuración
final config = ConfiguracionDian(...);
final resultado = await service.guardarConfiguracionDian(config);

// Obtener configuración
final config = await service.obtenerConfiguracionDian();

// Actualizar consecutivo
await service.actualizarConsecutivoActual('150');
```
