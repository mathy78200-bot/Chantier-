/// §6 : ecartDepenses% = (depenses − budgetPrevuTotal) / budgetPrevuTotal × 100
///      ← indicateur PRINCIPAL ; budgetPrevuTotal = budget + Σ TS[accepte].budget ;
///      heuresPrevuesTot = heuresPrevues + Σ TS[accepte].heuresPrevuesMinutes.
/// R9 : pourcentages arrondis à 1 décimale, half-up.
/// R8 : ce calculateur ignore la projection.
library;

import 'package:chantiers/core/constants/enums.dart';
import 'package:chantiers/features/rentabilite/domain/chantier_data.dart';
import 'package:chantiers/features/rentabilite/domain/depenses_calculator.dart';
import 'package:chantiers/features/rentabilite/domain/ecart_calculator.dart';
import 'package:chantiers/features/rentabilite/domain/heures_calculator.dart';
import 'package:chantiers/features/rentabilite/domain/previsionnel_calculator.dart';
import 'package:chantiers/features/rentabilite/domain/resultats.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/fixtures.dart';

EcartResult _ecart(ChantierData data) => EcartCalculator.compute(
  depenses: DepensesCalculator.compute(data),
  heures: HeuresCalculator.compute(data),
  previsionnel: PrevisionnelCalculator.compute(data),
);

