/// §6 : heures = Σ minutesParPersonne (durée) ;
///      heuresPersonnes = Σ nbPersonnes × minutesParPersonne (charge).
/// R1 : jamais converties en coût — le résultat ne contient aucun montant.
library;

import 'package:chantiers/features/rentabilite/domain/heures_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/fixtures.dart';

void main() {
  group('HeuresCalculator.compute', () {
    test('sans saisie : tout à 0, effectif moyen null', () {
      final r = HeuresCalculator.compute(Fixtures.data());

      expect(r.dureeMinutes, 0);
      expect(r.chargeMinutes, 0);
      expect(r.nbSaisies, 0);
      expect(r.effectifMoyen, isNull);
      expect(r.chargeParTacheMinutes, isEmpty);
      expect(r.dureeParTravauxSupMinutes, isEmpty);
      expect(r.chargeParTravauxSupMinutes, isEmpty);
    });

    test('§6 : durée = Σ minutes, charge = Σ nb × minutes', () {
      final r = HeuresCalculator.compute(
        Fixtures.data(
          heures: [
            Fixtures.heures(id: 'h1', nbPersonnes: 2, minutesParPersonne: 480),
            Fixtures.heures(id: 'h2', nbPersonnes: 1, minutesParPersonne: 240),
            Fixtures.heures(id: 'h3', nbPersonnes: 3, minutesParPersonne: 60),
          ],
        ),
      );

      expect(r.dureeMinutes, 780);
      expect(r.chargeMinutes, 960 + 240 + 180);
      expect(r.nbSaisies, 3);
      // Effectif moyen = charge / durée = 1380 / 780.
      expect(r.effectifMoyen, closeTo(1.769, 0.001));
    });

    test('charge par tâche ; saisie sans tâche non ventilée', () {
      final r = HeuresCalculator.compute(
        Fixtures.data(
          heures: [
            Fixtures.heures(
              id: 'h1',
              nbPersonnes: 2,
              minutesParPersonne: 300,
              tacheId: 't-1',
            ),
            Fixtures.heures(
              id: 'h2',
              nbPersonnes: 1,
              minutesParPersonne: 120,
              tacheId: 't-1',
            ),
            Fixtures.heures(
              id: 'h3',
              nbPersonnes: 1,
              minutesParPersonne: 90,
              tacheId: 't-2',
            ),
            Fixtures.heures(id: 'h4', nbPersonnes: 4, minutesParPersonne: 60),
          ],
        ),
      );

      expect(r.chargeParTacheMinutes, {'t-1': 720, 't-2': 90});
      expect(r.dureeMinutes, 570);
      expect(r.chargeMinutes, 600 + 120 + 90 + 240);
    });

    test('§5 : les heures d\'un TS sont comptées UNE fois dans le chantier et '
        'ventilées à part (durée et charge)', () {
      final r = HeuresCalculator.compute(
        Fixtures.data(
          heures: [
            Fixtures.heures(id: 'h1', nbPersonnes: 2, minutesParPersonne: 480),
            Fixtures.heures(
              id: 'h2',
              nbPersonnes: 2,
              minutesParPersonne: 240,
              travauxSupId: 'ts-1',
            ),
            Fixtures.heures(
              id: 'h3',
              nbPersonnes: 1,
              minutesParPersonne: 60,
              travauxSupId: 'ts-1',
            ),
          ],
        ),
      );

      expect(r.dureeMinutes, 780);
      expect(r.chargeMinutes, 960 + 480 + 60);
      expect(r.dureeParTravauxSupMinutes, {'ts-1': 300});
      expect(r.chargeParTravauxSupMinutes, {'ts-1': 540});
    });

    test('R6 : les saisies supprimées (soft delete) sont exclues', () {
      final r = HeuresCalculator.compute(
        Fixtures.data(
          heures: [
            Fixtures.heures(id: 'h1', nbPersonnes: 1, minutesParPersonne: 480),
            Fixtures.heures(
              id: 'h2',
              nbPersonnes: 5,
              minutesParPersonne: 1440,
              tacheId: 't-1',
              travauxSupId: 'ts-1',
              deletedAt: Fixtures.jour,
            ),
          ],
        ),
      );

      expect(r.dureeMinutes, 480);
      expect(r.chargeMinutes, 480);
      expect(r.nbSaisies, 1);
      expect(r.chargeParTacheMinutes, isEmpty);
      expect(r.chargeParTravauxSupMinutes, isEmpty);
    });

    test('effectif moyen = charge / durée (1 personne → 1,0)', () {
      final r = HeuresCalculator.compute(
        Fixtures.data(
          heures: [
            Fixtures.heures(id: 'h1', nbPersonnes: 1, minutesParPersonne: 480),
            Fixtures.heures(id: 'h2', nbPersonnes: 1, minutesParPersonne: 120),
          ],
        ),
      );

      expect(r.effectifMoyen, 1.0);
    });
  });
}
