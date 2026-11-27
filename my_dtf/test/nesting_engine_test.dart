import 'package:flutter_test/flutter_test.dart';
import 'package:my_dtf/core/nesting/nesting_engine.dart';
import 'package:my_dtf/core/pricing.dart';

void main() {
  const engine = NestingEngine(filmWidthCm: 58, gapCm: 0.3);

  void expectNoOverlap(NestResult r) {
    final p = r.placements;
    for (var a = 0; a < p.length; a++) {
      expect(p[a].x >= -1e-9 && p[a].x + p[a].width <= 58 + 1e-9, isTrue);
      for (var b = a + 1; b < p.length; b++) {
        final sep = p[a].x + p[a].width <= p[b].x + 1e-9 ||
            p[b].x + p[b].width <= p[a].x + 1e-9 ||
            p[a].y + p[a].height <= p[b].y + 1e-9 ||
            p[b].y + p[b].height <= p[a].y + 1e-9;
        expect(sep, isTrue);
      }
    }
  }

  test('28,5 × 30 × 10 → 2 par ligne, 5 lignes ≈ 1,51 m', () {
    final r = engine.nest(
        [const NestItem(id: 'a', widthCm: 28.5, heightCm: 30, quantity: 10)]);
    expect(r.placements.length, 10);
    expect(r.lengthCm, closeTo(151.2, 0.01));
    expectNoOverlap(r);
  });

  test('10 × 10 × 20 → 5 par ligne, 4 lignes', () {
    final r = engine.nest(
        [const NestItem(id: 'a', widthCm: 10, heightCm: 10, quantity: 20)]);
    expect(r.lengthCm, closeTo(40.9, 0.01));
    expectNoOverlap(r);
  });

  test('commande mixte 8×10, 25×30, 25×40', () {
    final r = engine.nest(const [
      NestItem(id: 'p', widthCm: 8, heightCm: 10, quantity: 6),
      NestItem(id: 'q', widthCm: 25, heightCm: 30, quantity: 1),
      NestItem(id: 'r', widthCm: 25, heightCm: 40, quantity: 1),
    ]);
    expect(r.placements.length, 8);
    expect(r.lengthCm, closeTo(45.6, 0.01));
    expectNoOverlap(r);
  });

  test('image trop large refusée', () {
    expect(
        () => engine.nest([
              const NestItem(id: 'x', widthCm: 70, heightCm: 65, quantity: 1)
            ]),
        throwsA(isA<ItemTooWideException>()));
  });

  test('prix : arrondi au 0,1 m et minimum de commande', () {
    const s = PricingSettings(
        pricePerMeter: 1000, minOrderAmount: 500, meterRoundingStep: 0.1);
    expect(computeQuote(151.2, s).billedMeters, closeTo(1.6, 1e-9));
    expect(computeQuote(151.2, s).printAmount, 1600);
    expect(computeQuote(20, s).printAmount, 500);
  });
}
