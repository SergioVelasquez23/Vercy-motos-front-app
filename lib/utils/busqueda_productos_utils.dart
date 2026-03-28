/// Utilidades para búsqueda inteligente de productos
library;

import '../models/producto.dart';
import '../utils/logger.dart';

/// Normaliza un texto removiendo acentos, convirtiendo a minúsculas
String _normalizar(String texto) {
  const acentos = 'áéíóúÁÉÍÓÚñÑ';
  const sinAcentos = 'aeiouAEIOUnN';

  String resultado = texto.toLowerCase();

  for (int i = 0; i < acentos.length; i++) {
    resultado = resultado.replaceAll(acentos[i], sinAcentos[i]);
  }

  return resultado;
}

/// Normaliza palabra para comparación con plurales
/// Ejemplo: "carpas" -> "carpa", "cascos" -> "casco"
String _normalizarPalabra(String palabra) {
  // Si termina en 's' y tiene más de 3 caracteres, quitar la 's'
  if (palabra.length > 3 && palabra.endsWith('s')) {
    return palabra.substring(0, palabra.length - 1);
  }
  return palabra;
}

/// Compara dos textos considerando plurales
bool _coincidePlural(String texto, String busqueda) {
  final textoBajo = texto.toLowerCase();
  final busquedaBajo = busqueda.toLowerCase();

  // Coincidencia exacta
  if (textoBajo.contains(busquedaBajo)) return true;

  // Probar sin la 's' final en la búsqueda
  final busquedaSinS = _normalizarPalabra(busquedaBajo);
  if (busquedaSinS != busquedaBajo && textoBajo.contains(busquedaSinS)) {
    return true;
  }

  // Probar sin la 's' final en el texto
  final textoSinS = _normalizarPalabra(textoBajo);
  if (textoSinS != textoBajo && textoSinS.contains(busquedaBajo)) {
    return true;
  }

  return false;
}

/// Busca productos de forma inteligente considerando:
/// - Búsqueda por código exacto o parcial
/// - Búsqueda por múltiples palabras clave en el nombre
/// - Ignora mayúsculas, acentos y orden de las palabras
/// - Maneja plurales (carpas/carpa)
bool busquedaInteligente(Producto producto, String busqueda) {
  if (busqueda.trim().isEmpty) return false;

  final busquedaNormalizada = _normalizar(busqueda.trim());

  // 1. Búsqueda por CÓDIGO (exacto o que contenga) - PRIORIDAD ALTA
  if (producto.codigo != null && producto.codigo!.isNotEmpty) {
    final codigoNormalizado = _normalizar(producto.codigo!);
    // Búsqueda flexible: el código contiene la búsqueda O la búsqueda contiene el código
    if (codigoNormalizado.contains(busquedaNormalizada) ||
        busquedaNormalizada.contains(codigoNormalizado)) {
      return true;
    }
  }

  // 2. Búsqueda por CÓDIGO DE BARRAS
  if (producto.codigoBarras != null && producto.codigoBarras!.isNotEmpty) {
    final codigoBarrasNormalizado = _normalizar(producto.codigoBarras!);
    if (codigoBarrasNormalizado.contains(busquedaNormalizada)) {
      return true;
    }
  }

  // 3. Búsqueda por NOMBRE con múltiples palabras clave y manejo de plurales
  final nombreNormalizado = _normalizar(producto.nombre);

  // Si busqueda es una sola palabra, búsqueda con plurales
  if (!busqueda.contains(' ')) {
    return _coincidePlural(nombreNormalizado, busquedaNormalizada);
  }

  // Dividir búsqueda en palabras clave
  final palabrasClave = busquedaNormalizada
      .split(' ')
      .where((p) => p.isNotEmpty)
      .toList();

  // El producto debe contener TODAS las palabras clave (considerando plurales)
  for (final palabra in palabrasClave) {
    if (!_coincidePlural(nombreNormalizado, palabra)) {
      return false;
    }
  }

  return true;
}

