import 'package:intl/intl.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/factura_electronica_dian.dart';
import '../models/documento_mesa.dart';
import '../models/item_pedido.dart';
import 'configuracion_facturacion_service.dart';

/// Servicio para generar facturas electrónicas DIAN desde documentos de mesa
class FacturaElectronicaService {
  static final _configService = ConfiguracionFacturacionService();

  /// Configuración del emisor (debe venir de la configuración del negocio)
  static EmisorDian? _emisorConfiguracion;

  /// Configuración de autorización DIAN
  static String? _numeroAutorizacion;
  static DateTime? _fechaInicioAutorizacion;
  static DateTime? _fechaFinAutorizacion;
  static String? _prefijoFactura;
  static String? _rangoDesde;
  static String? _rangoHasta;
  static String? _softwareId;
  static String? _softwareSecurityCode;
  static String? _proveedorSoftwareNit;

  /// Configurar el emisor (restaurante) y guardar en MongoDB
  static Future<void> configurarEmisor(EmisorDian emisor) async {
    _emisorConfiguracion = emisor;
    await _configService.guardarEmisor(emisor);
  }

  /// Configurar autorización DIAN y guardar en MongoDB
  static Future<void> configurarAutorizacionDian({
    required String numeroAutorizacion,
    required DateTime fechaInicioAutorizacion,
    required DateTime fechaFinAutorizacion,
    required String prefijoFactura,
    required String rangoDesde,
    required String rangoHasta,
    required String softwareId,
    required String softwareSecurityCode,
    required String proveedorSoftwareNit,
  }) async {
    _numeroAutorizacion = numeroAutorizacion;
    _fechaInicioAutorizacion = fechaInicioAutorizacion;
    _fechaFinAutorizacion = fechaFinAutorizacion;
    _prefijoFactura = prefijoFactura;
    _rangoDesde = rangoDesde;
    _rangoHasta = rangoHasta;
    _softwareId = softwareId;
    _softwareSecurityCode = softwareSecurityCode;
    _proveedorSoftwareNit = proveedorSoftwareNit;

    await _configService.guardarAutorizacion({
      'numeroAutorizacion': numeroAutorizacion,
      'fechaInicioAutorizacion': fechaInicioAutorizacion.toIso8601String(),
      'fechaFinAutorizacion': fechaFinAutorizacion.toIso8601String(),
      'prefijoFactura': prefijoFactura,
      'rangoDesde': rangoDesde,
      'rangoHasta': rangoHasta,
      'softwareId': softwareId,
      'softwareSecurityCode': softwareSecurityCode,
      'proveedorSoftwareNit': proveedorSoftwareNit,
    });
  }

  /// Cargar configuración desde MongoDB
  static Future<void> cargarConfiguracion() async {
    final emisor = await _configService.obtenerEmisor();
    if (emisor != null) {
      _emisorConfiguracion = emisor;
    }

    final autorizacion = await _configService.obtenerAutorizacion();
    if (autorizacion != null) {
      _numeroAutorizacion = autorizacion['numeroAutorizacion'];
      _fechaInicioAutorizacion = autorizacion['fechaInicioAutorizacion'] != null
          ? DateTime.parse(autorizacion['fechaInicioAutorizacion'])
          : null;
      _fechaFinAutorizacion = autorizacion['fechaFinAutorizacion'] != null
          ? DateTime.parse(autorizacion['fechaFinAutorizacion'])
          : null;
      _prefijoFactura = autorizacion['prefijoFactura'];
      _rangoDesde = autorizacion['rangoDesde'];
      _rangoHasta = autorizacion['rangoHasta'];
      _softwareId = autorizacion['softwareId'];
      _softwareSecurityCode = autorizacion['softwareSecurityCode'];
      _proveedorSoftwareNit = autorizacion['proveedorSoftwareNit'];
    }
  }

