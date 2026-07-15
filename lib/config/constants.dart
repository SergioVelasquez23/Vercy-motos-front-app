// Constantes generales para la aplicación
// Configuración de API
const String kBackendUrl =
    'https://204-168-190-85.nip.io'; // URL del backend en producción (Hetzner)

// URL de desarrollo local
const String kLocalBackendUrl = 'http://localhost:8081';

// URL dinámica que considera el entorno de desarrollo
String get kDynamicBackendUrl {
  if (const bool.fromEnvironment('dart.vm.product') == false) {
    return kLocalBackendUrl; // local en debug
  }
  return kBackendUrl; // producción en release
}

// Colores principales de la aplicación
const kPrimaryColor = 0xFFFF6B00;
const kBackgroundDark = 0xFF1E1E1E;
const kCardBackgroundDark = 0xFF252525;
const kTextDark = 0xFFE0E0E0;
const kTextLight = 0xFFA0A0A0;

// Constantes para formatos de fecha
const kDateFormat = 'dd/MM/yyyy';
const kTimeFormat = 'hh:mm a'; // Formato 12 horas con AM/PM
const kTimeFormat24 = 'HH:mm'; // Formato 24 horas (para backend)
const kDateTimeFormat = 'dd/MM/yyyy hh:mm a'; // Formato 12 horas con AM/PM
const kDateTimeFormat24 = 'dd/MM/yyyy HH:mm'; // Formato 24 horas (para backend)

// Mensajes de error comunes
const kErrorConexion =
    'Error de conexión. Por favor, revise su conexión a internet e intente nuevamente.';
const kErrorCargaDatos = 'No se pudieron cargar los datos.';
const kErrorGuardado = 'No se pudieron guardar los cambios.';

// Límites y valores por defecto
const kStockBajoUmbral = 10; // Umbral para considerar stock bajo
const kMaximoCantidadInventario =
    9999; // Cantidad máxima permitida en inventario
const kMaximoCaracteres =
    50; // Máximo de caracteres para campos de texto básicos
const kMaximoCaracteresDescripcion =
    200; // Máximo de caracteres para descripciones

// Tipos de movimientos de inventario
const kTiposMovimiento = [
  'Entrada - Compra',
  'Entrada - Devolución',
  'Entrada - Ajuste',
  'Entrada - Otro',
  'Salida - Venta',
  'Salida - Devolución',
  'Salida - Ajuste',
  'Salida - Merma',
  'Salida - Otro',
];

// Nombre de la aplicación
const kNombreApp = 'Vercy Motos';

// Estados de documentos / facturas
const kEstadoTodos = 'TODOS';
const kEstadoPendiente = 'PENDIENTE';
const kEstadoPagada = 'PAGADA';
const kEstadoCancelada = 'CANCELADA';
const kEstadoAnulada = 'ANULADA';
const kEstadoAprobada = 'APROBADA';
const kEstadoBorrador = 'BORRADOR';
const kEstadoActivo = 'ACTIVO';
const kEstadoInactivo = 'INACTIVO';

// Tipos de descuento
const kTipoDescuentoPorcentaje = 'Porcentaje';
const kTipoDescuentoValor = 'Valor';

// Listas de precios
const kListaPrecioDetal = 'Detal';
const kListaPrecioMayoreo = 'Mayoreo';
