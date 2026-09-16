/// §6 : prixVendu = prixVenduInitial + Σ TS[accepte].prixVendu ;
///      potentielTS = Σ TS[propose].prixVendu (à part) ;
///      rentabilite = prixVendu − depenses ;
///      marge% = prixVendu > 0 ? rentabilite / prixVendu × 100 : null.
/// R1 : les heures ne sont jamais converties en coût.
/// R3 : jamais de proposé / refusé dans le CA ni la rentabilité.
library;

import 'package:chantiers/core/constants/enums.dart';
import 'package:chantiers/features/rentabilite/domain/rentabilite_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/fixtures.dart';

void main() {
  group('RentabiliteCalculator.compute', () {
    test('sans dépense ni TS : rentabilité = prix vendu, marge 100 %', () {
      final r = RentabiliteCalculator.compute(Fixtures.data());

      expect(r.prixVenduInitialCents, 1000000);
      expect(r.travauxSupAcceptesCents, 0);
      expect(r.prixVenduCents, 1000000);
      expect(r.potentielTravauxSupCents, 0);
      expect(r.depensesCents, 0);
      expect(r.rentabiliteCents, 1000000);
      expect(r.margePct, 100.0);
      expect(r.estNegative, isFalse);
    });

    test('§6 : rentabilité = prix vendu − Σ dépenses (tous types)', () {
      final r = RentabiliteCalculator.compute(
        Fixtures.data(
          depenses: [
            Fixtures.depense(id: 'd1', montantCents: 10000),
            Fixtures.depense(
              id: 'd2',
              type: TypeDepense.sousTraitance,
              montantCents: 25000,
            ),
          ],
        ),
      );

      expect(r.depensesCents, 35000);
      expect(r.rentabiliteCents, 965000);
      expect(r.margePct, 96.5);
    });

    test('R1 : 1 000 h saisies (3 personnes) ne changent pas la rentabilité',
        () {
      final sansHeures = RentabiliteCalculator.compute(
        Fixtures.data(
          depenses: [Fixtures.depense(montantCents: 35000)],
        ),
      );
      final avecHeures = RentabiliteCalculator.compute(
        Fixtures.data(
          depenses: [Fixtures.depense(montantCents: 35000)],
          heures: [
            for (var i = 0; i < 50; i++)
              Fixtures.heures(
                id: 'h$i',
                nbPersonnes: 3,
                minutesParPersonne: 1200,
              ),
          ],
        ),
      );

      expect(avecHeures.rentabiliteCents, sansHeures.rentabiliteCents);
      expect(avecHeures.rentabiliteCents, 965000);
      expect(avecHeures.margePct, sansHeures.margePct);
      expect(avecHeures.depensesCents, 35000);
    });

    test('R3 : un TS accepté entre dans le prix vendu', () {
      final r = RentabiliteCalculator.compute(
        Fixtures.data(
          travauxSup: [
            Fixtures.travauxSup(
              id: 'ts-1',
              statut: StatutTravauxSup.accepte,
              prixVenduCents: 200000,
            ),
            Fixtures.travauxSup(
              id: 'ts-2',
              statut: StatutTravauxSup.accepte,
              prixVenduCents: 50000,
            ),
          ],
        ),
      );

      expect(r.travauxSupAcceptesCents, 250000);
      expect(r.prixVenduCents, 1250000);
      expect(r.rentabiliteCents, 1250000);
      expect(r.potentielTravauxSupCents, 0);
    });

    test('R3 : un TS proposé n\'entre pas dans le prix vendu, il forme le '
        'potentiel affiché à part', () {
      final r = RentabiliteCalculator.compute(
        Fixtures.data(
          travauxSup: [
            Fixtures.travauxSup(
              id: 'ts-1',
              statut: StatutTravauxSup.propose,
              prixVenduCents: 150000,
            ),
          ],
        ),
      );

      expect(r.prixVenduCents, 1000000);
      expect(r.travauxSupAcceptesCents, 0);
      expect(r.potentielTravauxSupCents, 150000);
      expect(r.rentabiliteCents, 1000000);
      expect(r.margePct, 100.0);
    });

    test('R3 : un TS refusé n\'apparaît ni dans le prix vendu ni dans le '
        'potentiel', () {
      final r = RentabiliteCalculator.compute(
        Fixtures.data(
          travauxSup: [
            Fixtures.travauxSup(
              id: 'ts-1',
              statut: StatutTravauxSup.refuse,
              prixVenduCents: 99999,
            ),
          ],
        ),
      );

      expect(r.prixVenduCents, 1000000);
      expect(r.potentielTravauxSupCents, 0);
      expect(r.rentabiliteCents, 1000000);
    });

    test('R3 : les trois statuts ensemble', () {
      final r = RentabiliteCalculator.compute(
        Fixtures.data(
          travauxSup: [
            Fixtures.travauxSup(
              id: 'ts-1',
              statut: StatutTravauxSup.accepte,
              prixVenduCents: 200000,
            ),
            Fixtures.travauxSup(
              id: 'ts-2',
              statut: StatutTravauxSup.propose,
              prixVenduCents: 150000,
            ),
            Fixtures.travauxSup(
              id: 'ts-3',
              statut: StatutTravauxSup.refuse,
              prixVenduCents: 80000,
            ),
          ],
          depenses: [Fixtures.depense(montantCents: 300000)],
        ),
      );

      expect(r.prixVenduCents, 1200000);
      expect(r.potentielTravauxSupCents, 150000);
      expect(r.depensesCents, 300000);
      expect(r.rentabiliteCents, 900000);
      expect(r.margePct, 75.0);
    });

    test('§5 : les dépenses d\'un TS sont comptées une seule fois dans les '
        'dépenses du chantier', () {
      final r = RentabiliteCalculator.compute(
        Fixtures.data(
          travauxSup: [
            Fixtures.travauxSup(id: 'ts-1', prixVenduCents: 200000),
          ],
          depenses: [
            Fixtures.depense(id: 'd1', montantCents: 10000),
            Fixtures.depense(
              id: 'd2',
              montantCents: 30000,
              travauxSupId: 'ts-1',
            ),
          ],
        ),
      );

      expect(r.depensesCents, 40000);
      expect(r.rentabiliteCents, 1200000 - 40000);
    });

    test('R9 : marge arrondie à 1 décimale, half-up', () {
      // 200 000 − 175 100 = 24 900 → 12,45 % → 12,5 (bankers donnerait 12,4).
      final r = RentabiliteCalculator.compute(
        Fixtures.data(
          chantier: Fixtures.chantier(prixVenduInitialCents: 200000),
          depenses: [Fixtures.depense(montantCents: 175100)],
        ),
      );

      expect(r.rentabiliteCents, 24900);
      expect(r.margePct, 12.5);
    });

    test('R9 : marge 2/3 → 66,7', () {
      final r = RentabiliteCalculator.compute(
        Fixtures.data(
          chantier: Fixtures.chantier(prixVenduInitialCents: 300000),
          depenses: [Fixtures.depense(montantCents: 100000)],
        ),
      );

      expect(r.margePct, 66.7);
    });

    test('rentabilité négative : marge négative, estNegative', () {
      final r = RentabiliteCalculator.compute(
        Fixtures.data(
          chantier: Fixtures.chantier(prixVenduInitialCents: 100000),
          depenses: [Fixtures.depense(montantCents: 150000)],
        ),
      );

      expect(r.rentabiliteCents, -50000);
      expect(r.margePct, -50.0);
      expect(r.estNegative, isTrue);
    });

    test('division par zéro : prix vendu 0 → marge null', () {
      final r = RentabiliteCalculator.compute(
        Fixtures.data(
          chantier: Fixtures.chantier(prixVenduInitialCents: 0),
          depenses: [Fixtures.depense(montantCents: 5000)],
        ),
      );

      expect(r.prixVenduCents, 0);
      expect(r.rentabiliteCents, -5000);
      expect(r.margePct, isNull);
      expect(r.estNegative, isTrue);
    });

    test('R6 : TS accepté supprimé et dépense supprimée exclus', () {
      final r = RentabiliteCalculator.compute(
        Fixtures.data(
          travauxSup: [
            Fixtures.travauxSup(
              id: 'ts-1',
              prixVenduCents: 200000,
              deletedAt: Fixtures.jour,
            ),
          ],
          depenses: [
            Fixtures.depense(montantCents: 500000, deletedAt: Fixtures.jour),
          ],
        ),
      );

      expect(r.prixVenduCents, 1000000);
      expect(r.depensesCents, 0);
      expect(r.rentabiliteCents, 1000000);
    });

    test('le statut du chantier n\'intervient pas (un « à faire signer » a '
        'une rentabilité calculable ; R11 s\'applique aux agrégats)', () {
      final r = RentabiliteCalculator.compute(
        Fixtures.data(
          chantier: Fixtures.chantier(statut: StatutChantier.aFaireSigner),
          depenses: [Fixtures.depense(montantCents: 1000)],
        ),
      );

      expect(r.rentabiliteCents, 999000);
    });
  });

  group('RentabiliteCalculator.margePct', () {
    test('R9 : 1 décimale half-up ; null si prix ≤ 0', () {
      expect(RentabiliteCalculator.margePct(24900, 200000), 12.5);
      expect(RentabiliteCalculator.margePct(200000, 300000), 66.7);
      expect(RentabiliteCalculator.margePct(-50000, 100000), -50.0);
      expect(RentabiliteCalculator.margePct(0, 100000), 0.0);
      expect(RentabiliteCalculator.margePct(100, 0), isNull);
      expect(RentabiliteCalculator.margePct(100, -1), isNull);
    });
  });
}