/// Calcula una puntuación de relevancia para ordenar resultados
/// Mayor puntuación = más relevante
int calcularRelevancia(Producto producto, String busqueda) {
  if (busqueda.trim().isEmpty) return 0;

  final busquedaNormalizada = _normalizar(busqueda.trim());
  int puntuacion = 0;

  // Coincidencia exacta en código (máxima prioridad)
  if (producto.codigo != null &&
      _normalizar(producto.codigo!) == busquedaNormalizada) {
    return 1000;
  }

  // Código contiene la búsqueda (alta prioridad)
  if (producto.codigo != null && producto.codigo!.isNotEmpty) {
    final codigoNormalizado = _normalizar(producto.codigo!);
    if (codigoNormalizado.contains(busquedaNormalizada)) {
      puntuacion += 500;
    }
    // Búsqueda contiene el código (útil para códigos cortos como "MOM")
    if (busquedaNormalizada.contains(codigoNormalizado)) {
      puntuacion += 450;
    }
  }

  final nombreNormalizado = _normalizar(producto.nombre);

  // Nombre empieza con la búsqueda
  if (nombreNormalizado.startsWith(busquedaNormalizada)) {
    puntuacion += 300;
  }

  // Nombre contiene la búsqueda completa
  if (nombreNormalizado.contains(busquedaNormalizada)) {
    puntuacion += 200;
  }

  // Coincidencias de palabras clave (incluyendo plurales)
  final palabrasClave = busquedaNormalizada
      .split(' ')
      .where((p) => p.isNotEmpty);
  for (final palabra in palabrasClave) {
    if (_coincidePlural(nombreNormalizado, palabra)) {
      puntuacion += 10;
    }
  }

  return puntuacion;
}

/// Filtra y ordena productos por relevancia
List<Producto> filtrarYOrdenarProductos(
  List<Producto> productos,
  String busqueda, {
  int limite = 15,
}) {
  // Permitir búsquedas de 2+ caracteres para códigos
  if (busqueda.trim().isEmpty || busqueda.trim().length < 2) {
    return [];
  }

  appLog('🔍 [Filtro] Buscando: "$busqueda"');
  appLog('   Total productos: ${productos.length}');
  final conCodigo = productos
      .where((p) => p.codigo != null && p.codigo!.isNotEmpty)
      .length;
  appLog('   Con código definido: $conCodigo');

  // Mostrar algunos productos de ejemplo si es búsqueda corta
  if (busqueda.length <= 5 && conCodigo > 0) {
    appLog('   📝 Ejemplos aleatorios de códigos:');
    final productosConCodigo = productos
        .where((p) => p.codigo != null && p.codigo!.isNotEmpty)
        .take(5)
        .toList();
    for (var p in productosConCodigo) {
      appLog(
        '     - [${p.codigo}] ${p.nombre.substring(0, p.nombre.length > 30 ? 30 : p.nombre.length)}...',
      );
    }
  }

  // Filtrar productos que coincidan
  final productosFiltrados = productos
      .where((producto) => busquedaInteligente(producto, busqueda))
      .toList();

  appLog(
    '   Productos filtrados (antes de ordenar): ${productosFiltrados.length}',
  );

  // Si es una búsqueda corta (posible código), mostrar algunos ejemplos
  if (busqueda.length <= 5) {
    appLog('   Ejemplos de códigos en productos filtrados:');
    for (var p in productosFiltrados.take(5)) {
      appLog(
        '     - [${p.codigo ?? "SIN"}] ${p.nombre.substring(0, p.nombre.length > 30 ? 30 : p.nombre.length)}',
      );
    }
  }

  // Ordenar por relevancia (mayor a menor)
  productosFiltrados.sort((a, b) {
    final relevanciaA = calcularRelevancia(a, busqueda);
    final relevanciaB = calcularRelevancia(b, busqueda);
    return relevanciaB.compareTo(relevanciaA);
  });

  // Limitar resultados
  return productosFiltrados.take(limite).toList();
}
