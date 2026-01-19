import 'package:flutter/material.dart';
import 'item_pedido.dart'; // Importar el ItemPedido correcto
import 'historial_edicion.dart'; // Para el historial de cambios
import 'pago_parcial.dart'; // Para pagos mixtos

enum TipoPedido { normal, rt, interno, cancelado, cortesia, domicilio }

enum EstadoPedido { activo, pagado, cancelado, cortesia }

extension EstadoPedidoExtension on EstadoPedido {
  String toJson() {
    return toString().split('.').last;
  }

  static EstadoPedido fromJson(String json) {
    // Convertir a minúsculas para comparación case-insensitive
    final jsonLowerCase = json.toLowerCase();
    return EstadoPedido.values.firstWhere(
      (e) => e.toString().split('.').last.toLowerCase() == jsonLowerCase,
      orElse: () => EstadoPedido.activo,
    );
  }
}

extension TipoPedidoExtension on TipoPedido {
  String toJson() {
    return toString().split('.').last;
  }

  static TipoPedido fromJson(String json) {
    // Convertir a minúsculas para comparación case-insensitive
    final jsonLowerCase = json.toLowerCase();
    return TipoPedido.values.firstWhere(
      (e) => e.toString().split('.').last.toLowerCase() == jsonLowerCase,
      orElse: () => TipoPedido.normal,
    );
  }
}

class Pedido {
  String id;
  DateTime fecha;
  TipoPedido tipo;
  String mesa;
  String? cliente;
  String mesero;
  List<ItemPedido> items;
  double total;
  EstadoPedido estado;
  String? notas;
  String? plataforma;
  String? pedidoPor;
  String? guardadoPor;
  DateTime? fechaCortesia;
  String? formaPago;
  bool incluyePropina;
  double descuento;
  String? cuadreId; // ID del cuadre de caja al que pertenece este pedido

  // Campos adicionales para pagos según la guía de integración
  double totalPagado = 0.0;
  List<PagoParcial> pagosParciales = [];
  List<HistorialEdicion> historialEdiciones = [];
  DateTime? fechaPago;
  String? pagadoPor;
  double propina = 0.0;

  // ===== NUEVOS CAMPOS PARA FACTURACIÓN ELECTRÓNICA =====

  // 📄 INFORMACIÓN DE FACTURA
  String? descripcionFactura; // Descripción general de la factura
  List<String>? archivosAdjuntos; // URLs de archivos adjuntos
  String tipoFactura; // "POS", "Electrónica", "Computarizada"
  DateTime? fechaVencimiento; // Fecha de vencimiento de la factura
  String? numeroFactura; // Número único de factura
  String? codigoBarrasFactura; // Código de barras de la factura

  // 💰 RETENCIONES Y TRIBUTOS
  double retencion; // % de retención
  double valorRetencion; // Valor calculado de retención
  double reteIVA; // % de ReteIVA
  double valorReteIVA; // Valor calculado de ReteIVA
  double reteICA; // % de ReteICA
  double valorReteICA; // Valor calculado de ReteICA
  Map<String, dynamic>? aiu; // AIU (Administración, Imprevistos, Utilidad)

  // 🎯 DESCUENTOS DETALLADOS
  String tipoDescuentoGeneral; // "Valor" o "Porcentaje"
  double descuentoGeneral; // Valor del descuento general
  double descuentoProductos; // Suma de descuentos de items individuales

  // 📊 TOTALES CALCULADOS
  double subtotal; // Suma de items sin impuestos/descuentos
  double totalImpuestos; // Suma de todos los impuestos
  double totalDescuentos; // Suma de todos los descuentos
  double totalRetenciones; // Suma de todas las retenciones
  double totalFinal; // Total después de todo

  void setFormaPago(String formaPago) {
    this.formaPago = formaPago;
  }

  void setIncluyePropina(bool incluyePropina) {
    this.incluyePropina = incluyePropina;
  }

  void setDescuento(double descuento) {
    this.descuento = descuento;
  }

  Pedido({
    required this.id,
    required this.fecha,
    required this.tipo,
    required this.mesa,
    required this.mesero,
    required this.items,
    required this.total,
    required this.estado,
    this.cliente,
    this.notas,
    this.plataforma,
    this.pedidoPor,
    this.guardadoPor,
    this.fechaCortesia,
    this.formaPago,
    this.incluyePropina = false,
    this.descuento = 0,
    this.cuadreId, // ID del cuadre de caja (opcional pero recomendado)
    this.totalPagado = 0.0,
    this.pagosParciales = const [],
    this.historialEdiciones = const [],
    this.fechaPago,
    this.pagadoPor,
    this.propina = 0.0,
    // Nuevos campos de facturación
    this.descripcionFactura,
    this.archivosAdjuntos,
    this.tipoFactura = 'POS',
    this.fechaVencimiento,
    this.numeroFactura,
    this.codigoBarrasFactura,
    this.retencion = 0.0,
    this.valorRetencion = 0.0,
    this.reteIVA = 0.0,
    this.valorReteIVA = 0.0,
    this.reteICA = 0.0,
    this.valorReteICA = 0.0,
    this.aiu,
    this.tipoDescuentoGeneral = 'Valor',
    this.descuentoGeneral = 0.0,
    this.descuentoProductos = 0.0,
    this.subtotal = 0.0,
    this.totalImpuestos = 0.0,
    this.totalDescuentos = 0.0,
    this.totalRetenciones = 0.0,
    this.totalFinal = 0.0,
  });