  /// Generar factura electrónica desde un documento de mesa
  static Future<FacturaElectronicaDian> generarFacturaDesdeDocumentoMesa({
    required DocumentoMesa documentoMesa,
    required String numeroConsecutivo,
    String? clienteNombre,
    String? clienteIdentificacion,
    String? clienteTipoDocumento,
    String? clienteEmail,
    String? clienteTelefono,
    String? clienteDireccion,
  }) async {
    if (_emisorConfiguracion == null) {
      throw Exception('Debe configurar el emisor antes de generar facturas');
    }

    // Crear adquiriente
    final adquiriente = AdquirienteDian(
      nombre:
          clienteNombre ?? documentoMesa.clienteNombre ?? 'CONSUMIDOR FINAL',
      identificacion:
          clienteIdentificacion ??
          documentoMesa.clienteIdentificacion ??
          '222222222222', // Identificación genérica para consumidor final
      tipoDocumento:
          clienteTipoDocumento ??
          documentoMesa.clienteTipoDocumento ??
          '13', // Cédula por defecto
      tipoPersona: '2', // Persona natural por defecto
      email: clienteEmail ?? documentoMesa.clienteEmail,
      telefono: clienteTelefono ?? documentoMesa.clienteTelefono,
      direccion: clienteDireccion ?? documentoMesa.clienteDireccion,
      pais: 'CO',
    );

    // Convertir items del documento a items de factura
    final itemsFactura = await _convertirItemsDocumentoAFactura(documentoMesa);

    // Calcular totales
    final subtotal = itemsFactura.fold<double>(
      0.0,
      (sum, item) => sum + item.subtotalItem,
    );

    final totalImpuestos = itemsFactura.fold<double>(
      0.0,
      (sum, item) =>
          sum +
          item.impuestos.fold<double>(
            0.0,
            (sumImp, imp) => sumImp + imp.valorImpuesto,
          ),
    );

    // Agrupar impuestos por tipo
    final impuestosAgrupados = _agruparImpuestos(itemsFactura);

    final totalFactura =
        subtotal + totalImpuestos + (documentoMesa.propina ?? 0.0);

    // Generar número de factura con prefijo
    final numeroFactura = '${_prefijoFactura ?? 'FACT'}$numeroConsecutivo';

    // Generar hora de emisión
    final now = DateTime.now();
    final horaEmision = DateFormat('HH:mm:ss').format(now) + '-05:00';

    // Crear la factura
    final factura = FacturaElectronicaDian(
      numeroFactura: numeroFactura,
      fechaEmision: now,
      horaEmision: horaEmision,
      numeroAutorizacion: _numeroAutorizacion,
      fechaInicioAutorizacion: _fechaInicioAutorizacion,
      fechaFinAutorizacion: _fechaFinAutorizacion,
      prefijoFactura: _prefijoFactura,
      rangoDesde: _rangoDesde,
      rangoHasta: _rangoHasta,
      softwareId: _softwareId,
      softwareSecurityCode: _softwareSecurityCode,
      proveedorSoftwareNit: _proveedorSoftwareNit,
      emisor: _emisorConfiguracion!,
      adquiriente: adquiriente,
      items: itemsFactura,
      subtotal: subtotal,
      totalImpuestos: totalImpuestos,
      totalFactura: totalFactura,
      impuestos: impuestosAgrupados,
      formaPago: _mapearFormaPago(documentoMesa.formaPago),
      medioPago: _mapearMedioPago(documentoMesa.formaPago),
      mesaNombre: documentoMesa.mesaNombre,
      documentoMesaId: documentoMesa.id,
      vendedor: documentoMesa.vendedor,
      propina: documentoMesa.propina,
      estado: 'PENDIENTE',
    );

    // Generar CUFE
    final cufe = await generarCUFE(factura);
    final facturaConCufe = factura.copyWith(cufe: cufe);

    // Generar código QR
    final qrCode = generarCodigoQR(facturaConCufe);

    return facturaConCufe.copyWith(cufe: cufe, qrCode: qrCode);
  }

