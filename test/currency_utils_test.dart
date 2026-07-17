import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/utils/currency_utils.dart';

TextEditingValue _apply(MilesInputFormatter f, String text) {
  return f.formatEditUpdate(
    TextEditingValue.empty,
    TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length)),
  );
}

void main() {
  group('CurrencyUtils.format / formatPlain', () {
    test('agrupa miles y antepone el símbolo de peso', () {
      expect(CurrencyUtils.format(55500), '\$55.500');
    });

    test('formatPlain no antepone el símbolo', () {
      expect(CurrencyUtils.formatPlain(55500), '55.500');
    });

    test('redondea a entero (sin decimales)', () {
      expect(CurrencyUtils.format(1234.9), '\$1.235');
    });

    test('cero se formatea como \$0', () {
      expect(CurrencyUtils.format(0), '\$0');
    });
  });

  group('CurrencyUtils.formatForMilesInput', () {
    test('agrupa miles y conserva los decimales pedidos', () {
      expect(CurrencyUtils.formatForMilesInput(42016.81), '42.016.81');
    });

    test('con decimalDigits: 0 no agrega parte decimal', () {
      expect(CurrencyUtils.formatForMilesInput(42016, decimalDigits: 0), '42.016');
    });

    test('respeta el signo negativo', () {
      expect(CurrencyUtils.formatForMilesInput(-1500, decimalDigits: 0), '-1.500');
    });
  });

  group('CurrencyUtils.formatShort', () {
    test('valores en miles usan sufijo K', () {
      expect(CurrencyUtils.formatShort(55500), '\$55.5K');
    });

    test('valores en millones usan sufijo M', () {
      expect(CurrencyUtils.formatShort(1500000), '\$1.5M');
    });

    test('valores menores a mil se muestran completos', () {
      expect(CurrencyUtils.formatShort(500), '\$500');
    });

    test('cero es un caso especial: \$0', () {
      expect(CurrencyUtils.formatShort(0), '\$0');
    });

    test('respeta el signo negativo', () {
      expect(CurrencyUtils.formatShort(-2000), '-\$2K');
    });
  });

  group('CurrencyUtils.parse', () {
    test('quita símbolo de peso y puntos de miles', () {
      expect(CurrencyUtils.parse('\$55.500'), 55500.0);
    });

    test('un string vacío da 0', () {
      expect(CurrencyUtils.parse(''), 0.0);
    });

    test('texto no numérico da 0 (no lanza)', () {
      expect(CurrencyUtils.parse('abc'), 0.0);
    });
  });

  group('CurrencyUtils.isValidCurrency', () {
    test('parse nunca lanza, así que siempre es true', () {
      // NOTA: parse() usa tryParse y jamás lanza, así que isValidCurrency
      // siempre devuelve true incluso para basura como "abc" (-> 0.0).
      // Documentado por el test de regresión, no necesariamente el
      // comportamiento ideal.
      expect(CurrencyUtils.isValidCurrency('\$55.500'), isTrue);
      expect(CurrencyUtils.isValidCurrency('abc'), isTrue);
    });
  });

  group('CurrencyUtils.calculatePercentage / formatPercentage', () {
    test('calcula el porcentaje de un valor sobre un total', () {
      expect(CurrencyUtils.calculatePercentage(250, 1000), 25.0);
    });

    test('con total 0 devuelve 0 (no divide por cero)', () {
      expect(CurrencyUtils.calculatePercentage(250, 0), 0.0);
    });

    test('formatPercentage multiplica por 100 y agrega %', () {
      expect(CurrencyUtils.formatPercentage(0.05), '5.0%');
    });

    test('formatPercentageOf combina calculatePercentage + formatPercentage', () {
      expect(CurrencyUtils.formatPercentageOf(250, 1000), '25.0%');
    });
  });

  group('CurrencyUtils.parseDecimal', () {
    test('interpreta el último punto como separador decimal', () {
      expect(CurrencyUtils.parseDecimal('42.016.81'), closeTo(42016.81, 0.001));
    });

    test('sin puntos, es un entero directo', () {
      expect(CurrencyUtils.parseDecimal('1500'), 1500.0);
    });

    test('con un solo punto lo trata como decimal', () {
      expect(CurrencyUtils.parseDecimal('1500.5'), 1500.5);
    });

    test('string vacío da 0', () {
      expect(CurrencyUtils.parseDecimal(''), 0.0);
    });
  });

  group('MilesInputFormatter', () {
    test('agrupa miles mientras el usuario escribe (sin decimales)', () {
      const f = MilesInputFormatter();
      expect(_apply(f, '1000000').text, '1.000.000');
    });

    test('con decimalDigits > 0, el último punto es decimal', () {
      const f = MilesInputFormatter(decimalDigits: 2);
      expect(_apply(f, '42016.81').text, '42.016.81');
    });

    test('un texto vacío se limpia a vacío', () {
      const f = MilesInputFormatter();
      expect(_apply(f, '').text, '');
    });

    test('ignora caracteres no numéricos', () {
      const f = MilesInputFormatter();
      expect(_apply(f, 'a1b2c3').text, '123');
    });
  });
}
