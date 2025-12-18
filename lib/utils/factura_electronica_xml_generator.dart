import 'package:intl/intl.dart';
import 'package:xml/xml.dart' as xml;
import '../models/factura_electronica_dian.dart';

/// Utilidad para generar XML UBL 2.1 según especificaciones DIAN
class FacturaElectronicaXmlGenerator {
  /// Generar XML completo de la factura electrónica en formato UBL 2.1
  static String generarXmlUBL(FacturaElectronicaDian factura) {
    final builder = xml.XmlBuilder();

    // Documento raíz con namespaces
    builder.processing('xml', 'version="1.0" encoding="UTF-8" standalone="no"');

    builder.element(
      'Invoice',
      namespaces: {
        'urn:oasis:names:specification:ubl:schema:xsd:Invoice-2': '',
        'urn:oasis:names:specification:ubl:schema:xsd:CommonAggregateComponents-2':
            'cac',
        'urn:oasis:names:specification:ubl:schema:xsd:CommonBasicComponents-2':
            'cbc',
        'http://www.w3.org/2000/09/xmldsig#': 'ds',
        'urn:oasis:names:specification:ubl:schema:xsd:CommonExtensionComponents-2':
            'ext',
        'dian:gov:co:facturaelectronica:Structures-2-1': 'sts',
        'http://uri.etsi.org/01903/v1.3.2#': 'xades',
        'http://uri.etsi.org/01903/v1.4.1#': 'xades141',
        'http://www.w3.org/2001/XMLSchema-instance': 'xsi',
      },
      nest: () {
        // Extensiones DIAN
        _agregarExtensiones(builder, factura);

        // Información básica de la factura
        _agregarInformacionBasica(builder, factura);

        // Período de facturación
        _agregarPeriodoFacturacion(builder, factura);

        // Proveedor (Emisor/Restaurante)
        _agregarProveedor(builder, factura);

        // Cliente (Adquiriente)
        _agregarCliente(builder, factura);

        // Medios de pago
        _agregarMediosPago(builder, factura);

        // Totales de impuestos
        _agregarTotalesImpuestos(builder, factura);

        // Total monetario
        _agregarTotalMonetario(builder, factura);

        // Líneas de factura (items)
        _agregarLineasFactura(builder, factura);
      },
    );

    final document = builder.buildDocument();
    return document.toXmlString(pretty: true, indent: '   ');
  }

