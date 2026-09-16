/// R10 : le prévisionnel est complet sans tâche si prix vendu > 0, budget,
///       heures prévues et effectif sont renseignés (globaux ou dérivés).
/// §6 : recommandé = durée ; % = (nbOb × 2 + nbRec) / 9 × 100.
library;

import 'package:chantiers/core/constants/enums.dart';
import 'package:chantiers/features/rentabilite/domain/chantier_data.dart';
import 'package:chantiers/features/rentabilite/domain/completude_calculator.dart';
import 'package:chantiers/features/rentabilite/domain/previsionnel_calculator.dart';
import 'package:chantiers/features/rentabilite/domain/rentabilite_calculator.dart';
import 'package:chantiers/features/rentabilite/domain/resultats.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/fixtures.dart';

CompletudeResult _completude(ChantierData data) => CompletudeCalculator.compute(
  data: data,
  previsionnel: PrevisionnelCalculator.compute(data),
  rentabilite: RentabiliteCalculator.compute(data),
);

void main() {
  group('CompletudeCalculator.compute — R10', () {
    test('complet sans tâche : prix vendu > 0, budget, heures, effectif '
        '(durée absente → 89 %)', () {
      final r = _completude(
        Fixtures.data(
          previsionnel: Fixtures.previsionnel(
            budgetDepensesCents: 600000,
            heuresPrevuesMinutes: 4800,
            effectifPrevu: 2,
          ),
        ),
      );

      expect(r.estComplet, isTrue);
      expect(r.manquants, [ChampPrevisionnel.duree]);
      expect(r.manquantsObligatoires, isEmpty);
      expect(r.manquantsRecommandes, [ChampPrevisionnel.duree]);
      // (4 × 2 + 0) / 9 = 88,9 → 89.
      expect(r.pct, 89);
    });

    test('100 % : quatre obligatoires + durée', () {
      final r = _completude(
        Fixtures.data(previsionnel: Fixtures.previsionnelComplet()),
      );

      expect(r.pct, 100);
      expect(r.manquants, isEmpty);
      expect(r.estComplet, isTrue);
    });

    test('incomplet si prix vendu = 0, même avec un prévisionnel complet', () {
      final r = _completude(
        Fixtures.data(
          chantier: Fixtures.chantier(prixVenduInitialCents: 0),
          previsionnel: Fixtures.previsionnelComplet(),
        ),
      );

      expect(r.estComplet, isFalse);
      expect(r.manquants, [ChampPrevisionnel.prixVendu]);
      expect(r.manquantsObligatoires, [ChampPrevisionnel.prixVendu]);
      // (3 × 2 + 1) / 9 = 77,8 → 78.
      expect(r.pct, 78);
    });

    test('0 % : rien de renseigné, tous les champs manquent dans l\'ordre de '
        'ChampPrevisionnel.values', () {
      final r = _completude(
        Fixtures.data(chantier: Fixtures.chantier(prixVenduInitialCents: 0)),
      );

      expect(r.pct, 0);
      expect(r.estComplet, isFalse);
      expect(r.manquants, ChampPrevisionnel.values);
    });

    test('44 % : deux obligatoires (prix vendu, budget)', () {
      final r = _completude(
        Fixtures.data(
          previsionnel: Fixtures.previsionnel(budgetDepensesCents: 600000),
        ),
      );

      // (2 × 2) / 9 = 44,4 → 44.
      expect(r.pct, 44);
      expect(r.estComplet, isFalse);
      expect(r.manquants, [
        ChampPrevisionnel.heuresPrevues,
        ChampPrevisionnel.effectif,
        ChampPrevisionnel.duree,
      ]);
    });

    test('22 % : prix vendu seul ; 11 % : durée seule', () {
      final prixSeul = _completude(Fixtures.data());
      final dureeSeule = _completude(
        Fixtures.data(
          chantier: Fixtures.chantier(prixVenduInitialCents: 0),
          previsionnel: Fixtures.previsionnel(dureePrevueJours: 5),
        ),
      );

      // 2 / 9 = 22,2 → 22 ; 1 / 9 = 11,1 → 11.
      expect(prixSeul.pct, 22);
      expect(dureeSeule.pct, 11);
      expect(dureeSeule.manquants, [
        ChampPrevisionnel.prixVendu,
        ChampPrevisionnel.budget,
        ChampPrevisionnel.heuresPrevues,
        ChampPrevisionnel.effectif,
      ]);
    });

    test('67 % : trois obligatoires ; manquants dans l\'ordre de l\'enum '
        'quel que soit l\'ordre de saisie', () {
      final r = _completude(
        Fixtures.data(
          previsionnel: Fixtures.previsionnel(
            effectifPrevu: 3,
            heuresPrevuesMinutes: 4800,
          ),
        ),
      );

      // (3 × 2) / 9 = 66,7 → 67.
      expect(r.pct, 67);
      expect(r.manquants, [ChampPrevisionnel.budget, ChampPrevisionnel.duree]);
    });
  });

  group('CompletudeCalculator.compute — valeurs dérivées', () {
    test('R10 : heures et effectif dérivés des tâches comptent comme '
        'renseignés', () {
      final r = _completude(
        Fixtures.data(
          previsionnel: Fixtures.previsionnel(budgetDepensesCents: 600000),
          taches: [
            Fixtures.tache(
              id: 't-1',
              heuresPrevuesMinutes: 600,
              effectifPrevu: 2,
            ),
          ],
        ),
      );

      expect(r.estComplet, isTrue);
      expect(r.manquants, [ChampPrevisionnel.duree]);
      expect(r.pct, 89);
    });

    test('R5 : heures et effectif dérivés d\'une tâche de bibliothèque '
        '(snapshots) comptent aussi', () {
      final r = _completude(
        Fixtures.data(
          previsionnel: Fixtures.previsionnel(budgetDepensesCents: 600000),
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

      expect(r.estComplet, isTrue);
      expect(r.manquants, [ChampPrevisionnel.duree]);
    });

    test('une tâche liée à un TS ne dérive rien pour le chantier', () {
      final r = _completude(
        Fixtures.data(
          previsionnel: Fixtures.previsionnel(budgetDepensesCents: 600000),
          taches: [
            Fixtures.tache(
              id: 't-ts',
              heuresPrevuesMinutes: 600,
              effectifPrevu: 2,
              travauxSupId: 'ts-1',
            ),
          ],
        ),
      );

      expect(r.estComplet, isFalse);
      expect(r.manquants, [
        ChampPrevisionnel.heuresPrevues,
        ChampPrevisionnel.effectif,
        ChampPrevisionnel.duree,
      ]);
    });

    test('budget dérivé des budgets par type compte comme renseigné', () {
      final r = _completude(
        Fixtures.data(
          previsionnel: Fixtures.previsionnel(
            budgetParTypeCents: {'materiaux': 300000},
            heuresPrevuesMinutes: 4800,
            effectifPrevu: 2,
          ),
        ),
      );

      expect(r.estComplet, isTrue);
      expect(r.manquants, [ChampPrevisionnel.duree]);
    });

    test('durée dérivée des dates prévues compte comme renseignée (100 %)', () {
      final r = _completude(
        Fixtures.data(
          chantier: Fixtures.chantier(
            dateDebutPrevue: DateTime.utc(2026, 3, 2),
            dateFinPrevue: DateTime.utc(2026, 3, 6),
          ),
          previsionnel: Fixtures.previsionnel(
            budgetDepensesCents: 600000,
            heuresPrevuesMinutes: 4800,
            effectifPrevu: 2,
          ),
        ),
      );

      expect(r.pct, 100);
      expect(r.manquants, isEmpty);
    });

    test('R3 : le prix vendu compte un TS accepté (prix initial 0 + TS '
        'accepté → renseigné), pas un TS proposé', () {
      final avecAccepte = _completude(
        Fixtures.data(
          chantier: Fixtures.chantier(prixVenduInitialCents: 0),
          previsionnel: Fixtures.previsionnelComplet(),
          travauxSup: [
            Fixtures.travauxSup(
              statut: StatutTravauxSup.accepte,
              prixVenduCents: 200000,
            ),
          ],
        ),
      );
      final avecPropose = _completude(
        Fixtures.data(
          chantier: Fixtures.chantier(prixVenduInitialCents: 0),
          previsionnel: Fixtures.previsionnelComplet(),
          travauxSup: [
            Fixtures.travauxSup(
              statut: StatutTravauxSup.propose,
              prixVenduCents: 200000,
            ),
          ],
        ),
      );

      expect(avecAccepte.estComplet, isTrue);
      expect(avecAccepte.pct, 100);
      expect(avecPropose.estComplet, isFalse);
      expect(avecPropose.manquants, [ChampPrevisionnel.prixVendu]);
    });

    test(
      'un budget saisi à 0 est renseigné (chantier sans dépense prévue)',
      () {
        final r = _completude(
          Fixtures.data(
            previsionnel: Fixtures.previsionnel(
              budgetDepensesCents: 0,
              heuresPrevuesMinutes: 4800,
              effectifPrevu: 2,
              dureePrevueJours: 5,
            ),
          ),
        );

        expect(r.estComplet, isTrue);
        expect(r.pct, 100);
      },
    );

    test('R6 : une tâche supprimée ne dérive rien', () {
      final r = _completude(
        Fixtures.data(
          previsionnel: Fixtures.previsionnel(budgetDepensesCents: 600000),
          taches: [
            Fixtures.tache(
              id: 't-del',
              heuresPrevuesMinutes: 600,
              effectifPrevu: 2,
              deletedAt: Fixtures.jour,
            ),
          ],
        ),
      );

      expect(r.estComplet, isFalse);
      expect(r.pct, 44);
    });
  });
}
