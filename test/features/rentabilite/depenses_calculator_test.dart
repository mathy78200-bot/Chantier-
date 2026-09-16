/// §6 : depenses = Σ depenses.montantCents (tous types).
/// §5 : les dépenses d'un travaux sup sont comptées une seule fois.
library;

import 'package:chantiers/core/constants/enums.dart';
import 'package:chantiers/features/rentabilite/domain/depenses_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/fixtures.dart';

void main() {
  group('DepensesCalculator.compute', () {
    test('sans dépense : total 0, aucun type, aucune ventilation', () {
      final r = DepensesCalculator.compute(Fixtures.data());

      expect(r.totalCents, 0);
      expect(r.nbDepenses, 0);
      expect(r.horsTravauxSupCents, 0);
      expect(r.parTravauxSupCents, isEmpty);
      expect(r.parTacheCents, isEmpty);
      for (final type in TypeDepense.values) {
        expect(r.pourType(type), 0, reason: type.name);
      }
    });

    test('§6 : total = Σ montantCents, tous types confondus', () {
      final r = DepensesCalculator.compute(
        Fixtures.data(
          depenses: [
            Fixtures.depense(id: 'd1', montantCents: 10000),
            Fixtures.depense(
              id: 'd2',
              type: TypeDepense.sousTraitance,
              montantCents: 25000,
            ),
            Fixtures.depense(
              id: 'd3',
              type: TypeDepense.repas,
              montantCents: 1500,
            ),
            Fixtures.depense(
              id: 'd4',
              type: TypeDepense.deplacement,
              montantCents: 3000,
              distanceKm: 50,
              baremeKmCentsSnapshot: 60,
            ),
          ],
        ),
      );

      expect(r.totalCents, 39500);
      expect(r.nbDepenses, 4);
      expect(r.horsTravauxSupCents, 39500);
    });

    test('ventilation par type ; type absent → 0', () {
      final r = DepensesCalculator.compute(
        Fixtures.data(
          depenses: [
            Fixtures.depense(id: 'd1', montantCents: 10000),
            Fixtures.depense(id: 'd2', montantCents: 5000),
            Fixtures.depense(
              id: 'd3',
              type: TypeDepense.sousTraitance,
              montantCents: 25000,
            ),
          ],
        ),
      );

      expect(r.pourType(TypeDepense.materiaux), 15000);
      expect(r.pourType(TypeDepense.sousTraitance), 25000);
      expect(r.pourType(TypeDepense.hotel), 0);
      expect(r.pourType(TypeDepense.autre), 0);
    });

    test('§5 : une dépense de TS est comptée UNE fois dans le total du '
        'chantier et ventilée à part', () {
      final r = DepensesCalculator.compute(
        Fixtures.data(
          depenses: [
            Fixtures.depense(id: 'd1', montantCents: 10000),
            Fixtures.depense(
              id: 'd2',
              montantCents: 5000,
              travauxSupId: 'ts-1',
            ),
            Fixtures.depense(
              id: 'd3',
              montantCents: 2500,
              travauxSupId: 'ts-1',
            ),
            Fixtures.depense(
              id: 'd4',
              montantCents: 1000,
              travauxSupId: 'ts-2',
            ),
          ],
        ),
      );

      expect(r.totalCents, 18500);
      expect(r.horsTravauxSupCents, 10000);
      expect(r.parTravauxSupCents, {'ts-1': 7500, 'ts-2': 1000});
      // Invariant : total = hors TS + Σ par TS.
      expect(
        r.horsTravauxSupCents +
            r.parTravauxSupCents.values.fold<int>(0, (a, b) => a + b),
        r.totalCents,
      );
    });

    test('ventilation par tâche ; dépense sans tâche non ventilée', () {
      final r = DepensesCalculator.compute(
        Fixtures.data(
          depenses: [
            Fixtures.depense(id: 'd1', montantCents: 10000, tacheId: 't-1'),
            Fixtures.depense(id: 'd2', montantCents: 5000, tacheId: 't-1'),
            Fixtures.depense(id: 'd3', montantCents: 2000, tacheId: 't-2'),
            Fixtures.depense(id: 'd4', montantCents: 700),
          ],
        ),
      );

      expect(r.parTacheCents, {'t-1': 15000, 't-2': 2000});
      expect(r.totalCents, 17700);
    });

    test('R6 : les dépenses supprimées (soft delete) sont exclues', () {
      final r = DepensesCalculator.compute(
        Fixtures.data(
          depenses: [
            Fixtures.depense(id: 'd1', montantCents: 10000),
            Fixtures.depense(
              id: 'd2',
              montantCents: 999999,
              tacheId: 't-1',
              travauxSupId: 'ts-1',
              deletedAt: Fixtures.jour,
            ),
          ],
        ),
      );

      expect(r.totalCents, 10000);
      expect(r.nbDepenses, 1);
      expect(r.parTravauxSupCents, isEmpty);
      expect(r.parTacheCents, isEmpty);
    });

    test('une dépense à 0 compte dans le nombre mais pas dans le total', () {
      final r = DepensesCalculator.compute(
        Fixtures.data(depenses: [Fixtures.depense(montantCents: 0)]),
      );

      expect(r.totalCents, 0);
      expect(r.nbDepenses, 1);
    });
  });
}
