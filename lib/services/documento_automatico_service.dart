import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/pedido.dart';
import '../models/documento_mesa.dart';
import '../services/documento_mesa_service.dart';
import '../services/pedido_service.dart';

/// Servicio especializado en la generación automática de documentos
/// tras el pago de pedidos, con lógica de negocio específica para diferentes escenarios
class DocumentoAutomaticoService {
  static final DocumentoAutomaticoService _instance = DocumentoAutomaticoService._internal();
  factory DocumentoAutomaticoService() => _instance;
  DocumentoAutomaticoService._internal();

  final DocumentoMesaService _documentoMesaService = DocumentoMesaService();
  final PedidoService _pedidoService = PedidoService();

  /// Genera automáticamente un documento tras pagar un pedido
  /// Maneja diferentes tipos de pedido y escenarios especiales
  Future<DocumentoMesa?> generarDocumentoAutomatico({
    required String pedidoId,
    required String vendedor,
    String? formaPago,
    double? propina,
    String? pagadoPor,
    bool esMovimiento = false,
    String? mesaEspecifica,
  }) async {
    try {
      print('🤖 DocumentoAutomaticoService: Iniciando generación automática');
      print('  - Pedido ID: $pedidoId');
      print('  - Vendedor: $vendedor');
      print('  - Es movimiento: $esMovimiento');
      print('  - Mesa específica: $mesaEspecifica');

      // Obtener datos completos del pedido
      final pedido = await _pedidoService.getPedidoById(pedidoId);
      
      if (pedido == null) {
        throw Exception('No se encontró el pedido con ID: $pedidoId');
      }

      // Determinar la mesa donde crear el documento
      final mesaNombre = mesaEspecifica ?? pedido.mesa;
      
      // Validar forma de pago
      final formapagoValidada = _validarFormaPago(formaPago);
      
      // Preparar datos del documento
      final datosDocumento = _prepararDatosDocumento(
        pedido: pedido,
        mesaNombre: mesaNombre,
        vendedor: vendedor,
        formaPago: formapagoValidada,
        pagadoPor: pagadoPor ?? vendedor,
        propina: propina ?? 0.0,
        esMovimiento: esMovimiento,
      );

      print('📋 Datos preparados para documento:');
      print('  - Mesa: ${datosDocumento['mesaNombre']}');
      print('  - Tipo pedido: ${pedido.tipoTexto}');
      print('  - Total: \$${pedido.total}');
      print('  - Forma pago: ${datosDocumento['formaPago']}');

      // Verificar si ya existe documento para este pedido
      final existeDocumento = await _verificarDocumentoExistente(pedidoId, mesaNombre);
      
      if (existeDocumento != null && !esMovimiento) {
        print('⚠️ Ya existe documento para este pedido: ${existeDocumento.numeroDocumento}');
        return existeDocumento;
      }

      // Crear el documento
      final documento = await _documentoMesaService.crearDocumento(
        mesaNombre: datosDocumento['mesaNombre'],
        vendedor: datosDocumento['vendedor'],
        pedidosIds: datosDocumento['pedidosIds'],
        formaPago: datosDocumento['formaPago'],
        pagadoPor: datosDocumento['pagadoPor'],
        propina: datosDocumento['propina'],
        pagado: true,
        estado: datosDocumento['estado'],
        fechaPago: DateTime.now(),
      );

      if (documento != null) {
        print('✅ Documento generado automáticamente: ${documento.numeroDocumento}');
        await _registrarEventoDocumento(pedido, documento, esMovimiento);
        return documento;
      } else {
        throw Exception('El servicio de documentos devolvió null');
      }

    } catch (e) {
      print('❌ Error en generación automática de documento: $e');
      rethrow;
    }
  }

