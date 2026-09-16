import '../../../core/utils/rounding.dart';
import 'chantier_data.dart';
import 'resultats.dart';

/// R10 — complétude du prévisionnel : complet sans tâche si prix vendu,
/// budget, heures prévues et effectif sont renseignés (globaux ou dérivés).
/// La durée est seulement recommandée.
///
/// % = (nbObligatoiresRenseignés × 2 + nbRecommandésRenseignés) / 9 × 100.
abstract final class CompletudeCalculator {
  /// [data] est reçu pour homogénéité avec les autres calculateurs ; les
  /// valeurs dérivées viennent de [previsionnel] et [rentabilite].
  static CompletudeResult compute({
    required ChantierData data,
    required PrevisionnelResult previsionnel,
    required RentabiliteResult rentabilite,
  }) {
    final renseigne = <ChampPrevisionnel, bool>{
      ChampPrevisionnel.prixVendu: rentabilite.prixVenduCents > 0,
      ChampPrevisionnel.budget: previsionnel.budgetDepensesCents != null,
      ChampPrevisionnel.heuresPrevues:
          previsionnel.heuresPrevuesMinutes != null,
      ChampPrevisionnel.effectif: previsionnel.effectifPrevu != null,
      ChampPrevisionnel.duree: previsionnel.dureePrevueJours != null,
    };

    var points = 0;
    var pointsMax = 0;
    final manquants = <ChampPrevisionnel>[];
    for (final champ in ChampPrevisionnel.values) {
      final poids = _poids(champ);
      pointsMax += poids;
      if (renseigne[champ] ?? false) {
        points += poids;
      } else {
        manquants.add(champ);
      }
    }

    return CompletudeResult(
      pct: Rounding.halfUp(points / pointsMax * 100),
      manquants: List.unmodifiable(manquants),
    );
  }

  /// Obligatoire = 2 points, recommandé = 1 point (total 9).
  static int _poids(ChampPrevisionnel champ) => champ.obligatoire ? 2 : 1;
}
