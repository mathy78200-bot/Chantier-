/// §6 : estimation tâche : reel = heuresPersonnes(tâche) / quantitePrevue
///      (min/unité pour 1 personne) ;
///      ecart% = (reel − minutesParUniteSnapshot) / snapshot × 100 (1 décimale).
/// R5 : la bibliothèque ne modifie jamais le passé — seul le snapshot copié
///      dans l'instance de tâche est utilisé.
library;

import 'package:chantiers/core/constants/enums.dart';
import 'package:chantiers/features/bibliotheque/domain/bibliotheque_tache.dart';
import 'package:chantiers/features/rentabilite/domain/chantier_data.dart';
import 'package:chantiers/features/rentabilite/domain/estimation_calculator.dart';
import 'package:chantiers/features/rentabilite/domain/heures_calculator.dart';
import 'package:chantiers/features/rentabilite/domain/resultats.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/fixtures.dart';

List<EstimationTache> _estimations(ChantierData data) =>
    EstimationCalculator.compute(data, HeuresCalculator.compute(data));

void main() {
  group('EstimationCalculator.compute — formules', () {
    test('§6 : reel = charge / quantité ; 600 pers.-min sur 20 m² = 30,0 '
        'min/m² = snapshot → écart 0,0 %', () {
      final r = _estimations(
        Fixtures.data(
          taches: [
            Fixtures.tache(
              id: 't-1',
              quantitePrevue: 20,
              minutesParUniteSnapshot: 30,
            ),
          ],
          heures: [
            Fixtures.heures(
              nbPersonnes: 2,
              minutesParPersonne: 300,
              tacheId: 't-1',
            ),
          ],
        ),
      );

      expect(r, hasLength(1));
      final e = r.single;
      expect(e.tacheId, 't-1');
      expect(e.libelle, 'Pose carrelage');
      expect(e.unite, Unite.m2);
      expect(e.quantitePrevue, 20);
      expect(e.chargeReelleMinutes, 600);
      expect(e.minutesParUniteSnapshot, 30);
      expect(e.minutesParUniteReel, 30.0);
      expect(e.ecartPct, 0.0);
      expect(e.valeurConstateeDisponible, isFalse);
    });

    test('§6 : heures de plusieurs saisies cumulées avec nbPersonnes '
        '(2 × 300 + 1 × 90 = 690 → 34,5 min/m² → +15,0 %)', () {
      final r = _estimations(
        Fixtures.data(
          taches: [
            Fixtures.tache(
              id: 't-1',
              quantitePrevue: 20,
              minutesParUniteSnapshot: 30,
            ),
          ],
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
              minutesParPersonne: 90,
              tacheId: 't-1',
            ),
            // Autre tâche et saisie sans tâche : non comptées pour t-1.
            Fixtures.heures(
              id: 'h3',
              nbPersonnes: 3,
              minutesParPersonne: 480,
              tacheId: 't-autre',
            ),
            Fixtures.heures(id: 'h4', nbPersonnes: 3, minutesParPersonne: 480),
          ],
        ),
      );

      final e = r.single;
      expect(e.chargeReelleMinutes, 690);
      expect(e.minutesParUniteReel, 34.5);
      // (34,5 − 30) / 30 × 100 = 15,0.
      expect(e.ecartPct, 15.0);
      expect(e.valeurConstateeDisponible, isTrue);
    });

    test('réel inférieur à l\'estimation : écart négatif (24 min/m² sur '
        '30 → −20,0 %)', () {
      final r = _estimations(
        Fixtures.data(
          taches: [
            Fixtures.tache(
              id: 't-1',
              quantitePrevue: 20,
              minutesParUniteSnapshot: 30,
            ),
          ],
          heures: [
            Fixtures.heures(
              nbPersonnes: 1,
              minutesParPersonne: 480,
              tacheId: 't-1',
            ),
          ],
        ),
      );

      expect(r.single.minutesParUniteReel, 24.0);
      expect(r.single.ecartPct, -20.0);
    });

    test('R9 : réel arrondi 1 décimale half-up (450 / 8 = 56,25 → 56,3)', () {
      final r = _estimations(
        Fixtures.data(
          taches: [
            Fixtures.tache(
              id: 't-1',
              quantitePrevue: 8,
              minutesParUniteSnapshot: 50,
            ),
          ],
          heures: [
            Fixtures.heures(
              nbPersonnes: 1,
              minutesParPersonne: 450,
              tacheId: 't-1',
            ),
          ],
        ),
      );

      expect(r.single.minutesParUniteReel, 56.3);
    });

    test('R9 : écart arrondi 1 décimale (reel 31 sur snapshot 30 → 3,33… → '
        '3,3 ; reel 32 → 6,66… → 6,7)', () {
      final r = _estimations(
        Fixtures.data(
          taches: [
            Fixtures.tache(
              id: 't-1',
              quantitePrevue: 10,
              minutesParUniteSnapshot: 30,
            ),
            Fixtures.tache(
              id: 't-2',
              quantitePrevue: 10,
              minutesParUniteSnapshot: 30,
            ),
          ],
          heures: [
            Fixtures.heures(id: 'h1', minutesParPersonne: 310, tacheId: 't-1'),
            Fixtures.heures(id: 'h2', minutesParPersonne: 320, tacheId: 't-2'),
          ],
        ),
      );

      expect(r[0].minutesParUniteReel, 31.0);
      expect(r[0].ecartPct, 3.3);
      expect(r[1].minutesParUniteReel, 32.0);
      expect(r[1].ecartPct, 6.7);
    });

    test('quantité décimale (12,5 m) : 500 / 12,5 = 40,0', () {
      final r = _estimations(
        Fixtures.data(
          taches: [
            Fixtures.tache(
              id: 't-1',
              unite: Unite.m,
              quantitePrevue: 12.5,
              minutesParUniteSnapshot: 32,
            ),
          ],
          heures: [Fixtures.heures(minutesParPersonne: 500, tacheId: 't-1')],
        ),
      );

      expect(r.single.minutesParUniteReel, 40.0);
      // (40 − 32) / 32 = 25,0 %.
      expect(r.single.ecartPct, 25.0);
    });
  });

  group('EstimationCalculator.compute — cas null', () {
    test('aucune heure saisie : réel et écart null, charge 0', () {
      final r = _estimations(
        Fixtures.data(
          taches: [
            Fixtures.tache(
              id: 't-1',
              quantitePrevue: 20,
              minutesParUniteSnapshot: 30,
            ),
          ],
        ),
      );

      final e = r.single;
      expect(e.chargeReelleMinutes, 0);
      expect(e.minutesParUniteReel, isNull);
      expect(e.ecartPct, isNull);
      expect(e.minutesParUniteSnapshot, 30);
      expect(e.valeurConstateeDisponible, isFalse);
    });

    test('quantité 0 : réel et écart null, charge conservée', () {
      final r = _estimations(
        Fixtures.data(
          taches: [
            Fixtures.tache(
              id: 't-1',
              quantitePrevue: 0,
              minutesParUniteSnapshot: 30,
            ),
          ],
          heures: [Fixtures.heures(minutesParPersonne: 480, tacheId: 't-1')],
        ),
      );

      final e = r.single;
      expect(e.chargeReelleMinutes, 480);
      expect(e.minutesParUniteReel, isNull);
      expect(e.ecartPct, isNull);
    });

    test('tâche libre (snapshot null) : réel calculé, écart null', () {
      final r = _estimations(
        Fixtures.data(
          taches: [Fixtures.tache(id: 't-1', quantitePrevue: 20)],
          heures: [Fixtures.heures(minutesParPersonne: 480, tacheId: 't-1')],
        ),
      );

      final e = r.single;
      expect(e.minutesParUniteSnapshot, isNull);
      expect(e.minutesParUniteReel, 24.0);
      expect(e.ecartPct, isNull);
      // Valeur constatée disponible pour alimenter la bibliothèque.
      expect(e.valeurConstateeDisponible, isTrue);
    });

    test('snapshot 0 : écart null (division par zéro)', () {
      final r = _estimations(
        Fixtures.data(
          taches: [
            Fixtures.tache(
              id: 't-1',
              quantitePrevue: 20,
              minutesParUniteSnapshot: 0,
            ),
          ],
          heures: [Fixtures.heures(minutesParPersonne: 480, tacheId: 't-1')],
        ),
      );

      expect(r.single.minutesParUniteReel, 24.0);
      expect(r.single.ecartPct, isNull);
    });
  });

  group('EstimationCalculator.compute — R5 et périmètre', () {
    test('R5 : utilise le snapshot et la version copiés dans l\'instance, '
        'jamais la bibliothèque (qui a évolué depuis)', () {
      // La bibliothèque a été modifiée après la création de la tâche.
      const bibliotheque = BibliothequeTache(
        id: 'bib-1',
        libelle: 'Pose carrelage',
        unite: Unite.m2,
        minutesParUnite: 45,
        version: 5,
      );
      final r = _estimations(
        Fixtures.data(
          taches: [
            Fixtures.tache(
              id: 't-1',
              quantitePrevue: 20,
              minutesParUniteSnapshot: 30,
              bibliothequeTacheId: bibliotheque.id,
              bibliothequeVersion: 3,
            ),
          ],
          heures: [
            Fixtures.heures(
              nbPersonnes: 2,
              minutesParPersonne: 300,
              tacheId: 't-1',
            ),
          ],
        ),
      );

      final e = r.single;
      expect(e.bibliothequeTacheId, 'bib-1');
      expect(e.bibliothequeVersion, 3);
      expect(e.minutesParUniteSnapshot, 30);
      expect(e.minutesParUniteSnapshot, isNot(bibliotheque.minutesParUnite));
      expect(e.bibliothequeVersion, isNot(bibliotheque.version));
      // Écart calculé contre 30 (snapshot), pas contre 45 (bibliothèque).
      expect(e.ecartPct, 0.0);
    });

    test('les tâches liées à un travaux sup sont incluses', () {
      final r = _estimations(
        Fixtures.data(
          taches: [
            Fixtures.tache(id: 't-1', quantitePrevue: 20),
            Fixtures.tache(
              id: 't-ts',
              libelle: 'Cloison TS',
              quantitePrevue: 10,
              minutesParUniteSnapshot: 60,
              travauxSupId: 'ts-1',
            ).copyWith(ordre: 1),
          ],
          heures: [
            Fixtures.heures(
              nbPersonnes: 2,
              minutesParPersonne: 240,
              tacheId: 't-ts',
              travauxSupId: 'ts-1',
            ),
          ],
        ),
      );

      expect(r.map((e) => e.tacheId), ['t-1', 't-ts']);
      final ts = r[1];
      expect(ts.chargeReelleMinutes, 480);
      expect(ts.minutesParUniteReel, 48.0);
      expect(ts.ecartPct, -20.0);
    });

    test('tri : ordre, puis libellé (insensible à la casse), puis id', () {
      final r = _estimations(
        Fixtures.data(
          taches: [
            Fixtures.tache(id: 't-c', libelle: 'Peinture').copyWith(ordre: 1),
            Fixtures.tache(id: 't-a', libelle: 'carrelage').copyWith(ordre: 1),
            Fixtures.tache(id: 't-b', libelle: 'Zinguerie').copyWith(ordre: 0),
            Fixtures.tache(id: 't-d', libelle: 'Carrelage').copyWith(ordre: 1),
          ],
        ),
      );

      expect(r.map((e) => e.tacheId), ['t-b', 't-a', 't-d', 't-c']);
    });

    test('sans tâche : liste vide même avec des heures', () {
      final r = _estimations(
        Fixtures.data(
          heures: [Fixtures.heures(minutesParPersonne: 480, tacheId: 't-1')],
        ),
      );

      expect(r, isEmpty);
    });

    test('R6 : tâche supprimée absente ; ses heures supprimées ne comptent '
        'pas', () {
      final r = _estimations(
        Fixtures.data(
          taches: [
            Fixtures.tache(id: 't-1', quantitePrevue: 20),
            Fixtures.tache(id: 't-del', deletedAt: Fixtures.jour),
          ],
          heures: [
            Fixtures.heures(id: 'h1', minutesParPersonne: 480, tacheId: 't-1'),
            Fixtures.heures(
              id: 'h2',
              minutesParPersonne: 480,
              tacheId: 't-1',
              deletedAt: Fixtures.jour,
            ),
          ],
        ),
      );

      expect(r.map((e) => e.tacheId), ['t-1']);
      expect(r.single.chargeReelleMinutes, 480);
    });
  });
}
