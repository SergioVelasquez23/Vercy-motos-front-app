import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget que maneja imágenes de categorías con fallback local
class ImagenCategoriaWidget extends StatelessWidget {
  final String? urlRemota;
  final String? nombreCategoria;
  final double? width;
  final double? height;
  final BoxFit fit;

  const ImagenCategoriaWidget({
    super.key,
    this.urlRemota,
    this.nombreCategoria,
    this.width = 50,
    this.height = 50,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    // Si tenemos URL remota, intentar cargarla primero
    if (urlRemota != null && urlRemota!.isNotEmpty) {
      return Image.network(
        urlRemota!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          // Si falla la imagen remota, usar imagen local
          return _buildImagenLocal();
        },
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
      );
    }

    // Si no hay URL remota, usar imagen local directamente
    return _buildImagenLocal();
  }

  Widget _buildImagenLocal() {
    // Mapeo de nombres de categorías a archivos locales disponibles
    final Map<String, String> imagenesLocales = {
      // Archivos que tienes disponibles
      'bebidas': 'assets/images/categorias/624dc4fa07ef431e635b42e2.jpg',
      'bebidas calientes':
          'assets/images/categorias/624dc4fa07ef431e635b42e2.jpg',
      'bebidas frias': 'assets/images/categorias/624dc4fa07ef431e635b42e2.jpg',
      'comidas': 'assets/images/categorias/6251c76a6e273405efb3cffa.jpg',
      'postres': 'assets/images/categorias/6251c91d6e273405efb3d043.jpg',
      'entradas': 'assets/images/categorias/6259b95f955f8605f5670239.jpg',
      'platos fuertes': 'assets/images/categorias/6259bd69955f8605f56702c6.jpg',
      'carnes': 'assets/images/categorias/625af5b2f116990ee2844779.jpg',
      'mariscos': 'assets/images/categorias/66e6f8fef1ee3e30557abb4c.jpeg',
      'pescados': 'assets/images/categorias/66e6f8fef1ee3e30557abb4c.jpeg',
      'adicionales': 'assets/images/categorias/adicionales.jpg',
      // Categorías vistas en las imágenes
      'cafe': 'assets/images/categorias/625af5b2f116990ee2844779.jpg',
      'especiales': 'assets/images/categorias/6259bd69955f8605f56702c6.jpg',
      'parrilla': 'assets/images/categorias/625af5b2f116990ee2844779.jpg',
      // Fallbacks genéricos
      'sopas': 'assets/images/categorias/6251c76a6e273405efb3cffa.jpg',
      'ensaladas': 'assets/images/categorias/6259b95f955f8605f5670239.jpg',
      'alcoholicas': 'assets/images/categorias/624dc4fa07ef431e635b42e2.jpg',
      'no alcoholicas': 'assets/images/categorias/624dc4fa07ef431e635b42e2.jpg',
      'gaseosas': 'assets/images/categorias/624dc4fa07ef431e635b42e2.jpg',
      'jugos': 'assets/images/categorias/624dc4fa07ef431e635b42e2.jpg',
    };

    String? rutaImagen;
    if (nombreCategoria != null) {
      rutaImagen = imagenesLocales[nombreCategoria!.toLowerCase()];
    }

    if (rutaImagen != null) {
      return FutureBuilder<bool>(
        future: _existeAsset(rutaImagen),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data == true) {
            return Image.asset(
              rutaImagen!,
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (context, error, stackTrace) {
                return _buildImagenPorDefecto();
              },
            );
          }
          return _buildImagenPorDefecto();
        },
      );
    }

    return _buildImagenPorDefecto();
  }

  Widget _buildImagenPorDefecto() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.restaurant_menu,
        color: Colors.grey[600],
        size: (width ?? 50) * 0.5,
      ),
    );
  }

  Future<bool> _existeAsset(String rutaAsset) async {
    try {
      await rootBundle.load(rutaAsset);
      return true;
    } catch (e) {
      return false;
    }
  }
}
