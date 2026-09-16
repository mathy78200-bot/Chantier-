import '../../../core/constants/enums.dart';
import 'resultats.dart';
import 'seuils.dart';

/// Couleur PRINCIPALE d'un chantier.
///
/// gris si le prévisionnel est incomplet ; rouge si la rentabilité est
/// négative ou si l'écart dépenses dépasse le seuil rouge ; orange s'il dépasse
/// le seuil orange ; vert sinon.
///
/// R8 : la projection n'entre jamais ici ; elle utilise [pourEcart] avec son
/// propre écart pour obtenir sa couleur séparée.
abstract final class CouleurCalculator {
  static CouleurEtat compute({
    required CompletudeResult completude,
    required RentabiliteResult rentabilite,
    required EcartResult ecart,
    required Seuils seuils,
  }) {
    if (!completude.estComplet) return CouleurEtat.gris;
    if (rentabilite.estNegative) return CouleurEtat.rouge;
    final ecartPct = ecart.ecartDepensesPct;
    // Prévisionnel complet mais budget total nul : aucun écart calculable,
    // seule la rentabilité (déjà testée) peut alerter.
    if (ecartPct == null) return CouleurEtat.vert;
    return pourEcart(ecartPct, seuils);
  }

  /// Couleur d'un écart dépenses (%) seul : gris si null, rouge au-delà du
  /// seuil rouge, orange au-delà du seuil orange, vert sinon.
  static CouleurEtat pourEcart(double? ecartPct, Seuils seuils) {
    if (ecartPct == null) return CouleurEtat.gris;
    if (ecartPct > seuils.rougePct) return CouleurEtat.rouge;
    if (ecartPct > seuils.orangePct) return CouleurEtat.orange;
    return CouleurEtat.vert;
  }
}
