/// §6 : projection : si enCours et avancement = heures / heuresPrevuesTot
///      ≥ 20 % : depensesProjetees = depenses / avancement ; ecartProjete% ;
///      couleur séparée ← SECONDAIRE.
/// R8 : la projection ne remplace jamais l'écart réel et n'entre jamais dans
///      la couleur principale ni dans la rentabilité.
library;

import 'package:chantiers/core/constants/enums.dart';
import 'package:chantiers/features/rentabilite/domain/chantier_data.dart';
import 'package:chantiers/features/rentabilite/domain/chantier_kpis.dart';
import 'package:chantiers/features/rentabilite/domain/depenses_calculator.dart';
import 'package:chantiers/features/rentabilite/domain/heures_calculator.dart';
import 'package:chantiers/features/rentabilite/domain/previsionnel_calculator.dart';
import 'package:chantiers/features/rentabilite/domain/projection_calculator.dart';
import 'package:chantiers/features/rentabilite/domain/resultats.dart';
import 'package:chantiers/features/rentabilite/domain/seuils.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/fixtures.dart';

ProjectionResult? _projection(
  ChantierData data, {
  Seuils seuils = Seuils.defaut,
}) => ProjectionCalculator.compute(
  data: data,
  depenses: DepensesCalculator.compute(data),
  heures: HeuresCalculator.compute(data),
  previsionnel: PrevisionnelCalculator.compute(data),
  seuils: seuils,
);

/// Chantier en cours, budget 6 000 €, 100 h prévues, [depensesCents] dépensés
/// et [dureeMinutes] de durée saisie.
ChantierData _data({
  StatutChantier statut = StatutChantier.enCours,
  int depensesCents = 300000,
  int dureeMinutes = 1800,
  int? budgetDepensesCents = 600000,
  int? heuresPrevuesMinutes = 6000,
}) => Fixtures.data(
  chantier: Fixtures.chantier(statut: statut),
  previsionnel: Fixtures.previsionnel(
    budgetDepensesCents: budgetDepensesCents,
    heuresPrevuesMinutes: heuresPrevuesMinutes,
    effectifPrevu: 2,
  ),
  depenses: [Fixtures.depense(montantCents: depensesCents)],
  heures: [Fixtures.heures(minutesParPersonne: dureeMinutes)],
);

