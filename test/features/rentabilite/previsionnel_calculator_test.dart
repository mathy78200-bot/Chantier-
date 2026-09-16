/// §6 : heuresPrevues = previsionnel.heuresPrevuesMinutes
///                      ?? Σ tachesPrincipales.heuresPrevuesMinutes ;
///      budgetPrevuTotal = budget + Σ TS[accepte].budgetDepensesCents ;
///      heuresPrevuesTot = heuresPrevues + Σ TS[accepte].heuresPrevuesMinutes.
/// R10 : valeurs globales, sinon dérivées des tâches ; tâches optionnelles.
library;

import 'package:chantiers/core/constants/enums.dart';
import 'package:chantiers/features/rentabilite/domain/previsionnel_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/fixtures.dart';

void main() {
  group('PrevisionnelCalculator.compute', () {
    test('sans prévisionnel ni tâche ni date : tout null, rien de dérivé', () {
      final r = PrevisionnelCalculator.compute(Fixtures.data());

      expect(r.budgetDepensesCents, isNull);
      expect(r.budgetTotalCents, isNull);
      expect(r.budgetParTypeCents, isEmpty);
      expect(r.heuresPrevuesMinutes, isNull);
      expect(r.heuresPrevuesTotalMinutes, isNull);
      expect(r.chargePrevueMinutes, isNull);
      expect(r.chargePrevueTotalMinutes, isNull);
      expect(r.effectifPrevu, isNull);
      expect(r.dureePrevueJours, isNull);
      expect(r.budgetDeriveParType, isFalse);
      expect(r.heuresDeriveesDesTaches, isFalse);
      expect(r.chargeDeriveeDesTaches, isFalse);
      expect(r.effectifDeriveDesTaches, isFalse);
      expect(r.dureeDeriveeDesDates, isFalse);
    });

    test('R10 : prévisionnel global complet sans tâche', () {
      final r = PrevisionnelCalculator.compute(
        Fixtures.data(previsionnel: Fixtures.previsionnelComplet()),
      );

      expect(r.budgetDepensesCents, 600000);
      expect(r.budgetTotalCents, 600000);
      expect(r.heuresPrevuesMinutes, 4800);
      expect(r.heuresPrevuesTotalMinutes, 4800);
      expect(r.effectifPrevu, 2);
      expect(r.dureePrevueJours, 5);
      // Charge = heures × effectif quand elle n'est pas saisie.
      expect(r.chargePrevueMinutes, 9600);
      expect(r.chargePrevueTotalMinutes, 9600);
      expect(r.budgetDeriveParType, isFalse);
      expect(r.heuresDeriveesDesTaches, isFalse);
      expect(r.chargeDeriveeDesTaches, isFalse);
      expect(r.effectifDeriveDesTaches, isFalse);
      expect(r.dureeDeriveeDesDates, isFalse);
    });

    test(
      'charge prévue globale saisie : prioritaire sur heures × effectif',
      () {
        final r = PrevisionnelCalculator.compute(
          Fixtures.data(
            previsionnel: Fixtures.previsionnel(
              heuresPrevuesMinutes: 4800,
              heuresPersonnesPrevuesMinutes: 7200,
              effectifPrevu: 2,
            ),
          ),
        );

        expect(r.chargePrevueMinutes, 7200);
        expect(r.chargeDeriveeDesTaches, isFalse);
      },
    );

    group('budget', () {
      test('global prioritaire sur la somme par type', () {
        final r = PrevisionnelCalculator.compute(
          Fixtures.data(
            previsionnel: Fixtures.previsionnel(
              budgetDepensesCents: 600000,
              budgetParTypeCents: {'materiaux': 300000, 'repas': 10000},
            ),
          ),
        );

        expect(r.budgetDepensesCents, 600000);
        expect(r.budgetDeriveParType, isFalse);
        expect(r.budgetParTypeCents, {
          TypeDepense.materiaux: 300000,
          TypeDepense.repas: 10000,
        });
      });

      test('sinon dérivé : Σ budgets par type', () {
        final r = PrevisionnelCalculator.compute(
          Fixtures.data(
            previsionnel: Fixtures.previsionnel(
              budgetParTypeCents: {
                'materiaux': 300000,
                'sousTraitance': 200000,
              },
            ),
          ),
        );

        expect(r.budgetDepensesCents, 500000);
        expect(r.budgetTotalCents, 500000);
        expect(r.budgetDeriveParType, isTrue);
        expect(r.budgetParTypeCents, {
          TypeDepense.materiaux: 300000,
          TypeDepense.sousTraitance: 200000,
        });
      });

      test('§6 : budgetPrevuTotal = budget + Σ TS[accepte].budget ; proposés '
          'et refusés ignorés', () {
        final r = PrevisionnelCalculator.compute(
          Fixtures.data(
            previsionnel: Fixtures.previsionnel(budgetDepensesCents: 600000),
            travauxSup: [
              Fixtures.travauxSup(
                id: 'ts-1',
                statut: StatutTravauxSup.accepte,
                budgetDepensesCents: 50000,
              ),
              Fixtures.travauxSup(
                id: 'ts-2',
                statut: StatutTravauxSup.accepte,
                budgetDepensesCents: 20000,
              ),
              Fixtures.travauxSup(
                id: 'ts-3',
                statut: StatutTravauxSup.propose,
                budgetDepensesCents: 70000,
              ),
              Fixtures.travauxSup(
                id: 'ts-4',
                statut: StatutTravauxSup.refuse,
                budgetDepensesCents: 80000,
              ),
              // Accepté sans budget : ne change rien.
              Fixtures.travauxSup(id: 'ts-5', statut: StatutTravauxSup.accepte),
            ],
          ),
        );

        expect(r.budgetDepensesCents, 600000);
        expect(r.budgetTotalCents, 670000);
      });

      test('sans budget de chantier, le total reste null même avec un TS '
          'accepté budgété', () {
        final r = PrevisionnelCalculator.compute(
          Fixtures.data(
            travauxSup: [
              Fixtures.travauxSup(id: 'ts-1', budgetDepensesCents: 50000),
            ],
          ),
        );

        expect(r.budgetDepensesCents, isNull);
        expect(r.budgetTotalCents, isNull);
      });

      test('R6 : TS accepté supprimé exclu du total', () {
        final r = PrevisionnelCalculator.compute(
          Fixtures.data(
            previsionnel: Fixtures.previsionnel(budgetDepensesCents: 600000),
            travauxSup: [
              Fixtures.travauxSup(
                id: 'ts-1',
                budgetDepensesCents: 50000,
                heuresPrevuesMinutes: 600,
                deletedAt: Fixtures.jour,
              ),
            ],
          ),
        );

        expect(r.budgetTotalCents, 600000);
      });
    });

    group('heures prévues', () {
      test('§6 : globales prioritaires sur Σ tâches', () {
        final r = PrevisionnelCalculator.compute(
          Fixtures.data(
            previsionnel: Fixtures.previsionnel(heuresPrevuesMinutes: 4800),
            taches: [Fixtures.tache(id: 't-1', heuresPrevuesMinutes: 600)],
          ),
        );

        expect(r.heuresPrevuesMinutes, 4800);
        expect(r.heuresDeriveesDesTaches, isFalse);
      });

      test('§6 : sinon Σ tachesPrincipales.heuresPrevuesMinutes', () {
        final r = PrevisionnelCalculator.compute(
          Fixtures.data(
            taches: [
              Fixtures.tache(id: 't-1', heuresPrevuesMinutes: 600),
              Fixtures.tache(id: 't-2', heuresPrevuesMinutes: 900),
              // Tâche sans heures : ignorée, mais ne bloque pas la dérivation.
              Fixtures.tache(id: 't-3'),
            ],
          ),
        );

        expect(r.heuresPrevuesMinutes, 1500);
        expect(r.heuresPrevuesTotalMinutes, 1500);
        expect(r.heuresDeriveesDesTaches, isTrue);
      });

      test('les tâches liées à un TS et les tâches supprimées ne sont pas '
          'des tâches principales', () {
        final r = PrevisionnelCalculator.compute(
          Fixtures.data(
            taches: [
              Fixtures.tache(id: 't-1', heuresPrevuesMinutes: 600),
              Fixtures.tache(
                id: 't-ts',
                heuresPrevuesMinutes: 300,
                travauxSupId: 'ts-1',
              ),
              Fixtures.tache(
                id: 't-del',
                heuresPrevuesMinutes: 5000,
                deletedAt: Fixtures.jour,
              ),
            ],
          ),
        );

        expect(r.heuresPrevuesMinutes, 600);
      });

      test('R5 : tâche de bibliothèque → durée = snapshot × quantité / '
          'effectif, charge = snapshot × quantité', () {
        // 30 min/m² × 20 m² = 600 personne-minutes ; à 2 → 300 min.
        final r = PrevisionnelCalculator.compute(
          Fixtures.data(
            taches: [
              Fixtures.tache(
                id: 't-1',
                quantitePrevue: 20,
                minutesParUniteSnapshot: 30,
                effectifDefautSnapshot: 2,
              ),
            ],
          ),
        );

        expect(r.heuresPrevuesMinutes, 300);
        expect(r.chargePrevueMinutes, 600);
        expect(r.effectifPrevu, 2);
        expect(r.heuresDeriveesDesTaches, isTrue);
        expect(r.chargeDeriveeDesTaches, isTrue);
        expect(r.effectifDeriveDesTaches, isTrue);
      });

      test('§6 : heuresPrevuesTot = heuresPrevues + Σ TS[accepte].heures', () {
        final r = PrevisionnelCalculator.compute(
          Fixtures.data(
            previsionnel: Fixtures.previsionnel(heuresPrevuesMinutes: 4800),
            travauxSup: [
              Fixtures.travauxSup(
                id: 'ts-1',
                statut: StatutTravauxSup.accepte,
                heuresPrevuesMinutes: 600,
              ),
              Fixtures.travauxSup(
                id: 'ts-2',
                statut: StatutTravauxSup.propose,
                heuresPrevuesMinutes: 1000,
              ),
              Fixtures.travauxSup(
                id: 'ts-3',
                statut: StatutTravauxSup.refuse,
                heuresPrevuesMinutes: 1000,
              ),
            ],
          ),
        );

        expect(r.heuresPrevuesMinutes, 4800);
        expect(r.heuresPrevuesTotalMinutes, 5400);
      });

      test('sans heures prévues, le total reste null malgré un TS accepté', () {
        final r = PrevisionnelCalculator.compute(
          Fixtures.data(
            travauxSup: [
              Fixtures.travauxSup(id: 'ts-1', heuresPrevuesMinutes: 600),
            ],
          ),
        );

        expect(r.heuresPrevuesMinutes, isNull);
        expect(r.heuresPrevuesTotalMinutes, isNull);
      });
    });

    group('effectif', () {
      test('global prioritaire', () {
        final r = PrevisionnelCalculator.compute(
          Fixtures.data(
            previsionnel: Fixtures.previsionnel(effectifPrevu: 3),
            taches: [Fixtures.tache(id: 't-1', effectifPrevu: 5)],
          ),
        );

        expect(r.effectifPrevu, 3);
        expect(r.effectifDeriveDesTaches, isFalse);
      });

      test('sinon max des tâches principales (saisi ou snapshot)', () {
        final r = PrevisionnelCalculator.compute(
          Fixtures.data(
            taches: [
              Fixtures.tache(id: 't-1', effectifPrevu: 2),
              Fixtures.tache(id: 't-2', effectifDefautSnapshot: 4),
              Fixtures.tache(id: 't-3'),
              Fixtures.tache(id: 't-ts', effectifPrevu: 9, travauxSupId: 'ts'),
            ],
          ),
        );

        expect(r.effectifPrevu, 4);
        expect(r.effectifDeriveDesTaches, isTrue);
      });
    });

    group('charge prévue', () {
      test('dérivée des tâches quand elles la fournissent', () {
        final r = PrevisionnelCalculator.compute(
          Fixtures.data(
            taches: [
              Fixtures.tache(
                id: 't-1',
                heuresPrevuesMinutes: 600,
                effectifPrevu: 2,
              ),
              Fixtures.tache(
                id: 't-2',
                heuresPrevuesMinutes: 300,
                effectifPrevu: 3,
              ),
            ],
          ),
        );

        // 600 × 2 + 300 × 3.
        expect(r.chargePrevueMinutes, 2100);
        expect(r.chargeDeriveeDesTaches, isTrue);
        expect(r.heuresPrevuesMinutes, 900);
        expect(r.effectifPrevu, 3);
      });

      test(
        'total = charge + Σ TS[accepte] heures × effectif (1 par défaut)',
        () {
          final r = PrevisionnelCalculator.compute(
            Fixtures.data(
              previsionnel: Fixtures.previsionnel(
                heuresPersonnesPrevuesMinutes: 9600,
              ),
              travauxSup: [
                Fixtures.travauxSup(
                  id: 'ts-1',
                  heuresPrevuesMinutes: 600,
                  effectifPrevu: 2,
                ),
                Fixtures.travauxSup(id: 'ts-2', heuresPrevuesMinutes: 100),
              ],
            ),
          );

          expect(r.chargePrevueMinutes, 9600);
          expect(r.chargePrevueTotalMinutes, 9600 + 1200 + 100);
        },
      );

      test('heures globales sans effectif : charge non calculable', () {
        final r = PrevisionnelCalculator.compute(
          Fixtures.data(
            previsionnel: Fixtures.previsionnel(heuresPrevuesMinutes: 4800),
          ),
        );

        expect(r.chargePrevueMinutes, isNull);
        expect(r.chargePrevueTotalMinutes, isNull);
      });
    });

    group('durée prévue', () {
      test('globale prioritaire sur les dates', () {
        final r = PrevisionnelCalculator.compute(
          Fixtures.data(
            chantier: Fixtures.chantier(
              dateDebutPrevue: DateTime.utc(2026, 3, 2),
              dateFinPrevue: DateTime.utc(2026, 3, 13),
            ),
            previsionnel: Fixtures.previsionnel(dureePrevueJours: 5),
          ),
        );

        expect(r.dureePrevueJours, 5);
        expect(r.dureeDeriveeDesDates, isFalse);
      });

      test('sinon jours ouvrés entre les dates prévues (lun. 2 → ven. 13 mars '
          '2026 = 10 jours)', () {
        final r = PrevisionnelCalculator.compute(
          Fixtures.data(
            chantier: Fixtures.chantier(
              dateDebutPrevue: DateTime.utc(2026, 3, 2),
              dateFinPrevue: DateTime.utc(2026, 3, 13),
            ),
          ),
        );

        expect(r.dureePrevueJours, 10);
        expect(r.dureeDeriveeDesDates, isTrue);
      });

      test('une seule date : non dérivable', () {
        final r = PrevisionnelCalculator.compute(
          Fixtures.data(
            chantier: Fixtures.chantier(
              dateDebutPrevue: DateTime.utc(2026, 3, 2),
            ),
          ),
        );

        expect(r.dureePrevueJours, isNull);
        expect(r.dureeDeriveeDesDates, isFalse);
      });
    });
  });
}