void main() {
  group('EcartCalculator.compute — écart dépenses (PRINCIPAL)', () {
    test('§6 : (dépenses − budget) / budget × 100 ; 6 300 € sur 6 000 € → '
        '+300 €, +5,0 %', () {
      final r = _ecart(
        Fixtures.data(
          previsionnel: Fixtures.previsionnel(budgetDepensesCents: 600000),
          depenses: [Fixtures.depense(montantCents: 630000)],
        ),
      );

      expect(r.ecartDepensesCents, 30000);
      expect(r.ecartDepensesPct, 5.0);
    });

    test('dépenses sous le budget : écart négatif (4 500 € sur 6 000 € → '
        '−25,0 %)', () {
      final r = _ecart(
        Fixtures.data(
          previsionnel: Fixtures.previsionnel(budgetDepensesCents: 600000),
          depenses: [Fixtures.depense(montantCents: 450000)],
        ),
      );

      expect(r.ecartDepensesCents, -150000);
      expect(r.ecartDepensesPct, -25.0);
    });

    test('R9 : 1 décimale half-up (24 900 / 200 000 = 12,45 → 12,5)', () {
      final r = _ecart(
        Fixtures.data(
          previsionnel: Fixtures.previsionnel(budgetDepensesCents: 200000),
          depenses: [Fixtures.depense(montantCents: 224900)],
        ),
      );

      expect(r.ecartDepensesCents, 24900);
      expect(r.ecartDepensesPct, 12.5);
    });

    test('R9 : 2/3 → 66,7 ; 1/3 → 33,3', () {
      final deuxTiers = _ecart(
        Fixtures.data(
          previsionnel: Fixtures.previsionnel(budgetDepensesCents: 300000),
          depenses: [Fixtures.depense(montantCents: 500000)],
        ),
      );
      final unTiers = _ecart(
        Fixtures.data(
          previsionnel: Fixtures.previsionnel(budgetDepensesCents: 300000),
          depenses: [Fixtures.depense(montantCents: 400000)],
        ),
      );

      expect(deuxTiers.ecartDepensesPct, 66.7);
      expect(unTiers.ecartDepensesPct, 33.3);
    });

    test('null si budget null (aucun prévisionnel)', () {
      final r = _ecart(
        Fixtures.data(depenses: [Fixtures.depense(montantCents: 630000)]),
      );

      expect(r.ecartDepensesCents, isNull);
      expect(r.ecartDepensesPct, isNull);
    });

    test('budget saisi à 0 : écart absolu = dépenses, pourcentage null '
        '(division par zéro)', () {
      final r = _ecart(
        Fixtures.data(
          previsionnel: Fixtures.previsionnel(budgetDepensesCents: 0),
          depenses: [Fixtures.depense(montantCents: 50000)],
        ),
      );

      expect(r.ecartDepensesCents, 50000);
      expect(r.ecartDepensesPct, isNull);
    });

    test('§6 : budgetPrevuTotal inclut Σ TS acceptés, pas les proposés ni '
        'les refusés (6 000 + 1 000 = 7 000 € ; 7 700 € dépensés → +10,0 %)', () {
      final r = _ecart(
        Fixtures.data(
          previsionnel: Fixtures.previsionnel(budgetDepensesCents: 600000),
          travauxSup: [
            Fixtures.travauxSup(
              id: 'ts-acc',
              statut: StatutTravauxSup.accepte,
              budgetDepensesCents: 100000,
            ),
            Fixtures.travauxSup(
              id: 'ts-prop',
              statut: StatutTravauxSup.propose,
              budgetDepensesCents: 50000,
            ),
            Fixtures.travauxSup(
              id: 'ts-ref',
              statut: StatutTravauxSup.refuse,
              budgetDepensesCents: 80000,
            ),
          ],
          depenses: [
            Fixtures.depense(id: 'd1', montantCents: 700000),
            Fixtures.depense(
              id: 'd2',
              montantCents: 70000,
              travauxSupId: 'ts-acc',
            ),
          ],
        ),
      );

      // Sans les TS, l'écart serait de (770 000 − 600 000) / 600 000 = 28,3 %.
      expect(r.ecartDepensesCents, 70000);
      expect(r.ecartDepensesPct, 10.0);
    });

    test('sans dépense : écart = −budget, −100 %', () {
      final r = _ecart(
        Fixtures.data(
          previsionnel: Fixtures.previsionnel(budgetDepensesCents: 600000),
        ),
      );

      expect(r.ecartDepensesCents, -600000);
      expect(r.ecartDepensesPct, -100.0);
    });
  });

  group('EcartCalculator.compute — écarts par type', () {
    test('ecartParTypeCents seulement pour les types budgétés', () {
      final r = _ecart(
        Fixtures.data(
          previsionnel: Fixtures.previsionnel(
            budgetParTypeCents: {'materiaux': 300000, 'repas': 10000},
          ),
          depenses: [
            Fixtures.depense(
              id: 'd1',
              type: TypeDepense.materiaux,
              montantCents: 350000,
            ),
            // Non budgété : absent des écarts par type, mais dans le total.
            Fixtures.depense(
              id: 'd2',
              type: TypeDepense.sousTraitance,
              montantCents: 50000,
            ),
          ],
        ),
      );

      expect(r.ecartParTypeCents, {
        TypeDepense.materiaux: 50000,
        TypeDepense.repas: -10000,
      });
      expect(
        r.ecartParTypeCents.containsKey(TypeDepense.sousTraitance),
        isFalse,
      );
      // Budget dérivé des types = 310 000 ; (400 000 − 310 000) / 310 000.
      expect(r.ecartDepensesCents, 90000);
      expect(r.ecartDepensesPct, 29.0);
    });

    test('sans budget par type : map vide', () {
      final r = _ecart(
        Fixtures.data(
          previsionnel: Fixtures.previsionnel(budgetDepensesCents: 600000),
          depenses: [Fixtures.depense(montantCents: 10000)],
        ),
      );

      expect(r.ecartParTypeCents, isEmpty);
    });
  });

  group('EcartCalculator.compute — écarts heures et charge', () {
    test('§6 : heures vs heuresPrevuesTot (TS acceptés inclus), charge vs '
        'charge prévue totale', () {
      // Prévu : 80 h × 2 pers. = 9 600 pers.-min ; TS accepté 10 h × 2 =
      // 1 200. Totaux : 5 400 min, 10 800 pers.-min.
      // Réel : 480 + 420 + 300 = 1 200 min ; 960 + 1 260 + 600 = 2 820.
      final r = _ecart(
        Fixtures.data(
          previsionnel: Fixtures.previsionnel(
            heuresPrevuesMinutes: 4800,
            effectifPrevu: 2,
          ),
          travauxSup: [
            Fixtures.travauxSup(
              id: 'ts-acc',
              heuresPrevuesMinutes: 600,
              effectifPrevu: 2,
            ),
          ],
          heures: [
            Fixtures.heures(id: 'h1', nbPersonnes: 2, minutesParPersonne: 480),
            Fixtures.heures(id: 'h2', nbPersonnes: 3, minutesParPersonne: 420),
            Fixtures.heures(
              id: 'h3',
              nbPersonnes: 2,
              minutesParPersonne: 300,
              travauxSupId: 'ts-acc',
            ),
          ],
        ),
      );

      expect(r.ecartHeuresMinutes, -4200);
      // −4 200 / 5 400 = −77,77… → −77,8.
      expect(r.ecartHeuresPct, -77.8);
      expect(r.ecartChargeMinutes, -7980);
      // −7 980 / 10 800 = −73,88… → −73,9.
      expect(r.ecartChargePct, -73.9);
    });

    test('dépassement d\'heures : écart positif (90 h sur 80 h → +12,5 %)', () {
      final r = _ecart(
        Fixtures.data(
          previsionnel: Fixtures.previsionnel(heuresPrevuesMinutes: 4800),
          heures: [
            for (var i = 0; i < 9; i++)
              Fixtures.heures(id: 'h$i', minutesParPersonne: 600),
          ],
        ),
      );

      expect(r.ecartHeuresMinutes, 600);
      expect(r.ecartHeuresPct, 12.5);
    });

    test('sans heures prévues : écarts heures null ; sans effectif : charge '
        'null', () {
      final r = _ecart(
        Fixtures.data(
          previsionnel: Fixtures.previsionnel(budgetDepensesCents: 600000),
          heures: [Fixtures.heures(minutesParPersonne: 480)],
        ),
      );

      expect(r.ecartHeuresMinutes, isNull);
      expect(r.ecartHeuresPct, isNull);
      expect(r.ecartChargeMinutes, isNull);
      expect(r.ecartChargePct, isNull);
      // L'écart dépenses reste calculable indépendamment.
      expect(r.ecartDepensesPct, -100.0);
    });

    test(
      'heures prévues sans effectif : écart heures calculé, charge null',
      () {
        final r = _ecart(
          Fixtures.data(
            previsionnel: Fixtures.previsionnel(heuresPrevuesMinutes: 4800),
            heures: [Fixtures.heures(nbPersonnes: 2, minutesParPersonne: 480)],
          ),
        );

        expect(r.ecartHeuresMinutes, -4320);
        expect(r.ecartHeuresPct, -90.0);
        expect(r.ecartChargeMinutes, isNull);
        expect(r.ecartChargePct, isNull);
      },
    );
  });

  group('EcartCalculator.ecartAbsolu / ecartPct', () {
    test('ecartAbsolu : reel − prevu, null sans prévu', () {
      expect(EcartCalculator.ecartAbsolu(150, 100), 50);
      expect(EcartCalculator.ecartAbsolu(50, 100), -50);
      expect(EcartCalculator.ecartAbsolu(50, 0), 50);
      expect(EcartCalculator.ecartAbsolu(50, null), isNull);
    });

    test('R9 : ecartPct 1 décimale half-up ; null si prévu null ou ≤ 0', () {
      expect(EcartCalculator.ecartPct(224900, 200000), 12.5);
      expect(EcartCalculator.ecartPct(500000, 300000), 66.7);
      expect(EcartCalculator.ecartPct(0, 100), -100.0);
      expect(EcartCalculator.ecartPct(100, 100), 0.0);
      expect(EcartCalculator.ecartPct(100, null), isNull);
      expect(EcartCalculator.ecartPct(100, 0), isNull);
      expect(EcartCalculator.ecartPct(100, -5), isNull);
    });
  });
}
