import 'html_stub.dart' if (dart.library.html) 'dart:html' as html;
import 'dart:typed_data';
import '../utils/logger.dart';

/// Helper para descargar archivos en web
class FileDownloadHelper {
  /// Descarga un archivo binario en navegadores web
  static void downloadFile(
    List<int> bytes, {
    required String filename,
    String mimeType = 'application/octet-stream',
  }) {
    try {
      // Crear Blob con MIME type correcto para que el browser lo descargue en lugar de abrir una pestaña
      final blob = html.Blob([Uint8List.fromList(bytes)], mimeType);

      // Crear URL del blob
      final url = html.Url.createObjectUrlFromBlob(blob);

      // Crear elemento de ancla
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..style.display = 'none';

      // Agregar al documento y hacer click
      html.document.body!.children.add(anchor);
      anchor.click();

      // Limpiar con retraso para que el browser tenga tiempo de iniciar la descarga
      // antes de que se revoque la URL (evita que abra nueva pestaña)
      Future.delayed(const Duration(milliseconds: 500), () {
        html.Url.revokeObjectUrl(url);
        try {
          anchor.remove();
        } catch (_) {}
      });

      appLog('✅ Archivo descargado: $filename');
    } catch (e) {
      appLog('❌ Error descargando archivo: $e');
      throw Exception('No se pudo descargar el archivo: $e');
    }
  }

  /// Descarga un archivo con manejo de errores
  static Future<void> downloadFileWithErrorHandling(
    Future<List<int>> Function() downloadFuture, {
    required String filename,
    required Function(String) onSuccess,
    required Function(String) onError,
  }) async {
    try {
      final bytes = await downloadFuture();
      downloadFile(bytes, filename: filename);
      onSuccess('Archivo descargado exitosamente');
    } catch (e) {
      onError('Error descargando archivo: $e');
    }
  }
}
