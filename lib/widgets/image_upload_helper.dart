import 'package:flutter/material.dart';
import '../services/image_service.dart';
import '../services/producto_service.dart';
import '../theme/app_theme.dart';

/// Widget para gestión rápida de imágenes de productos
class ImageUploadHelper extends StatefulWidget {
  const ImageUploadHelper({super.key});

  @override
  State<ImageUploadHelper> createState() => _ImageUploadHelperState();
}

class _ImageUploadHelperState extends State<ImageUploadHelper> {
  final ImageService _imageService = ImageService();
  final ProductoService _productoService = ProductoService();
  List<String> _imagenesSubidas = [];
  List<String> _imagenesDisponibles = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarImagenesDisponibles();
    _verificarEstadoServidor();
  }

  Future<void> _verificarEstadoServidor() async {
    try {
      final status = await _imageService.getImageStatus();
      print('📊 Estado del servidor de imágenes:');
      print('   - Total de archivos: ${status['data']['totalFiles']}');
      print('   - Uploads existe: ${status['data']['uploadsExists']}');
      print('   - Default existe: ${status['data']['defaultExists']}');
    } catch (e) {
      print('❌ Error verificando estado del servidor: $e');
    }
  }

  Future<void> _cargarImagenesDisponibles() async {
    try {
      setState(() => _isLoading = true);
      final imagenes = await _imageService.listImages();
      setState(() {
        _imagenesDisponibles = imagenes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error cargando imágenes: $e');
    }
  }

  Future<void> _subirImagenes() async {
    try {
      // Seleccionar múltiples imágenes
      final imagenes = await _imageService.pickImageFromGallery();
      if (imagenes == null) return;

      setState(() => _isLoading = true);

      // Subir la imagen usando ProductoService con base64
      final filename = await _productoService.uploadProductImage(imagenes);

      setState(() {
        _imagenesSubidas.add(filename);
        _imagenesDisponibles.add(filename);
        _isLoading = false;
      });

      _mostrarExito('Imagen subida: $filename');
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError('Error subiendo imagen: $e');
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardBg,
      title: Text(
        'Gestión de Imágenes',
        style: TextStyle(color: AppTheme.textPrimary),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            // Botón para subir nueva imagen
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _subirImagenes,
              icon: Icon(Icons.cloud_upload),
              label: Text('Subir Nueva Imagen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
            ),

            SizedBox(height: 16),

            // Estado de carga
            if (_isLoading) LinearProgressIndicator(color: AppTheme.primary),

            SizedBox(height: 16),

            // Lista de imágenes disponibles
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Imágenes Disponibles (${_imagenesDisponibles.length})',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),

                  Expanded(
                    child: _imagenesDisponibles.isEmpty
                        ? Center(
                            child: Text(
                              'No hay imágenes disponibles',
                              style: TextStyle(
                                color: AppTheme.textPrimary.withOpacity(0.6),
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _imagenesDisponibles.length,
                            itemBuilder: (context, index) {
                              final filename = _imagenesDisponibles[index];
                              final esNueva = _imagenesSubidas.contains(
                                filename,
                              );

                              return Card(
                                color: AppTheme.cardBg.withOpacity(0.5),
                                child: ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Colors.grey.withOpacity(0.3),
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.network(
                                        _imageService.getImageUrl(filename),
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Icon(
                                                Icons.image_not_supported,
                                                color: Colors.grey,
                                                size: 20,
                                              );
                                            },
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    filename,
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: esNueva
                                      ? Chip(
                                          label: Text(
                                            'Nueva',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                            ),
                                          ),
                                          backgroundColor: Colors.green,
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cerrar', style: TextStyle(color: AppTheme.textPrimary)),
        ),
        ElevatedButton(
          onPressed: () async {
            await _cargarImagenesDisponibles();
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
          child: Text('Actualizar', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
