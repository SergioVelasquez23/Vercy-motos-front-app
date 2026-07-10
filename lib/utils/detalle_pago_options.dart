/// Sub-categorías visuales de medio de pago para el libro contable.
///
/// Puramente informativo: `detallePago` viaja junto a `formaPago` pero no lo
/// reemplaza. Nequi/DaviPlata/Bancolombia se guardan con formaPago='transferencia'
/// (mismo comportamiento contable/DIAN de siempre); Bold se guarda con
/// formaPago='datafono'. El backend usa `detallePago` únicamente para agrupar
/// el libro contable por plataforma específica.
class DetallePagoOption {
  final String value;
  final String label;
  final String formaPagoBase;

  const DetallePagoOption(this.value, this.label, this.formaPagoBase);
}

/// Sub-opciones que aparecen cuando el cajero elige "Transferencia".
const List<DetallePagoOption> subOpcionesTransferencia = [
  DetallePagoOption('nequi', 'Nequi', 'transferencia'),
  DetallePagoOption('daviplata', 'DaviPlata', 'transferencia'),
  DetallePagoOption('bancolombia', 'Bancolombia', 'transferencia'),
];

/// Medios de pago de primer nivel adicionales, con su detallePago y la
/// formaPago contable a la que equivalen.
const List<DetallePagoOption> medioPagoDetalladoOptions = [
  DetallePagoOption('efectivo', 'Efectivo', 'efectivo'),
  DetallePagoOption('nequi', 'Nequi', 'transferencia'),
  DetallePagoOption('daviplata', 'DaviPlata', 'transferencia'),
  DetallePagoOption('bancolombia', 'Bancolombia', 'transferencia'),
  DetallePagoOption('bold', 'Bold', 'datafono'),
  DetallePagoOption('sistecredito', 'Sistecredito', 'sistecredito'),
  DetallePagoOption('addi', 'Addi', 'otro'),
  DetallePagoOption('credilondon', 'Credilondon', 'otro'),
];