  /// Convertir items del documento de mesa a items de factura DIAN
  static Future<List<ItemFacturaDian>> _convertirItemsDocumentoAFactura(
    DocumentoMesa documentoMesa,
  ) async {
    final itemsFactura = <ItemFacturaDian>[];
    int numeroLinea = 1;

    // Recorrer todos los pedidos del documento
    for (final pedido in documentoMesa.pedidos) {
      for (final item in pedido.items) {
        // Calcular impuestos para este item
        final impuestosItem = _calcularImpuestosItem(item);

        final subtotalItem = item.subtotal;
        final totalImpuestosItem = impuestosItem.fold<double>(
          0.0,
          (sum, imp) => sum + imp.valorImpuesto,
        );
        final totalItem = subtotalItem + totalImpuestosItem;

        itemsFactura.add(
          ItemFacturaDian(
            numeroLinea: numeroLinea++,
            codigoProducto: item.productoId,
            descripcion: item.productoNombre ?? 'Producto sin nombre',
            cantidad: item.cantidad.toDouble(),
            unidadMedida: 'EA', // Unidad por defecto
            precioUnitario: item.precioUnitario,
            subtotalItem: subtotalItem,
            descuento: 0.0, // ItemPedido no tiene campo descuento individual
            impuestos: impuestosItem,
            totalItem: totalItem,
            notas: item.notas,
          ),
        );
      }
    }

    // Agregar propina como item adicional si existe
    if (documentoMesa.propina != null && documentoMesa.propina! > 0) {
      itemsFactura.add(
        ItemFacturaDian(
          numeroLinea: numeroLinea,
          codigoProducto: 'PROPINA',
          descripcion: 'Propina voluntaria',
          cantidad: 1.0,
          unidadMedida: 'EA',
          precioUnitario: documentoMesa.propina!,
          subtotalItem: documentoMesa.propina!,
          impuestos: [], // La propina generalmente no tiene IVA
          totalItem: documentoMesa.propina!,
        ),
      );
    }

    return itemsFactura;
  }

  /// Calcular impuestos para un item (principalmente IVA)
  static List<ImpuestoDian> _calcularImpuestosItem(ItemPedido item) {
    // En Colombia, la mayoría de alimentos tienen IVA 0%, pero algunos tienen 5% o 19%
    // Aquí puedes ajustar la lógica según tu negocio

    final impuestos = <ImpuestoDian>[];

    // Por defecto, asumir IVA 19% para restaurantes
    // Puedes agregar lógica para determinar la tarifa según el producto
    final tarifaIva = 19.0; // Puedes hacer esto configurable por producto

    if (tarifaIva > 0) {
      final baseImponible = item.subtotal;
      final valorIva = baseImponible * (tarifaIva / 100);

      impuestos.add(
        ImpuestoDian(
          tipoImpuesto: '01',
          nombreImpuesto: 'IVA',
          baseImponible: baseImponible,
          porcentaje: tarifaIva,
          valorImpuesto: valorIva,
        ),
      );
    }

    return impuestos;
  }

  /// Agrupar impuestos por tipo y tarifa
  static List<ImpuestoDian> _agruparImpuestos(List<ItemFacturaDian> items) {
    final mapaImpuestos = <String, ImpuestoDian>{};

    for (final item in items) {
      for (final impuesto in item.impuestos) {
        final clave = '${impuesto.tipoImpuesto}_${impuesto.porcentaje}';

        if (mapaImpuestos.containsKey(clave)) {
          final impuestoExistente = mapaImpuestos[clave]!;
          mapaImpuestos[clave] = ImpuestoDian(
            tipoImpuesto: impuesto.tipoImpuesto,
            nombreImpuesto: impuesto.nombreImpuesto,
            baseImponible:
                impuestoExistente.baseImponible + impuesto.baseImponible,
            porcentaje: impuesto.porcentaje,
            valorImpuesto:
                impuestoExistente.valorImpuesto + impuesto.valorImpuesto,
          );
        } else {
          mapaImpuestos[clave] = impuesto;
        }
      }
    }

    return mapaImpuestos.values.toList();
  }

  /// Mapear forma de pago a código DIAN
  static String _mapearFormaPago(String? formaPago) {
    // 1: Contado, 2: Crédito
    if (formaPago == null || formaPago.isEmpty) return '1';

    final formaLower = formaPago.toLowerCase();
    if (formaLower.contains('credito') || formaLower.contains('crédito')) {
      return '2';
    }
    return '1'; // Por defecto: Contado
  }