void main() {
  group('ProjectionCalculator.compute — conditions', () {
    test('null si le chantier n\'est pas en cours (à faire signer, à venir, '
        'terminé)', () {
      for (final statut in [
        StatutChantier.aFaireSigner,
        StatutChantier.aVenir,
        StatutChantier.termine,
      ]) {
        expect(_projection(_data(statut: statut)), isNull, reason: '$statut');
      }
      expect(_projection(_data()), isNotNull);
    });

    test('null si avancement < 20 % : 19,9 → null, 20,0 → présent', () {
      // 1 194 / 6 000 = 19,9 % ; 1 200 / 6 000 = 20,0 %.
      expect(_projection(_data(dureeMinutes: 1194)), isNull);

      final r = _projection(_data(dureeMinutes: 1200));
      expect(r, isNotNull);
      expect(r!.avancementPct, 20.0);
    });

    test('R9 : avancement arrondi 1 décimale half-up avant comparaison '
        '(1 197 / 6 000 = 19,95 → 20,0 → présent)', () {
      final r = _projection(_data(dureeMinutes: 1197));

      expect(r, isNotNull);
      expect(r!.avancementPct, 20.0);
    });

    test('seuil de projection personnalisé (Seuils(projectionPct: 50))', () {
      const seuils = Seuils(projectionPct: 50);

      expect(_projection(_data(dureeMinutes: 1800), seuils: seuils), isNull);
      expect(_projection(_data(dureeMinutes: 2994), seuils: seuils), isNull);

      final r = _projection(_data(dureeMinutes: 3000), seuils: seuils);
      expect(r, isNotNull);
      expect(r!.avancementPct, 50.0);
    });

    test('seuil abaissé (Seuils(projectionPct: 10)) : 19,9 % devient '
        'projetable', () {
      final r = _projection(
        _data(dureeMinutes: 1194),
        seuils: const Seuils(projectionPct: 10),
      );

      expect(r, isNotNull);
      expect(r!.avancementPct, 19.9);
    });

    test('null sans heures prévues (avancement incalculable)', () {
      expect(_projection(_data(heuresPrevuesMinutes: null)), isNull);
      expect(_projection(_data(heuresPrevuesMinutes: 0)), isNull);
    });

    test(
      'null sans aucune heure saisie (avancement 0), même avec un seuil à 0',
      () {
        expect(
          _projection(
            _data(dureeMinutes: 0),
            seuils: const Seuils(projectionPct: 0),
          ),
          isNull,
        );
      },
    );
  });

  group('ProjectionCalculator.compute — formules', () {
    test('§6 : depensesProjetees = dépenses / avancement (30 % d\'avancement, '
        '3 000 € → 10 000 €)', () {
      final r = _projection(_data(depensesCents: 300000, dureeMinutes: 1800))!;

      expect(r.avancementPct, 30.0);
      expect(r.depensesProjeteesCents, 1000000);
      // 10 000 − 6 000 = 4 000 € ; 4 000 / 6 000 = 66,7 %.
      expect(r.ecartProjeteCents, 400000);
      expect(r.ecartProjetePct, 66.7);
      expect(r.couleur, CouleurEtat.rouge);
    });

    test('avancement plafonné à 100 % : projeté = dépenses réelles', () {
      // 7 200 / 6 000 = 120 % → 100 %.
      final r = _projection(_data(depensesCents: 500000, dureeMinutes: 7200))!;

      expect(r.avancementPct, 100.0);
      expect(r.depensesProjeteesCents, 500000);
      expect(r.ecartProjeteCents, -100000);
      // −100 000 / 600 000 = −16,7 %.
      expect(r.ecartProjetePct, -16.7);
      expect(r.couleur, CouleurEtat.vert);
    });

    test('à 100 % exactement : projeté = dépenses', () {
      final r = _projection(_data(depensesCents: 610000, dureeMinutes: 6000))!;

      expect(r.avancementPct, 100.0);
      expect(r.depensesProjeteesCents, 610000);
      expect(r.ecartProjetePct, 1.7);
    });

    test('R9 : projeté arrondi half-up au centime (1 000 € à 33,3 % → '
        '3 003,00 €)', () {
      // 1 998 / 6 000 = 33,3 % ; 100 000 / 0,333 = 300 300,3 → 300 300.
      final r = _projection(_data(depensesCents: 100000, dureeMinutes: 1998))!;

      expect(r.avancementPct, 33.3);
      expect(r.depensesProjeteesCents, 300300);
    });

    test('§6 : écart projeté vs budgetPrevuTotal (TS accepté inclus dans le '
        'budget ET dans les heures prévues)', () {
      // Budget 6 000 + 1 000 = 7 000 € ; heures 6 000 + 1 200 = 7 200 min.
      // Durée 3 600 → 50 % ; 3 500 € / 0,5 = 7 000 € → écart 0.
      final r = _projection(
        Fixtures.data(
          previsionnel: Fixtures.previsionnel(
            budgetDepensesCents: 600000,
            heuresPrevuesMinutes: 6000,
          ),
          travauxSup: [
            Fixtures.travauxSup(
              id: 'ts-acc',
              statut: StatutTravauxSup.accepte,
              budgetDepensesCents: 100000,
              heuresPrevuesMinutes: 1200,
            ),
            // Proposé : ignoré partout.
            Fixtures.travauxSup(
              id: 'ts-prop',
              statut: StatutTravauxSup.propose,
              budgetDepensesCents: 900000,
              heuresPrevuesMinutes: 9000,
            ),
          ],
          depenses: [
            Fixtures.depense(id: 'd1', montantCents: 300000),
            Fixtures.depense(
              id: 'd2',
              montantCents: 50000,
              travauxSupId: 'ts-acc',
            ),
          ],
          heures: [
            Fixtures.heures(id: 'h1', minutesParPersonne: 1200),
            Fixtures.heures(id: 'h2', minutesParPersonne: 1200),
            Fixtures.heures(
              id: 'h3',
              minutesParPersonne: 1200,
              travauxSupId: 'ts-acc',
            ),
          ],
        ),
      )!;

      expect(r.avancementPct, 50.0);
      expect(r.depensesProjeteesCents, 700000);
      expect(r.ecartProjeteCents, 0);
      expect(r.ecartProjetePct, 0.0);
      expect(r.couleur, CouleurEtat.vert);
    });

    test('la charge (nbPersonnes) n\'entre pas dans l\'avancement : seule la '
        'durée compte', () {
      final r = _projection(
        Fixtures.data(
          previsionnel: Fixtures.previsionnel(
            budgetDepensesCents: 600000,
            heuresPrevuesMinutes: 6000,
          ),
          depenses: [Fixtures.depense(montantCents: 300000)],
          heures: [Fixtures.heures(nbPersonnes: 4, minutesParPersonne: 1800)],
        ),
      )!;

      expect(r.avancementPct, 30.0);
    });

    test('sans budget : projeté calculable, écart null, couleur grise', () {
      final r = _projection(_data(budgetDepensesCents: null))!;

      expect(r.avancementPct, 30.0);
      expect(r.depensesProjeteesCents, 1000000);
      expect(r.ecartProjeteCents, isNull);
      expect(r.ecartProjetePct, isNull);
      expect(r.couleur, CouleurEtat.gris);
    });

    test('la mention obligatoire (§9.7) est disponible', () {
      expect(ProjectionResult.mention, contains('Projection indicative'));
    });
  });

  group('ProjectionCalculator.compute — couleur propre', () {
    test('rouge au-delà du seuil rouge (66,7 %)', () {
      final r = _projection(_data(depensesCents: 300000, dureeMinutes: 1800))!;

      expect(r.couleur, CouleurEtat.rouge);
    });

    test('orange entre les seuils (50 % d\'avancement, 3 300 € → 6 600 € → '
        '+10,0 %)', () {
      final r = _projection(_data(depensesCents: 330000, dureeMinutes: 3000))!;

      expect(r.depensesProjeteesCents, 660000);
      expect(r.ecartProjetePct, 10.0);
      expect(r.couleur, CouleurEtat.orange);
    });

    test('vert dans le budget (50 %, 3 000 € → 6 000 € → 0 %)', () {
      final r = _projection(_data(depensesCents: 300000, dureeMinutes: 3000))!;

      expect(r.depensesProjeteesCents, 600000);
      expect(r.ecartProjetePct, 0.0);
      expect(r.couleur, CouleurEtat.vert);
    });

    test('seuils orange / rouge personnalisés appliqués à la projection', () {
      final r = _projection(
        _data(depensesCents: 330000, dureeMinutes: 3000),
        seuils: const Seuils(orangePct: 10, rougePct: 30),
      )!;

      expect(r.ecartProjetePct, 10.0);
      expect(r.couleur, CouleurEtat.vert);
    });
  });

  group('R8 — la projection est un indicateur SECONDAIRE', () {
    test('la couleur principale du ChantierKpis reste verte quand la '
        'projection est rouge', () {
      // Écart réel : (3 000 − 6 000) / 6 000 = −50 % → vert.
      // Projection : 30 % d'avancement → 10 000 € → +66,7 % → rouge.
      final kpis = ChantierKpis.compute(
        Fixtures.data(
          previsionnel: Fixtures.previsionnel(
            budgetDepensesCents: 600000,
            heuresPrevuesMinutes: 6000,
            effectifPrevu: 2,
          ),
          depenses: [Fixtures.depense(montantCents: 300000)],
          heures: [Fixtures.heures(minutesParPersonne: 1800)],
        ),
        Seuils.defaut,
      );

      expect(kpis.completude.estComplet, isTrue);
      expect(kpis.ecart.ecartDepensesPct, -50.0);
      expect(kpis.couleur, CouleurEtat.vert);
      expect(kpis.projection, isNotNull);
      expect(kpis.projection!.couleur, CouleurEtat.rouge);
      expect(kpis.projectionRouge, isTrue);
    });

    test('la projection ne modifie ni la rentabilité ni l\'écart réel', () {
      final avecProjection = ChantierKpis.compute(
        _data(depensesCents: 300000, dureeMinutes: 1800),
        Seuils.defaut,
      );
      final sansProjection = ChantierKpis.compute(
        _data(depensesCents: 300000, dureeMinutes: 600),
        Seuils.defaut,
      );

      expect(avecProjection.projection, isNotNull);
      expect(sansProjection.projection, isNull);
      expect(avecProjection.rentabilite.rentabiliteCents, 700000);
      expect(
        avecProjection.rentabilite.rentabiliteCents,
        sansProjection.rentabilite.rentabiliteCents,
      );
      expect(
        avecProjection.ecart.ecartDepensesPct,
        sansProjection.ecart.ecartDepensesPct,
      );
      expect(avecProjection.couleur, sansProjection.couleur);
    });
  });
}
