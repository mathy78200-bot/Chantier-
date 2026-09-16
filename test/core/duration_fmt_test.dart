/// Durées : `int` minutes en base, saisie UI en heures / quarts d'heure.
library;

import 'package:chantiers/core/utils/duration_fmt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DurationFmt.format', () {
    test('heures et minutes : « 7 h 30 »', () {
      expect(DurationFmt.format(450), '7 h 30');
      expect(DurationFmt.format(65), '1 h 05');
    });

    test('minutes seules : « 45 min »', () {
      expect(DurationFmt.format(45), '45 min');
      expect(DurationFmt.format(1), '1 min');
    });

    test('heures rondes : « 7 h »', () {
      expect(DurationFmt.format(420), '7 h');
      expect(DurationFmt.format(60), '1 h');
    });

    test('zéro : « 0 h »', () {
      expect(DurationFmt.format(0), '0 h');
    });

    test('durées négatives (écarts) : signe devant', () {
      expect(DurationFmt.format(-90), '-1 h 30');
      expect(DurationFmt.format(-45), '-45 min');
      expect(DurationFmt.format(-120), '-2 h');
    });
  });

  group('DurationFmt.formatDecimal', () {
    test('une décimale, virgule française', () {
      expect(DurationFmt.formatDecimal(450), '7,5 h');
      expect(DurationFmt.formatDecimal(60), '1,0 h');
      expect(DurationFmt.formatDecimal(0), '0,0 h');
    });

    test('R9 : arrondi half-up à la décimale', () {
      // 80 min = 1,333 h → 1,3 ; 455 min = 7,583 h → 7,6 ; 27 min = 0,45 → 0,5.
      expect(DurationFmt.formatDecimal(80), '1,3 h');
      expect(DurationFmt.formatDecimal(455), '7,6 h');
      expect(DurationFmt.formatDecimal(27), '0,5 h');
    });
  });

  group('DurationFmt.formatJours', () {
    test('journée type par défaut (7 h = 420 min)', () {
      expect(DurationFmt.formatJours(2100), '5,0 j');
      expect(DurationFmt.formatJours(630), '1,5 j');
    });

    test('journée type personnalisée, arrondi half-up', () {
      // 600 / 480 = 1,25 → 1,3.
      expect(DurationFmt.formatJours(600, minutesJourneeType: 480), '1,3 j');
    });
  });

  group('DurationFmt.toHeures / fromHeures', () {
    test('toHeures : conversion exacte en double', () {
      expect(DurationFmt.toHeures(90), 1.5);
      expect(DurationFmt.toHeures(0), 0);
    });

    test('fromHeures : R9 arrondi half-up à la minute', () {
      expect(DurationFmt.fromHeures(7.5), 450);
      expect(DurationFmt.fromHeures(1.333), 80);
      expect(DurationFmt.fromHeures(0.004), 0);
      // 0,0125 h = 0,75 min → 1 min.
      expect(DurationFmt.fromHeures(0.0125), 1);
    });
  });

  group('DurationFmt.arrondiQuartHeure', () {
    test('arrondit au quart d\'heure le plus proche', () {
      expect(DurationFmt.arrondiQuartHeure(37), 30);
      expect(DurationFmt.arrondiQuartHeure(38), 45);
      expect(DurationFmt.arrondiQuartHeure(7), 0);
      expect(DurationFmt.arrondiQuartHeure(8), 15);
      expect(DurationFmt.arrondiQuartHeure(22), 15);
      expect(DurationFmt.arrondiQuartHeure(23), 30);
    });

    test('un multiple de 15 est inchangé', () {
      expect(DurationFmt.arrondiQuartHeure(450), 450);
      expect(DurationFmt.arrondiQuartHeure(0), 0);
      expect(DurationFmt.arrondiQuartHeure(15), 15);
    });
  });

  group('DurationFmt.parse', () {
    test('formats heures/minutes : 7h30, 7 h 30, 7:30, 7H30', () {
      expect(DurationFmt.parse('7h30'), 450);
      expect(DurationFmt.parse('7 h 30'), 450);
      expect(DurationFmt.parse('7:30'), 450);
      expect(DurationFmt.parse('7H30'), 450);
      expect(DurationFmt.parse('  7h30  '), 450);
      expect(DurationFmt.parse('7:5'), 425);
    });

    test('heures seules : 7h, 7', () {
      expect(DurationFmt.parse('7h'), 420);
      expect(DurationFmt.parse('7'), 420);
      expect(DurationFmt.parse('0'), 0);
    });

    test('décimales : 7,5 et 7.25 (heures décimales)', () {
      expect(DurationFmt.parse('7,5'), 450);
      expect(DurationFmt.parse('7.25'), 435);
      expect(DurationFmt.parse('1.5h'), 90);
    });

    test('minutes seules : 45min, 45 min', () {
      expect(DurationFmt.parse('45min'), 45);
      expect(DurationFmt.parse('45 min'), 45);
      expect(DurationFmt.parse('90min'), 90);
    });

    test('saisies invalides → null', () {
      expect(DurationFmt.parse(''), isNull);
      expect(DurationFmt.parse('   '), isNull);
      expect(DurationFmt.parse('abc'), isNull);
      expect(DurationFmt.parse('7h60'), isNull);
      expect(DurationFmt.parse('-1'), isNull);
      expect(DurationFmt.parse('7h30min'), isNull);
    });

    test('aller-retour format → parse', () {
      for (final minutes in [0, 15, 45, 60, 450, 1440]) {
        expect(DurationFmt.parse(DurationFmt.format(minutes)), minutes);
      }
    });
  });
}