  /// Mapear medio de pago a código DIAN
  static String _mapearMedioPago(String? formaPago) {
    // 10: Efectivo, 41: Tarjeta débito, 42: Tarjeta crédito, 47: Transferencia, 48: PSE
    if (formaPago == null || formaPago.isEmpty) return '10';

    final formaLower = formaPago.toLowerCase();

    if (formaLower.contains('efectivo') || formaLower == 'cash') {
      return '10';
    } else if (formaLower.contains('debito') || formaLower.contains('débito')) {
      return '41';
    } else if (formaLower.contains('tarjeta') ||
        formaLower.contains('credito')) {
      return '42';
    } else if (formaLower.contains('transferencia')) {
      return '47';
    } else if (formaLower.contains('pse')) {
      return '48';
    }

    return '10'; // Por defecto: Efectivo
  }

  /// Generar CUFE (Código Único de Factura Electrónica)
  /// Según Resolución DIAN, el CUFE se genera con SHA-384
  static Future<String> generarCUFE(FacturaElectronicaDian factura) async {
    // Formato del CUFE según DIAN:
    // NumFac + FecFac + HorFac + ValFac + CodImp1 + ValImp1 + CodImp2 + ValImp2 +
    // CodImp3 + ValImp3 + ValTot + NitOFE + NumAdq + ClTec + TipoAmb

    final numFac = factura.numeroFactura;
    final fecFac = DateFormat('yyyyMMdd').format(factura.fechaEmision);
    final horFac = factura.horaEmision.split('-')[0].replaceAll(':', '');
    final valFac = factura.subtotal.toStringAsFixed(2);

    // Códigos de impuestos (01: IVA, 02: IC, 03: ICA)
    var codImp1 = '01';
    var valImp1 = '0.00';
    var codImp2 = '02';
    var valImp2 = '0.00';
    var codImp3 = '03';
    var valImp3 = '0.00';

    // Buscar IVA
    final iva = factura.impuestos.firstWhere(
      (imp) => imp.tipoImpuesto == '01',
      orElse: () => ImpuestoDian(
        tipoImpuesto: '01',
        nombreImpuesto: 'IVA',
        baseImponible: 0,
        porcentaje: 0,
        valorImpuesto: 0,
      ),
    );
    valImp1 = iva.valorImpuesto.toStringAsFixed(2);

    final valTot = factura.totalFactura.toStringAsFixed(2);
    final nitOFE = factura.emisor.nit + factura.emisor.digitoVerificacion;
    final numAdq = factura.adquiriente.identificacion;
    final clTec = factura.softwareSecurityCode ?? '';
    final tipoAmb = '2'; // 1: Producción, 2: Habilitación/Pruebas

    // Concatenar todos los valores
    final cadena =
        '$numFac$fecFac$horFac$valFac$codImp1$valImp1$codImp2$valImp2$codImp3$valImp3$valTot$nitOFE$numAdq$clTec$tipoAmb';

    // Generar hash SHA-384
    final bytes = utf8.encode(cadena);
    final digest = sha384.convert(bytes);

    return digest.toString();
  }

  /// Generar código QR para la factura
  static String generarCodigoQR(FacturaElectronicaDian factura) {
    final lineas = <String>[
      'NroFactura=${factura.numeroFactura}',
      'NitFacturador=${factura.emisor.nit}',
      'NitAdquiriente=${factura.adquiriente.identificacion}',
      'FechaFactura=${DateFormat('yyyy-MM-dd').format(factura.fechaEmision)}',
      'ValorTotalFactura=${factura.totalFactura.toStringAsFixed(2)}',
      'CUFE=${factura.cufe}',
      'URL=https://catalogo-vpfe.dian.gov.co/Document/FindDocument?documentKey=${factura.cufe}',
    ];

    return lineas.join('\n');
  }

  /// Validar que una factura esté lista para enviarse a la DIAN
  static bool validarFacturaParaEnvio(FacturaElectronicaDian factura) {
    // Validaciones básicas
    if (factura.numeroFactura.isEmpty) return false;
    if (factura.cufe == null || factura.cufe!.isEmpty) return false;
    if (factura.items.isEmpty) return false;
    if (factura.totalFactura <= 0) return false;

    // Validar emisor
    if (factura.emisor.nit.isEmpty) return false;
    if (factura.emisor.razonSocial.isEmpty) return false;

    // Validar adquiriente
    if (factura.adquiriente.identificacion.isEmpty) return false;
    if (factura.adquiriente.nombre.isEmpty) return false;

    return true;
  }
}
