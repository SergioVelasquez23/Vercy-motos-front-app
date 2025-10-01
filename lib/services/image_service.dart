import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import '../config/api_config.dart';

/// Servicio para manejo de imágenes
/// Incluye funcionalidades para subir, listar, verificar y eliminar imágenes
class ImageService {
  final ApiConfig _apiConfig = ApiConfig();
  final ImagePicker _picker = ImagePicker();

  /// Obtiene los headers de autenticación
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  /// Obtiene los headers para multipart
  Map<String, String> get _multipartHeaders => {'Accept': 'application/json'};

  /// Lista todas las imágenes disponibles en el servidor
  Future<List<String>> listImages() async {
    try {
      print('📋 Listando imágenes disponibles...');

      final response = await http
          .get(Uri.parse(_apiConfig.endpoints.images.list), headers: _headers)
          .timeout(Duration(seconds: 10));

      print('📋 Response status: ${response.statusCode}');
      print('📋 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        List<String> images = [];

        // El backend retorna la estructura: { "data": { "uploadsFiles": [...], "defaultFiles": [...] } }
        if (jsonData is Map && jsonData.containsKey('data')) {
          final data = jsonData['data'];
          if (data is Map) {
            // Agregar archivos de uploads (prioridad)
            if (data['uploadsFiles'] is List) {
              final uploadsFiles = (data['uploadsFiles'] as List)
                  .cast<String>();
              images.addAll(uploadsFiles);
              print('📋 Archivos en uploads: ${uploadsFiles.length}');
            }

            // Agregar archivos del directorio por defecto (si no están ya en uploads)
            if (data['defaultFiles'] is List) {
              final defaultFiles = (data['defaultFiles'] as List)
                  .cast<String>();
              for (String file in defaultFiles) {
                if (!images.contains(file)) {
                  images.add(file);
                }
              }
              print(
                '📋 Archivos en directorio por defecto: ${defaultFiles.length}',
              );
            }
          }
        }

        print('✅ Total de imágenes encontradas: ${images.length}');
        return images;
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error listando imágenes: $e');
      throw Exception('No se pudieron listar las imágenes: $e');
    }
  }

  /// Verifica si una imagen específica existe
  Future<bool> checkImageExists(String filename) async {
    try {
      print('🔍 Verificando imagen: $filename');

      final response = await http
          .get(
            Uri.parse(_apiConfig.endpoints.images.check(filename)),
            headers: _headers,
          )
          .timeout(Duration(seconds: 5));

      print('🔍 Check response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        // El backend retorna si existe en 'data.anyExists'
        if (jsonData is Map && jsonData.containsKey('data')) {
          final data = jsonData['data'];
          if (data is Map && data.containsKey('anyExists')) {
            return data['anyExists'] as bool;
          }
        }
      }

      return false;
    } catch (e) {
      print('❌ Error verificando imagen: $e');
      return false;
    }
  }

  /// Sube una imagen al servidor
  Future<String> uploadImage(XFile image) async {
    try {
      print('📤 Subiendo imagen: ${image.name}');

      if (kIsWeb) {
        // Flutter Web: usar upload base64
        return await _uploadImageBase64(image);
      } else {
        // Mobile/Desktop: usar multipart
        return await _uploadImageMultipart(image);
      }
    } catch (e) {
      print('❌ Error subiendo imagen: $e');
      throw Exception('No se pudo subir la imagen: $e');
    }
  }

  /// Sube imagen usando base64 (para web)
  Future<String> _uploadImageBase64(XFile image) async {
    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);

    final response = await http
        .post(
          Uri.parse(_apiConfig.endpoints.images.uploadBase64),
          headers: _headers,
          body: json.encode({
            'fileName': image.name,
            'imageBase64': base64Image,
          }),
        )
        .timeout(Duration(seconds: 30));

    print('📤 Upload base64 response: ${response.statusCode}');
    print('📤 Response body: ${response.body}');

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      // El backend retorna la URL en el campo 'data'
      final imageUrl = jsonData['data'] as String;

      // Extraer solo el nombre del archivo de la URL
      // El backend retorna "/images/platos/filename.ext", queremos solo "filename.ext"
      String filename = imageUrl;
      if (imageUrl.startsWith('/images/platos/')) {
        filename = imageUrl.substring('/images/platos/'.length);
      }

      print('✅ Imagen subida exitosamente (web): $filename');
      return filename;
    } else {
      throw Exception(
        'Error del servidor (web): ${response.statusCode} - ${response.body}',
      );
    }
  }

  /// Sube imagen usando multipart (para mobile/desktop)
  Future<String> _uploadImageMultipart(XFile image) async {
    final uri = Uri.parse(_apiConfig.endpoints.images.upload);
    final request = http.MultipartRequest('POST', uri);

    request.headers.addAll(_multipartHeaders);

    // Agregar el archivo con el nombre 'file' que espera el backend
    request.files.add(
      await http.MultipartFile.fromPath(
        'file', // El backend espera 'file' como nombre del parámetro
        image.path,
        contentType: MediaType('image', _getImageExtension(image.name)),
      ),
    );

    print('📤 Sending multipart request to: $uri');

    final streamResponse = await request.send().timeout(Duration(seconds: 30));
    final response = await http.Response.fromStream(streamResponse);

    print('📤 Upload multipart response: ${response.statusCode}');
    print('📤 Response body: ${response.body}');

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      // El backend retorna la URL en el campo 'data'
      final imageUrl = jsonData['data'] as String;

      // Extraer solo el nombre del archivo de la URL
      // El backend retorna "/images/platos/filename.ext", queremos solo "filename.ext"
      String filename = imageUrl;
      if (imageUrl.startsWith('/images/platos/')) {
        filename = imageUrl.substring('/images/platos/'.length);
      }

      print('✅ Imagen subida exitosamente (multipart): $filename');
      return filename;
    } else {
      throw Exception(
        'Error del servidor (multipart): ${response.statusCode} - ${response.body}',
      );
    }
  }

  /// Selecciona una imagen de la galería
  Future<XFile?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        print('🖼️ Imagen seleccionada: ${image.name}');
      }

      return image;
    } catch (e) {
      print('❌ Error seleccionando imagen: $e');
      throw Exception('No se pudo seleccionar la imagen: $e');
    }
  }

  /// Selecciona una imagen de la cámara
  Future<XFile?> pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        print('📷 Imagen capturada: ${image.name}');
      }

      return image;
    } catch (e) {
      print('❌ Error capturando imagen: $e');
      throw Exception('No se pudo capturar la imagen: $e');
    }
  }

  /// Elimina una imagen del servidor
  Future<bool> deleteImage(String filename) async {
    try {
      print('🗑️ Eliminando imagen: $filename');

      final response = await http
          .delete(
            Uri.parse(_apiConfig.endpoints.images.delete(filename)),
            headers: _headers,
          )
          .timeout(Duration(seconds: 10));

      print('🗑️ Delete response: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ Imagen eliminada exitosamente: $filename');
        return true;
      } else {
        print('❌ Error eliminando imagen: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error eliminando imagen: $e');
      return false;
    }
  }

  /// Obtiene la URL directa de una imagen para mostrar en la UI con mejoras para móviles
  String getImageUrl(String filename) {
    // Validar que el filename no esté vacío
    if (filename.trim().isEmpty) {
      print('⚠️ Filename vacío proporcionado a getImageUrl');
      return '';
    }

    final cleanFilename = filename.trim();

    // 🎯 PRIORIDAD 1: Si es una data URL base64, retornarla directamente
    if (cleanFilename.startsWith('data:image/')) {
      print('✅ Data URL base64 detectada, retornando directamente');
      return cleanFilename;
    }

    // Si ya es una URL completa, validarla
    if (cleanFilename.startsWith('http')) {
      // Validar que no termine en rutas incompletas
      if (cleanFilename.endsWith('/images/platos/') ||
          cleanFilename.endsWith('/images/platos')) {
        print('⚠️ URL incompleta detectada: $cleanFilename');
        return '';
      }

      // Validar que sea una URL bien formada
      try {
        final uri = Uri.parse(cleanFilename);
        if (!uri.hasScheme || !uri.hasAuthority) {
          print('⚠️ URL mal formada: $cleanFilename');
          return '';
        }

        // Verificar que tenga una extensión de imagen válida
        if (!isValidImageFile(uri.path.split('/').last)) {
          print('⚠️ URL no apunta a imagen válida: $cleanFilename');
          return '';
        }

        return cleanFilename;
      } catch (e) {
        print('❌ Error validando URL: $cleanFilename - $e');
        return '';
      }
    }

    // Si ya tiene el prefijo /images/platos/, construir URL completa
    if (cleanFilename.startsWith('/images/platos/')) {
      // Validar que no sea solo el path sin archivo
      if (cleanFilename == '/images/platos/' ||
          cleanFilename == '/images/platos') {
        print('⚠️ Path incompleto detectado: $cleanFilename');
        return '';
      }

      // Validar que el archivo tenga extensión válida
      final fileName = cleanFilename.split('/').last;
      if (!isValidImageFile(fileName)) {
        print('⚠️ Archivo sin extensión válida en path: $cleanFilename');
        return '';
      }

      return '${_apiConfig.baseUrl}$cleanFilename';
    }

    // Si es solo el nombre del archivo, validar que tenga extensión
    if (!cleanFilename.contains('.') || !isValidImageFile(cleanFilename)) {
      print('⚠️ Filename inválido o sin extensión: $cleanFilename');
      return '';
    }

    // Construir la URL completa
    final fullUrl = '${_apiConfig.baseUrl}/images/platos/$cleanFilename';
    print('🔗 URL construida para móvil: $fullUrl');
    return fullUrl;
  }

  /// Valida si un archivo es una imagen válida
  bool isValidImageFile(String filename) {
    final validExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
    final extension = filename.toLowerCase().split('.').last;
    return validExtensions.contains(extension);
  }

  /// Obtiene la extensión de imagen basada en el nombre del archivo
  String _getImageExtension(String filename) {
    final extension = filename.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'jpeg';
      case 'png':
        return 'png';
      case 'gif':
        return 'gif';
      case 'webp':
        return 'webp';
      default:
        return 'jpeg';
    }
  }

  /// Obtiene información detallada del estado de las imágenes
  Future<Map<String, dynamic>> getImageStatus() async {
    try {
      print('📊 Obteniendo estado de las imágenes...');

      final response = await http
          .get(Uri.parse(_apiConfig.endpoints.images.list), headers: _headers)
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        print('📊 Estado completo: $jsonData');
        return jsonData;
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error obteniendo estado: $e');
      throw Exception('No se pudo obtener el estado de las imágenes: $e');
    }
  }

  /// Verifica la conectividad con el backend
  Future<bool> testConnection() async {
    try {
      print('🔗 Probando conexión con el backend...');

      final response = await http
          .get(Uri.parse(_apiConfig.endpoints.images.list), headers: _headers)
          .timeout(Duration(seconds: 5));

      final isConnected = response.statusCode == 200;
      print(isConnected ? '✅ Conexión exitosa' : '❌ Conexión fallida');
      return isConnected;
    } catch (e) {
      print('❌ Error de conexión: $e');
      return false;
    }
  }
}
