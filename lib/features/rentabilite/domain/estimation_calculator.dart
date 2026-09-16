import '../../../core/utils/rounding.dart';
import '../../taches/domain/tache_chantier.dart';
import 'chantier_data.dart';
import 'resultats.dart';

/// Comparaison estimation ↔ réel de chaque tâche (min/unité pour 1 personne).
///
/// R5 : n'utilise que les snapshots copiés dans l'instance de tâche, jamais
/// la bibliothèque. Toutes les tâches sont analysées (principales et liées à
/// un travaux sup), triées par `ordre` puis libellé.
abstract final class EstimationCalculator {
  static List<EstimationTache> compute(ChantierData data, HeuresResult heures) {
    final taches = List.of(data.taches)..sort(_ordre);
    return List.unmodifiable(taches.map((tache) => _analyse(tache, heures)));
  }

  static EstimationTache _analyse(TacheChantier tache, HeuresResult heures) {
    final chargeReelleMinutes = heures.chargeParTacheMinutes[tache.id] ?? 0;
    final quantite = tache.quantitePrevue;
    final snapshot = tache.minutesParUniteSnapshot;

    final minutesParUniteReel = quantite > 0 && chargeReelleMinutes > 0
        ? Rounding.toDecimals(chargeReelleMinutes / quantite, 1)
        : null;

    final ecartPct =
        snapshot != null && snapshot > 0 && minutesParUniteReel != null
        ? Rounding.toDecimals(
            (minutesParUniteReel - snapshot) / snapshot * 100,
            1,
          )
        : null;

    return EstimationTache(
      tacheId: tache.id,
      libelle: tache.libelle,
      unite: tache.unite,
      quantitePrevue: quantite,
      minutesParUniteSnapshot: snapshot,
      minutesParUniteReel: minutesParUniteReel,
      ecartPct: ecartPct,
      chargeReelleMinutes: chargeReelleMinutes,
      bibliothequeTacheId: tache.bibliothequeTacheId,
      bibliothequeVersion: tache.bibliothequeVersion,
    );
  }

  /// `ordre`, puis libellé (insensible à la casse), puis id pour un tri stable.
  static int _ordre(TacheChantier a, TacheChantier b) {
    final parOrdre = a.ordre.compareTo(b.ordre);
    if (parOrdre != 0) return parOrdre;
    final parLibelle = a.libelle.toLowerCase().compareTo(
      b.libelle.toLowerCase(),
    );
    if (parLibelle != 0) return parLibelle;
    return a.id.compareTo(b.id);
  }
}
