/// §6 : accueil : par ModePrix — caVendu, depenses, rentabilite,
///      margeMoyenne% = rentab / caVendu (pondérée) ; aFaireSigner (nb,
///      Σ prixVenduInitial) ; aVenir (nb, Σ prixVendu) ; aSurveiller (rouge,
///      orange, proj. rouge).
/// R2 : HT et TTC ne sont jamais additionnés.
/// R11 : « à faire signer » = potentiel, jamais CA vendu.
library;

import 'package:chantiers/core/constants/enums.dart';
import 'package:chantiers/features/rentabilite/domain/agregats_calculator.dart';
import 'package:chantiers/features/rentabilite/domain/chantier_kpis.dart';
import 'package:chantiers/features/rentabilite/domain/seuils.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/fixtures.dart';

/// KPIs d'un chantier au prévisionnel complet (budget 6 000 €, 80 h,
/// 2 personnes, 5 jours), avec [depensesCents] dépensés et [dureeMinutes]
/// saisies. Sans [previsionnel], le chantier est gris.
ChantierKpis _kpis({
  required String id,
  ModePrix mode = ModePrix.ht,
  StatutChantier statut = StatutChantier.enCours,
  int prixVenduInitialCents = 1000000,
  int depensesCents = 0,
  int dureeMinutes = 0,
  bool previsionnel = true,
  int travauxSupAccepteCents = 0,
  int travauxSupProposeCents = 0,
}) => ChantierKpis.compute(
  Fixtures.data(
    chantier: Fixtures.chantier(
      id: id,
      nom: 'Chantier $id',
      modePrix: mode,
      statut: statut,
      prixVenduInitialCents: prixVenduInitialCents,
    ),
    previsionnel: previsionnel
        ? Fixtures.previsionnelComplet(chantierId: id)
        : null,
    depenses: [
      if (depensesCents > 0)
        Fixtures.depense(chantierId: id, montantCents: depensesCents),
    ],
    heures: [
      if (dureeMinutes > 0)
        Fixtures.heures(chantierId: id, minutesParPersonne: dureeMinutes),
    ],
    travauxSup: [
      if (travauxSupAccepteCents > 0)
        Fixtures.travauxSup(
          id: '$id-ts-acc',
          chantierId: id,
          statut: StatutTravauxSup.accepte,
          prixVenduCents: travauxSupAccepteCents,
        ),
      if (travauxSupProposeCents > 0)
        Fixtures.travauxSup(
          id: '$id-ts-prop',
          chantierId: id,
          statut: StatutTravauxSup.propose,
          prixVenduCents: travauxSupProposeCents,
        ),
    ],
  ),
  Seuils.defaut,
);

