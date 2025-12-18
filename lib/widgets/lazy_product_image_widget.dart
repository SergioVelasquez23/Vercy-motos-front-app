import 'package:flutter/material.dart';
import '../models/producto.dart';
import '../services/image_loader_service.dart';
import 'imagen_producto_widget.dart';

/// Widget que carga imágenes de productos de forma lazy (bajo demanda)
///
/// Características:
/// - Muestra placeholder mientras carga
/// - Carga la imagen solo cuando es visible
/// - Usa cache para evitar recargas
/// - Se integra con ImageLoaderService para carga en lotes
class LazyProductImageWidget extends StatefulWidget {
  final Producto producto;
  final double width;
  final double height;
  final BoxFit fit;
  final String backendBaseUrl;

  const LazyProductImageWidget({
    Key? key,
    required this.producto,
    this.width = 50,
    this.height = 50,
    this.fit = BoxFit.cover,
    required this.backendBaseUrl,
  }) : super(key: key);

  @override
  State<LazyProductImageWidget> createState() => _LazyProductImageWidgetState();
}

class _LazyProductImageWidgetState extends State<LazyProductImageWidget> {
  final ImageLoaderService _imageLoader = ImageLoaderService();
  String? _imagenUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarImagen();
  }

  @override
  void didUpdateWidget(LazyProductImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si cambió el producto, recargar la imagen
    if (oldWidget.producto.id != widget.producto.id) {
      _imageLoader.removeImageListener(oldWidget.producto.id, _onImagenCargada);
      _imagenUrl = null;
      _isLoading = false;
      _cargarImagen();
    }
  }

  void _cargarImagen() async {
    // ✅ CORREGIDO: NUNCA usar imagenUrl del producto, siempre cargar desde servicio
    // Esto evita que imágenes cacheadas incorrectas se muestren al cambiar categorías
    
    // Verificar cache del servicio PRIMERO (más fresco que el del producto)
    final imagenCache = _imageLoader.getImagenFromCache(widget.producto.id);
    if (imagenCache != null) {
      if (mounted) {
        setState(() {
          _imagenUrl = imagenCache;
        });
      }
      return;
    }

    // Registrar listener para cuando se cargue la imagen
    _imageLoader.addImageListener(widget.producto.id, _onImagenCargada);

    // Si no está cargando, iniciar carga individual
    if (!_imageLoader.hasImageInCache(widget.producto.id) && !_isLoading) {
      setState(() {
        _isLoading = true;
      });

      // Cargar imagen individual desde el servidor
      final url = await _imageLoader.cargarImagenProducto(widget.producto.id);

      if (mounted && url != null) {
        setState(() {
          _imagenUrl = url;
          _isLoading = false;
        });
      }
    }
  }

  void _onImagenCargada(String imagenUrl) {
    if (mounted) {
      setState(() {
        _imagenUrl = imagenUrl;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _imageLoader.removeImageListener(widget.producto.id, _onImagenCargada);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Si tenemos la imagen, mostrarla
    if (_imagenUrl != null && _imagenUrl!.isNotEmpty) {
      // Determinar si es data URI o URL relativa
      String urlFinal;
      if (_imagenUrl!.startsWith('data:')) {
        // Es un data URI completo, usarlo directamente
        urlFinal = _imagenUrl!;
      } else if (_imagenUrl!.startsWith('http')) {
        // Es una URL completa
        urlFinal = _imagenUrl!;
      } else {
        // Es una ruta relativa, concatenar con baseUrl
        urlFinal = '${widget.backendBaseUrl}$_imagenUrl';
      }
      
      return ImagenProductoWidget(
        key: ValueKey('img-${widget.producto.id}-${urlFinal.hashCode}'), // ✅ Key única por producto
        urlRemota: urlFinal,
        nombreProducto: widget.producto.nombre,
        productoId: widget.producto.id, // ✅ NUEVO: Pasar ID del producto
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        backendBaseUrl: widget.backendBaseUrl,
      );
    }

    // Placeholder mientras carga
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: _isLoading
          ? Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
                ),
              ),
            )
          : Icon(
              Icons.fastfood,
              color: Colors.white38,
              size: widget.width * 0.5,
            ),
    );
  }
}
