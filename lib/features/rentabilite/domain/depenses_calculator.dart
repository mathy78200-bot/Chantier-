import '../../../core/constants/enums.dart';
import 'chantier_data.dart';
import 'resultats.dart';

/// Σ dépenses (tous types) et répartitions par type, tâche et travaux sup.
///
/// Une dépense portant un `travauxSupId` est comptée une seule fois : dans
/// [DepensesResult.totalCents] (réel du chantier) et, en ventilation, dans
/// [DepensesResult.parTravauxSupCents] (réel du travaux sup).
abstract final class DepensesCalculator {
  static DepensesResult compute(ChantierData data) {
    var totalCents = 0;
    var horsTravauxSupCents = 0;
    final parTypeCents = <TypeDepense, int>{
      for (final type in TypeDepense.values) type: 0,
    };
    final parTravauxSupCents = <String, int>{};
    final parTacheCents = <String, int>{};

    for (final depense in data.depenses) {
      final montant = depense.montantCents;
      totalCents += montant;
      _ajoute(parTypeCents, depense.type, montant);

      final travauxSupId = depense.travauxSupId;
      if (travauxSupId == null) {
        horsTravauxSupCents += montant;
      } else {
        _ajoute(parTravauxSupCents, travauxSupId, montant);
      }

      final tacheId = depense.tacheId;
      if (tacheId != null) {
        _ajoute(parTacheCents, tacheId, montant);
      }
    }

    return DepensesResult(
      totalCents: totalCents,
      parTypeCents: Map.unmodifiable(parTypeCents),
      parTravauxSupCents: Map.unmodifiable(parTravauxSupCents),
      parTacheCents: Map.unmodifiable(parTacheCents),
      horsTravauxSupCents: horsTravauxSupCents,
      nbDepenses: data.depenses.length,
    );
  }

  static void _ajoute<K>(Map<K, int> cumul, K cle, int valeur) {
    cumul.update(cle, (v) => v + valeur, ifAbsent: () => valeur);
  }
}
