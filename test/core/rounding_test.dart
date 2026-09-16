/// R9 — une seule règle d'arrondi double → entier : half-up (0,5 s'éloigne
/// de zéro), jamais de bankers rounding.
library;

import 'package:chantiers/core/utils/rounding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rounding.halfUp', () {
    test('R9 : 0,5 → 1, 1,5 → 2, 2,5 → 3 (pas de bankers rounding)', () {
      expect(Rounding.halfUp(0.5), 1);
      expect(Rounding.halfUp(1.5), 2);
      expect(Rounding.halfUp(2.5), 3);
      expect(Rounding.halfUp(3.5), 4);
    });

    test('R9 : −2,5 → −3 (le demi s\'éloigne de zéro)', () {
      expect(Rounding.halfUp(-2.5), -3);
      expect(Rounding.halfUp(-0.5), -1);
      expect(Rounding.halfUp(-1.5), -2);
    });

    test('en dessous du demi, arrondi vers zéro', () {
      expect(Rounding.halfUp(2.4999), 2);
      expect(Rounding.halfUp(-2.4999), -2);
      expect(Rounding.halfUp(0.49), 0);
    });

    test('valeurs entières et zéro inchangés', () {
      expect(Rounding.halfUp(0), 0);
      expect(Rounding.halfUp(7), 7);
      expect(Rounding.halfUp(-7), -7);
    });

    test('NaN et infinis → ArgumentError', () {
      expect(() => Rounding.halfUp(double.nan), throwsArgumentError);
      expect(() => Rounding.halfUp(double.infinity), throwsArgumentError);
      expect(
        () => Rounding.halfUp(double.negativeInfinity),
        throwsArgumentError,
      );
    });
  });

  group('Rounding.toCents', () {
    test('R9 : 1,005 € → 101 c (imprécision binaire compensée)', () {
      expect(Rounding.toCents(1.005), 101);
    });

    test('R9 : 2,675 € → 268 c', () {
      expect(Rounding.toCents(2.675), 268);
    });

    test('valeurs exactes et négatives', () {
      expect(Rounding.toCents(10), 1000);
      expect(Rounding.toCents(0), 0);
      expect(Rounding.toCents(1234.56), 123456);
      expect(Rounding.toCents(-1.005), -101);
      expect(Rounding.toCents(-0.004), 0);
    });

    test('NaN → ArgumentError', () {
      expect(() => Rounding.toCents(double.nan), throwsArgumentError);
    });
  });

  group('Rounding.toMinutes', () {
    test('R9 : demi-minute arrondie vers le haut', () {
      expect(Rounding.toMinutes(7.5), 8);
      expect(Rounding.toMinutes(2.5), 3);
      expect(Rounding.toMinutes(-2.5), -3);
    });

    test('valeurs ordinaires', () {
      expect(Rounding.toMinutes(450), 450);
      expect(Rounding.toMinutes(79.98), 80);
      expect(Rounding.toMinutes(0.24), 0);
    });

    test('NaN → ArgumentError', () {
      expect(() => Rounding.toMinutes(double.nan), throwsArgumentError);
    });
  });

  group('Rounding.toDecimals', () {
    test('R9 : toDecimals(12,35, 1) = 12,4', () {
      expect(Rounding.toDecimals(12.35, 1), 12.4);
    });

    test('R9 : half-up sur les négatifs et à 2 décimales', () {
      expect(Rounding.toDecimals(-12.35, 1), -12.4);
      expect(Rounding.toDecimals(2.675, 2), 2.68);
      expect(Rounding.toDecimals(66.6666, 1), 66.7);
      expect(Rounding.toDecimals(-34.8333, 1), -34.8);
    });

    test('0 décimale = entier (en double)', () {
      expect(Rounding.toDecimals(12.5, 0), 13.0);
      expect(Rounding.toDecimals(12.34, 0), 12.0);
    });

    test('décimales négatives → ArgumentError', () {
      expect(() => Rounding.toDecimals(1, -1), throwsArgumentError);
    });

    test('NaN → ArgumentError', () {
      expect(() => Rounding.toDecimals(double.nan, 1), throwsArgumentError);
    });
  });
}
