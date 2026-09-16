import 'chantier_data.dart';
import 'resultats.dart';

/// Σ heures : durée (Σ minutesParPersonne) et charge (Σ nb × minutes).
///
/// R1 : aucune conversion en coût. Les saisies portant un `travauxSupId` sont
/// comptées une seule fois dans le total du chantier et ventilées à part.
abstract final class HeuresCalculator {
  static HeuresResult compute(ChantierData data) {
    var dureeMinutes = 0;
    var chargeMinutes = 0;
    final chargeParTacheMinutes = <String, int>{};
    final dureeParTravauxSupMinutes = <String, int>{};
    final chargeParTravauxSupMinutes = <String, int>{};

    for (final saisie in data.heures) {
      final duree = saisie.minutesParPersonne;
      final charge = saisie.chargeMinutes;
      dureeMinutes += duree;
      chargeMinutes += charge;

      final tacheId = saisie.tacheId;
      if (tacheId != null) {
        _ajoute(chargeParTacheMinutes, tacheId, charge);
      }

      final travauxSupId = saisie.travauxSupId;
      if (travauxSupId != null) {
        _ajoute(dureeParTravauxSupMinutes, travauxSupId, duree);
        _ajoute(chargeParTravauxSupMinutes, travauxSupId, charge);
      }
    }

    return HeuresResult(
      dureeMinutes: dureeMinutes,
      chargeMinutes: chargeMinutes,
      chargeParTacheMinutes: Map.unmodifiable(chargeParTacheMinutes),
      dureeParTravauxSupMinutes: Map.unmodifiable(dureeParTravauxSupMinutes),
      chargeParTravauxSupMinutes: Map.unmodifiable(chargeParTravauxSupMinutes),
      nbSaisies: data.heures.length,
    );
  }

  static void _ajoute(Map<String, int> cumul, String cle, int valeur) {
    cumul.update(cle, (v) => v + valeur, ifAbsent: () => valeur);
  }
}
