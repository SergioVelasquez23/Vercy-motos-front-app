// Mapeos puros de forma/medio de pago, compartidos entre las dos pantallas
// que arman documentos para Matías/DIAN (facturacion_screen.dart y
// MatiasService, usado por PosRapidoButton/FacturizadorMatiasButton).
//
// Antes cada archivo tenía su propia copia y se habían desincronizado —
// ver docs/AUDITORIA_SIN_FILTROS_V2.md punto 6: matias_service.dart mapeaba
// 'sistecredito' y 'transferencia' a códigos DIAN distintos de los que usa
// MatiasTransformer.mapearMeansPaymentId en el backend, así que un Documento
// POS Electrónico (que el backend reenvía sin recalcular `payments`, ver
// MatiasPosService.java) salía con el código de medio de pago equivocado.

/// Mapeo de método de pago UI → medioPago DIAN. Puramente informativo: el
/// backend no consume este valor (ver el comentario original en
/// facturacion_screen.dart), solo `mapFormaPagoBackend` importa contablemente.
const Map<String, String> medioPagoDianMap = {
  'efectivo': 'efectivo',
  'transferencia': 'transferencia',
  'nequi': 'transferencia',
  'daviplata': 'transferencia',
  'bancolombia': 'transferencia',
  'tarjeta': 'tarjeta debito',
  'tarjeta_credito': 'tarjeta credito',
  'bold': 'tarjeta credito',
  // Addi y Credilondon son plataformas de crédito (BNPL): ante la DIAN se
  // reportan como Crédito (no Contado/Efectivo) — el backend lo detecta por
  // `detallePago` ('addi') en MatiasTransformer. Este mapa es solo
  // informativo (el backend no lo consume actualmente).
  'addi': 'credito',
  'credilondon': 'credito',
  'sistecredito': 'sistecredito',
  'credito': 'efectivo',
  'multiple': 'efectivo',
};

/// Mapeo de método UI → formaPago backend (valor contable real).
String mapFormaPagoBackend(String metodo) {
  if (metodo == 'credito') return 'Crédito';
  const aliasesTransferencia = {'nequi', 'daviplata', 'bancolombia'};
  if (aliasesTransferencia.contains(metodo)) return 'transferencia';
  if (metodo == 'bold') return 'datafono';
  // Addi y Credilondon son plataformas de crédito (BNPL): NO deben contarse
  // como Efectivo en el cuadre de caja (ese dinero nunca llega como efectivo
  // físico). Se reportan como 'sistecredito' — el bucket de crédito más
  // cercano que ya existe en el cuadre/DIAN — y quedan identificadas aparte
  // por su propio `detallePago` ('addi'/'credilondon').
  if (metodo == 'addi' || metodo == 'credilondon') return 'sistecredito';
  return metodo; // El backend acepta los valores directos para el resto
}

/// Sub-categorías visuales reconocidas: se guardan en `detallePago` para el
/// libro contable, pero siempre resuelven a un formaPago contable existente
/// (ver [mapFormaPagoBackend]) — "contablemente no cambia nada".
const Set<String> detallesPagoConocidos = {
  'efectivo', 'nequi', 'daviplata', 'bancolombia', 'bold', 'addi',
  'credilondon', 'sistecredito',
};

String? detalleParaMetodo(String metodo) =>
    detallesPagoConocidos.contains(metodo) ? metodo : null;

/// Mapea forma/detalle de pago (texto libre) al `means_payment_id` que
/// espera Matías/DIAN. Debe coincidir exactamente con
/// `MatiasTransformer.mapearMeansPaymentId` en el backend (Postura B,
/// 14-jul-2026) — el Documento POS Electrónico arma este código en el
/// frontend y el backend lo reenvía tal cual, sin recalcularlo.
int mapFormaPagoToMeansId(String? formaPago, {String? detallePago}) {
  // "A Crédito" literal (venta fiada real): Crédito Directo de Banco. Debe
  // ser el string exacto 'Crédito' (con tilde) que produce
  // [mapFormaPagoBackend] — igual que `esCreditoLiteral` en el backend.
  if (formaPago != null && formaPago.toLowerCase() == 'crédito') return 47;

  // Addi/Credilondon: BNPL, el negocio recibe el dinero de inmediato por
  // transferencia — se identifican por detallePago, no por formaPago, porque
  // según la pantalla que originó la venta pueden traer formaPago='otro' o
  // formaPago='sistecredito' (ver [mapFormaPagoBackend] y
  // lib/utils/detalle_pago_options.dart).
  final dp = detallePago?.toLowerCase() ?? '';
  if (dp == 'addi' || dp == 'credilondon') return 42; // Transferencia

  final fp = (formaPago ?? 'efectivo').toLowerCase();
  if (fp.contains('sistecredito')) return 42; // Transferencia
  if (fp.contains('tarjeta')) return 41; // Tarjeta de crédito/débito
  if (fp.contains('transfer')) return 42; // Transferencia
  if (fp.contains('cheque')) return 20; // Cheque
  // Bold es un datafono/terminal físico: el cliente paga con su tarjeta ahí
  // mismo, Bold solo procesa el cobro — se reporta como pago con tarjeta.
  if (fp.contains('datafono')) return 41; // Tarjeta de crédito/débito
  return 10; // Consignación Bancaria (default)
}