void main() {
  group('AgregatsCalculator.compute — R2 un bloc par mode', () {
    test('deux chantiers HT et un TTC → deux blocs, aucune somme croisée', () {
      final r = AgregatsCalculator.compute([
        _kpis(id: 'c1', depensesCents: 300000),
        _kpis(
          id: 'c2',
          statut: StatutChantier.termine,
          prixVenduInitialCents: 500000,
          depensesCents: 200000,
        ),
        _kpis(
          id: 'c3',
          mode: ModePrix.ttc,
          prixVenduInitialCents: 1200000,
          depensesCents: 600000,
        ),
      ]);

      expect(r.estVide, isFalse);
      expect(r.modes, [ModePrix.ht, ModePrix.ttc]);
      expect(r.parMode.keys, containsAll([ModePrix.ht, ModePrix.ttc]));

      final ht = r.pour(ModePrix.ht)!;
      expect(ht.mode, ModePrix.ht);
      expect(ht.nbChantiers, 2);
      expect(ht.caVenduCents, 1500000);
      expect(ht.depensesCents, 500000);
      expect(ht.rentabiliteCents, 1000000);
      // 1 000 000 / 1 500 000 = 66,67 → 66,7.
      expect(ht.margeMoyennePct, 66.7);

      final ttc = r.pour(ModePrix.ttc)!;
      expect(ttc.mode, ModePrix.ttc);
      expect(ttc.nbChantiers, 1);
      expect(ttc.caVenduCents, 1200000);
      expect(ttc.depensesCents, 600000);
      expect(ttc.rentabiliteCents, 600000);
      expect(ttc.margeMoyennePct, 50.0);
    });

    test('modes toujours HT avant TTC, quel que soit l\'ordre d\'entrée', () {
      final r = AgregatsCalculator.compute([
        _kpis(id: 'c-ttc', mode: ModePrix.ttc),
        _kpis(id: 'c-ht'),
      ]);

      expect(r.modes, [ModePrix.ht, ModePrix.ttc]);
    });

    test('un seul mode présent : l\'autre est absent (pas de bloc vide)', () {
      final r = AgregatsCalculator.compute([_kpis(id: 'c1')]);

      expect(r.modes, [ModePrix.ht]);
      expect(r.pour(ModePrix.ttc), isNull);
    });

    test('aucun chantier : Agregats.vide', () {
      final r = AgregatsCalculator.compute(const []);

      expect(r.estVide, isTrue);
      expect(r.modes, isEmpty);
      expect(r.pour(ModePrix.ht), isNull);
    });
  });

  group('AgregatsCalculator.compute — statuts (R11)', () {
    test('caVendu = en cours + terminé seulement ; à venir et à faire signer '
        'sont comptés à part', () {
      final r = AgregatsCalculator.compute([
        _kpis(id: 'c-enCours', depensesCents: 300000),
        _kpis(
          id: 'c-termine',
          statut: StatutChantier.termine,
          prixVenduInitialCents: 500000,
          depensesCents: 200000,
        ),
        _kpis(
          id: 'c-aVenir',
          statut: StatutChantier.aVenir,
          prixVenduInitialCents: 400000,
        ),
        _kpis(
          id: 'c-aSigner',
          statut: StatutChantier.aFaireSigner,
          prixVenduInitialCents: 300000,
        ),
      ]).pour(ModePrix.ht)!;

      expect(r.nbChantiers, 2);
      expect(r.caVenduCents, 1500000);
      expect(r.depensesCents, 500000);
      expect(r.rentabiliteCents, 1000000);
      expect(r.aVenirNb, 1);
      expect(r.aVenirCents, 400000);
      expect(r.aFaireSignerNb, 1);
      expect(r.aFaireSignerCents, 300000);
    });

    test('à venir : Σ prixVendu, TS acceptés inclus, proposés exclus', () {
      final r = AgregatsCalculator.compute([
        _kpis(
          id: 'c-aVenir',
          statut: StatutChantier.aVenir,
          prixVenduInitialCents: 400000,
          travauxSupAccepteCents: 50000,
          travauxSupProposeCents: 70000,
        ),
      ]).pour(ModePrix.ht)!;

      expect(r.aVenirNb, 1);
      expect(r.aVenirCents, 450000);
      expect(r.caVenduCents, 0);
    });

    test('R11 : à faire signer : Σ prixVenduInitial (hors CA, hors TS)', () {
      final r = AgregatsCalculator.compute([
        _kpis(
          id: 'c-aSigner',
          statut: StatutChantier.aFaireSigner,
          prixVenduInitialCents: 300000,
          travauxSupAccepteCents: 20000,
          travauxSupProposeCents: 70000,
        ),
        _kpis(
          id: 'c-aSigner-2',
          statut: StatutChantier.aFaireSigner,
          prixVenduInitialCents: 100000,
        ),
      ]).pour(ModePrix.ht)!;

      expect(r.aFaireSignerNb, 2);
      expect(r.aFaireSignerCents, 400000);
      expect(r.nbChantiers, 0);
      expect(r.caVenduCents, 0);
      expect(r.depensesCents, 0);
      expect(r.rentabiliteCents, 0);
      expect(r.margeMoyennePct, isNull);
    });

    test('les dépenses d\'un chantier à venir n\'entrent pas dans les '
        'dépenses agrégées', () {
      final r = AgregatsCalculator.compute([
        _kpis(id: 'c-enCours', depensesCents: 100000),
        _kpis(
          id: 'c-aVenir',
          statut: StatutChantier.aVenir,
          depensesCents: 50000,
        ),
      ]).pour(ModePrix.ht)!;

      expect(r.depensesCents, 100000);
      expect(r.rentabiliteCents, 900000);
    });

    test('R3 : le CA vendu d\'un chantier en cours inclut ses TS acceptés, '
        'pas les proposés', () {
      final r = AgregatsCalculator.compute([
        _kpis(
          id: 'c1',
          travauxSupAccepteCents: 200000,
          travauxSupProposeCents: 150000,
        ),
      ]).pour(ModePrix.ht)!;

      expect(r.caVenduCents, 1200000);
    });
  });

  group('AgregatsCalculator.compute — marge moyenne', () {
    test('§6 : pondérée = Σ rentab / Σ caVendu, pas la moyenne des marges', () {
      // c1 : 10 000 € / 5 000 € → 50 % ; c2 : 1 000 € / 900 € → 10 %.
      // Moyenne simple = 30 % ; pondérée = 5 100 / 11 000 = 46,36 → 46,4.
      final r = AgregatsCalculator.compute([
        _kpis(id: 'c1', depensesCents: 500000),
        _kpis(id: 'c2', prixVenduInitialCents: 100000, depensesCents: 90000),
      ]).pour(ModePrix.ht)!;

      expect(r.rentabiliteCents, 510000);
      expect(r.margeMoyennePct, 46.4);
      expect(r.margeMoyennePct, isNot(30.0));
    });

    test('marge négative possible ; null si CA vendu = 0', () {
      final negative = AgregatsCalculator.compute([
        _kpis(id: 'c1', prixVenduInitialCents: 100000, depensesCents: 150000),
      ]).pour(ModePrix.ht)!;
      final sansCa = AgregatsCalculator.compute([
        _kpis(id: 'c2', prixVenduInitialCents: 0, depensesCents: 5000),
      ]).pour(ModePrix.ht)!;

      expect(negative.margeMoyennePct, -50.0);
      expect(sansCa.nbChantiers, 1);
      expect(sansCa.caVenduCents, 0);
      expect(sansCa.rentabiliteCents, -5000);
      expect(sansCa.margeMoyennePct, isNull);
    });
  });

  group('AgregatsCalculator.compute — à surveiller', () {
    test('rouges, puis oranges, puis projections rouges ; un chantier une '
        'seule fois ; verts et gris absents', () {
      final r = AgregatsCalculator.compute([
        // Vert (−50 %) mais projection rouge : 30 % d'avancement (1 440 /
        // 4 800), 3 000 € → 10 000 € projetés (+66,7 %).
        _kpis(id: 'c-proj', depensesCents: 300000, dureeMinutes: 1440),
        // Orange : 6 600 € sur 6 000 € → +10 %.
        _kpis(id: 'c-orange', depensesCents: 660000),
        // Vert : 6 000 € → 0 %.
        _kpis(id: 'c-vert', depensesCents: 600000),
        // Rouge (+16,7 %) ET projection rouge (50 % → 14 000 €).
        _kpis(id: 'c-rouge-proj', depensesCents: 700000, dureeMinutes: 2400),
        // Rouge : rentabilité négative.
        _kpis(id: 'c-rouge', depensesCents: 1100000),
        // Gris : prévisionnel absent, même avec rentabilité négative.
        _kpis(id: 'c-gris', depensesCents: 1100000, previsionnel: false),
      ]).pour(ModePrix.ht)!;

      expect(r.aSurveiller.map((c) => c.chantierId), [
        'c-rouge-proj',
        'c-rouge',
        'c-orange',
        'c-proj',
      ]);
      expect(r.aSurveiller.map((c) => c.couleur), [
        CouleurEtat.rouge,
        CouleurEtat.rouge,
        CouleurEtat.orange,
        CouleurEtat.vert,
      ]);
      expect(r.aSurveiller.map((c) => c.projectionRouge), [
        true,
        false,
        false,
        true,
      ]);
      expect(r.aSurveiller.first.nom, 'Chantier c-rouge-proj');
      expect(r.nbRouges, 2);
      expect(r.nbOranges, 1);
      expect(r.nbProjectionsRouges, 2);
    });

    test('un chantier orange avec projection rouge est listé une seule fois, '
        'comme orange', () {
      // Orange (+10 %) ; 50 % d'avancement → 13 200 € projetés (+120 %).
      final r = AgregatsCalculator.compute([
        _kpis(id: 'c1', depensesCents: 660000, dureeMinutes: 2400),
      ]).pour(ModePrix.ht)!;

      expect(r.aSurveiller, hasLength(1));
      expect(r.aSurveiller.single.couleur, CouleurEtat.orange);
      expect(r.aSurveiller.single.projectionRouge, isTrue);
      expect(r.nbOranges, 1);
      expect(r.nbRouges, 0);
    });

    test('rien à surveiller : liste vide, compteurs à 0', () {
      final r = AgregatsCalculator.compute([
        _kpis(id: 'c-vert', depensesCents: 600000),
        _kpis(id: 'c-gris', previsionnel: false),
      ]).pour(ModePrix.ht)!;

      expect(r.aSurveiller, isEmpty);
      expect(r.nbRouges, 0);
      expect(r.nbOranges, 0);
      expect(r.nbProjectionsRouges, 0);
    });

    test(
      'R2 : les chantiers à surveiller restent dans le bloc de leur mode',
      () {
        final r = AgregatsCalculator.compute([
          _kpis(id: 'c-ht', depensesCents: 1100000),
          _kpis(id: 'c-ttc', mode: ModePrix.ttc, depensesCents: 660000),
        ]);

        expect(r.pour(ModePrix.ht)!.aSurveiller.map((c) => c.chantierId), [
          'c-ht',
        ]);
        expect(r.pour(ModePrix.ttc)!.aSurveiller.map((c) => c.chantierId), [
          'c-ttc',
        ]);
      },
    );
  });
}
