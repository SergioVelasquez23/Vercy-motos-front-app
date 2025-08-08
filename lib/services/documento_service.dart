import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class DocumentoService {
  // Obtener todos los documentos (facturas, recibos, etc.)
  Future<List<Map<String, dynamic>>> obtenerDocumentos({
    String? tipoDocumento,
    String? fechaInicio,
    String? fechaFin,
    String? filtro,
  }) async {
    try {
      print('📄 Obteniendo documentos/facturas...');

      Map<String, String> queryParams = {};

      if (tipoDocumento != null && tipoDocumento != 'Todos') {
        queryParams['tipo'] = tipoDocumento;
      }
      if (fechaInicio != null && fechaInicio.isNotEmpty) {
        queryParams['fechaInicio'] = fechaInicio;
      }
      if (fechaFin != null && fechaFin.isNotEmpty) {
        queryParams['fechaFin'] = fechaFin;
      }
      if (filtro != null && filtro.isNotEmpty) {
        queryParams['filtro'] = filtro;
      }

      // Cambiar el endpoint para usar el patrón de facturas que ya funciona
      final uri = Uri.parse(
        '${ApiConfig().baseUrl}/api/facturas/lista',
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('✅ ${data.length} documentos obtenidos');
        return data.cast<Map<String, dynamic>>();
      } else if (response.statusCode == 404) {
        print('⚠️ Endpoint no encontrado, retornando lista vacía');
        return [];
      } else {
        print('❌ Error del servidor: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error obteniendo documentos: $e');
      return [];
    }
  }

  // Obtener facturas específicamente
  Future<List<Map<String, dynamic>>> obtenerFacturas({
    String? fechaInicio,
    String? fechaFin,
    String? filtro,
  }) async {
    try {
      print('🧾 Obteniendo facturas...');

      Map<String, String> queryParams = {};

      if (fechaInicio != null && fechaInicio.isNotEmpty) {
        queryParams['fechaInicio'] = fechaInicio;
      }
      if (fechaFin != null && fechaFin.isNotEmpty) {
        queryParams['fechaFin'] = fechaFin;
      }
      if (filtro != null && filtro.isNotEmpty) {
        queryParams['filtro'] = filtro;
      }

      final uri = Uri.parse(
        '${ApiConfig().baseUrl}/api/facturas/lista',
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('✅ ${data.length} facturas obtenidas');
        return data.cast<Map<String, dynamic>>();
      } else if (response.statusCode == 404) {
        print('⚠️ Endpoint no encontrado, retornando lista vacía');
        return [];
      } else {
        print('❌ Error del servidor: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error obteniendo facturas: $e');
      return [];
    }
  }

  // Obtener detalle de un documento específico
  Future<Map<String, dynamic>?> obtenerDocumento(String documentoId) async {
    try {
      print('📄 Obteniendo documento: $documentoId');

      final response = await http.get(
        Uri.parse('${ApiConfig().baseUrl}/api/facturas/$documentoId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ Documento obtenido correctamente');
        return data;
      } else if (response.statusCode == 404) {
        print('⚠️ Documento no encontrado: $documentoId');
        return null;
      } else {
        print('❌ Error del servidor: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error obteniendo documento: $e');
      return null;
    }
  }

  // Anular o cancelar un documento
  Future<bool> anularDocumento(String documentoId, String motivo) async {
    try {
      print('❌ Anulando documento: $documentoId');

      final response = await http.patch(
        Uri.parse('${ApiConfig().baseUrl}/api/facturas/$documentoId/anular'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'motivo': motivo}),
      );

      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ Documento anulado correctamente');
        return true;
      } else {
        print('❌ Error anulando documento: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Error anulando documento: $e');
      return false;
    }
  }

  // Formatear documento para mostrar en UI
  Map<String, dynamic> formatearDocumentoParaUI(
    Map<String, dynamic> documento,
  ) {
    try {
      return {
        'id': documento['_id'] ?? documento['id'] ?? 'N/A',
        'numero': documento['numero'] ?? 'N/A',
        'tipo': documento['tipo'] ?? _determinarTipoDocumento(documento),
        'fecha': _formatearFecha(
          documento['fechaCreacion'] ?? documento['fecha'],
        ),
        'hora': _formatearHora(
          documento['fechaCreacion'] ?? documento['fecha'],
        ),
        'cliente':
            documento['clienteTelefono'] ??
            documento['cliente'] ??
            'Cliente General',
        'total': (documento['total'] ?? 0.0).toDouble(),
        'estado': documento['estado'] ?? 'Activo',
        'mesa': documento['mesa'] ?? documento['pedidoId'] ?? 'N/A',
        'mesero': documento['atendidoPor'] ?? documento['mesero'] ?? 'N/A',
        'medioPago': documento['medioPago'] ?? 'Efectivo',
        'observaciones': documento['observaciones'] ?? '',
        'detalles':
            documento['detalleProductos'] ?? documento['productos'] ?? [],
      };
    } catch (e) {
      print('❌ Error formateando documento: $e');
      return {
        'id': 'ERROR',
        'numero': 'Error',
        'tipo': 'Error',
        'fecha': DateTime.now().toString().split(' ')[0],
        'hora': DateTime.now().toString().split(' ')[1].substring(0, 8),
        'cliente': 'Error',
        'total': 0.0,
        'estado': 'Error',
        'mesa': 'N/A',
        'mesero': 'N/A',
        'medioPago': 'N/A',
        'observaciones': 'Error procesando documento',
        'detalles': [],
      };
    }
  }

  // Determinar tipo de documento basado en su estructura
  String _determinarTipoDocumento(Map<String, dynamic> documento) {
    if (documento.containsKey('numero') &&
        documento['numero'].toString().startsWith('FAC')) {
      return 'Factura';
    } else if (documento.containsKey('numero') &&
        documento['numero'].toString().startsWith('REC')) {
      return 'Recibo';
    } else if (documento.containsKey('pedidoId')) {
      return 'Comanda';
    } else {
      return 'Documento';
    }
  }

  // Formatear fecha
  String _formatearFecha(dynamic fecha) {
    try {
      if (fecha == null) return DateTime.now().toString().split(' ')[0];

      if (fecha is String) {
        final fechaDateTime = DateTime.parse(fecha);
        return '${fechaDateTime.year.toString().padLeft(4, '0')}-${fechaDateTime.month.toString().padLeft(2, '0')}-${fechaDateTime.day.toString().padLeft(2, '0')}';
      }

      return fecha.toString().split(' ')[0];
    } catch (e) {
      return DateTime.now().toString().split(' ')[0];
    }
  }

  // Formatear hora
  String _formatearHora(dynamic fecha) {
    try {
      if (fecha == null)
        return DateTime.now().toString().split(' ')[1].substring(0, 8);

      if (fecha is String) {
        final fechaDateTime = DateTime.parse(fecha);
        return '${fechaDateTime.hour.toString().padLeft(2, '0')}:${fechaDateTime.minute.toString().padLeft(2, '0')}:${fechaDateTime.second.toString().padLeft(2, '0')}';
      }

      final horaCompleta = fecha.toString().split(' ')[1];
      return horaCompleta.length >= 8
          ? horaCompleta.substring(0, 8)
          : horaCompleta;
    } catch (e) {
      return DateTime.now().toString().split(' ')[1].substring(0, 8);
    }
  }
}
