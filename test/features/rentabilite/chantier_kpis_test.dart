/// Scénario de bout en bout : `ChantierKpis.compute` enchaîne les 10
/// calculateurs d'un chantier. Chaque valeur attendue est calculée à la main
/// d'après les formules de CLAUDE.md §6.
///
/// Chantier HT en cours, prix 10 000 € ; TS accepté 2 000 € (budget 1 000 €,
/// 10 h) ; TS proposé 1 500 € ; budget 6 000 €, 80 h, 2 personnes, 5 jours ;
/// dépenses 5 000 € dont 800 € sur le TS accepté ; 40 h saisies ; 2 tâches.
library;

import 'package:chantiers/core/constants/enums.dart';
import 'package:chantiers/features/rentabilite/domain/chantier_data.dart';
import 'package:chantiers/features/rentabilite/domain/chantier_kpis.dart';
import 'package:chantiers/features/rentabilite/domain/resultats.dart';
import 'package:chantiers/features/rentabilite/domain/seuils.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/fixtures.dart';

ChantierData _scenario({StatutChantier statut = StatutChantier.enCours}) =>
    Fixtures.data(
      chantier: Fixtures.chantier(statut: statut),
      previsionnel: Fixtures.previsionnelComplet(),
      travauxSup: [
        Fixtures.travauxSup(
          id: 'ts-acc',
          libelle: 'Cloison supplémentaire',
          statut: StatutTravauxSup.accepte,
          prixVenduCents: 200000,
          budgetDepensesCents: 100000,
          heuresPrevuesMinutes: 600,
          effectifPrevu: 2,
        ),
        Fixtures.travauxSup(
          id: 'ts-prop',
          libelle: 'Terrasse',
          statut: StatutTravauxSup.propose,
          prixVenduCents: 150000,
          budgetDepensesCents: 50000,
          heuresPrevuesMinutes: 300,
        ),
      ],
      taches: [
        Fixtures.tache(
          id: 't-1',
          libelle: 'Pose carrelage',
          quantitePrevue: 20,
          minutesParUniteSnapshot: 30,
        ),
        Fixtures.tache(
          id: 't-2',
          libelle: 'Peinture',
          quantitePrevue: 50,
          minutesParUniteSnapshot: 12,
        ).copyWith(ordre: 1),
      ],
      depenses: [
        Fixtures.depense(
          id: 'd1',
          type: TypeDepense.materiaux,
          montantCents: 300000,
          tacheId: 't-1',
        ),
        Fixtures.depense(
          id: 'd2',
          type: TypeDepense.sousTraitance,
          montantCents: 120000,
        ),
        Fixtures.depense(
          id: 'd3',
          type: TypeDepense.materiaux,
          montantCents: 80000,
          travauxSupId: 'ts-acc',
        ),
      ],
      heures: [
        Fixtures.heures(id: 'h1', nbPersonnes: 2, tacheId: 't-1'),
        Fixtures.heures(id: 'h2', nbPersonnes: 2, tacheId: 't-1'),
        Fixtures.heures(id: 'h3', nbPersonnes: 1, tacheId: 't-2'),
        Fixtures.heures(id: 'h4', nbPersonnes: 2, tacheId: 't-2'),
        Fixtures.heures(id: 'h5', nbPersonnes: 2, travauxSupId: 'ts-acc'),
      ],
    );

