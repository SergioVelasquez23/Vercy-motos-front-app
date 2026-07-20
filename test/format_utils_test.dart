import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/utils/format_utils.dart';

void main() {
  group('formatNumberWithDots', () {
    test('agrupa miles con puntos', () {
      expect(formatNumberWithDots(55500), '55.500');
      expect(formatNumberWithDots(1234567), '1.234.567');
    });

    test('números menores a 1000 no llevan punto', () {
      expect(formatNumberWithDots(999), '999');
      expect(formatNumberWithDots(0), '0');
    });

    test('null da "0"', () {
      expect(formatNumberWithDots(null), '0');
    });

    test('redondea decimales (no trunca)', () {
      // 1234.6 -> redondea a 1235, no a 1234
      expect(formatNumberWithDots(1234.6), '1.235');
    });

    test('respeta el signo negativo', () {
      expect(formatNumberWithDots(-1500), '-1.500');
    });

    test('acepta un String con símbolo de peso y espacios sueltos', () {
      expect(formatNumberWithDots('\$ 55500 '), '55.500');
    });

    test('un String con coma de miles estilo US se interpreta correctamente (no como decimal)', () {
      // Antes: la coma se reemplazaba por punto y double.tryParse la leía
      // como separador decimal ("55,500" -> 55.5 -> redondeaba a 56).
      // Ahora se descarta igual que hace CurrencyUtils.parse en el resto
      // del código (esta app no maneja centavos de peso).
      expect(formatNumberWithDots('55,500'), '55.500');
    });

    test('un String con coma de miles y punto decimal estilo US también se interpreta bien', () {
      expect(formatNumberWithDots('1,234.56'), '1.235'); // redondea, sin decimales
    });

    test('String vacío o no numérico da "0"', () {
      expect(formatNumberWithDots(''), '0');
      expect(formatNumberWithDots('abc'), '0');
    });

    test('NaN e infinito dan "0"', () {
      expect(formatNumberWithDots(double.nan), '0');
      expect(formatNumberWithDots(double.infinity), '0');
    });

    test('un tipo no soportado (no String, no num) da "0"', () {
      expect(formatNumberWithDots(true), '0');
    });
  });

  group('formatCurrency', () {
    test('antepone el símbolo de peso al número formateado', () {
      expect(formatCurrency(55500), '\$55.500');
    });

    test('cero da "\$0"', () {
      expect(formatCurrency(0), '\$0');
    });

    test('valor negativo conserva el signo antes del símbolo', () {
      expect(formatCurrency(-2000), '\$-2.000');
    });
  });

  group('formatCurrencyRoundedTo1000', () {
    test('redondea hacia arriba al siguiente múltiplo de 1000', () {
      expect(formatCurrencyRoundedTo1000(2023991), '\$2.024.000');
    });

    test('un valor ya múltiplo de 1000 no cambia', () {
      expect(formatCurrencyRoundedTo1000(50000), '\$50.000');
    });

    test('acepta un String como entrada', () {
      expect(formatCurrencyRoundedTo1000('1500'), '\$2.000');
    });
  });

  group('formatDate / formatDateOnly', () {
    test('formatDateOnly da dd/MM/yyyy con ceros a la izquierda', () {
      expect(formatDateOnly(DateTime(2026, 3, 5)), '05/03/2026');
    });

    test('formatDate incluye hora en formato 12h con AM/PM', () {
      expect(formatDate(DateTime(2026, 9, 30, 14, 30)), '30/09/2026 02:30 PM');
    });

    test('formatDate a medianoche muestra 12:00 AM', () {
      expect(formatDate(DateTime(2026, 1, 1, 0, 0)), '01/01/2026 12:00 AM');
    });

    test('formatDate al mediodía muestra 12:00 PM', () {
      expect(formatDate(DateTime(2026, 1, 1, 12, 0)), '01/01/2026 12:00 PM');
    });
  });

  group('formatTime12h / formatTime12hShort', () {
    test('formatTime12h agrega ceros a la izquierda en la hora', () {
      expect(formatTime12h(DateTime(2026, 1, 1, 9, 5)), '09:05 AM');
    });

    test('formatTime12hShort no agrega ceros a la izquierda en la hora', () {
      expect(formatTime12hShort(DateTime(2026, 1, 1, 9, 5)), '9:05 AM');
    });

    test('la hora 23 se muestra como 11 PM', () {
      expect(formatTime12h(DateTime(2026, 1, 1, 23, 15)), '11:15 PM');
    });
  });
}