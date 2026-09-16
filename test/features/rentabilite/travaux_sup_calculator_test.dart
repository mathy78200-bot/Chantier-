/// §5 : réel d'un travaux sup = Σ depenses[travauxSupId] et
///      Σ heures[travauxSupId] (comptés une seule fois dans le chantier).
/// R3 : accepté → prix vendu ; proposé → potentiel ; refusé → historique.
///      Tous sont analysés ici, mais seul l'accepté entre dans la
///      rentabilité du chantier.
library;

import 'package:chantiers/core/constants/enums.dart';
import 'package:chantiers/features/rentabilite/domain/chantier_data.dart';
import 'package:chantiers/features/rentabilite/domain/depenses_calculator.dart';
import 'package:chantiers/features/rentabilite/domain/heures_calculator.dart';
import 'package:chantiers/features/rentabilite/domain/rentabilite_calculator.dart';
import 'package:chantiers/features/rentabilite/domain/resultats.dart';
import 'package:chantiers/features/rentabilite/domain/travaux_sup_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/fixtures.dart';

List<TravauxSupAnalyse> _analyses(ChantierData data) =>
    TravauxSupCalculator.compute(
      data,
      DepensesCalculator.compute(data),
      HeuresCalculator.compute(data),
    );

void main() {
  group('TravauxSupCalculator.compute', () {
    test('R3 : accepté, proposé et refusé sont tous analysés', () {
      final r = _analyses(
        Fixtures.data(
          travauxSup: [
            Fixtures.travauxSup(
              id: 'ts-acc',
              libelle: 'A',
              statut: StatutTravauxSup.accepte,
            ),
            Fixtures.travauxSup(
              id: 'ts-prop',
              libelle: 'B',
              statut: StatutTravauxSup.propose,
            ),
            Fixtures.travauxSup(
              id: 'ts-ref',
              libelle: 'C',
              statut: StatutTravauxSup.refuse,
            ),
          ],
        ),
      );

      expect(r.map((a) => a.id), ['ts-acc', 'ts-prop', 'ts-ref']);
      expect(r.map((a) => a.statut), [
        StatutTravauxSup.accepte,
        StatutTravauxSup.propose,
        StatutTravauxSup.refuse,
      ]);
    });

    test('§5 : dépenses / heures d\'un TS = Σ des éléments portant son id', () {
      final r = _analyses(
        Fixtures.data(
          travauxSup: [
            Fixtures.travauxSup(id: 'ts-1', libelle: 'Un'),
            Fixtures.travauxSup(id: 'ts-2', libelle: 'Deux'),
          ],
          depenses: [
            Fixtures.depense(
              id: 'd1',
              montantCents: 30000,
              travauxSupId: 'ts-1',
            ),
            Fixtures.depense(
              id: 'd2',
              montantCents: 50000,
              travauxSupId: 'ts-1',
            ),
            Fixtures.depense(
              id: 'd3',
              montantCents: 20000,
              travauxSupId: 'ts-2',
            ),
            Fixtures.depense(id: 'd4', montantCents: 10000),
          ],
          heures: [
            Fixtures.heures(
              id: 'h1',
              nbPersonnes: 2,
              minutesParPersonne: 240,
              travauxSupId: 'ts-1',
            ),
            Fixtures.heures(
              id: 'h2',
              nbPersonnes: 1,
              minutesParPersonne: 60,
              travauxSupId: 'ts-1',
            ),
            Fixtures.heures(id: 'h3', nbPersonnes: 3, minutesParPersonne: 480),
          ],
        ),
      );

      final un = r.singleWhere((a) => a.id == 'ts-1');
      final deux = r.singleWhere((a) => a.id == 'ts-2');
      expect(un.depensesCents, 80000);
      expect(un.dureeMinutes, 300);
      expect(un.chargeMinutes, 540);
      expect(deux.depensesCents, 20000);
      expect(deux.dureeMinutes, 0);
      expect(deux.chargeMinutes, 0);
    });

    test('rentabilité TS = prix − dépenses ; marge = rentab / prix (2 000 € − '
        '800 € → 1 200 €, 60,0 %)', () {
      final r = _analyses(
        Fixtures.data(
          travauxSup: [Fixtures.travauxSup(id: 'ts-1', prixVenduCents: 200000)],
          depenses: [
            Fixtures.depense(montantCents: 80000, travauxSupId: 'ts-1'),
          ],
        ),
      );

      expect(r.single.rentabiliteCents, 120000);
      expect(r.single.margePct, 60.0);
    });

    test('R9 : marge arrondie half-up (24 900 / 200 000 = 12,45 → 12,5)', () {
      final r = _analyses(
        Fixtures.data(
          travauxSup: [Fixtures.travauxSup(id: 'ts-1', prixVenduCents: 200000)],
          depenses: [
            Fixtures.depense(montantCents: 175100, travauxSupId: 'ts-1'),
          ],
        ),
      );

      expect(r.single.rentabiliteCents, 24900);
      expect(r.single.margePct, 12.5);
    });

    test('rentabilité TS négative ; marge null si prix 0', () {
      final r = _analyses(
        Fixtures.data(
          travauxSup: [
            Fixtures.travauxSup(
              id: 'ts-1',
              libelle: 'A',
              prixVenduCents: 10000,
            ),
            Fixtures.travauxSup(id: 'ts-2', libelle: 'B', prixVenduCents: 0),
          ],
          depenses: [
            Fixtures.depense(
              id: 'd1',
              montantCents: 15000,
              travauxSupId: 'ts-1',
            ),
            Fixtures.depense(
              id: 'd2',
              montantCents: 5000,
              travauxSupId: 'ts-2',
            ),
          ],
        ),
      );

      expect(r[0].rentabiliteCents, -5000);
      expect(r[0].margePct, -50.0);
      expect(r[1].rentabiliteCents, -5000);
      expect(r[1].margePct, isNull);
    });

    test('écarts vs budget et heures prévues du TS (800 € sur 1 000 € → '
        '−200 €, −20,0 % ; 5 h sur 10 h → −300 min, −50,0 %)', () {
      final r = _analyses(
        Fixtures.data(
          travauxSup: [
            Fixtures.travauxSup(
              id: 'ts-1',
              prixVenduCents: 200000,
              budgetDepensesCents: 100000,
              heuresPrevuesMinutes: 600,
            ),
          ],
          depenses: [
            Fixtures.depense(montantCents: 80000, travauxSupId: 'ts-1'),
          ],
          heures: [
            Fixtures.heures(
              nbPersonnes: 2,
              minutesParPersonne: 300,
              travauxSupId: 'ts-1',
            ),
          ],
        ),
      );

      final a = r.single;
      expect(a.ecartDepensesCents, -20000);
      expect(a.ecartDepensesPct, -20.0);
      // L'écart heures compare la durée (pas la charge) aux heures prévues.
      expect(a.ecartHeuresMinutes, -300);
      expect(a.ecartHeuresPct, -50.0);
    });

    test('dépassement : écarts positifs (1 100 € sur 1 000 € → +10,0 %)', () {
      final r = _analyses(
        Fixtures.data(
          travauxSup: [
            Fixtures.travauxSup(
              id: 'ts-1',
              budgetDepensesCents: 100000,
              heuresPrevuesMinutes: 600,
            ),
          ],
          depenses: [
            Fixtures.depense(montantCents: 110000, travauxSupId: 'ts-1'),
          ],
          heures: [
            Fixtures.heures(minutesParPersonne: 690, travauxSupId: 'ts-1'),
          ],
        ),
      );

      expect(r.single.ecartDepensesCents, 10000);
      expect(r.single.ecartDepensesPct, 10.0);
      expect(r.single.ecartHeuresMinutes, 90);
      expect(r.single.ecartHeuresPct, 15.0);
    });

    test('écarts null si le TS n\'a ni budget ni heures prévues', () {
      final r = _analyses(
        Fixtures.data(
          travauxSup: [Fixtures.travauxSup(id: 'ts-1')],
          depenses: [
            Fixtures.depense(montantCents: 80000, travauxSupId: 'ts-1'),
          ],
          heures: [
            Fixtures.heures(minutesParPersonne: 300, travauxSupId: 'ts-1'),
          ],
        ),
      );

      final a = r.single;
      expect(a.depensesCents, 80000);
      expect(a.dureeMinutes, 300);
      expect(a.ecartDepensesCents, isNull);
      expect(a.ecartDepensesPct, isNull);
      expect(a.ecartHeuresMinutes, isNull);
      expect(a.ecartHeuresPct, isNull);
    });

    test('budget TS saisi à 0 : écart absolu calculé, pourcentage null', () {
      final r = _analyses(
        Fixtures.data(
          travauxSup: [Fixtures.travauxSup(id: 'ts-1', budgetDepensesCents: 0)],
          depenses: [
            Fixtures.depense(montantCents: 5000, travauxSupId: 'ts-1'),
          ],
        ),
      );

      expect(r.single.ecartDepensesCents, 5000);
      expect(r.single.ecartDepensesPct, isNull);
    });

    test('R3 : un TS refusé avec dépenses — ses dépenses comptent dans le '
        'chantier, pas son prix', () {
      final data = Fixtures.data(
        travauxSup: [
          Fixtures.travauxSup(
            id: 'ts-ref',
            statut: StatutTravauxSup.refuse,
            prixVenduCents: 80000,
          ),
        ],
        depenses: [
          Fixtures.depense(id: 'd1', montantCents: 100000),
          Fixtures.depense(
            id: 'd2',
            montantCents: 20000,
            travauxSupId: 'ts-ref',
          ),
        ],
      );
      final analyses = _analyses(data);
      final depenses = DepensesCalculator.compute(data);
      final rentabilite = RentabiliteCalculator.compute(data);

      expect(analyses.single.depensesCents, 20000);
      expect(analyses.single.rentabiliteCents, 60000);
      expect(depenses.totalCents, 120000);
      expect(depenses.parTravauxSupCents, {'ts-ref': 20000});
      expect(rentabilite.prixVenduCents, 1000000);
      expect(rentabilite.potentielTravauxSupCents, 0);
      expect(rentabilite.rentabiliteCents, 880000);
    });

    test('tri : date de proposition, puis libellé (insensible à la casse), '
        'puis id', () {
      final r = _analyses(
        Fixtures.data(
          travauxSup: [
            Fixtures.travauxSup(
              id: 'ts-c',
              libelle: 'Terrasse',
            ).copyWith(dateProposition: DateTime.utc(2026, 3, 10)),
            Fixtures.travauxSup(
              id: 'ts-b',
              libelle: 'cloison',
            ).copyWith(dateProposition: DateTime.utc(2026, 3, 10)),
            Fixtures.travauxSup(
              id: 'ts-a',
              libelle: 'Cloison',
            ).copyWith(dateProposition: DateTime.utc(2026, 3, 10)),
            Fixtures.travauxSup(
              id: 'ts-d',
              libelle: 'Zinguerie',
            ).copyWith(dateProposition: DateTime.utc(2026, 3, 1)),
          ],
        ),
      );

      expect(r.map((a) => a.id), ['ts-d', 'ts-a', 'ts-b', 'ts-c']);
    });

    test('sans TS : liste vide même avec des dépenses orphelines', () {
      final r = _analyses(
        Fixtures.data(
          depenses: [
            Fixtures.depense(montantCents: 5000, travauxSupId: 'ts-inconnu'),
          ],
        ),
      );

      expect(r, isEmpty);
    });

    test(
      'R6 : TS supprimé absent ; dépense supprimée d\'un TS non comptée',
      () {
        final r = _analyses(
          Fixtures.data(
            travauxSup: [
              Fixtures.travauxSup(id: 'ts-1', libelle: 'A'),
              Fixtures.travauxSup(
                id: 'ts-del',
                libelle: 'B',
                deletedAt: Fixtures.jour,
              ),
            ],
            depenses: [
              Fixtures.depense(
                id: 'd1',
                montantCents: 10000,
                travauxSupId: 'ts-1',
              ),
              Fixtures.depense(
                id: 'd2',
                montantCents: 90000,
                travauxSupId: 'ts-1',
                deletedAt: Fixtures.jour,
              ),
            ],
          ),
        );

        expect(r.map((a) => a.id), ['ts-1']);
        expect(r.single.depensesCents, 10000);
      },
    );
  });
}
