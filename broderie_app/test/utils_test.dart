import 'package:atelier_broderie/utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async => initializeDateFormatting('fr_FR'));

  test('la semaine commence le samedi', () {
    final r = rangeFor(Periode.semaine, null);
    expect(r.start.weekday, DateTime.saturday);
    expect(r.end.difference(r.start).inDays, lessThan(7));
  });

  test('mois dernier couvre le mois complet', () {
    final r = rangeFor(Periode.moisDernier, null);
    expect(r.start.day, 1);
    expect(r.end.add(const Duration(days: 1)).day, 1);
  });

  test('lecture des nombres', () {
    expect(parseInt('1 500'), 1500);
    expect(parseNum('12,5'), 12.5);
    expect(dateKey(DateTime(2026, 3, 7)), '2026-03-07');
  });
}
