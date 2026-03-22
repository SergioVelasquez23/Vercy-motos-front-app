import 'package:flutter/foundation.dart';
import 'pedido.dart';
import 'item_pedido.dart';
import 'user.dart';

/// Modelo que representa una factura en el sistema
class Factura {
  final String? id;
  final String? numero;
  final String clienteNombre;
  final String? clienteNit;
  final String? clienteTelefono;
  final String? clienteDireccion;
  final String? clienteDepartamento;
  final String? clienteCiudad;
  final String? clienteCorreo;
  final double total;
  final double? descuento;
  final double subtotal;
  final String? estadoPago; // "PAGADO", "PENDIENTE", "ANULADO"
  final String? metodoPago; // "EFECTIVO", "TARJETA", "CHEQUE", etc.
  final bool emitida;
  final bool anulada;
  final String? motivoAnulacion;
  final DateTime? fechaCreacion;
  final DateTime? fechaPago;
  final List<String>? pedidosIds;
  final List<ItemPedido>? items;
  final User? usuario;
  final Map<String, dynamic>? datosAdicionales;
  
  // ===== CAMPOS PARA FACTURACIÓN ELECTRÓNICA DIAN =====
  final String? cufe; // Código Único de Factura Electrónica (SHA-384)
  final String? uuid; // Identificador único universal
  final String? qrCode; // Código QR para validación
  final String?
  estadoDIAN; // "PENDIENTE", "PROCESANDO", "ACEPTADA", "RECHAZADA"
  final String? xmlFactura; // XML UBL 2.1 generado
  final String? numeroDocumentoElectronico; // Número de FE con prefijo
  final DateTime? fechaSolicitud; // Fecha de envío a DIAN
  final String? respuestaDIAN; // XML respuesta de DIAN
  final String? motivoRechazo; // Razón del rechazo si aplica
  final String? trackId; // ID de seguimiento en DIAN

  Factura({
    this.id,
    this.numero,
    required this.clienteNombre,
    this.clienteNit,
    this.clienteTelefono,
    this.clienteDireccion,
    this.clienteDepartamento,
    this.clienteCiudad,
    this.clienteCorreo,
    required this.total,
    this.descuento = 0.0,
    required this.subtotal,
    this.estadoPago = "PENDIENTE",
    this.metodoPago,
    this.emitida = false,
    this.anulada = false,
    this.motivoAnulacion,
    this.fechaCreacion,
    this.fechaPago,
    this.pedidosIds,
    this.items,
    this.usuario,
    this.datosAdicionales,
    // DIAN
    this.cufe,
    this.uuid,
    this.qrCode,
    this.estadoDIAN,
    this.xmlFactura,
    this.numeroDocumentoElectronico,
    this.fechaSolicitud,
    this.respuestaDIAN,
    this.motivoRechazo,
    this.trackId,
  });