void main() {
  group('ChantierKpis.compute — scénario complet', () {
    final kpis = ChantierKpis.compute(_scenario(), Seuils.defaut);

    test('accès directs au chantier', () {
      expect(kpis.chantierId, Fixtures.chantierId);
      expect(kpis.chantier.nom, 'Rénovation Dupont');
      expect(kpis.modePrix, ModePrix.ht);
      expect(kpis.statut, StatutChantier.enCours);
      expect(kpis.data.depenses, hasLength(3));
      expect(kpis.data.heures, hasLength(5));
      expect(kpis.data.taches, hasLength(2));
      expect(kpis.data.travauxSup, hasLength(2));
    });

    test('§6 : dépenses = Σ montants (tous types), TS comptés une fois', () {
      final d = kpis.depenses;
      expect(d.totalCents, 500000);
      expect(d.nbDepenses, 3);
      expect(d.pourType(TypeDepense.materiaux), 380000);
      expect(d.pourType(TypeDepense.sousTraitance), 120000);
      expect(d.pourType(TypeDepense.repas), 0);
      expect(d.parTravauxSupCents, {'ts-acc': 80000});
      expect(d.horsTravauxSupCents, 420000);
      expect(d.parTacheCents, {'t-1': 300000});
    });

    test(
      '§6 : heures = Σ minutes (durée), heuresPersonnes = Σ nb × minutes',
      () {
        final h = kpis.heures;
        // 5 saisies de 480 min → 40 h de durée.
        expect(h.dureeMinutes, 2400);
        // 960 + 960 + 480 + 960 + 960.
        expect(h.chargeMinutes, 4320);
        expect(h.nbSaisies, 5);
        expect(h.chargeParTacheMinutes, {'t-1': 1920, 't-2': 1440});
        expect(h.dureeParTravauxSupMinutes, {'ts-acc': 480});
        expect(h.chargeParTravauxSupMinutes, {'ts-acc': 960});
        expect(h.effectifMoyen, 1.8);
      },
    );

    test('§6 : prévisionnel global + TS accepté (budget 7 000 €, 90 h)', () {
      final p = kpis.previsionnel;
      expect(p.budgetDepensesCents, 600000);
      expect(p.budgetTotalCents, 700000);
      expect(p.heuresPrevuesMinutes, 4800);
      expect(p.heuresPrevuesTotalMinutes, 5400);
      expect(p.effectifPrevu, 2);
      expect(p.dureePrevueJours, 5);
      // Charge : non saisie globalement → Σ tâches principales (priorité sur
      // heures × effectif) : 30 × 20 + 12 × 50 = 1 200 ; TS : 600 × 2 = 1 200.
      // Point à trancher : avec heures et effectif globaux (80 h × 2 = 9 600),
      // la charge dérivée des tâches (1 200) implique un effectif de 0,25.
      expect(p.chargePrevueMinutes, 1200);
      expect(p.chargeDeriveeDesTaches, isTrue);
      expect(p.chargePrevueTotalMinutes, 2400);
      // Heures et effectif globaux saisis : non dérivés des tâches.
      expect(p.heuresDeriveesDesTaches, isFalse);
      expect(p.effectifDeriveDesTaches, isFalse);
      expect(p.budgetParTypeCents, isEmpty);
    });

    test('R1, R3 : rentabilité = (10 000 + 2 000) − 5 000 = 7 000 € ; '
        'potentiel 1 500 € à part ; marge 58,3 %', () {
      final r = kpis.rentabilite;
      expect(r.prixVenduInitialCents, 1000000);
      expect(r.travauxSupAcceptesCents, 200000);
      expect(r.prixVenduCents, 1200000);
      expect(r.potentielTravauxSupCents, 150000);
      expect(r.depensesCents, 500000);
      expect(r.rentabiliteCents, 700000);
      // 700 000 / 1 200 000 = 58,33 → 58,3.
      expect(r.margePct, 58.3);
      expect(r.estNegative, isFalse);
    });

    test('§6 : écarts réel − prévu (dépenses −2 000 € / −28,6 % ; heures '
        '−50 h ; charge +80 %)', () {
      final e = kpis.ecart;
      expect(e.ecartDepensesCents, -200000);
      // −200 000 / 700 000 = −28,57 → −28,6.
      expect(e.ecartDepensesPct, -28.6);
      expect(e.ecartParTypeCents, isEmpty);
      expect(e.ecartHeuresMinutes, -3000);
      // −3 000 / 5 400 = −55,55 → −55,6.
      expect(e.ecartHeuresPct, -55.6);
      // Charge prévue totale dérivée des tâches (2 400) : 4 320 − 2 400.
      expect(e.ecartChargeMinutes, 1920);
      // 1 920 / 2 400 = 80,0.
      expect(e.ecartChargePct, 80.0);
    });

    test('R10 : prévisionnel complet à 100 %', () {
      expect(kpis.completude.pct, 100);
      expect(kpis.completude.manquants, isEmpty);
      expect(kpis.completude.estComplet, isTrue);
    });

    test('couleur principale verte (rentable, sous le budget)', () {
      expect(kpis.couleur, CouleurEtat.vert);
    });

    test('R8 : projection à 44,4 % d\'avancement → 11 261,26 € projetés, '
        '+60,9 %, rouge — sans toucher à la couleur principale', () {
      final p = kpis.projection;
      expect(p, isNotNull);
      // 2 400 / 5 400 = 44,44 → 44,4.
      expect(p!.avancementPct, 44.4);
      // 500 000 / 0,444 = 1 126 126,13 → 1 126 126.
      expect(p.depensesProjeteesCents, 1126126);
      expect(p.ecartProjeteCents, 426126);
      // 426 126 / 700 000 = 60,875 → 60,9.
      expect(p.ecartProjetePct, 60.9);
      expect(p.couleur, CouleurEtat.rouge);
      expect(kpis.projectionRouge, isTrue);
      expect(kpis.couleur, CouleurEtat.vert);
    });

    test('R5 : estimations par tâche, triées par ordre (carrelage 96,0 '
        'min/m² → +220 % ; peinture 28,8 → +140 %)', () {
      final est = kpis.estimations;
      expect(est.map((e) => e.tacheId), ['t-1', 't-2']);

      final carrelage = est[0];
      expect(carrelage.chargeReelleMinutes, 1920);
      // 1 920 / 20 = 96,0 ; (96 − 30) / 30 = 220,0 %.
      expect(carrelage.minutesParUniteReel, 96.0);
      expect(carrelage.ecartPct, 220.0);
      expect(carrelage.valeurConstateeDisponible, isTrue);

      final peinture = est[1];
      expect(peinture.chargeReelleMinutes, 1440);
      // 1 440 / 50 = 28,8 ; (28,8 − 12) / 12 = 140,0 %.
      expect(peinture.minutesParUniteReel, 28.8);
      expect(peinture.ecartPct, 140.0);
    });

    test('§5 : analyse des TS (accepté : 800 € dépensés, 8 h ; proposé : '
        'rien)', () {
      final ts = kpis.travauxSup;
      // Même date de proposition : tri par libellé.
      expect(ts.map((a) => a.id), ['ts-acc', 'ts-prop']);

      final accepte = ts[0];
      expect(accepte.statut, StatutTravauxSup.accepte);
      expect(accepte.depensesCents, 80000);
      expect(accepte.dureeMinutes, 480);
      expect(accepte.chargeMinutes, 960);
      expect(accepte.rentabiliteCents, 120000);
      expect(accepte.margePct, 60.0);
      expect(accepte.ecartDepensesCents, -20000);
      expect(accepte.ecartDepensesPct, -20.0);
      expect(accepte.ecartHeuresMinutes, -120);
      expect(accepte.ecartHeuresPct, -20.0);

      final propose = ts[1];
      expect(propose.statut, StatutTravauxSup.propose);
      expect(propose.depensesCents, 0);
      expect(propose.dureeMinutes, 0);
      expect(propose.rentabiliteCents, 150000);
      expect(propose.margePct, 100.0);
      expect(propose.ecartDepensesCents, -50000);
      expect(propose.ecartDepensesPct, -100.0);
      expect(propose.ecartHeuresMinutes, -300);
      expect(propose.ecartHeuresPct, -100.0);
    });
  });

  group('ChantierKpis.compute — invariants', () {
    test('R6 : ChantierData exclut les supprimés — une dépense supprimée est '
        'absente du total, un TS accepté supprimé du prix vendu', () {
      final base = _scenario();
      final avecSupprimes = Fixtures.data(
        chantier: base.chantier,
        previsionnel: base.previsionnel,
        travauxSup: [
          ...base.travauxSup,
          Fixtures.travauxSup(
            id: 'ts-del',
            statut: StatutTravauxSup.accepte,
            prixVenduCents: 999999,
            deletedAt: Fixtures.jour,
          ),
        ],
        taches: [
          ...base.taches,
          Fixtures.tache(id: 't-del', deletedAt: Fixtures.jour),
        ],
        depenses: [
          ...base.depenses,
          Fixtures.depense(
            id: 'd-del',
            montantCents: 999999,
            deletedAt: Fixtures.jour,
          ),
        ],
        heures: [
          ...base.heures,
          Fixtures.heures(
            id: 'h-del',
            nbPersonnes: 9,
            minutesParPersonne: 1440,
            tacheId: 't-1',
            deletedAt: Fixtures.jour,
          ),
        ],
      );
      final reference = ChantierKpis.compute(base, Seuils.defaut);
      final kpis = ChantierKpis.compute(avecSupprimes, Seuils.defaut);

      expect(kpis.data.depenses, hasLength(3));
      expect(kpis.data.heures, hasLength(5));
      expect(kpis.data.taches, hasLength(2));
      expect(kpis.data.travauxSup, hasLength(2));
      expect(kpis.depenses.totalCents, 500000);
      expect(kpis.rentabilite.prixVenduCents, 1200000);
      expect(
        kpis.rentabilite.rentabiliteCents,
        reference.rentabilite.rentabiliteCents,
      );
      expect(kpis.heures.chargeMinutes, reference.heures.chargeMinutes);
      expect(kpis.estimations, hasLength(2));
      expect(kpis.travauxSup, hasLength(2));
      expect(kpis.couleur, reference.couleur);
    });

    test(
      'R1 : 1 000 h saisies ne changent pas rentabiliteCents ni margePct',
      () {
        final base = _scenario();
        final avecHeures = Fixtures.data(
          chantier: base.chantier,
          previsionnel: base.previsionnel,
          travauxSup: base.travauxSup,
          taches: base.taches,
          depenses: base.depenses,
          heures: [
            ...base.heures,
            for (var i = 0; i < 50; i++)
              Fixtures.heures(
                id: 'h-extra-$i',
                nbPersonnes: 3,
                minutesParPersonne: 1200,
                tacheId: 't-1',
              ),
          ],
        );
        final reference = ChantierKpis.compute(base, Seuils.defaut);
        final kpis = ChantierKpis.compute(avecHeures, Seuils.defaut);

        expect(kpis.heures.dureeMinutes, 2400 + 60000);
        expect(kpis.rentabilite.rentabiliteCents, 700000);
        expect(
          kpis.rentabilite.rentabiliteCents,
          reference.rentabilite.rentabiliteCents,
        );
        expect(kpis.rentabilite.margePct, reference.rentabilite.margePct);
        expect(
          kpis.rentabilite.depensesCents,
          reference.rentabilite.depensesCents,
        );
        // Les heures agissent seulement sur les écarts heures et l'avancement.
        expect(kpis.ecart.ecartDepensesPct, reference.ecart.ecartDepensesPct);
        expect(kpis.ecart.ecartHeuresMinutes, 2400 + 60000 - 5400);
        expect(kpis.projection!.avancementPct, 100.0);
      },
    );

    test('R8 : un chantier terminé n\'a pas de projection, le reste est '
        'identique', () {
      final enCours = ChantierKpis.compute(_scenario(), Seuils.defaut);
      final termine = ChantierKpis.compute(
        _scenario(statut: StatutChantier.termine),
        Seuils.defaut,
      );

      expect(termine.projection, isNull);
      expect(termine.projectionRouge, isFalse);
      expect(
        termine.rentabilite.rentabiliteCents,
        enCours.rentabilite.rentabiliteCents,
      );
      expect(termine.ecart.ecartDepensesPct, enCours.ecart.ecartDepensesPct);
      expect(termine.couleur, enCours.couleur);
    });

    test(
      'les seuils sont transmis à la couleur principale et à la projection',
      () {
        // Dépenses 8 400 € sur 7 000 € → +20 % : rouge par défaut, orange avec
        // un seuil rouge à 30. Projection : 44,4 % → 18 918,92 € → +170 %.
        final base = _scenario();
        final data = Fixtures.data(
          chantier: base.chantier,
          previsionnel: base.previsionnel,
          travauxSup: base.travauxSup,
          taches: base.taches,
          heures: base.heures,
          depenses: [
            ...base.depenses,
            Fixtures.depense(id: 'd-plus', montantCents: 340000),
          ],
        );
        final defaut = ChantierKpis.compute(data, Seuils.defaut);
        final large = ChantierKpis.compute(
          data,
          const Seuils(orangePct: 10, rougePct: 30, projectionPct: 50),
        );

        expect(defaut.ecart.ecartDepensesPct, 20.0);
        expect(defaut.couleur, CouleurEtat.rouge);
        expect(defaut.projection, isNotNull);
        expect(large.couleur, CouleurEtat.orange);
        // Seuil de projection à 50 % : 44,4 % ne suffit plus.
        expect(large.projection, isNull);
      },
    );

    test('chantier vide (sans prévisionnel) : gris, projection null, listes '
        'vides, rentabilité = prix vendu', () {
      final kpis = ChantierKpis.compute(Fixtures.data(), Seuils.defaut);

      expect(kpis.couleur, CouleurEtat.gris);
      expect(kpis.completude.pct, 22);
      expect(kpis.projection, isNull);
      expect(kpis.projectionRouge, isFalse);
      expect(kpis.estimations, isEmpty);
      expect(kpis.travauxSup, isEmpty);
      expect(kpis.depenses.totalCents, DepensesResult.vide.totalCents);
      expect(kpis.depenses.nbDepenses, 0);
      expect(kpis.heures.dureeMinutes, 0);
      expect(kpis.rentabilite.rentabiliteCents, 1000000);
      expect(kpis.ecart.ecartDepensesPct, isNull);
    });
  });
}
