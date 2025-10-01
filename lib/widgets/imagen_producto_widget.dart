import 'package:flutter/material.dart';
import 'dart:convert';

/// Widget que maneja imágenes de productos con fallback local
class ImagenProductoWidget extends StatelessWidget {
  final String? urlRemota;
  final String? nombreProducto;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String backendBaseUrl;

  const ImagenProductoWidget({
    super.key,
    this.urlRemota,
    this.nombreProducto,
    this.width = 50,
    this.height = 50,
    this.fit = BoxFit.cover,
    required this.backendBaseUrl,
  });

  @override
  Widget build(BuildContext context) {
    // Si no hay URL, mostrar icono por defecto
    if (urlRemota == null || urlRemota!.isEmpty) {
      return _buildIconoDefault();
    }

    final imagenUrl = urlRemota!;

    // Filtrar referencias al placeholder corrupto
    if (imagenUrl.contains('placeholder/food_placeholder.png')) {
      print(
        '⚠️ Detectada referencia al placeholder corrupto, usando icono por defecto',
      );
      return _buildIconoDefault();
    }

    // Si es una imagen base64
    if (imagenUrl.startsWith('data:image')) {
      return _buildImagenBase64(imagenUrl);
    }

    // Si es una URL web absoluta
    if (imagenUrl.startsWith('http')) {
      return _buildImagenNetwork(imagenUrl);
    }

    // Si es solo un nombre de archivo, construir la URL completa
    if (!imagenUrl.startsWith('/') && !imagenUrl.contains('/')) {
      final fullUrl = '$backendBaseUrl/images/platos/$imagenUrl';
      return _buildImagenNetwork(fullUrl);
    }

    // Si es una URL relativa
    if (imagenUrl.startsWith('/')) {
      final fullUrl = '$backendBaseUrl$imagenUrl';
      return _buildImagenNetwork(fullUrl);
    }

    // Si es un asset local
    return _buildImagenAsset(imagenUrl);
  }

  Widget _buildImagenBase64(String imagenUrl) {
    try {
      final base64Str = imagenUrl.split(',').last;
      final bytes = base64Decode(base64Str);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildIconoDefault(),
        ),
      );
    } catch (e) {
      return _buildIconoError();
    }
  }

  Widget _buildImagenNetwork(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print('❌ Error cargando imagen de red: $url');
          print('   Tipo de error: ${error.runtimeType}');
          print('   Detalles: $error');

          // Intentar detectar el tipo de error específico
          if (error.toString().contains('500')) {
            print(
              '   🚨 Error 500 del servidor - imagen no encontrada o endpoint dañado',
            );
          } else if (error.toString().contains('404')) {
            print('   🚨 Error 404 - imagen no encontrada');
          } else if (error.toString().contains(
            'Failed to detect image file format',
          )) {
            print('   🚨 Archivo no es una imagen válida o está corrupto');
          }

          return _buildImagenAssetFallback();
        },
      ),
    );
  }

  Widget _buildImagenAsset(String assetPath) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        assetPath,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          print('❌ Error cargando asset: $assetPath - Error: $error');
          return _buildImagenAssetFallback();
        },
      ),
    );
  }

  Widget _buildImagenAssetFallback() {
    // Intentar cargar imagen local específica basada en el nombre del producto
    if (nombreProducto != null) {
      final nombreLimpio = nombreProducto!
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      // Mapeo de productos comunes a imágenes locales disponibles
      final Map<String, String> imagenesLocales = {
        'adicion de carne': 'assets/images/productos/adicion de carne.png',
        'adicional carne': 'assets/images/productos/adicion de carne.png',
        'carne adicional': 'assets/images/productos/adicion de carne.png',
        'carne extra': 'assets/images/productos/adicion de carne.png',
        // Fallbacks por categorías de productos
        'carne': 'assets/images/productos/adicion de carne.png',
        'pollo': 'assets/images/productos/adicion de carne.png',
        'cerdo': 'assets/images/productos/adicion de carne.png',
        'res': 'assets/images/productos/adicion de carne.png',
      };

      // Buscar coincidencia exacta
      String? rutaImagen = imagenesLocales[nombreLimpio];

      // Si no encuentra exacta, buscar por palabras clave
      if (rutaImagen == null) {
        for (final palabra in imagenesLocales.keys) {
          if (nombreLimpio.contains(palabra) ||
              palabra.contains(nombreLimpio)) {
            rutaImagen = imagenesLocales[palabra];
            break;
          }
        }
      }

      if (rutaImagen != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            rutaImagen,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) {
              print(
                '❌ Error cargando imagen local: $rutaImagen - Error: $error',
              );
              return _buildIconoDefault();
            },
          ),
        );
      }
    }

    // Fallback final: icono por defecto
    return _buildIconoDefault();
  }

  Widget _buildIconoDefault() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant,
            color: Colors.grey[400],
            size: (width != null && height != null)
                ? (width! < height! ? width! * 0.4 : height! * 0.4)
                : 20,
          ),
          if (height != null && height! > 60) ...[
            SizedBox(height: 4),
            Text(
              'Sin imagen',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIconoError() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[200]!, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported,
            color: Colors.orange[400],
            size: (width != null && height != null)
                ? (width! < height! ? width! * 0.4 : height! * 0.4)
                : 20,
          ),
          if (height != null && height! > 60) ...[
            SizedBox(height: 4),
            Text(
              'Error\ncargando',
              style: TextStyle(
                color: Colors.orange[600],
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