  /// Crea una copia de la factura con los campos actualizados
  Factura copyWith({
    String? id,
    String? numero,
    String? clienteNombre,
    String? clienteNit,
    String? clienteTelefono,
    String? clienteDireccion,
    String? clienteDepartamento,
    String? clienteCiudad,
    String? clienteCorreo,
    double? total,
    double? descuento,
    double? subtotal,
    String? estadoPago,
    String? metodoPago,
    bool? emitida,
    bool? anulada,
    String? motivoAnulacion,
    DateTime? fechaCreacion,
    DateTime? fechaPago,
    List<String>? pedidosIds,
    List<ItemPedido>? items,
    User? usuario,
    Map<String, dynamic>? datosAdicionales,
    // DIAN
    String? cufe,
    String? uuid,
    String? qrCode,
    String? estadoDIAN,
    String? xmlFactura,
    String? numeroDocumentoElectronico,
    DateTime? fechaSolicitud,
    String? respuestaDIAN,
    String? motivoRechazo,
    String? trackId,
  }) {
    return Factura(
      id: id ?? this.id,
      numero: numero ?? this.numero,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      clienteNit: clienteNit ?? this.clienteNit,
      clienteTelefono: clienteTelefono ?? this.clienteTelefono,
      clienteDireccion: clienteDireccion ?? this.clienteDireccion,
      clienteDepartamento: clienteDepartamento ?? this.clienteDepartamento,
      clienteCiudad: clienteCiudad ?? this.clienteCiudad,
      clienteCorreo: clienteCorreo ?? this.clienteCorreo,
      total: total ?? this.total,
      descuento: descuento ?? this.descuento,
      subtotal: subtotal ?? this.subtotal,
      estadoPago: estadoPago ?? this.estadoPago,
      metodoPago: metodoPago ?? this.metodoPago,
      emitida: emitida ?? this.emitida,
      anulada: anulada ?? this.anulada,
      motivoAnulacion: motivoAnulacion ?? this.motivoAnulacion,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaPago: fechaPago ?? this.fechaPago,
      pedidosIds: pedidosIds ?? this.pedidosIds,
      items: items ?? this.items,
      usuario: usuario ?? this.usuario,
      datosAdicionales: datosAdicionales ?? this.datosAdicionales,
      // DIAN
      cufe: cufe ?? this.cufe,
      uuid: uuid ?? this.uuid,
      qrCode: qrCode ?? this.qrCode,
      estadoDIAN: estadoDIAN ?? this.estadoDIAN,
      xmlFactura: xmlFactura ?? this.xmlFactura,
      numeroDocumentoElectronico:
          numeroDocumentoElectronico ?? this.numeroDocumentoElectronico,
      fechaSolicitud: fechaSolicitud ?? this.fechaSolicitud,
      respuestaDIAN: respuestaDIAN ?? this.respuestaDIAN,
      motivoRechazo: motivoRechazo ?? this.motivoRechazo,
      trackId: trackId ?? this.trackId,
    );
  }

