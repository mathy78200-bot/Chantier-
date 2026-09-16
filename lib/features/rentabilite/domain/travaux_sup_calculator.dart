import '../../travaux_sup/domain/travaux_supplementaire.dart';
import 'chantier_data.dart';
import 'ecart_calculator.dart';
import 'rentabilite_calculator.dart';
import 'resultats.dart';

/// Analyse prévu vs réel de chaque travaux sup (acceptés, proposés, refusés),
/// triés par date de proposition puis libellé.
///
/// Réel d'un TS = Σ dépenses / heures portant son `travauxSupId`. La
/// rentabilité calculée ici est indicative : seul un TS accepté entre dans la
/// rentabilité du chantier (R3, garanti par `RentabiliteCalculator`).
abstract final class TravauxSupCalculator {
  static List<TravauxSupAnalyse> compute(
    ChantierData data,
    DepensesResult depenses,
    HeuresResult heures,
  ) {
    final travauxSup = List.of(data.travauxSup)..sort(_ordre);
    return List.unmodifiable(
      travauxSup.map((ts) => _analyse(ts, depenses, heures)),
    );
  }

  static TravauxSupAnalyse _analyse(
    TravauxSupplementaire ts,
    DepensesResult depenses,
    HeuresResult heures,
  ) {
    final depensesCents = depenses.parTravauxSupCents[ts.id] ?? 0;
    final dureeMinutes = heures.dureeParTravauxSupMinutes[ts.id] ?? 0;
    final chargeMinutes = heures.chargeParTravauxSupMinutes[ts.id] ?? 0;
    final rentabiliteCents = ts.prixVenduCents - depensesCents;

    return TravauxSupAnalyse(
      travauxSup: ts,
      depensesCents: depensesCents,
      dureeMinutes: dureeMinutes,
      chargeMinutes: chargeMinutes,
      rentabiliteCents: rentabiliteCents,
      margePct: RentabiliteCalculator.margePct(
        rentabiliteCents,
        ts.prixVenduCents,
      ),
      ecartDepensesCents: EcartCalculator.ecartAbsolu(
        depensesCents,
        ts.budgetDepensesCents,
      ),
      ecartDepensesPct: EcartCalculator.ecartPct(
        depensesCents,
        ts.budgetDepensesCents,
      ),
      ecartHeuresMinutes: EcartCalculator.ecartAbsolu(
        dureeMinutes,
        ts.heuresPrevuesMinutes,
      ),
      ecartHeuresPct: EcartCalculator.ecartPct(
        dureeMinutes,
        ts.heuresPrevuesMinutes,
      ),
    );
  }

  /// Date de proposition, puis libellé (insensible à la casse), puis id.
  static int _ordre(TravauxSupplementaire a, TravauxSupplementaire b) {
    final parDate = a.dateProposition.compareTo(b.dateProposition);
    if (parDate != 0) return parDate;
    final parLibelle = a.libelle.toLowerCase().compareTo(
      b.libelle.toLowerCase(),
    );
    if (parLibelle != 0) return parLibelle;
    return a.id.compareTo(b.id);
  }
}