  String get tipoTexto {
    switch (tipo) {
      case TipoPedido.normal:
        return 'Normal';
      case TipoPedido.rt:
        return 'RT';
      case TipoPedido.interno:
        return 'Interno';
      case TipoPedido.cancelado:
        return 'Cancelado';
      case TipoPedido.cortesia:
        return 'Cortesía';
      case TipoPedido.domicilio:
        return 'Domicilio';
    }
  }

  String get estadoTexto {
    switch (estado) {
      case EstadoPedido.activo:
        return 'Activo';
      case EstadoPedido.pagado:
        return 'Pagado';
      case EstadoPedido.cancelado:
        return 'Cancelado';
      case EstadoPedido.cortesia:
        return 'Cortesía';
    }
  }

  // Método para verificar si un pedido está realmente pagado, considerando
  // todas las formas posibles de determinar el estado
  bool get estaPagado {
    // Estado explícito como pagado o cortesía
    if (estado == EstadoPedido.pagado || estado == EstadoPedido.cortesia) {
      return true;
    }

    // Si tiene pagadoPor definido, se considera como pagado
    if (pagadoPor != null && pagadoPor!.isNotEmpty) {
      return true;
    }

    // Si tiene fechaPago, se considera como pagado
    if (fechaPago != null) {
      return true;
    }

    // Si tiene formaPago definido, se considera como pagado
    if (formaPago != null && formaPago!.isNotEmpty) {
      return true;
    }

    // Si tiene totalPagado > 0, se considera como pagado
    if (totalPagado > 0) {
      return true;
    }

    // Si tiene pagosParciales, se considera como pagado
    if (pagosParciales.isNotEmpty) {
      return true;
    }

    return false;
  }

  Color getColorByTipo() {
    switch (tipo) {
      case TipoPedido.normal:
        return Colors.blue;
      case TipoPedido.rt:
        return Colors.purple;
      case TipoPedido.interno:
        return Colors.orange;
      case TipoPedido.cancelado:
        return Colors.red;
      case TipoPedido.cortesia:
        return Colors.green;
      case TipoPedido.domicilio:
        return Colors.cyan;
    }
  }

  Color getColorByEstado() {
    switch (estado) {
      case EstadoPedido.activo:
        return Colors.green;
      case EstadoPedido.pagado:
        return Colors.blue;
      case EstadoPedido.cancelado:
        return Colors.red;
      case EstadoPedido.cortesia:
        return Colors.green;
    }
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'fecha': fecha.toIso8601String(),
    'tipo': tipo.toJson(),
    'mesa': mesa,
    'cliente': cliente,
    'mesero': mesero,
    'items': items.map((item) => item.toJson()).toList(),
    'total': total,
    'estado': estado.toJson(),
    'notas': notas ?? "", // Asegurar que notas nunca sea null
    'plataforma': plataforma,
    'pedidoPor': pedidoPor,
    'guardadoPor': guardadoPor,
    'fechaCortesia': fechaCortesia?.toIso8601String(),
    'formaPago': formaPago,
    'incluyePropina': incluyePropina,
    'descuento': descuento,
    if (cuadreId != null)
      'cuadreId': cuadreId, // Añadimos el cuadreId si existe
    'totalPagado': totalPagado,
    if (pagosParciales.isNotEmpty)
      'pagosParciales': pagosParciales.map((pago) => pago.toJson()).toList(),
    if (historialEdiciones.isNotEmpty)
      'historialEdiciones': historialEdiciones.map((h) => h.toJson()).toList(),
    if (fechaPago != null) 'fechaPago': fechaPago!.toIso8601String(),
    if (pagadoPor != null) 'pagadoPor': pagadoPor,
    'propina': propina,
    // Nuevos campos de facturación
    if (descripcionFactura != null) 'descripcionFactura': descripcionFactura,
    if (archivosAdjuntos != null) 'archivosAdjuntos': archivosAdjuntos,
    'tipoFactura': tipoFactura,
    if (fechaVencimiento != null)
      'fechaVencimiento': fechaVencimiento!.toIso8601String(),
    if (numeroFactura != null) 'numeroFactura': numeroFactura,
    if (codigoBarrasFactura != null) 'codigoBarrasFactura': codigoBarrasFactura,
    'retencion': retencion,
    'valorRetencion': valorRetencion,
    'reteIVA': reteIVA,
    'valorReteIVA': valorReteIVA,
    'reteICA': reteICA,
    'valorReteICA': valorReteICA,
    if (aiu != null) 'aiu': aiu,
    'tipoDescuentoGeneral': tipoDescuentoGeneral,
    'descuentoGeneral': descuentoGeneral,
    'descuentoProductos': descuentoProductos,
    'subtotal': subtotal,
    'totalImpuestos': totalImpuestos,
    'totalDescuentos': totalDescuentos,
    'totalRetenciones': totalRetenciones,
    'totalFinal': totalFinal,
  };