  /// Convierte la factura a un mapa JSON
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (numero != null) 'numero': numero,
      'clienteNombre': clienteNombre,
      if (clienteNit != null) 'clienteNit': clienteNit,
      if (clienteTelefono != null) 'clienteTelefono': clienteTelefono,
      if (clienteDireccion != null) 'clienteDireccion': clienteDireccion,
      if (clienteDepartamento != null)
        'clienteDepartamento': clienteDepartamento,
      if (clienteCiudad != null) 'clienteCiudad': clienteCiudad,
      if (clienteCorreo != null) 'clienteCorreo': clienteCorreo,
      'total': total,
      'descuento': descuento,
      'subtotal': subtotal,
      'estadoPago': estadoPago,
      if (metodoPago != null) 'metodoPago': metodoPago,
      'emitida': emitida,
      'anulada': anulada,
      if (motivoAnulacion != null) 'motivoAnulacion': motivoAnulacion,
      if (fechaCreacion != null)
        'fechaCreacion': fechaCreacion?.toIso8601String(),
      if (fechaPago != null) 'fechaPago': fechaPago?.toIso8601String(),
      if (pedidosIds != null) 'pedidosIds': pedidosIds,
      if (items != null) 'items': items?.map((item) => item.toJson()).toList(),
      if (usuario != null) 'usuario': usuario?.toJson(),
      if (datosAdicionales != null) 'datosAdicionales': datosAdicionales,
      // DIAN
      if (cufe != null) 'cufe': cufe,
      if (uuid != null) 'uuid': uuid,
      if (qrCode != null) 'qrCode': qrCode,
      if (estadoDIAN != null) 'estadoDIAN': estadoDIAN,
      if (xmlFactura != null) 'xmlFactura': xmlFactura,
      if (numeroDocumentoElectronico != null)
        'numeroDocumentoElectronico': numeroDocumentoElectronico,
      if (fechaSolicitud != null)
        'fechaSolicitud': fechaSolicitud?.toIso8601String(),
      if (respuestaDIAN != null) 'respuestaDIAN': respuestaDIAN,
      if (motivoRechazo != null) 'motivoRechazo': motivoRechazo,
      if (trackId != null) 'trackId': trackId,
    };
  }

  /// Crea una factura a partir de un mapa JSON
  factory Factura.fromJson(Map<String, dynamic> json) {
    // Manejo de fechas que pueden venir en diferentes formatos
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return null;
        }
      }
      return null;
    }

    // Manejo de listas que pueden venir en diferentes formatos
    List<String> parseStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) {
        return value.map((item) => item.toString()).toList();
      }
      return [];
    }

    // Manejo de lista de items
    List<ItemPedido>? parseItems(dynamic value) {
      if (value == null) return null;
      if (value is List) {
        return value.map((item) => ItemPedido.fromJson(item)).toList();
      }
      return null;
    }

    return Factura(
      id: json['id'],
      numero: json['numero'],
      clienteNombre: json['clienteNombre'] ?? 'Cliente General',
      clienteNit: json['clienteNit'],
      clienteTelefono: json['clienteTelefono'],
      clienteDireccion: json['clienteDireccion'],
      clienteDepartamento: json['clienteDepartamento'],
      clienteCiudad: json['clienteCiudad'],
      clienteCorreo: json['clienteCorreo'],
      total: json['total']?.toDouble() ?? 0.0,
      descuento: json['descuento']?.toDouble() ?? 0.0,
      subtotal: json['subtotal']?.toDouble() ?? 0.0,
      estadoPago: json['estadoPago'] ?? 'PENDIENTE',
      metodoPago: json['metodoPago'],
      emitida: json['emitida'] ?? false,
      anulada: json['anulada'] ?? false,
      motivoAnulacion: json['motivoAnulacion'],
      fechaCreacion: parseDateTime(json['fechaCreacion']),
      fechaPago: parseDateTime(json['fechaPago']),
      pedidosIds: parseStringList(json['pedidosIds']),
      items: parseItems(json['items']),
      usuario: json['usuario'] != null ? User.fromJson(json['usuario']) : null,
      datosAdicionales: json['datosAdicionales'],
      // DIAN
      cufe: json['cufe'],
      uuid: json['uuid'],
      qrCode: json['qrCode'],
      estadoDIAN: json['estadoDIAN'],
      xmlFactura: json['xmlFactura'],
      numeroDocumentoElectronico: json['numeroDocumentoElectronico'],
      fechaSolicitud: parseDateTime(json['fechaSolicitud']),
      respuestaDIAN: json['respuestaDIAN'],
      motivoRechazo: json['motivoRechazo'],
      trackId: json['trackId'],
    );
  }

  /// Crea una factura a partir de un pedido
  factory Factura.fromPedido(
    Pedido pedido, {
    String? clienteNombre,
    String? clienteNit,
    String? clienteTelefono,
    String? clienteDireccion,
    String? clienteDepartamento,
    String? clienteCiudad,
    String? clienteCorreo,
    double? descuentoAdicional,
  }) {
    // Usa el descuento del pedido si no se proporciona uno adicional
    final descuentoTotal = descuentoAdicional ?? pedido.descuento;

    return Factura(
      clienteNombre: clienteNombre ?? pedido.cliente ?? 'Cliente General',
      clienteNit: clienteNit,
      clienteTelefono: clienteTelefono,
      clienteDireccion: clienteDireccion,
      clienteDepartamento: clienteDepartamento,
      clienteCiudad: clienteCiudad,
      clienteCorreo: clienteCorreo,
      total: pedido.total - descuentoTotal,
      descuento: descuentoTotal,
      subtotal: pedido.total,
      pedidosIds: [pedido.id], // pedido.id ya es una String no nula
      items: pedido.items,
      // No hay campo usuario en Pedido, usamos guardadoPor como referencia
      datosAdicionales: {
        'mesero': pedido.mesero,
        'guardadoPor': pedido.guardadoPor,
        'pedidoPor': pedido.pedidoPor,
        'tipo': pedido.tipo.toJson(),
        'formaPago': pedido.formaPago,
      },
      fechaCreacion: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'Factura{id: $id, numero: $numero, clienteNombre: $clienteNombre, total: $total, estadoPago: $estadoPago}';
  }
}
