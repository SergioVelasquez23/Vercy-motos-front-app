import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/utils/payment_mapping.dart';

void main() {
  group('mapFormaPagoBackend', () {
    test('"credito" (A Crédito real) se mapea a Crédito con tilde', () {
      expect(mapFormaPagoBackend('credito'), 'Crédito');
    });

    test('nequi/daviplata/bancolombia se mapean a transferencia', () {
      expect(mapFormaPagoBackend('nequi'), 'transferencia');
      expect(mapFormaPagoBackend('daviplata'), 'transferencia');
      expect(mapFormaPagoBackend('bancolombia'), 'transferencia');
    });

    test('bold se mapea a datafono', () {
      expect(mapFormaPagoBackend('bold'), 'datafono');
    });

    test('addi y credilondon se mapean a sistecredito (BNPL, no Efectivo)', () {
      expect(mapFormaPagoBackend('addi'), 'sistecredito');
      expect(mapFormaPagoBackend('credilondon'), 'sistecredito');
    });

    test('valores sin mapeo especial pasan directo', () {
      for (final metodo in [
        'efectivo',
        'tarjeta',
        'tarjeta_credito',
        'transferencia',
        'sistecredito',
        'multiple',
      ]) {
        expect(mapFormaPagoBackend(metodo), metodo);
      }
    });
  });

  group('detalleParaMetodo', () {
    test('reconoce las sub-categorías del libro contable', () {
      for (final metodo in detallesPagoConocidos) {
        expect(detalleParaMetodo(metodo), metodo);
      }
    });

    test('devuelve null para métodos que no son sub-categoría (credito, multiple, tarjeta_credito)', () {
      expect(detalleParaMetodo('credito'), isNull);
      expect(detalleParaMetodo('multiple'), isNull);
      expect(detalleParaMetodo('tarjeta_credito'), isNull);
    });
  });

  group('mapFormaPagoToMeansId — debe coincidir con mapearMeansPaymentId del backend', () {
    test('"Crédito" literal (A Crédito real) es Crédito Directo de Banco (47)', () {
      expect(mapFormaPagoToMeansId('Crédito'), 47);
      expect(mapFormaPagoToMeansId('crédito'), 47); // case-insensitive
    });

    test('un "credito" sin tilde NO dispara el caso literal (cae al default)', () {
      // Coincide con esCreditoLiteral del backend: equalsIgnoreCase("Crédito")
      // exige el acento, "credito" sin tilde no matchea.
      expect(mapFormaPagoToMeansId('credito'), 10);
    });

    test('Addi/Credilondon se identifican por detallePago, sin importar formaPago (42)', () {
      expect(mapFormaPagoToMeansId('sistecredito', detallePago: 'addi'), 42);
      expect(mapFormaPagoToMeansId('otro', detallePago: 'addi'), 42);
      expect(mapFormaPagoToMeansId('otro', detallePago: 'credilondon'), 42);
      expect(mapFormaPagoToMeansId(null, detallePago: 'Addi'), 42); // case-insensitive
    });

    test('sistecredito (sin detallePago de Addi/Credilondon) es Transferencia (42)', () {
      // Regresión: antes esta función devolvía 41 (Tarjeta) para sistecredito,
      // desalineado del backend — ver AUDITORIA_SIN_FILTROS_V2.md punto 6.
      expect(mapFormaPagoToMeansId('sistecredito'), 42);
    });

    test('transferencia es Transferencia (42), no Crédito Directo de Banco', () {
      // Regresión: antes devolvía 47 ("Crédito Directo de Banco") para
      // transferencias normales — un código DIAN incorrecto para pagos que
      // sí son de contado.
      expect(mapFormaPagoToMeansId('transferencia'), 42);
    });

    test('tarjeta y datafono (Bold) son Tarjeta de crédito/débito (41)', () {
      expect(mapFormaPagoToMeansId('tarjeta'), 41);
      expect(mapFormaPagoToMeansId('tarjeta_credito'), 41);
      expect(mapFormaPagoToMeansId('datafono'), 41);
    });

    test('cheque es Cheque (20)', () {
      expect(mapFormaPagoToMeansId('cheque'), 20);
    });

    test('efectivo, null y valores desconocidos caen al default (10)', () {
      expect(mapFormaPagoToMeansId('efectivo'), 10);
      expect(mapFormaPagoToMeansId(null), 10);
      expect(mapFormaPagoToMeansId(''), 10);
      expect(mapFormaPagoToMeansId('otro'), 10);
    });
  });
}