  /// Agregar extensiones DIAN al XML
  static void _agregarExtensiones(
    xml.XmlBuilder builder,
    FacturaElectronicaDian factura,
  ) {
    builder.element(
      'ext:UBLExtensions',
      nest: () {
        builder.element(
          'ext:UBLExtension',
          nest: () {
            builder.element(
              'ext:ExtensionContent',
              nest: () {
                builder.element(
                  'sts:DianExtensions',
                  nest: () {
                    // Control de factura
                    builder.element(
                      'sts:InvoiceControl',
                      nest: () {
                        builder.element(
                          'sts:InvoiceAuthorization',
                          nest: factura.numeroAutorizacion ?? '',
                        );

                        builder.element(
                          'sts:AuthorizationPeriod',
                          nest: () {
                            builder.element(
                              'cbc:StartDate',
                              nest: DateFormat('yyyy-MM-dd').format(
                                factura.fechaInicioAutorizacion ??
                                    DateTime.now(),
                              ),
                            );
                            builder.element(
                              'cbc:EndDate',
                              nest: DateFormat('yyyy-MM-dd').format(
                                factura.fechaFinAutorizacion ??
                                    DateTime.now().add(Duration(days: 365)),
                              ),
                            );
                          },
                        );

                        builder.element(
                          'sts:AuthorizedInvoices',
                          nest: () {
                            builder.element(
                              'sts:Prefix',
                              nest: factura.prefijoFactura ?? '',
                            );
                            builder.element(
                              'sts:From',
                              nest: factura.rangoDesde ?? '',
                            );
                            builder.element(
                              'sts:To',
                              nest: factura.rangoHasta ?? '',
                            );
                          },
                        );
                      },
                    );

                    // Fuente de la factura
                    builder.element(
                      'sts:InvoiceSource',
                      nest: () {
                        builder.element(
                          'cbc:IdentificationCode',
                          attributes: {
                            'listAgencyID': '6',
                            'listAgencyName':
                                'United Nations Economic Commission for Europe',
                            'listSchemeURI':
                                'urn:oasis:names:specification:ubl:codelist:gc:CountryIdentificationCode-2.1',
                          },
                          nest: 'CO',
                        );
                      },
                    );

                    // Proveedor de software
                    builder.element(
                      'sts:SoftwareProvider',
                      nest: () {
                        builder.element(
                          'sts:ProviderID',
                          attributes: {
                            'schemeAgencyID': '195',
                            'schemeAgencyName':
                                'CO, DIAN (Dirección de Impuestos y Aduanas Nacionales)',
                            'schemeID': '4',
                            'schemeName': '31',
                          },
                          nest: factura.proveedorSoftwareNit ?? '',
                        );

                        builder.element(
                          'sts:SoftwareID',
                          attributes: {
                            'schemeAgencyID': '195',
                            'schemeAgencyName':
                                'CO, DIAN (Dirección de Impuestos y Aduanas Nacionales)',
                          },
                          nest: factura.softwareId ?? '',
                        );
                      },
                    );

                    // Código de seguridad del software
                    builder.element(
                      'sts:SoftwareSecurityCode',
                      attributes: {
                        'schemeAgencyID': '195',
                        'schemeAgencyName':
                            'CO, DIAN (Dirección de Impuestos y Aduanas Nacionales)',
                      },
                      nest: factura.softwareSecurityCode ?? '',
                    );

                    // Proveedor de autorización
                    builder.element(
                      'sts:AuthorizationProvider',
                      nest: () {
                        builder.element(
                          'sts:AuthorizationProviderID',
                          attributes: {
                            'schemeAgencyID': '195',
                            'schemeAgencyName':
                                'CO, DIAN (Dirección de Impuestos y Aduanas Nacionales)',
                            'schemeID': '4',
                            'schemeName': '31',
                          },
                          nest: factura.proveedorSoftwareNit ?? '',
                        );
                      },
                    );

                    // Código QR
                    if (factura.qrCode != null) {
                      builder.element('sts:QRCode', nest: factura.qrCode);
                    }
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  /// Agregar información básica de la factura
  static void _agregarInformacionBasica(
    xml.XmlBuilder builder,
    FacturaElectronicaDian factura,
  ) {
    builder.element('cbc:UBLVersionID', nest: 'UBL 2.1');
    builder.element('cbc:CustomizationID', nest: factura.tipoOperacion);
    builder.element('cbc:ProfileID', nest: 'DIAN 2.1');
    builder.element(
      'cbc:ProfileExecutionID',
      nest: '2',
    ); // 1: Producción, 2: Habilitación
    builder.element('cbc:ID', nest: factura.numeroFactura);

    // UUID (CUFE)
    builder.element(
      'cbc:UUID',
      attributes: {'schemeID': '2', 'schemeName': 'CUFE-SHA384'},
      nest: factura.cufe ?? '',
    );

    builder.element(
      'cbc:IssueDate',
      nest: DateFormat('yyyy-MM-dd').format(factura.fechaEmision),
    );
    builder.element('cbc:IssueTime', nest: factura.horaEmision);
    builder.element('cbc:InvoiceTypeCode', nest: factura.tipoFactura);

    // Moneda
    builder.element(
      'cbc:DocumentCurrencyCode',
      attributes: {
        'listAgencyID': '6',
        'listAgencyName': 'United Nations Economic Commission for Europe',
        'listID': 'ISO 4217 Alpha',
      },
      nest: factura.moneda,
    );

    // Número de líneas
    builder.element(
      'cbc:LineCountNumeric',
      nest: factura.items.length.toString(),
    );
  }

  /// Agregar período de facturación
  static void _agregarPeriodoFacturacion(
    xml.XmlBuilder builder,
    FacturaElectronicaDian factura,
  ) {
    builder.element(
      'cac:InvoicePeriod',
      nest: () {
        final fecha = factura.fechaEmision;
        final primerDia = DateTime(fecha.year, fecha.month, 1);
        final ultimoDia = DateTime(fecha.year, fecha.month + 1, 0);

        builder.element(
          'cbc:StartDate',
          nest: DateFormat('yyyy-MM-dd').format(primerDia),
        );
        builder.element(
          'cbc:EndDate',
          nest: DateFormat('yyyy-MM-dd').format(ultimoDia),
        );
      },
    );
  }

  /// Agregar información del proveedor (emisor/restaurante)
  static void _agregarProveedor(
    xml.XmlBuilder builder,
    FacturaElectronicaDian factura,
  ) {
    final emisor = factura.emisor;

    builder.element(
      'cac:AccountingSupplierParty',
      nest: () {
        builder.element('cbc:AdditionalAccountID', nest: emisor.tipoPersona);

        builder.element(
          'cac:Party',
          nest: () {
            // Nombres
            builder.element(
              'cac:PartyName',
              nest: () {
                builder.element('cbc:Name', nest: emisor.nombreComercial);
              },
            );

            // Ubicación física
            builder.element(
              'cac:PhysicalLocation',
              nest: () {
                builder.element(
                  'cac:Address',
                  nest: () {
                    builder.element('cbc:ID', nest: emisor.codigoCiudad);
                    builder.element('cbc:CityName', nest: emisor.ciudad);
                    builder.element(
                      'cbc:CountrySubentity',
                      nest: emisor.departamento,
                    );
                    builder.element(
                      'cbc:CountrySubentityCode',
                      nest: emisor.codigoDepartamento,
                    );
                    builder.element(
                      'cac:AddressLine',
                      nest: () {
                        builder.element('cbc:Line', nest: emisor.direccion);
                      },
                    );
                    builder.element(
                      'cac:Country',
                      nest: () {
                        builder.element(
                          'cbc:IdentificationCode',
                          nest: emisor.pais,
                        );
                        builder.element(
                          'cbc:Name',
                          attributes: {'languageID': 'es'},
                          nest: 'Colombia',
                        );
                      },
                    );
                  },
                );
              },
            );

            // Esquema tributario
            builder.element(
              'cac:PartyTaxScheme',
              nest: () {
                builder.element(
                  'cbc:RegistrationName',
                  nest: emisor.razonSocial,
                );
                builder.element(
                  'cbc:CompanyID',
                  attributes: {
                    'schemeAgencyID': '195',
                    'schemeAgencyName':
                        'CO, DIAN (Dirección de Impuestos y Aduanas Nacionales)',
                    'schemeID': emisor.tipoDocumento,
                    'schemeName': '31',
                  },
                  nest: emisor.nit,
                );

                builder.element(
                  'cbc:TaxLevelCode',
                  attributes: {'listName': '05'},
                  nest: emisor.tipoRegimen,
                );

                builder.element(
                  'cac:TaxScheme',
                  nest: () {
                    builder.element('cbc:ID', nest: '01');
                    builder.element('cbc:Name', nest: 'IVA');
                  },
                );
              },
            );

            // Entidad legal
            builder.element(
              'cac:PartyLegalEntity',
              nest: () {
                builder.element(
                  'cbc:RegistrationName',
                  nest: emisor.razonSocial,
                );
                builder.element(
                  'cbc:CompanyID',
                  attributes: {
                    'schemeAgencyID': '195',
                    'schemeAgencyName':
                        'CO, DIAN (Dirección de Impuestos y Aduanas Nacionales)',
                    'schemeID': emisor.tipoDocumento,
                    'schemeName': '31',
                  },
                  nest: emisor.nit,
                );
              },
            );

            // Contacto
            builder.element(
              'cac:Contact',
              nest: () {
                builder.element('cbc:Telephone', nest: emisor.telefono);
                builder.element('cbc:ElectronicMail', nest: emisor.email);
              },
            );
          },
        );
      },
    );
  }

  /// Agregar información del cliente (adquiriente)
  static void _agregarCliente(
    xml.XmlBuilder builder,
    FacturaElectronicaDian factura,
  ) {
    final adquiriente = factura.adquiriente;

    builder.element(
      'cac:AccountingCustomerParty',
      nest: () {
        builder.element(
          'cbc:AdditionalAccountID',
          nest: adquiriente.tipoPersona,
        );

        builder.element(
          'cac:Party',
          nest: () {
            builder.element(
              'cac:PartyName',
              nest: () {
                builder.element('cbc:Name', nest: adquiriente.nombre);
              },
            );

            // Ubicación física (si está disponible)
            if (adquiriente.direccion != null) {
              builder.element(
                'cac:PhysicalLocation',
                nest: () {
                  builder.element(
                    'cac:Address',
                    nest: () {
                      if (adquiriente.codigoCiudad != null) {
                        builder.element(
                          'cbc:ID',
                          nest: adquiriente.codigoCiudad,
                        );
                      }
                      if (adquiriente.ciudad != null) {
                        builder.element(
                          'cbc:CityName',
                          nest: adquiriente.ciudad,
                        );
                      }
                      if (adquiriente.departamento != null) {
                        builder.element(
                          'cbc:CountrySubentity',
                          nest: adquiriente.departamento,
                        );
                      }
                      if (adquiriente.codigoDepartamento != null) {
                        builder.element(
                          'cbc:CountrySubentityCode',
                          nest: adquiriente.codigoDepartamento,
                        );
                      }
                      builder.element(
                        'cac:AddressLine',
                        nest: () {
                          builder.element(
                            'cbc:Line',
                            nest: adquiriente.direccion,
                          );
                        },
                      );
                      builder.element(
                        'cac:Country',
                        nest: () {
                          builder.element(
                            'cbc:IdentificationCode',
                            nest: adquiriente.pais,
                          );
                          builder.element(
                            'cbc:Name',
                            attributes: {'languageID': 'es'},
                            nest: 'Colombia',
                          );
                        },
                      );
                    },
                  );
                },
              );
            }

            // Esquema tributario
            builder.element(
              'cac:PartyTaxScheme',
              nest: () {
                builder.element(
                  'cbc:RegistrationName',
                  nest: adquiriente.nombre,
                );
                builder.element(
                  'cbc:CompanyID',
                  attributes: {
                    'schemeAgencyID': '195',
                    'schemeAgencyName':
                        'CO, DIAN (Dirección de Impuestos y Aduanas Nacionales)',
                    'schemeID': adquiriente.tipoDocumento,
                    'schemeName': '31',
                  },
                  nest: adquiriente.identificacion,
                );

                if (adquiriente.tipoRegimen != null) {
                  builder.element(
                    'cbc:TaxLevelCode',
                    attributes: {'listName': '04'},
                    nest: adquiriente.tipoRegimen,
                  );
                }

                builder.element(
                  'cac:TaxScheme',
                  nest: () {
                    builder.element('cbc:ID', nest: '01');
                    builder.element('cbc:Name', nest: 'IVA');
                  },
                );
              },
            );

            // Entidad legal
            builder.element(
              'cac:PartyLegalEntity',
              nest: () {
                builder.element(
                  'cbc:RegistrationName',
                  nest: adquiriente.nombre,
                );
                builder.element(
                  'cbc:CompanyID',
                  attributes: {
                    'schemeAgencyID': '195',
                    'schemeAgencyName':
                        'CO, DIAN (Dirección de Impuestos y Aduanas Nacionales)',
                    'schemeID': adquiriente.tipoDocumento,
                    'schemeName': '31',
                  },
                  nest: adquiriente.identificacion,
                );
              },
            );

            // Contacto (si está disponible)
            if (adquiriente.telefono != null || adquiriente.email != null) {
              builder.element(
                'cac:Contact',
                nest: () {
                  if (adquiriente.telefono != null) {
                    builder.element(
                      'cbc:Telephone',
                      nest: adquiriente.telefono,
                    );
                  }
                  if (adquiriente.email != null) {
                    builder.element(
                      'cbc:ElectronicMail',
                      nest: adquiriente.email,
                    );
                  }
                },
              );
            }
          },
        );
      },
    );
  }

  /// Agregar medios de pago
  static void _agregarMediosPago(
    xml.XmlBuilder builder,
    FacturaElectronicaDian factura,
  ) {
    builder.element(
      'cac:PaymentMeans',
      nest: () {
        builder.element('cbc:ID', nest: factura.formaPago ?? '1');
        builder.element(
          'cbc:PaymentMeansCode',
          nest: factura.medioPago ?? '10',
        );

        if (factura.fechaVencimiento != null) {
          builder.element(
            'cbc:PaymentDueDate',
            nest: DateFormat('yyyy-MM-dd').format(factura.fechaVencimiento!),
          );
        }

        if (factura.referenciaPago != null) {
          builder.element('cbc:PaymentID', nest: factura.referenciaPago);
        }
      },
    );
  }

  /// Agregar totales de impuestos
  static void _agregarTotalesImpuestos(
    xml.XmlBuilder builder,
    FacturaElectronicaDian factura,
  ) {
    for (final impuesto in factura.impuestos) {
      builder.element(
        'cac:TaxTotal',
        nest: () {
          builder.element(
            'cbc:TaxAmount',
            attributes: {'currencyID': factura.moneda},
            nest: impuesto.valorImpuesto.toStringAsFixed(2),
          );

          builder.element(
            'cac:TaxSubtotal',
            nest: () {
              builder.element(
                'cbc:TaxableAmount',
                attributes: {'currencyID': factura.moneda},
                nest: impuesto.baseImponible.toStringAsFixed(2),
              );

              builder.element(
                'cbc:TaxAmount',
                attributes: {'currencyID': factura.moneda},
                nest: impuesto.valorImpuesto.toStringAsFixed(2),
              );

              builder.element(
                'cac:TaxCategory',
                nest: () {
                  builder.element(
                    'cbc:Percent',
                    nest: impuesto.porcentaje.toStringAsFixed(2),
                  );

                  builder.element(
                    'cac:TaxScheme',
                    nest: () {
                      builder.element('cbc:ID', nest: impuesto.tipoImpuesto);
                      builder.element(
                        'cbc:Name',
                        nest: impuesto.nombreImpuesto,
                      );
                    },
                  );
                },
              );
            },
          );
        },
      );
    }
  }

  /// Agregar total monetario legal
  static void _agregarTotalMonetario(
    xml.XmlBuilder builder,
    FacturaElectronicaDian factura,
  ) {
    builder.element(
      'cac:LegalMonetaryTotal',
      nest: () {
        builder.element(
          'cbc:LineExtensionAmount',
          attributes: {'currencyID': factura.moneda},
          nest: factura.subtotal.toStringAsFixed(2),
        );

        builder.element(
          'cbc:TaxExclusiveAmount',
          attributes: {'currencyID': factura.moneda},
          nest:
              (factura.subtotal - factura.totalDescuentos + factura.totalCargos)
                  .toStringAsFixed(2),
        );

        builder.element(
          'cbc:TaxInclusiveAmount',
          attributes: {'currencyID': factura.moneda},
          nest: (factura.subtotal + factura.totalImpuestos).toStringAsFixed(2),
        );

        if (factura.totalDescuentos > 0) {
          builder.element(
            'cbc:AllowanceTotalAmount',
            attributes: {'currencyID': factura.moneda},
            nest: factura.totalDescuentos.toStringAsFixed(2),
          );
        }

        if (factura.totalCargos > 0) {
          builder.element(
            'cbc:ChargeTotalAmount',
            attributes: {'currencyID': factura.moneda},
            nest: factura.totalCargos.toStringAsFixed(2),
          );
        }

        builder.element(
          'cbc:PayableAmount',
          attributes: {'currencyID': factura.moneda},
          nest: factura.totalFactura.toStringAsFixed(2),
        );
      },
    );
  }

  /// Agregar líneas de factura (items)
  static void _agregarLineasFactura(
    xml.XmlBuilder builder,
    FacturaElectronicaDian factura,
  ) {
    for (final item in factura.items) {
      builder.element(
        'cac:InvoiceLine',
        nest: () {
          builder.element('cbc:ID', nest: item.numeroLinea.toString());

          builder.element(
            'cbc:InvoicedQuantity',
            attributes: {'unitCode': item.unidadMedida},
            nest: item.cantidad.toStringAsFixed(6),
          );

          builder.element(
            'cbc:LineExtensionAmount',
            attributes: {'currencyID': factura.moneda},
            nest: item.subtotalItem.toStringAsFixed(2),
          );

          builder.element(
            'cbc:FreeOfChargeIndicator',
            nest: item.muestraGratis.toString(),
          );

          // Descuento si existe
          if (item.descuento != null && item.descuento! > 0) {
            builder.element(
              'cac:AllowanceCharge',
              nest: () {
                builder.element('cbc:ID', nest: '1');
                builder.element('cbc:ChargeIndicator', nest: 'false');
                builder.element(
                  'cbc:AllowanceChargeReason',
                  nest: 'Descuento aplicado',
                );

                if (item.porcentajeDescuento != null) {
                  builder.element(
                    'cbc:MultiplierFactorNumeric',
                    nest: item.porcentajeDescuento!.toStringAsFixed(2),
                  );
                }

                builder.element(
                  'cbc:Amount',
                  attributes: {'currencyID': factura.moneda},
                  nest: item.descuento!.toStringAsFixed(2),
                );

                builder.element(
                  'cbc:BaseAmount',
                  attributes: {'currencyID': factura.moneda},
                  nest: (item.subtotalItem + item.descuento!).toStringAsFixed(
                    2,
                  ),
                );
              },
            );
          }

          // Impuestos del item
          if (item.impuestos.isNotEmpty) {
            builder.element(
              'cac:TaxTotal',
              nest: () {
                final totalImpuestosItem = item.impuestos.fold<double>(
                  0.0,
                  (sum, imp) => sum + imp.valorImpuesto,
                );

                builder.element(
                  'cbc:TaxAmount',
                  attributes: {'currencyID': factura.moneda},
                  nest: totalImpuestosItem.toStringAsFixed(2),
                );

                for (final impuesto in item.impuestos) {
                  builder.element(
                    'cac:TaxSubtotal',
                    nest: () {
                      builder.element(
                        'cbc:TaxableAmount',
                        attributes: {'currencyID': factura.moneda},
                        nest: impuesto.baseImponible.toStringAsFixed(2),
                      );

                      builder.element(
                        'cbc:TaxAmount',
                        attributes: {'currencyID': factura.moneda},
                        nest: impuesto.valorImpuesto.toStringAsFixed(2),
                      );

                      builder.element(
                        'cac:TaxCategory',
                        nest: () {
                          builder.element(
                            'cbc:Percent',
                            nest: impuesto.porcentaje.toStringAsFixed(2),
                          );

                          builder.element(
                            'cac:TaxScheme',
                            nest: () {
                              builder.element(
                                'cbc:ID',
                                nest: impuesto.tipoImpuesto,
                              );
                              builder.element(
                                'cbc:Name',
                                nest: impuesto.nombreImpuesto,
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                }
              },
            );
          }

          // Item (producto)
          builder.element(
            'cac:Item',
            nest: () {
              builder.element('cbc:Description', nest: item.descripcion);

              builder.element(
                'cac:SellersItemIdentification',
                nest: () {
                  builder.element('cbc:ID', nest: item.codigoProducto);
                },
              );

              if (item.codigoEstandar != null) {
                builder.element(
                  'cac:StandardItemIdentification',
                  nest: () {
                    builder.element(
                      'cbc:ID',
                      attributes: {
                        'schemeAgencyID': '10',
                        'schemeID': '001',
                        'schemeName': 'UNSPSC',
                      },
                      nest: item.codigoEstandar,
                    );
                  },
                );
              }
            },
          );

          // Precio
          builder.element(
            'cac:Price',
            nest: () {
              builder.element(
                'cbc:PriceAmount',
                attributes: {'currencyID': factura.moneda},
                nest: item.precioUnitario.toStringAsFixed(2),
              );

              builder.element(
                'cbc:BaseQuantity',
                attributes: {'unitCode': item.unidadMedida},
                nest: '1.000000',
              );
            },
          );
        },
      );
    }
  }
}
