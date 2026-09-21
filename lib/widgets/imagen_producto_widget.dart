import 'package:flutter/material.dart';


/// Widget que maneja imágenes de productos con fallback local
class ImagenProductoWidget extends StatelessWidget {
  final String? urlRemota;
  final String? nombreProducto;
  final String? productoId;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String backendBaseUrl;

  const ImagenProductoWidget({
    super.key,
    this.urlRemota,
    this.nombreProducto,
    this.productoId,
    this.width = 50,
    this.height = 50,
    this.fit = BoxFit.cover,
    required this.backendBaseUrl,
  });

  @override
  Widget build(BuildContext context) {
    // 🚫 CARGA DE IMÁGENES DESACTIVADA - Siempre muestra ícono por defecto
    return _buildIconoDefault();

    // CÓDIGO DESACTIVADO TEMPORALMENTE:
    /*
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
      //   
      return _buildImagenBase64(imagenUrl);
    }
    */

    // CÓDIGO DESACTIVADO - El resto del método también está inactivo
    /*
    // PRIORIDAD 2: Si es una URL HTTP válida, intentar cargarla
    if (imagenUrl.startsWith('http')) {
      // Verificar si es una URL del backend actual
      if (imagenUrl.contains('204-168-190-85.nip.io')) {
        return _buildImagenNetwork(imagenUrl);
      }
        
      return _buildImagenNetwork(imagenUrl);
    }

    // PRIORIDAD 3: Construir URL del servidor
    final imageService = ImageService();
    final validatedUrl = imageService.getImageUrl(imagenUrl);

    if (validatedUrl.isNotEmpty) {
      // Si getImageUrl retorna un data URI, mostrarlo como base64
      if (validatedUrl.startsWith('data:image/')) {
        return _buildImagenBase64(validatedUrl);
      }
      
        
      return _buildImagenNetwork(validatedUrl);
    }

    // Si llegamos aquí, mostrar icono por defecto
    return _buildIconoDefault();
    */
  }

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
