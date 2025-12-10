import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/producto_service.dart';

/// Widget optimizado para lazy loading de imágenes de productos
/// Usa el endpoint GET /api/productos/{id}/imagen
class LazyImagenProducto extends StatefulWidget {
  final String productoId;
  final String productoNombre;
  final double width;
  final double height;
  final BoxFit fit;

  const LazyImagenProducto({
    Key? key,
    required this.productoId,
    required this.productoNombre,
    this.width = 100,
    this.height = 100,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  @override
  State<LazyImagenProducto> createState() => _LazyImagenProductoState();
}

class _LazyImagenProductoState extends State<LazyImagenProducto> {
  final ProductoService _productoService = ProductoService();
  String? _imagenBase64;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _cargarImagen();
  }

  Future<void> _cargarImagen() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final imagenBase64 = await _productoService.cargarImagenProducto(
        widget.productoId,
      );

      if (mounted) {
        setState(() {
          _imagenBase64 = imagenBase64;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mostrando loading
    if (_isLoading) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
            ),
          ),
        ),
      );
    }

    // Imagen cargada
    if (_imagenBase64 != null && _imagenBase64!.isNotEmpty) {
      try {
        // Detectar si es data URI o base64 puro
        String base64Data = _imagenBase64!;
        if (base64Data.startsWith('data:image')) {
          // Es data URI: data:image/png;base64,iVBORw0KG...
          base64Data = base64Data.split(',')[1];
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            base64Decode(base64Data),
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            errorBuilder: (context, error, stackTrace) {
              return _buildPlaceholder(icon: Icons.broken_image);
            },
          ),
        );
      } catch (e) {
        return _buildPlaceholder(icon: Icons.broken_image);
      }
    }

    // Sin imagen o error
    return _buildPlaceholder(
      icon: _hasError ? Icons.image_not_supported : Icons.image,
    );
  }

  Widget _buildPlaceholder({required IconData icon}) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(icon, size: widget.width * 0.4, color: Colors.grey[400]),
      ),
    );
  }
}