  factory Pedido.fromJson(Map<String, dynamic> json) {
    // Parsear historial de ediciones si está presente
    List<HistorialEdicion> historial = [];
    if (json['historialEdiciones'] != null) {
      historial = (json['historialEdiciones'] as List<dynamic>)
          .map((item) => HistorialEdicion.fromJson(item))
          .toList();
    }

    // Parsear pagos parciales si están presentes
    List<PagoParcial> pagosParciales = [];
    if (json['pagosParciales'] != null) {
      pagosParciales = (json['pagosParciales'] as List<dynamic>)
          .map((item) => PagoParcial.fromJson(item))
          .toList();
    }

    return Pedido(
      id: json['_id'] ?? json['id'] ?? '',
      fecha: DateTime.parse(json['fecha']),
      tipo: TipoPedidoExtension.fromJson(json['tipo'] ?? 'normal'),
      mesa: json['mesa'] ?? '',
      cliente:
          json['cliente'] ??
          json['nombrePedido'], // Usar nombrePedido como cliente si no hay cliente
      mesero: json['mesero'] ?? '',
      items:
          (json['items'] as List<dynamic>?)
              ?.map((item) => ItemPedido.fromJson(item))
              .toList() ??
          [],
      total: (json['total'] ?? 0).toDouble(),
      estado: EstadoPedidoExtension.fromJson(json['estado'] ?? 'activo'),
      notas: json['notas'],
      plataforma: json['plataforma'] ?? 'local',
      pedidoPor: json['pedidoPor'] ?? json['guardadoPor'],
      guardadoPor: json['guardadoPor'],
      fechaCortesia: json['fechaCortesia'] != null
          ? DateTime.parse(json['fechaCortesia'])
          : null,
      formaPago: json['formaPago'],
      incluyePropina: json['incluyePropina'] ?? false,
      descuento: (json['descuento'] ?? 0).toDouble(),
      cuadreId: json['cuadreId']
          ?.toString(), // Capturamos el ID del cuadre de caja
      totalPagado: (json['totalPagado'] ?? 0).toDouble(),
      pagosParciales: pagosParciales,
      historialEdiciones: historial,
      fechaPago: json['fechaPago'] != null
          ? DateTime.parse(json['fechaPago'])
          : null,
      pagadoPor: json['pagadoPor'],
      propina: (json['propina'] ?? 0).toDouble(),
      // Nuevos campos de facturación
      descripcionFactura: json['descripcionFactura'],
      archivosAdjuntos: json['archivosAdjuntos'] != null
          ? List<String>.from(json['archivosAdjuntos'])
          : null,
      tipoFactura: json['tipoFactura'] ?? 'POS',
      fechaVencimiento: json['fechaVencimiento'] != null
          ? DateTime.parse(json['fechaVencimiento'])
          : null,
      numeroFactura: json['numeroFactura'],
      codigoBarrasFactura: json['codigoBarrasFactura'],
      retencion: (json['retencion'] ?? 0).toDouble(),
      valorRetencion: (json['valorRetencion'] ?? 0).toDouble(),
      reteIVA: (json['reteIVA'] ?? 0).toDouble(),
      valorReteIVA: (json['valorReteIVA'] ?? 0).toDouble(),
      reteICA: (json['reteICA'] ?? 0).toDouble(),
      valorReteICA: (json['valorReteICA'] ?? 0).toDouble(),
      aiu: json['aiu'] != null ? Map<String, dynamic>.from(json['aiu']) : null,
      tipoDescuentoGeneral: json['tipoDescuentoGeneral'] ?? 'Valor',
      descuentoGeneral: (json['descuentoGeneral'] ?? 0).toDouble(),
      descuentoProductos: (json['descuentoProductos'] ?? 0).toDouble(),
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      totalImpuestos: (json['totalImpuestos'] ?? 0).toDouble(),
      totalDescuentos: (json['totalDescuentos'] ?? 0).toDouble(),
      totalRetenciones: (json['totalRetenciones'] ?? 0).toDouble(),
      totalFinal: (json['totalFinal'] ?? 0).toDouble(),
    );
  }
}
