import '../models/factura_electronica_dian.dart';

/// Configuración de ejemplo para facturación electrónica DIAN
///
/// IMPORTANTE: Esta configuración debe personalizarse con los datos reales
/// de tu negocio y la autorización obtenida de la DIAN.
class FacturaElectronicaConfig {
  /// Obtener configuración del emisor (datos del restaurante)
  ///
  /// DEBES MODIFICAR ESTOS DATOS CON LA INFORMACIÓN REAL DE TU NEGOCIO
  static EmisorDian obtenerEmisorConfiguracion() {
    return EmisorDian(
      // Razón social registrada en la DIAN
      razonSocial: 'RESTAURANTE SOPA Y CARBON SAS',

      // NIT sin dígito de verificación
      nit: '900123456',

      // Dígito de verificación del NIT
      digitoVerificacion: '7',

      // Tipo de documento: 31 = NIT
      tipoDocumento: '31',

      // Tipo de persona: 1 = Jurídica, 2 = Natural
      tipoPersona: '1',

      // Tipo de régimen tributario
      // O-13: Gran contribuyente
      // O-15: Autoretenedor
      // O-23: Agente de retención IVA
      // O-47: Régimen simple de tributación
      // O-99: No responsable de IVA
      tipoRegimen: 'O-23',

      // Nombre comercial del negocio
      nombreComercial: 'Sopa y Carbón',

      // Dirección del establecimiento
      direccion: 'Calle 123 # 45-67',

      // Ciudad
      ciudad: 'Bogotá D.C.',

      // Código DANE de la ciudad (Bogotá = 11001)
      codigoCiudad: '11001',

      // Departamento
      departamento: 'Cundinamarca',

      // Código DANE del departamento (Cundinamarca = 11)
      codigoDepartamento: '11',

      // País (siempre CO para Colombia)
      pais: 'CO',

      // Teléfono de contacto
      telefono: '3001234567',

      // Email de contacto
      email: 'facturacion@sopaycarbon.com',

      // Responsabilidades fiscales (separadas por ;)
      // O-13: Gran contribuyente
      // O-15: Autoretenedor
      // O-23: Agente de retención IVA
      responsabilidadesFiscales: 'O-23',
    );
  }

  /// Obtener configuración de autorización DIAN
  ///
  /// DEBES SOLICITAR ESTOS DATOS A LA DIAN DESPUÉS DE HACER EL PROCESO
  /// DE HABILITACIÓN DE FACTURACIÓN ELECTRÓNICA
  static Map<String, dynamic> obtenerAutorizacionDian() {
    return {
      // Número de autorización otorgado por la DIAN
      'numeroAutorizacion': '18760000001',

      // Fecha de inicio de autorización
      'fechaInicioAutorizacion': DateTime(2024, 1, 1),

      // Fecha de fin de autorización
      'fechaFinAutorizacion': DateTime(2034, 12, 31),

      // Prefijo autorizado para las facturas
      'prefijoFactura': 'SOPE',

      // Rango de numeración autorizado - Desde
      'rangoDesde': '1',

      // Rango de numeración autorizado - Hasta
      'rangoHasta': '5000000',

      // ID del software registrado en la DIAN
      'softwareId': '56f2ae4e-9812-4fad-9255-08fcfcd5ccb0',

      // Código de seguridad del software (PIN)
      'softwareSecurityCode':
          'a8d18e4e5aa00b44a0b1f9ef413ad8215116bd3ce91730d580eaed795c83b5a32fe6f0823abc71400b3d59eb542b7de8',

      // NIT del proveedor del software
      'proveedorSoftwareNit': '900123456',
    };
  }

  /// Obtener el siguiente número consecutivo de factura
  ///
  /// IMPLEMENTACIÓN PENDIENTE: Debe conectarse a tu base de datos
  /// para obtener el siguiente número disponible
  static Future<String> obtenerSiguienteConsecutivo() async {
    // TODO: Implementar lógica para obtener el consecutivo desde la BD
    // Por ahora retorna un número de ejemplo
    return '0000001';
  }

  /// Mapeo de códigos de ciudades DANE más comunes
  static final Map<String, Map<String, String>> ciudadesColombia = {
    'bogota': {
      'nombre': 'Bogotá D.C.',
      'codigo': '11001',
      'departamento': 'Cundinamarca',
      'codigoDepartamento': '11',
    },
    'medellin': {
      'nombre': 'Medellín',
      'codigo': '05001',
      'departamento': 'Antioquia',
      'codigoDepartamento': '05',
    },
    'cali': {
      'nombre': 'Cali',
      'codigo': '76001',
      'departamento': 'Valle del Cauca',
      'codigoDepartamento': '76',
    },
    'barranquilla': {
      'nombre': 'Barranquilla',
      'codigo': '08001',
      'departamento': 'Atlántico',
      'codigoDepartamento': '08',
    },
    'cartagena': {
      'nombre': 'Cartagena',
      'codigo': '13001',
      'departamento': 'Bolívar',
      'codigoDepartamento': '13',
    },
  };

