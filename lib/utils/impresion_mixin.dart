import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/impresion_service.dart';
import '../services/pdf_service.dart';
import '../services/negocio_info_service.dart';
import '../models/negocio_info.dart';

/// Mixin que proporciona funcionalidades de impresión reutilizables
/// para diferentes pantallas de la aplicación
mixin ImpresionMixin<T extends StatefulWidget> on State<T> {
  // Servicios compartidos
  final ImpresionService _impresionService = ImpresionService();
  final PDFService _pdfService = PDFService();
  final NegocioInfoService _negocioInfoService = NegocioInfoService();

  // Colores del tema
  static const Color _primary = Color(0xFFFF6B00);
  static const Color _cardBg = Color(0xFF1E1E1E);
  static const Color _textLight = Color(0xFFE0E0E0);

  /// Prepara el resumen de un pedido para impresión usando el backend
  Future<Map<String, dynamic>?> prepararResumenPedido(String pedidoId,
  ) async {
    try {
      print('🔍 Preparando resumen para pedido: $pedidoId');

      // Obtener información del negocio
      print('📄 Obteniendo información del negocio...');
      NegocioInfo? negocioInfo;
      try {
        negocioInfo = await _negocioInfoService.getNegocioInfo();
        print('✅ Información del negocio obtenida correctamente');
      } catch (e) {
        print(
          '⚠️ Error obteniendo info del negocio, usando valores por defecto: $e',
        );
      }

      final resumen = await _impresionService.generarResumenPedido(pedidoId);

      // Actualizar la información del negocio en el resumen
      if (resumen != null && negocioInfo != null) {
        resumen['nombreNegocio'] = negocioInfo.nombre;
        resumen['direccionNegocio'] =
            '${negocioInfo.direccion ?? ''}${(negocioInfo.ciudad.isNotEmpty ?? false) ? ', ${negocioInfo.ciudad}' : ''}${(negocioInfo.departamento.isNotEmpty ?? false) ? ', ${negocioInfo.departamento}' : ''}';
        resumen['telefonoNegocio'] = negocioInfo.telefono ?? '';
        if (negocioInfo.email.isNotEmpty == true) {
          resumen['emailNegocio'] = negocioInfo.email ?? '';
        }
        if (negocioInfo.nit?.isNotEmpty == true) {
          resumen['nitNegocio'] = negocioInfo.nit ?? '';
        }
      }

      return resumen;
    } catch (e) {
      print('❌ Error preparando resumen: $e');
      return null;
    }
  }

  /// Método principal para imprimir documento
  Future<void> imprimirDocumento(Map<String, dynamic> resumen) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: _cardBg,
          content: Row(
            children: [
              CircularProgressIndicator(color: _primary),
              SizedBox(width: 20),
              Text(
                'Enviando a impresora...',
                style: TextStyle(color: _textLight),
              ),
            ],
          ),
        ),
      );

      final textoImpresion = _impresionService.generarTextoImpresion(resumen);

      // Mostrar opciones de impresión
      Navigator.of(context).pop(); // Cerrar diálogo de carga

      // Mostrar diálogo con opciones de impresión
      await mostrarOpcionesImpresion(textoImpresion, resumen);
    } catch (e) {
      Navigator.of(context).pop(); // Cerrar diálogo de carga
      mostrarMensajeError('Error preparando impresión: $e');
    }
  }

  /// Mostrar opciones de impresión
  Future<void> mostrarOpcionesImpresion(
    String contenido,
    Map<String, dynamic> resumen,
  ) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text(
          'Opciones de impresión',
          style: TextStyle(color: _textLight),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Opción: Imprimir en impresora térmica
              ListTile(
                leading: Icon(Icons.print, color: _primary),
                title: Text(
                  'Imprimir en impresora térmica',
                  style: TextStyle(color: _textLight),
                ),
                subtitle: Text(
                  'Enviar directamente a la impresora configurada',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                onTap: () => enviarAImpresora(contenido),
              ),
              Divider(),
              // Opción: Ver/compartir PDF
              ListTile(
                leading: Icon(Icons.picture_as_pdf, color: _primary),
                title: Text(
                  'Ver/compartir PDF',
                  style: TextStyle(color: _textLight),
                ),
                subtitle: Text(
                  'Generar archivo PDF para compartir',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                onTap: () => generarPDF(resumen),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancelar', style: TextStyle(color: _primary)),
          ),
        ],
      ),
    );
  }

  /// Enviar a impresora térmica
  Future<void> enviarAImpresora(String contenido) async {
    try {
      Navigator.of(context).pop(); // Cerrar diálogo de opciones

      // Mostrar diálogo de progreso
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: _cardBg,
          content: Row(
            children: [
              CircularProgressIndicator(color: _primary),
              SizedBox(width: 20),
              Text(
                'Enviando a impresora...',
                style: TextStyle(color: _textLight),
              ),
            ],
          ),
        ),
      );

      // Simular envío a impresora
      await Future.delayed(Duration(seconds: 2));

      Navigator.of(context).pop(); // Cerrar diálogo de progreso
      mostrarMensajeExito('Documento enviado a impresora');

      // Aquí se implementaría la lógica real de impresión
      print('Contenido para imprimir:\n$contenido');
    } catch (e) {
      Navigator.of(context).pop();
      mostrarMensajeError('Error al enviar a impresora: $e');
    }
  }

  /// Generar y compartir PDF
  Future<void> generarPDF(Map<String, dynamic> resumen) async {
    try {
      Navigator.of(context).pop(); // Cerrar diálogo de opciones

      // Mostrar diálogo de progreso
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: _cardBg,
          content: Row(
            children: [
              CircularProgressIndicator(color: _primary),
              SizedBox(width: 20),
              Text('Generando PDF...', style: TextStyle(color: _textLight)),
            ],
          ),
        ),
      );

      await _pdfService.compartirPDF(resumen: resumen, esFactura: false);

      Navigator.of(context).pop();
      mostrarMensajeExito('PDF listo para compartir');
    } catch (e) {
      Navigator.of(context).pop();
      mostrarMensajeError('Error compartiendo: $e');
    }
  }

  /// Actualizar resumen con información del negocio
  Future<Map<String, dynamic>> actualizarConInfoNegocio(
    Map<String, dynamic> resumen,
  ) async {
    try {
      print('📄 Actualizando resumen con información del negocio...');

      final negocioInfo = await _negocioInfoService.getNegocioInfo();

      if (negocioInfo != null) {
        resumen['nombreNegocio'] = negocioInfo.nombre;
        resumen['direccionNegocio'] =
            '${negocioInfo.direccion ?? ''}${(negocioInfo.ciudad.isNotEmpty ?? false) ? ', ${negocioInfo.ciudad}' : ''}${(negocioInfo.departamento.isNotEmpty ?? false) ? ', ${negocioInfo.departamento}' : ''}';
        resumen['telefonoNegocio'] = negocioInfo.telefono ?? '';

        if (negocioInfo.email.isNotEmpty == true) {
          resumen['emailNegocio'] = negocioInfo.email ?? '';
        }

        if (negocioInfo.nit?.isNotEmpty == true) {
          resumen['nitNegocio'] = negocioInfo.nit ?? '';
        }

        print('✅ Información del negocio actualizada en resumen');
      } else {
        print('⚠️ No se pudo obtener información del negocio');
      }
    } catch (e) {
      print('❌ Error actualizando información del negocio: $e');
    }

    return resumen;
  }

  /// Mostrar mensaje de éxito
  void mostrarMensajeExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.green),
    );
  }

  /// Mostrar mensaje de error
  void mostrarMensajeError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  /// Compartir pedido como texto
  Future<void> compartirPedido(Map<String, dynamic> resumen) async {
    try {
      final textoImpresion = _impresionService.generarTextoImpresion(resumen);

      // Por ahora, mostrar el contenido en un diálogo hasta que Share esté disponible
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: _cardBg,
          title: Text(
            'Compartir Documento',
            style: TextStyle(color: _textLight),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: SingleChildScrollView(
              child: Text(
                textoImpresion,
                style: TextStyle(
                  color: _textLight,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cerrar', style: TextStyle(color: _primary)),
            ),
          ],
        ),
      );
    } catch (e) {
      mostrarMensajeError('Error compartiendo: $e');
    }
  }
}
