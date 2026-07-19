/// Facturas electrónicas, notas crédito y documentos POS reales (emitidos y
/// aceptados por la DIAN vía Matías) cuyo Pedido de origen fue eliminado por
/// error del cajero al momento de facturar (3-6, 11-14 y 16-18 de julio de
/// 2026). No existe ningún Pedido en la base de datos al que asociarlos, así
/// que no se pueden reconstruir como Pedido/Factura reales sin arriesgar
/// afectar el cuadre de caja, el inventario o los reportes de ventas del mes
/// (que hoy ya no los cuentan, porque el pedido no existe).
///
/// Esta lista es deliberadamente estática y de solo lectura: los datos
/// (cliente, total, IVA, número real FAEL/NC/POS) se recuperaron cruzando
/// `matias_transactions`/`factura` en Mongo (por el ID de pedido embebido
/// en el campo `notes` de cada documento) contra la colección `pedido`,
/// para confirmar cuáles quedaron sin Pedido asociado. Se excluyen a
/// propósito las notas/POS que son pruebas de la integración (montos de
/// centavos, cliente el propio desarrollador). Se usa ÚNICAMENTE para
/// completar el Excel exportado desde "Lista documentos" — no participa en
/// ningún otro reporte, cuadre de caja o cálculo de
/// inventario.
class FacturaReconstruidaManual {
  final String numero;
  final String cliente;
  final DateTime fecha;
  final double total;
  final double iva;

  /// 'FE' (factura electrónica, el caso de casi toda la lista), 'NC' (nota
  /// crédito) o 'POS' (documento equivalente POS) — mismos valores que usa
  /// el export de facturas_list_screen.dart para la columna "Tipo".
  final String tipo;

  const FacturaReconstruidaManual({
    required this.numero,
    required this.cliente,
    required this.fecha,
    required this.total,
    required this.iva,
    this.tipo = 'FE',
  });
}

