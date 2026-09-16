/// Montants : `int` centimes en base, affichage fr_FR, saisie tolérante.
library;

import 'package:chantiers/core/constants/enums.dart';
import 'package:chantiers/core/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

/// intl (fr_FR) utilise l'espace fine insécable (U+202F) comme séparateur de
/// milliers et l'espace insécable (U+00A0) avant le symbole ; on normalise en
/// espace simple pour des attentes lisibles.
String norm(String s) => s.replaceAll(' ', ' ').replaceAll(' ', ' ');

void main() {
  group('Money.format', () {
    test('« 1 234,56 € » : virgule décimale et séparateur de milliers', () {
      expect(norm(Money.format(123456)), '1 234,56 €');
      expect(norm(Money.format(123456789)), '1 234 567,89 €');
    });

    test('zéro, petits montants et négatifs', () {
      expect(norm(Money.format(0)), '0,00 €');
      expect(norm(Money.format(5)), '0,05 €');
      expect(norm(Money.format(-5000)), '-50,00 €');
    });

    test('suffixe HT / TTC si le mode est fourni (R2 : montants qualifiés)',
        () {
      expect(norm(Money.format(100000, mode: ModePrix.ht)), '1 000,00 € HT');
      expect(norm(Money.format(100000, mode: ModePrix.ttc)), '1 000,00 € TTC');
      expect(norm(Money.format(100000)), '1 000,00 €');
    });

    test('les espaces produits sont insécables (pas de retour à la ligne)', () {
      final s = Money.format(123456);
      expect(s.contains(' '), isFalse);
      expect(s.contains(' '), isTrue);
    });
  });

  group('Money.formatSigne', () {
    test('« + » explicite pour les positifs uniquement', () {
      expect(norm(Money.formatSigne(5000)), '+50,00 €');
      expect(norm(Money.formatSigne(-5000)), '-50,00 €');
      expect(norm(Money.formatSigne(0)), '0,00 €');
      expect(norm(Money.formatSigne(5000, mode: ModePrix.ht)), '+50,00 € HT');
    });
  });

  group('Money.formatPct', () {
    test('une décimale, virgule française, suffixe %', () {
      expect(norm(Money.formatPct(12.3)), '12,3 %');
      expect(norm(Money.formatPct(12)), '12,0 %');
      expect(norm(Money.formatPct(-34.8)), '-34,8 %');
      expect(norm(Money.formatPct(100)), '100,0 %');
    });

    test('null → « — » (non calculable)', () {
      expect(Money.formatPct(null), '—');
    });
  });

  group('Money.parse', () {
    test('formats français et anglais, avec ou sans €', () {
      expect(Money.parse('1 234,56'), 123456);
      expect(Money.parse('1234.5'), 123450);
      expect(Money.parse('12 €'), 1200);
      expect(Money.parse('12€'), 1200);
      expect(Money.parse('0'), 0);
      expect(Money.parse('-50'), -5000);
    });

    test('espaces insécables acceptés (collage d\'un montant formaté)', () {
      expect(Money.parse('1 234,56 €'), 123456);
    });

    test('R9 : arrondi half-up au centime', () {
      expect(Money.parse('1,005'), 101);
      expect(Money.parse('2,675'), 268);
      expect(Money.parse('0,004'), 0);
    });

    test('saisies invalides → null', () {
      expect(Money.parse(''), isNull);
      expect(Money.parse('   '), isNull);
      expect(Money.parse('abc'), isNull);
      expect(Money.parse('€'), isNull);
      expect(Money.parse('12,34,56'), isNull);
    });

    test('aller-retour format → parse', () {
      for (final cents in [0, 5, 1200, 123456, -5000, 123456789]) {
        expect(Money.parse(Money.format(cents)), cents);
      }
    });
  });
}
