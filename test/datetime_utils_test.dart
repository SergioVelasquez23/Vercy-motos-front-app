import 'package:flutter_test/flutter_test.dart';
import 'package:vercy_motos/utils/datetime_utils.dart';

void main() {
  group('DateTimeUtils.nowColombia', () {
    test('esta ~5 horas detras de la hora UTC actual y no queda marcada como UTC', () {
      final antes = DateTime.now().toUtc();
      final colombia = DateTimeUtils.nowColombia();
      final despues = DateTime.now().toUtc();

      expect(colombia.isUtc, isFalse);
      final esperadoMin = antes.subtract(const Duration(hours: 5, seconds: 2));
      final esperadoMax = despues.subtract(const Duration(hours: 5, seconds: -2));
      final colombiaComoUtcParaComparar = DateTime.utc(
        colombia.year, colombia.month, colombia.day,
        colombia.hour, colombia.minute, colombia.second,
      );
      expect(colombiaComoUtcParaComparar.isAfter(esperadoMin), isTrue);
      expect(colombiaComoUtcParaComparar.isBefore(esperadoMax), isTrue);
    });
  });

  group('DateTimeUtils.safeParse', () {
    final fallback = DateTime(2000, 1, 1);

    test('un DateTime se devuelve tal cual', () {
      final dt = DateTime(2026, 7, 16);
      expect(DateTimeUtils.safeParse(dt, fallback: fallback), dt);
    });

    test('null devuelve el fallback', () {
      expect(DateTimeUtils.safeParse(null, fallback: fallback), fallback);
    });

    test('sin fallback explicito, null devuelve "ahora" (no lanza)', () {
      expect(DateTimeUtils.safeParse(null), isA<DateTime>());
    });

    test('un timestamp en milisegundos se interpreta correctamente', () {
      final ms = DateTime(2026, 1, 1).toUtc().millisecondsSinceEpoch;
      final resultado = DateTimeUtils.safeParse(ms, fallback: fallback);
      expect(resultado.toUtc().year, 2026);
    });

    test('un timestamp en segundos (< 10^10) se multiplica a milisegundos', () {
      final segundos = DateTime(2026, 1, 1).toUtc().millisecondsSinceEpoch ~/ 1000;
      final resultado = DateTimeUtils.safeParse(segundos, fallback: fallback);
      expect(resultado.toUtc().year, 2026);
    });

    test('un string ISO8601 valido se parsea directo', () {
      final resultado = DateTimeUtils.safeParse('2026-07-16T10:30:00.000Z', fallback: fallback);
      expect(resultado.toUtc().year, 2026);
      expect(resultado.toUtc().month, 7);
      expect(resultado.toUtc().day, 16);
    });

    test('un string vacío devuelve el fallback', () {
      expect(DateTimeUtils.safeParse('', fallback: fallback), fallback);
    });

    test('un string de fecha simple (yyyy-MM-dd) se parsea a medianoche', () {
      final resultado = DateTimeUtils.safeParse('2026-07-16', fallback: fallback);
      expect(resultado.year, 2026);
      expect(resultado.month, 7);
      expect(resultado.day, 16);
    });

    test('un string no parseable devuelve el fallback', () {
      expect(DateTimeUtils.safeParse('no-es-una-fecha', fallback: fallback), fallback);
    });

    test('un tipo inesperado (ej. bool) devuelve el fallback', () {
      expect(DateTimeUtils.safeParse(true, fallback: fallback), fallback);
    });
  });

  group('DateTimeUtils.safeParseFromJson', () {
    final fallback = DateTime(2000, 1, 1);

    test('clave ausente devuelve el fallback', () {
      expect(DateTimeUtils.safeParseFromJson({}, 'fecha', fallback: fallback), fallback);
    });

    test('clave presente pero null devuelve el fallback', () {
      expect(
        DateTimeUtils.safeParseFromJson({'fecha': null}, 'fecha', fallback: fallback),
        fallback,
      );
    });

    test('clave presente con fecha valida la parsea', () {
      final resultado = DateTimeUtils.safeParseFromJson(
        {'fecha': '2026-07-16T00:00:00.000Z'},
        'fecha',
        fallback: fallback,
      );
      expect(resultado!.toUtc().year, 2026);
    });
  });

  group('DateTimeUtils.toIsoString', () {
    test('null devuelve null', () {
      expect(DateTimeUtils.toIsoString(null), isNull);
    });

    test('un DateTime valido devuelve su ISO8601', () {
      final dt = DateTime(2026, 7, 16, 10, 30);
      expect(DateTimeUtils.toIsoString(dt), dt.toIso8601String());
    });
  });

  group('DateTimeUtils.formatForDisplay', () {
    final dt = DateTime(2026, 7, 16, 14, 5); // 2:05 PM

    test('null devuelve N/A', () {
      expect(DateTimeUtils.formatForDisplay(null), 'N/A');
    });

    test('formato "date" es dd/MM/yyyy', () {
      expect(DateTimeUtils.formatForDisplay(dt, format: 'date'), '16/07/2026');
    });

    test('formato "time" es 12 horas con AM/PM', () {
      expect(DateTimeUtils.formatForDisplay(dt, format: 'time'), '02:05 PM');
    });

    test('formato "time24" es 24 horas', () {
      expect(DateTimeUtils.formatForDisplay(dt, format: 'time24'), '14:05');
    });

    test('medianoche en formato 12h se muestra como 12 AM', () {
      final medianoche = DateTime(2026, 7, 16, 0, 0);
      expect(DateTimeUtils.formatForDisplay(medianoche, format: 'time'), '12:00 AM');
    });

    test('mediodia en formato 12h se muestra como 12 PM', () {
      final mediodia = DateTime(2026, 7, 16, 12, 0);
      expect(DateTimeUtils.formatForDisplay(mediodia, format: 'time'), '12:00 PM');
    });

    test('formato default ("datetime") combina fecha y hora 12h', () {
      expect(DateTimeUtils.formatForDisplay(dt), '16/07/2026 02:05 PM');
    });
  });

  group('DateTimeUtils.isValidDate', () {
    test('null no es valida', () {
      expect(DateTimeUtils.isValidDate(null), isFalse);
    });

    test('una fecha dentro del rango default es valida', () {
      expect(DateTimeUtils.isValidDate(DateTime(2026, 1, 1)), isTrue);
    });

    test('una fecha antes de minYear no es valida', () {
      expect(DateTimeUtils.isValidDate(DateTime(1999, 1, 1)), isFalse);
    });

    test('una fecha muy lejana en el futuro (> maxYear default) no es valida', () {
      expect(DateTimeUtils.isValidDate(DateTime(DateTime.now().year + 50, 1, 1)), isFalse);
    });

    test('respeta minYear/maxYear explicitos', () {
      expect(
        DateTimeUtils.isValidDate(DateTime(2010, 1, 1), minYear: 2015, maxYear: 2020),
        isFalse,
      );
      expect(
        DateTimeUtils.isValidDate(DateTime(2018, 1, 1), minYear: 2015, maxYear: 2020),
        isTrue,
      );
    });
  });
}