  /// Genera documento para pedidos movidos entre mesas
  Future<DocumentoMesa?> generarDocumentoMovimiento({
    required String pedidoId,
    required String mesaOrigen,
    required String mesaDestino,
    required String vendedor,
    String? formaPago,
    double? propina,
  }) async {
    try {
      print('🚚 Generando documento por movimiento de pedido');
      print('  - De: $mesaOrigen → A: $mesaDestino');

      // Verificar documento existente en mesa origen
      final documentoOrigen = await _verificarDocumentoExistente(pedidoId, mesaOrigen);
      
      if (documentoOrigen != null) {
        print('📄 Documento existente en mesa origen: ${documentoOrigen.numeroDocumento}');
        
        // Crear documento de referencia en mesa destino
        return await generarDocumentoAutomatico(
          pedidoId: pedidoId,
          vendedor: vendedor,
          formaPago: documentoOrigen.formaPago,
          propina: documentoOrigen.propina,
          pagadoPor: vendedor,
          esMovimiento: true,
          mesaEspecifica: mesaDestino,
        );
      } else {
        // Crear nuevo documento en mesa destino
        return await generarDocumentoAutomatico(
          pedidoId: pedidoId,
          vendedor: vendedor,
          formaPago: formaPago,
          propina: propina,
          mesaEspecifica: mesaDestino,
        );
      }
    } catch (e) {
      print('❌ Error generando documento por movimiento: $e');
      return null;
    }
  }

  /// Valida y normaliza la forma de pago
  String _validarFormaPago(String? formaPago) {
    final formaNormalizada = formaPago?.toLowerCase() ?? 'efectivo';
    
    if (formaNormalizada == 'efectivo' || formaNormalizada == 'transferencia') {
      return formaNormalizada;
    }
    
    print('⚠️ Forma de pago no reconocida: "$formaPago". Usando efectivo por defecto.');
    return 'efectivo';
  }

  /// Prepara los datos necesarios para crear el documento
  Map<String, dynamic> _prepararDatosDocumento({
    required Pedido pedido,
    required String mesaNombre,
    required String vendedor,
    required String formaPago,
    required String pagadoPor,
    required double propina,
    required bool esMovimiento,
  }) {
    String estado = 'Pagado';
    
    // Ajustar estado según tipo de pedido
    switch (pedido.tipo) {
      case TipoPedido.cortesia:
        estado = 'Cortesía';
        break;
      case TipoPedido.interno:
        estado = 'Consumo Interno';
        break;
      case TipoPedido.domicilio:
        estado = esMovimiento ? 'Movido a $mesaNombre' : 'Domicilio Pagado';
        break;
      default:
        estado = esMovimiento ? 'Movido a $mesaNombre' : 'Pagado';
        break;
    }

    return {
      'mesaNombre': mesaNombre,
      'vendedor': vendedor,
      'pedidosIds': [pedido.id],
      'formaPago': formaPago,
      'pagadoPor': pagadoPor,
      'propina': propina,
      'estado': estado,
    };
  }

  /// Verifica si ya existe un documento para el pedido en la mesa especificada
  Future<DocumentoMesa?> _verificarDocumentoExistente(String pedidoId, String mesaNombre) async {
    try {
      final documentos = await _documentoMesaService.getDocumentosPorMesa(mesaNombre);
      
      return documentos.where((doc) => doc.pedidosIds.contains(pedidoId)).firstOrNull;
    } catch (e) {
      print('⚠️ Error verificando documento existente: $e');
      return null;
    }
  }

  /// Registra el evento de creación de documento para auditoría
  Future<void> _registrarEventoDocumento(Pedido pedido, DocumentoMesa documento, bool esMovimiento) async {
    try {
      final evento = {
        'timestamp': DateTime.now().toIso8601String(),
        'pedidoId': pedido.id,
        'documentoId': documento.id,
        'documentoNumero': documento.numeroDocumento,
        'mesa': documento.mesaNombre,
        'tipo': pedido.tipoTexto,
        'total': pedido.total,
        'esMovimiento': esMovimiento,
        'evento': esMovimiento ? 'documento_movimiento_creado' : 'documento_automatico_creado',
      };
      
      print('📝 Evento registrado: ${evento['evento']}');
      print('  - Documento: ${evento['documentoNumero']}');
      print('  - Mesa: ${evento['mesa']}');
      
      // Aquí se podría enviar a un servicio de auditoría si fuera necesario
    } catch (e) {
      print('⚠️ Error registrando evento de documento: $e');
    }
  }

  /// Obtiene estadísticas de documentos generados automáticamente
  Future<Map<String, int>> obtenerEstadisticasGeneracionAutomatica() async {
    try {
      // Implementar lógica para obtener estadísticas si es necesario
      return {
        'documentos_automaticos_hoy': 0,
        'documentos_movimiento_hoy': 0,
        'total_generados': 0,
      };
    } catch (e) {
      print('⚠️ Error obteniendo estadísticas: $e');
      return {};
    }
  }
}