  /// Códigos de tipos de documento DIAN
  static final Map<String, String> tiposDocumento = {
    '11': 'Registro civil',
    '12': 'Tarjeta de identidad',
    '13': 'Cédula de ciudadanía',
    '21': 'Tarjeta de extranjería',
    '22': 'Cédula de extranjería',
    '31': 'NIT',
    '41': 'Pasaporte',
    '42': 'Documento de identificación extranjero',
    '91': 'NUIP',
  };

  /// Códigos de formas de pago DIAN
  static final Map<String, String> formasPago = {
    '1': 'Contado',
    '2': 'Crédito',
  };

  /// Códigos de medios de pago DIAN
  static final Map<String, String> mediosPago = {
    '10': 'Efectivo',
    '41': 'Tarjeta débito',
    '42': 'Tarjeta crédito',
    '47': 'Transferencia bancaria',
    '48': 'PSE',
    '49': 'ACH',
  };

  /// Códigos de unidades de medida más comunes
  static final Map<String, String> unidadesMedida = {
    'EA': 'Unidad',
    'NIU': 'Número de items',
    'KG': 'Kilogramo',
    'GRM': 'Gramo',
    'LTR': 'Litro',
    'MTR': 'Metro',
    'SET': 'Conjunto',
    'DZN': 'Docena',
  };

  /// Tarifas de IVA vigentes en Colombia
  static final Map<String, double> tarifasIVA = {
    'excluido': 0.0,
    'exento': 0.0,
    'tarifa_0': 0.0,
    'tarifa_5': 5.0,
    'tarifa_19': 19.0,
  };

  /// Categorías de productos con su IVA correspondiente
  ///
  /// PERSONALIZA SEGÚN TU NEGOCIO
  static final Map<String, double> ivaProductosPorCategoria = {
    // Alimentos preparados (restaurante)
    'plato_principal': 19.0,
    'entrada': 19.0,
    'postre': 19.0,
    'bebida_alcoholica': 19.0,
    'bebida_no_alcoholica': 19.0,
    'cafe': 19.0,

    // Algunos alimentos pueden tener IVA 5% o estar excluidos
    // según la normativa vigente
    'pan': 0.0,
    'leche': 0.0,
    'huevos': 0.0,
  };
}

/// Notas importantes sobre facturación electrónica DIAN:
/// 
/// 1. REQUISITOS PREVIOS:
///    - Estar inscrito en el RUT como facturador electrónico
///    - Tener un certificado digital de firma electrónica
///    - Completar el proceso de habilitación con la DIAN
///    - Registrar el software de facturación
/// 
/// 2. PROCESO DE HABILITACIÓN:
///    - Solicitar habilitación en el portal DIAN
///    - Generar facturas de prueba (mínimo 50)
///    - Esperar aprobación de la DIAN
///    - Recibir autorización y rango de numeración
/// 
/// 3. GENERACIÓN DE FACTURAS:
///    - Cada factura debe tener un CUFE único
///    - Debe firmarse digitalmente con certificado válido
///    - Debe enviarse a la DIAN en máximo 48 horas
///    - Debe enviarse copia al cliente
/// 
/// 4. CONSERVACIÓN:
///    - Las facturas deben conservarse por 10 años
///    - Tanto en formato XML como PDF
///    - Con las respuestas de validación de la DIAN
/// 
/// 5. PROVEEDORES TECNOLÓGICOS:
///    - Puedes usar un proveedor tecnológico autorizado
///    - Ellos se encargan de la firma digital y envío a DIAN
///    - Ejemplos: Siigo, Alegra, DataCrédito, etc.
/// 
/// 6. AMBIENTE DE PRUEBAS:
///    - La DIAN tiene un ambiente de habilitación
///    - ProfileExecutionID = 2 para pruebas
///    - ProfileExecutionID = 1 para producción
/// 
/// 7. DEPENDENCIAS NECESARIAS:
///    - xml: ^6.0.0 (para generar XML UBL)
///    - crypto: ^3.0.0 (para generar CUFE)
///    - intl: ^0.18.0 (para formateo de fechas)
///    - http: (para envío a proveedores tecnológicos)
