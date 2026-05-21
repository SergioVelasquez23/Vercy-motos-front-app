import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'html_stub.dart' if (dart.library.html) 'dart:html' as html;

/// Abre o descarga un archivo recibido en base64.
///
/// En web crea un Blob URL y lo abre en una pestaña nueva (o lo descarga si se
/// pasa [filename]). En mobile/desktop hace fallback a un data URL — funciona
/// para archivos pequeños pero puede fallar con PDFs grandes.
class Base64FileLauncher {
  static Future<bool> open({
    required String base64,
    required String mimeType,
    String? filename,
  }) async {
    final bytes = base64Decode(base64);

    if (kIsWeb) {
      final blob = html.Blob([bytes], mimeType);
      final blobUrl = html.Url.createObjectUrlFromBlob(blob);

      if (filename != null && filename.isNotEmpty) {
        final anchor = html.document.createElement('a') as html.AnchorElement;
        anchor.href = blobUrl;
        anchor.download = filename;
        anchor.style.display = 'none';
        html.document.body?.children.add(anchor);
        anchor.click();
        anchor.remove();
        return true;
      }

      return launchUrl(Uri.parse(blobUrl), mode: LaunchMode.externalApplication);
    }

    final dataUrl = 'data:$mimeType;base64,$base64';
    return launchUrl(Uri.parse(dataUrl), mode: LaunchMode.externalApplication);
  }
}
