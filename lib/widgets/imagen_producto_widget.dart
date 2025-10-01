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

    // Usar ImageService para obtener la URL validada
    final imageService = ImageService();
    final validatedUrl = imageService.getImageUrl(imagenUrl);
    
    // Si la URL validada está vacía, mostrar icono por defecto
    if (validatedUrl.isEmpty) {
      return _buildIconoDefault();
    }

    // Filtrar referencias al placeholder corrupto
    if (imagenUrl.contains('placeholder/food_placeholder.png')) {
      print('⚠️ Detectada referencia al placeholder corrupto, usando icono por defecto');
      return _buildIconoDefault();
    }

    // Si es una imagen base64
    if (validatedUrl.startsWith('data:image')) {
      return _buildImagenBase64(validatedUrl);
    }

    // Si es una URL web válida, cargarla
    if (validatedUrl.startsWith('http')) {
      return _buildImagenNetwork(validatedUrl);
    }

    // Si llegamos aquí, algo salió mal con la validación
    return _buildIconoDefault();
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
            decoration: BoxDecoration(
              color: Color(0xFF2A2A2A), // Fondo oscuro para loading
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color(0xFFFF6B00),
                ), // Color naranja
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          // Log más específico y silencioso para errores conocidos
          if (error.toString().contains('404')) {
            print('� Imagen no encontrada (404): $url');
          } else if (error.toString().contains('500')) {
            print('⚠️ Error del servidor (500): $url');
          } else {
            print('❌ Error cargando imagen: $url - ${error.toString()}');
          }
          return _buildIconoError();
        },
      ),
    );
  }

  Widget _buildIconoDefault() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        // Fondo con gradiente para mejor visibilidad
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A3A3A), Color(0xFF2A2A2A)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFF505050), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(0xFFFF6B00).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.restaurant_menu, // Icono más apropiado para comida
              color: Color(0xFFFF6B00), // Color naranja del tema
              size: (width != null && height != null)
                  ? (width! < height! ? width! * 0.3 : height! * 0.3)
                  : 18,
            ),
          ),
          if (height != null && height! > 60) ...[
            SizedBox(height: 4),
            Text(
              'Sin imagen',
              style: TextStyle(
                color: Color(0xFFB0B0B0), // Texto gris claro
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

  Widget _buildIconoError() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        // Fondo oscuro con tinte rojizo para indicar error
        color: Color(0xFF3A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFF604040), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image,
            color: Color(0xFFFF6B6B), // Rojo claro para error
            size: (width != null && height != null)
                ? (width! < height! ? width! * 0.4 : height! * 0.4)
                : 20,
          ),
          if (height != null && height! > 60) ...[
            SizedBox(height: 4),
            Text(
              'Error\ncargando',
              style: TextStyle(
                color: Color(0xFFB0B0B0), // Texto gris claro
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
