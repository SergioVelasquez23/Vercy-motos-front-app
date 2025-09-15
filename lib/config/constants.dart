// Constantes generales para la aplicación

// Configuración de API
const String kApiUrl =
    'https://sopa-y-carbon.onrender.com'; // URL del backend en producción

// Colores principales de la aplicación
const kPrimaryColor = 0xFFFF6B00;
const kBackgroundDark = 0xFF1E1E1E;
const kCardBackgroundDark = 0xFF252525;
const kTextDark = 0xFFE0E0E0;
const kTextLight = 0xFFA0A0A0;

// Constantes para formatos de fecha
const kDateFormat = 'dd/MM/yyyy';
const kTimeFormat = 'HH:mm';
const kDateTimeFormat = 'dd/MM/yyyy HH:mm';

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
const kNombreApp = 'Sopa y Carbon';
