import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/documento_mesa.dart';
import '../config/endpoints_config.dart';

class DocumentoMesaService {
  static final DocumentoMesaService _instance =
      DocumentoMesaService._internal();
  factory DocumentoMesaService() => _instance;
  DocumentoMesaService._internal();

  final EndpointsConfig _endpoints = EndpointsConfig();
  final storage = FlutterSecureStorage();

  Future<Map<String, String>> _getHeaders() async {
    final token = await storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Obtiene todos los documentos de una mesa específica
  Future<List<DocumentoMesa>> getDocumentosPorMesa(String nombreMesa) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(_endpoints.documentosMesa.mesa(nombreMesa)),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Debug: verificar estructura de respuesta
        print('🔍 Respuesta del API para mesa $nombreMesa:');
        print('  - Status: ${response.statusCode}');
        print('  - Response keys: ${responseData.keys}');
        print('  - Message: ${responseData['message']}');
        print(
          '  - Data length: ${(responseData['data'] as List?)?.length ?? 0}',
        );

        // Mostrar primer elemento para debug
        final List<dynamic> jsonList = responseData['data'] ?? [];
        if (jsonList.isNotEmpty) {
          print('  - Primer elemento keys: ${jsonList.first.keys}');
          print(
            '  - Primer elemento formaPago: ${jsonList.first['formaPago']}',
          );
          print(
            '  - Primer elemento numeroDocumento: ${jsonList.first['numeroDocumento']}',
          );
          print('  - Primer elemento mesa: ${jsonList.first['mesa']}');
          print('  - Primer elemento tipo: ${jsonList.first['tipo']}');
        }

        final documentos = jsonList
            .map((json) => DocumentoMesa.fromJson(json))
            .toList();

        // Ordenar documentos por fecha descendente (más recientes primero)
        documentos.sort((a, b) {
          final fechaA = a.fechaCreacion ?? a.fecha;
          final fechaB = b.fechaCreacion ?? b.fecha;
          return fechaB.compareTo(fechaA);
        });

        return documentos;
      } else {
        print('❌ Error obteniendo documentos: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error de conexión obteniendo documentos: $e');
      return [];
    }
  }

  /// Crea un nuevo documento para cualquier mesa
  Future<DocumentoMesa?> crearDocumento({
    required String mesaNombre,
    required String vendedor,
    required List<String> pedidosIds,
    String? formaPago,
    String? pagadoPor,
    double? propina,
    bool pagado = false,
    String? estado,
    DateTime? fechaPago,
  }) async {
    try {
      final headers = await _getHeaders();

      final Map<String, dynamic> bodyData = {
        'mesaNombre': mesaNombre,
        'vendedor': vendedor,
        'pedidosIds': pedidosIds,
        'pagado': pagado,
      };

      // Añadir datos de pago si el documento está pagado
      if (pagado) {
        bodyData['estado'] = estado ?? 'Pagado';
        bodyData['formaPago'] =
            formaPago ?? 'efectivo'; // Puede ser 'efectivo' o 'transferencia'
        bodyData['pagadoPor'] = pagadoPor ?? vendedor;
        bodyData['propina'] = propina ?? 0.0;
        bodyData['fechaPago'] = (fechaPago ?? DateTime.now()).toIso8601String();

        // Debug: mostrar información de forma de pago
        print('📝 Datos de pago en crearDocumento:');
        print('  - Forma de pago: $formaPago');
        print('  - Es pagado: $pagado');
        print('  - Estado: ${estado ?? 'Pagado'}');
      }

      final body = json.encode(bodyData);

      print('🔄 Enviando solicitud para crear documento');
      print('  - URL: ${_endpoints.documentosMesa.crear}');
      print('  - Datos: $body');

      final response = await http.post(
        Uri.parse(_endpoints.documentosMesa.crear),
        headers: headers,
        body: body,
      );

      print('📩 Respuesta creación documento: ${response.statusCode}');
      print(
        '  - Cuerpo: ${response.body.substring(0, min(200, response.body.length))}...',
      );

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final documento = DocumentoMesa.fromJson(responseData['data']);
          print('✅ Documento creado con ID: ${documento.id}');
          return documento;
        } else {
          print('❌ Formato de respuesta incorrecto: ${response.body}');
        }
      } else {
        print('❌ Error creando documento: Código ${response.statusCode}');
        print('  - Respuesta: ${response.body}');
      }
      return null;
    } catch (e) {
      print('❌ Error creando documento: $e');
      return null;
    }
  }

  /// Paga un documento existente
  Future<bool> pagarDocumento({
    required String documentoId,
    required String formaPago,
    required String pagadoPor,
    double? propina,
  }) async {
    try {
      final headers = await _getHeaders();

      // Verificar que el forma de pago sea válido (efectivo o transferencia)
      if (formaPago != 'efectivo' && formaPago != 'transferencia') {
        print(
          '⚠️ Forma de pago no reconocida: "$formaPago". Usando efectivo por defecto.',
        );
        formaPago = 'efectivo';
      }

      final Map<String, dynamic> payData = {
        'formaPago': formaPago,
        'pagadoPor': pagadoPor,
        'pagado': true, // Aseguramos que se envíe explícitamente como true
        'estado':
            'Pagado', // Asegurar que el estado sea actualizado correctamente
        'fechaPago': DateTime.now()
            .toIso8601String(), // Asegurar que se envía la fecha de pago
        'propina': propina ?? 0.0, // Siempre incluir propina, incluso si es 0
      };

      // Debug: información de pago
      print('💵 Datos de pago para documento $documentoId:');
      print('  - Forma de pago: $formaPago');
      print('  - Pagado por: $pagadoPor');
      print('  - Propina: ${propina ?? 0}');

      final body = json.encode(payData);

      print('🔄 Enviando solicitud de pago para documento $documentoId');
      print('  - URL: ${_endpoints.documentosMesa.pagar(documentoId)}');

      final response = await http.put(
        Uri.parse(_endpoints.documentosMesa.pagar(documentoId)),
        headers: headers,
        body: body,
      );

      print('📩 Respuesta: ${response.statusCode}');
      print('  - Cuerpo: ${response.body}');

      if (response.statusCode == 200) {
        // Verificar si la respuesta incluye información de éxito
        try {
          final responseData = json.decode(response.body);
          print(
            '✅ Documento pagado exitosamente: ${responseData['success'] ?? 'sin estado'}',
          );
          return true;
        } catch (e) {
          print('⚠️ No se pudo decodificar la respuesta pero el código es 200');
          return true;
        }
      } else {
        print('❌ Error al pagar documento: Código ${response.statusCode}');
        print('  - Respuesta: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error pagando documento: $e');
      return false;
    }
  }

  /// Elimina un documento
  Future<bool> eliminarDocumento(String documentoId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse(_endpoints.documentosMesa.eliminar(documentoId)),
        headers: headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error eliminando documento: $e');
      return false;
    }
  }

  /// Obtiene todos los documentos
  Future<List<DocumentoMesa>> getDocumentos() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(_endpoints.documentosMesa.listaCompleta),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Debug: verificar estructura de respuesta
        print('🔍 Respuesta del API para todos los documentos:');
        print('  - Status: ${response.statusCode}');
        print('  - Response keys: ${responseData.keys}');
        print('  - Message: ${responseData['message']}');
        print(
          '  - Data length: ${(responseData['data'] as List?)?.length ?? 0}',
        );

        // Mostrar primer elemento para debug
        final List<dynamic> jsonList = responseData['data'] ?? [];
        if (jsonList.isNotEmpty) {
          print('  - Primer elemento keys: ${jsonList.first.keys}');
          print(
            '  - Primer elemento formaPago: ${jsonList.first['formaPago']}',
          );
          print(
            '  - Primer elemento numeroDocumento: ${jsonList.first['numeroDocumento']}',
          );
          print('  - Primer elemento mesa: ${jsonList.first['mesa']}');
          print('  - Primer elemento tipo: ${jsonList.first['tipo']}');
        }

        final documentos = jsonList
            .map((json) => DocumentoMesa.fromJson(json))
            .toList();

        // Ordenar documentos por fecha descendente (más recientes primero)
        documentos.sort((a, b) {
          final fechaA = a.fechaCreacion ?? a.fecha;
          final fechaB = b.fechaCreacion ?? b.fecha;
          return fechaB.compareTo(fechaA);
        });

        return documentos;
      } else {
        print(
          '❌ Error obteniendo todos los documentos: ${response.statusCode}',
        );
        return [];
      }
    } catch (e) {
      print('❌ Error de conexión obteniendo todos los documentos: $e');
      return [];
    }
  }

  /// Anula un documento
  Future<bool> anularDocumento(String documentoId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse(_endpoints.documentosMesa.anular(documentoId)),
        headers: headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error anulando documento: $e');
      return false;
    }
  }

  /// Obtiene solo los documentos pendientes de pago
  Future<List<DocumentoMesa>> getDocumentosPendientes({String? mesa}) async {
    final documentos = mesa != null
        ? await getDocumentosPorMesa(mesa)
        : await getDocumentos();

    return documentos.where((doc) => !doc.pagado && !doc.anulado).toList();
  }

  /// Obtiene solo los documentos pagados
  Future<List<DocumentoMesa>> getDocumentosPagados({String? mesa}) async {
    final documentos = mesa != null
        ? await getDocumentosPorMesa(mesa)
        : await getDocumentos();

    return documentos.where((doc) => doc.pagado && !doc.anulado).toList();
  }

  /// Filtra documentos por rango de fechas mejorado
  List<DocumentoMesa> filtrarPorFechas(
    List<DocumentoMesa> documentos,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  ) {
    if (fechaInicio == null && fechaFin == null) return documentos;

    return documentos.where((doc) {
      final fecha = doc.fechaCreacion ?? doc.fecha;

      // Normalizar fechas para comparación solo por día
      final fechaDoc = DateTime(fecha.year, fecha.month, fecha.day);

      if (fechaInicio != null) {
        final inicioNormalizado = DateTime(
          fechaInicio.year,
          fechaInicio.month,
          fechaInicio.day,
        );
        if (fechaDoc.isBefore(inicioNormalizado)) {
          return false;
        }
      }

      if (fechaFin != null) {
        final finNormalizado = DateTime(
          fechaFin.year,
          fechaFin.month,
          fechaFin.day,
        );
        if (fechaDoc.isAfter(finNormalizado)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Obtiene documentos con formato de fecha mejorado
  String formatearFechaCompleta(DateTime fecha) {
    final ahora = DateTime.now();
    final diferencia = ahora.difference(fecha);

    if (diferencia.inDays == 0) {
      return 'Hoy ${_formatearHora(fecha)}';
    } else if (diferencia.inDays == 1) {
      return 'Ayer ${_formatearHora(fecha)}';
    } else if (diferencia.inDays < 7) {
      return '${_obtenerNombreDia(fecha)} ${_formatearHora(fecha)}';
    } else {
      return '${fecha.day}/${fecha.month}/${fecha.year} ${_formatearHora(fecha)}';
    }
  }

  String _formatearHora(DateTime fecha) {
    return '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }

  String _obtenerNombreDia(DateTime fecha) {
    const diasSemana = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    return diasSemana[fecha.weekday - 1];
  }
}
