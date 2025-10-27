import 'package:flutter/material.dart';

import 'dart:convert';
import '../services/image_service.dart';

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

    final imagenUrl = urlRemota!.trim();

    // Validar que la URL no esté vacía después del trim
    if (imagenUrl.isEmpty) {
      return _buildIconoDefault();
    }

    // Filtrar referencias al placeholder corrupto
    if (imagenUrl.contains('placeholder/food_placeholder.png')) {
      return _buildIconoDefault();
    }

    // PRIORIDAD 1: Si es una imagen base64, mostrarla directamente (PERSISTENTE)
    if (imagenUrl.startsWith('data:image/')) {
      // ✅ COMENTADO: Log de imagen base64 removido
      // print('🎨 Mostrando imagen base64 persistente');
      return _buildImagenBase64(imagenUrl);
    }

    // MIGRACIÓN: Si la URL contiene el servidor anterior, migrar a Railway
    if (imagenUrl.contains('sopa-y-carbon.onrender.com')) {
      final migratedUrl = imagenUrl.replaceAll(
        'sopa-y-carbon.onrender.com',
        'sopa-y-carbon-production.up.railway.app',
      );
      print('🔄 URL migrada a Railway: $migratedUrl');
      return _buildImagenNetwork(migratedUrl);
    }

    // PRIORIDAD 2: Si es una URL HTTP válida, intentar cargarla
    if (imagenUrl.startsWith('http')) {
      print('🌐 Intentando cargar imagen desde URL: $imagenUrl');
      return _buildImagenNetwork(imagenUrl);
    }

    // PRIORIDAD 3: Construir URL del servidor (probablemente fallará en Render)
    final imageService = ImageService();
    final validatedUrl = imageService.getImageUrl(imagenUrl);

    // Verificar si la URL validada contiene el servidor anterior y migrarla
    if (validatedUrl.contains('sopa-y-carbon.onrender.com')) {
      final migratedUrl = validatedUrl.replaceAll(
        'sopa-y-carbon.onrender.com',
        'sopa-y-carbon-production.up.railway.app',
      );
      print('🔄 URL validada migrada a Railway: $migratedUrl');
      return _buildImagenNetwork(migratedUrl);
    }

    if (validatedUrl.isNotEmpty) {
      print('🏗️ URL construida del servidor: $validatedUrl');
      return _buildImagenNetwork(validatedUrl);
    }

    // Si llegamos aquí, mostrar icono por defecto
    return _buildIconoDefault();
  }

  Widget _buildImagenBase64(String imagenUrl) {
    try {
      final base64Str = imagenUrl.split(',').last;
      final bytes = base64Decode(base64Str);
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Color(0xFF3A3A3A),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => _buildIconoError(),
          ),
        ),
      );
    } catch (e) {
      return _buildIconoError();
    }
  }

  Widget _buildImagenNetwork(String url) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Color(0xFF3A3A3A),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: width,
          height: height,
          fit: fit,
          headers: {
            'Accept': '*/*',
            'User-Agent': 'Mozilla/5.0 (Mobile; Flutter)',
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: width,
              height: height,
              color: Color(0xFF3A3A3A),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B00)),
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            // Log más específico para debug
            final errorStr = error.toString();
            print('❌ Error cargando imagen: $url - $errorStr');

            // Si es un error del servidor (500, 404, etc.) mostrar ícono por defecto
            if (errorStr.contains('500') ||
                errorStr.contains('404') ||
                errorStr.contains('EncodingError') ||
                errorStr.contains('cannot be decoded') ||
                errorStr.contains('HttpException')) {
              print('🔄 Servidor con problemas, mostrando ícono por defecto');
              return _buildIconoDefault();
            }

            return _buildIconoError();
          },
        ),
      ),
    );
  }

  /// Widget de respaldo cuando no hay imagen o URL vacía
  Widget _buildIconoDefault() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Color(0xFF2A2A2A),
        border: Border.all(color: Color(0xFF444444), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_menu,
            color: Color(0xFFFF6B00),
            size: (width ?? 50) * 0.5,
          ),
          if ((height ?? 50) > 40) ...[
            SizedBox(height: 2),
            Text(
              'Sin imagen',
              style: TextStyle(
                color: Color(0xFF888888),
                fontSize: 8,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  /// Widget de respaldo cuando hay error al cargar la imagen
  Widget _buildIconoError() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Color(0xFF2A2A2A),
        border: Border.all(color: Color(0xFF666666), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            color: Color(0xFF888888),
            size: (width ?? 50) * 0.4,
          ),
          if ((height ?? 50) > 60) ...[
            SizedBox(height: 2),
            Text(
              'Sin imagen',
              style: TextStyle(color: Color(0xFF888888), fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
