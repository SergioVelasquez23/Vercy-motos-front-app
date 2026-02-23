import 'dart:html' as html;
import 'dart:typed_data';

/// Helper para descargar archivos en web
class FileDownloadHelper {
  /// Descarga un archivo binario en navegadores web
  static void downloadFile(
    List<int> bytes, {
    required String filename,
    String mimeType = 'application/octet-stream',
  }) {
    try {
      // Crear un Blob con los datos
      final blob = html.Blob([Uint8List.fromList(bytes)]);

      // Crear URL del blob
      final url = html.Url.createObjectUrlFromBlob(blob);

      // Crear elemento de ancla
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..style.display = 'none';

      // Agregar al documento y hacer click
      html.document.body!.children.add(anchor);
      anchor.click();

      // Limpiar
      html.Url.revokeObjectUrl(url);
      anchor.remove();

      print('✅ Archivo descargado: $filename');
    } catch (e) {
      print('❌ Error descargando archivo: $e');
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
