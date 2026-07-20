import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/utils/detalle_pago_options.dart';

// Guarda de regresión: formaPagoBase determina cómo se reporta cada medio de
// pago detallado ante la DIAN (Nequi/DaviPlata/Bancolombia como
// "transferencia", Bold como "datafono"). Un typo aquí cambia silenciosamente
// la forma de pago que se reporta, sin que nada más lo detecte.
void main() {
  group('subOpcionesTransferencia', () {
    test('las 3 sub-opciones de transferencia mapean a formaPagoBase="transferencia"', () {
      expect(subOpcionesTransferencia, hasLength(3));
      for (final opcion in subOpcionesTransferencia) {
        expect(opcion.formaPagoBase, 'transferencia');
      }
      expect(subOpcionesTransferencia.map((o) => o.value), [
        'nequi',
        'daviplata',
        'bancolombia',
      ]);
    });
  });

  group('medioPagoDetalladoOptions', () {
    test('cada value es único (no hay opciones duplicadas)', () {
      final values = medioPagoDetalladoOptions.map((o) => o.value).toList();
      expect(values.toSet().length, values.length);
    });

    test('mapea cada medio a su formaPagoBase contable esperada', () {
      final porValue = {for (final o in medioPagoDetalladoOptions) o.value: o.formaPagoBase};

      expect(porValue['efectivo'], 'efectivo');
      expect(porValue['nequi'], 'transferencia');
      expect(porValue['daviplata'], 'transferencia');
      expect(porValue['bancolombia'], 'transferencia');
      expect(porValue['bold'], 'datafono');
      expect(porValue['sistecredito'], 'sistecredito');
      expect(porValue['addi'], 'otro');
      expect(porValue['credilondon'], 'otro');
    });
  });
}