final List<FacturaReconstruidaManual> facturasReconstruidasManual = [
  FacturaReconstruidaManual(
    numero: 'FAEL 444',
    cliente: 'CONSUMIDOR FINAL',
    fecha: DateTime(2026, 7, 3, 14, 34, 29),
    total: 180000.01,
    iva: 28739.4969,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 445',
    cliente: 'Guarin Aguilar Miguel Stevens',
    fecha: DateTime(2026, 7, 3, 14, 57, 12),
    total: 69999.99,
    iva: 11176.468799999999,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 462',
    cliente: 'CONSUMIDOR FINAL',
    fecha: DateTime(2026, 7, 4, 23, 26, 15),
    total: 78000,
    iva: 12453.781927731092,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 463',
    cliente: 'CONSUMIDOR FINAL',
    fecha: DateTime(2026, 7, 4, 23, 35, 7),
    total: 65000,
    iva: 10378.150494117646,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 464',
    cliente: 'CONSUMIDOR FINAL',
    fecha: DateTime(2026, 7, 4, 23, 39, 51),
    total: 430000.01,
    iva: 68655.4645,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 465',
    cliente: 'CONSUMIDOR FINAL',
    fecha: DateTime(2026, 7, 4, 23, 44, 37),
    total: 95000,
    iva: 15168.0667,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 466',
    cliente: 'CONSUMIDOR FINAL',
    fecha: DateTime(2026, 7, 4, 23, 47, 38),
    total: 5000,
    iva: 798.3193277310925,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 467',
    cliente: 'CONSUMIDOR FINAL',
    fecha: DateTime(2026, 7, 4, 23, 50, 5),
    total: 52999.99,
    iva: 8462.184027731091,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 468',
    cliente: 'KEVIN  CARVAJAL',
    fecha: DateTime(2026, 7, 5, 0, 6, 50),
    total: 70000,
    iva: 11176.4707,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 469',
    cliente: 'miguel Sánchez',
    fecha: DateTime(2026, 7, 5, 0, 11, 47),
    total: 44999.99,
    iva: 7184.872799999999,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 470',
    cliente: 'CONSUMIDOR FINAL',
    fecha: DateTime(2026, 7, 5, 0, 15, 4),
    total: 124999.99,
    iva: 19957.981532773112,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 471',
    cliente: 'NICOLAS ANDRES ROMERO RINCON',
    fecha: DateTime(2026, 7, 5, 0, 18, 17),
    total: 145000,
    iva: 23151.261126890757,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 472',
    cliente: 'Juan José loaiza',
    fecha: DateTime(2026, 7, 5, 0, 23, 43),
    total: 460000,
    iva: 73445.37811932774,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 473',
    cliente: 'Óscar David ospina',
    fecha: DateTime(2026, 7, 5, 0, 29, 22),
    total: 250000,
    iva: 39915.9657,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 474',
    cliente: 'Dario Miguel Taicus Guanga',
    fecha: DateTime(2026, 7, 5, 0, 30, 38),
    total: 110000,
    iva: 17563.025210084033,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 475',
    cliente: 'Danilo Martinez',
    fecha: DateTime(2026, 7, 5, 0, 34, 53),
    total: 180000,
    iva: 28739.495000000003,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 476',
    cliente: 'Edison Medina',
    fecha: DateTime(2026, 7, 5, 0, 36, 33),
    total: 230000,
    iva: 36722.6889,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 477',
    cliente: 'Brayan Andres Olaya Calderon',
    fecha: DateTime(2026, 7, 5, 0, 43, 27),
    total: 219999.99,
    iva: 35126.0486,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 478',
    cliente: 'JAIDER ARMANDO MEDINA  HERNANDEZ',
    fecha: DateTime(2026, 7, 5, 0, 44, 32),
    total: 380000,
    iva: 60672.2687,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 479',
    cliente: 'Juan Felipe Gómez Benavides',
    fecha: DateTime(2026, 7, 5, 0, 48, 56),
    total: 205000,
    iva: 32731.092899999996,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 480',
    cliente: 'Juan Sebastián  Rodríguez',
    fecha: DateTime(2026, 7, 5, 0, 54, 51),
    total: 440000,
    iva: 70252.101,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 481',
    cliente: 'Jose Tovar  Lopez',
    fecha: DateTime(2026, 7, 5, 0, 55, 48),
    total: 120000,
    iva: 19159.6646,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 482',
    cliente: 'Jaider Sebastian Rodriguez Pinto',
    fecha: DateTime(2026, 7, 5, 1, 0, 17),
    total: 245000,
    iva: 39117.646499999995,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 483',
    cliente: 'Mauricio Gamez',
    fecha: DateTime(2026, 7, 5, 1, 2, 56),
    total: 39999.99,
    iva: 6386.5536,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 484',
    cliente: 'Daniel Santiago meneses  Lozano',
    fecha: DateTime(2026, 7, 5, 1, 9, 40),
    total: 230000,
    iva: 36722.6889,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 485',
    cliente: 'Carlos Alberto Mestre  Arrieta',
    fecha: DateTime(2026, 7, 5, 1, 10, 29),
    total: 230000,
    iva: 36722.6889,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 486',
    cliente: 'EDUARDO  GUILLEN',
    fecha: DateTime(2026, 7, 5, 1, 11, 52),
    total: 120000,
    iva: 19159.6646,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 487',
    cliente: 'Luis Alberto Gomez Buitrago',
    fecha: DateTime(2026, 7, 5, 1, 14, 33),
    total: 300000,
    iva: 47899.1596,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 488',
    cliente: 'SEBASTIAN CASTRILLON',
    fecha: DateTime(2026, 7, 5, 12, 36, 31),
    total: 147999.99,
    iva: 23630.251238655463,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 489',
    cliente: 'Diego   Blandon',
    fecha: DateTime(2026, 7, 5, 12, 58, 28),
    total: 189999.99,
    iva: 30336.133399999995,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 490',
    cliente: 'Carolina Gutierrez Arias',
    fecha: DateTime(2026, 7, 5, 13, 18, 50),
    total: 414999.99,
    iva: 66260.50209411766,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 491',
    cliente: 'Carlos Alberto Mestre  Arrieta',
    fecha: DateTime(2026, 7, 5, 13, 24, 21),
    total: 50000,
    iva: 7983.193899999999,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 501',
    cliente: 'Jhon Elmer Sánchez GIL',
    fecha: DateTime(2026, 7, 6, 17, 43, 0),
    total: 429999.998,
    iva: 68655.46186554623,
  ),
  FacturaReconstruidaManual(
    // OJO: mismo pedidoId (6a4d5052d5190d516ede5c2e) que FAEL 546 — el mismo
    // pedido quedó facturado electrónicamente dos veces ante la DIAN.
    numero: 'FAEL 510',
    cliente: 'CONSUMIDOR FINAL',
    fecha: DateTime(2026, 7, 10, 18, 54, 46),
    total: 423000,
    iva: 67537.82,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 525',
    cliente: 'CONSUMIDOR FINAL',
    fecha: DateTime(2026, 7, 6, 19, 42, 45),
    total: 209999.99,
    iva: 34327.73,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 530',
    cliente: 'CONSUMIDOR FINAL',
    fecha: DateTime(2026, 7, 6, 19, 24, 6),
    total: 759999.98,
    iva: 128529.41,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 536',
    cliente: 'CONSUMIDOR FINAL',
    fecha: DateTime(2026, 7, 6, 10, 14, 22),
    total: 1200000,
    iva: 0,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 538',
    cliente: 'CONSUMIDOR FINAL',
    fecha: DateTime(2026, 7, 8, 12, 15, 6),
    total: 140000.0006,
    iva: 23151.26,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 546',
    cliente: 'CONSUMIDOR FINAL',
    fecha: DateTime(2026, 7, 7, 14, 15, 30),
    total: 422999.99,
    iva: 69134.45,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 547',
    cliente: 'Anderson  Martínez',
    fecha: DateTime(2026, 7, 8, 19, 37, 42),
    total: 878000.01,
    iva: 147689.08,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 548',
    cliente: 'Darinson Camilo ubaque  castellano',
    fecha: DateTime(2026, 7, 8, 19, 54, 40),
    total: 95000,
    iva: 32731.09,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 552',
    cliente: 'Mateo Capote  Carvajal',
    fecha: DateTime(2026, 7, 9, 14, 45, 51),
    total: 443999.98,
    iva: 80630.25,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 554',
    cliente: 'CONSUMIDOR FINAL',
    fecha: DateTime(2026, 7, 9, 17, 40, 30),
    total: 299999.99,
    iva: 50294.12,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 564',
    cliente: 'CRISTIAN GALVEZ',
    fecha: DateTime(2026, 7, 11, 11, 12, 10),
    total: 109999.99,
    iva: 17563.02,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 570',
    cliente: 'Andersson ramirez  florez',
    fecha: DateTime(2026, 7, 11, 19, 16, 57),
    total: 79999.99,
    iva: 12773.11,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 577',
    cliente: 'CRISTIAN GALVEZ',
    fecha: DateTime(2026, 7, 14, 15, 17, 50),
    total: 109999.99,
    iva: 17563.02,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 593',
    cliente: 'angel herrera',
    fecha: DateTime(2026, 7, 16, 15, 22, 22),
    total: 170000,
    iva: 27143,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 594',
    cliente: 'CONSUMIDOR FINAL',
    fecha: DateTime(2026, 7, 16, 18, 21, 7),
    total: 720000,
    iva: 114957.98,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 595',
    cliente: 'SEBASTIÁN valencia',
    fecha: DateTime(2026, 7, 16, 18, 50, 45),
    total: 70000,
    iva: 11176.47,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 596',
    cliente: 'CONSUMIDOR FINAL',
    fecha: DateTime(2026, 7, 16, 18, 59, 22),
    total: 465000.01,
    iva: 74243.70,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 599',
    cliente: 'juan david aguirre',
    fecha: DateTime(2026, 7, 16, 19, 1, 25),
    total: 500000.01,
    iva: 79831.94,
  ),
  FacturaReconstruidaManual(
    numero: 'FAEL 600',
    cliente: 'yohan  GONZALEZ',
    fecha: DateTime(2026, 7, 18, 10, 32, 10),
    total: 260000,
    iva: 41512.60,
  ),

  // ── Notas Crédito / Documentos POS reales, mismo caso de Pedido/origen
  // eliminado — ver matias_transactions (tipoDocumento NC/POS). Se excluyen
  // deliberadamente NC2/ND3/NC3/ND1/POS9/POS10: son pruebas de la
  // integración (montos de centavos, cliente "Sergio Velasquez" = el
  // desarrollador), no ventas reales del negocio.
  FacturaReconstruidaManual(
    numero: 'NC 4',
    cliente: 'CONSUMIDOR FINAL',
    fecha: DateTime(2026, 7, 14, 14, 17, 28),
    total: 110000,
    iva: 0,
    tipo: 'NC',
  ),
  FacturaReconstruidaManual(
    numero: 'POS 11',
    cliente: 'ANDRES FELIPE LOAIZA',
    fecha: DateTime(2026, 7, 2, 16, 8, 38),
    total: 40000,
    iva: 6386.55,
    tipo: 'POS',
  ),
  FacturaReconstruidaManual(
    numero: 'POS 12',
    cliente: 'CONSUMIDOR FINAL',
    fecha: DateTime(2026, 7, 17, 10, 20, 20),
    total: 44000,
    iva: 7025.21,
    tipo: 'POS',
  ),
];
