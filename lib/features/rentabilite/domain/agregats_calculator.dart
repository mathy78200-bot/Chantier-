import '../../../core/constants/enums.dart';
import 'chantier_kpis.dart';
import 'rentabilite_calculator.dart';
import 'resultats.dart';

/// Agrégats de l'accueil : un bloc par mode de prix présent.
///
/// R2 : jamais de somme HT + TTC. R11 : les « à faire signer » sont un
/// potentiel, jamais du CA vendu ; seuls les chantiers en cours et terminés
/// (`StatutChantier.compteDansCaVendu`) entrent dans le CA, les dépenses, la
/// rentabilité et la marge moyenne pondérée.
abstract final class AgregatsCalculator {
  static Agregats compute(Iterable<ChantierKpis> kpis) {
    final parMode = <ModePrix, List<ChantierKpis>>{};
    for (final k in kpis) {
      parMode.putIfAbsent(k.modePrix, () => []).add(k);
    }
    if (parMode.isEmpty) return Agregats.vide;

    final result = <ModePrix, AgregatMode>{};
    for (final mode in ModePrix.values) {
      final liste = parMode[mode];
      if (liste != null) result[mode] = _agregatMode(mode, liste);
    }
    return Agregats(parMode: Map.unmodifiable(result));
  }

  static AgregatMode _agregatMode(ModePrix mode, List<ChantierKpis> liste) {
    var nbChantiers = 0;
    var caVenduCents = 0;
    var depensesCents = 0;
    var rentabiliteCents = 0;
    var aFaireSignerNb = 0;
    var aFaireSignerCents = 0;
    var aVenirNb = 0;
    var aVenirCents = 0;

    for (final k in liste) {
      final statut = k.statut;
      if (statut.compteDansCaVendu) {
        nbChantiers++;
        caVenduCents += k.rentabilite.prixVenduCents;
        depensesCents += k.rentabilite.depensesCents;
        rentabiliteCents += k.rentabilite.rentabiliteCents;
      } else if (statut == StatutChantier.aFaireSigner) {
        aFaireSignerNb++;
        aFaireSignerCents += k.chantier.prixVenduInitialCents;
      } else if (statut == StatutChantier.aVenir) {
        aVenirNb++;
        aVenirCents += k.rentabilite.prixVenduCents;
      }
    }

    return AgregatMode(
      mode: mode,
      nbChantiers: nbChantiers,
      caVenduCents: caVenduCents,
      depensesCents: depensesCents,
      rentabiliteCents: rentabiliteCents,
      margeMoyennePct: RentabiliteCalculator.margePct(
        rentabiliteCents,
        caVenduCents,
      ),
      aFaireSignerNb: aFaireSignerNb,
      aFaireSignerCents: aFaireSignerCents,
      aVenirNb: aVenirNb,
      aVenirCents: aVenirCents,
      aSurveiller: _aSurveiller(liste),
    );
  }

  /// Rouges, puis oranges, puis projections rouges non déjà listées ; chaque
  /// chantier n'apparaît qu'une fois, dans l'ordre d'entrée au sein d'un
  /// groupe.
  static List<ChantierASurveiller> _aSurveiller(List<ChantierKpis> liste) {
    final rouges = liste.where((k) => k.couleur == CouleurEtat.rouge);
    final oranges = liste.where((k) => k.couleur == CouleurEtat.orange);
    final projections = liste.where(
      (k) =>
          k.projectionRouge &&
          k.couleur != CouleurEtat.rouge &&
          k.couleur != CouleurEtat.orange,
    );
    return List.unmodifiable(
      [...rouges, ...oranges, ...projections].map(_surveille),
    );
  }

  static ChantierASurveiller _surveille(ChantierKpis k) => ChantierASurveiller(
    chantierId: k.chantierId,
    nom: k.chantier.nom,
    couleur: k.couleur,
    projectionRouge: k.projectionRouge,
  );
}
