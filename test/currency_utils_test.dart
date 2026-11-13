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

  group('CurrencyUtils.formatForMilesInputAuto', () {
    test('un valor entero no muestra decimales', () {
      expect(CurrencyUtils.formatForMilesInputAuto(13400.0), '13.400');
      expect(CurrencyUtils.formatForMilesInputAuto(0), '0');
    });

    test('un valor con centavos conserva 2 decimales', () {
      expect(CurrencyUtils.formatForMilesInputAuto(4639.32), '4.639.32');
    });

    test('ciclo completo: prellenar -> reformatear al teclear -> leer', () {
      // Costos reales de producción: enteros y con decimales.
      for (final costo in [13400.0, 4639.32, 20780.9, 1500000.0]) {
        final prellenado = CurrencyUtils.formatForMilesInputAuto(costo);
        final tras = _apply(const MilesInputFormatter(decimalDigits: 2), prellenado).text;
        expect(CurrencyUtils.parseDecimal(tras), closeTo(costo, 0.001),
            reason: 'costo $costo -> "$prellenado" -> "$tras"');
      }
    });

    test('el texto crudo que se asigna por código también se lee bien', () {
      // facturacion_screen asigna "50000.0" o "0" directo al controller.
      expect(CurrencyUtils.parseDecimal('50000.0'), 50000.0);
      expect(CurrencyUtils.parseDecimal('0'), 0.0);
      expect(CurrencyUtils.parseDecimal(''), 0.0);
    });

    test('un precio sin decimales con puntos de miles no se lee como 1,5', () {
      const f = MilesInputFormatter();
      final tras = _apply(f, '1500').text;
      expect(tras, '1.500');
      expect(CurrencyUtils.parse(tras), 1500.0);
      expect(double.tryParse(tras), 1.5, reason: 'el bug que se evita');
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

    test('una agrupación de miles pura NO se lee como decimal', () {
      expect(CurrencyUtils.parseDecimal('1.500'), 1500.0);
      expect(CurrencyUtils.parseDecimal('13.400'), 13400.0);
      expect(CurrencyUtils.parseDecimal('85.000'), 85000.0);
      expect(CurrencyUtils.parseDecimal('1.500.000'), 1500000.0);
    });

    test('un decimal real (1-2 dígitos tras el último punto) se sigue leyendo', () {
      expect(CurrencyUtils.parseDecimal('80.000.00'), 80000.0);
      expect(CurrencyUtils.parseDecimal('4.639.32'), closeTo(4639.32, 0.001));
      expect(CurrencyUtils.parseDecimal('50000.0'), 50000.0);
      expect(CurrencyUtils.parseDecimal('0.5'), 0.5);
    });

    test('tecleando enteros en un campo con decimalDigits: 2 se lee el valor correcto', () {
      const f = MilesInputFormatter(decimalDigits: 2);
      for (final t in ['500', '1500', '85000', '150000', '1500000']) {
        var v = TextEditingValue.empty;
        for (final ch in t.split('')) {
          final txt = v.text + ch;
          v = f.formatEditUpdate(
            v,
            TextEditingValue(text: txt, selection: TextSelection.collapsed(offset: txt.length)),
          );
        }
        expect(CurrencyUtils.parseDecimal(v.text), double.parse(t),
            reason: 'tecleado "$t" -> campo "${v.text}"');
      }
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
