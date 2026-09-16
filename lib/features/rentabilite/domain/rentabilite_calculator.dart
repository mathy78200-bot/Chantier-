import '../../../core/utils/rounding.dart';
import '../../travaux_sup/domain/travaux_supplementaire.dart';
import 'chantier_data.dart';
import 'depenses_calculator.dart';
import 'resultats.dart';

/// R1 — rentabilité = prix vendu − dépenses. SEUL endroit qui calcule
/// `rentabiliteCents` ; les heures et l'effectif ne sont jamais convertis en
/// coût.
///
/// R3 — prix vendu = prix initial + Σ TS acceptés ; les TS proposés forment un
/// potentiel affiché à part ; les TS refusés sont ignorés.
abstract final class RentabiliteCalculator {
  static RentabiliteResult compute(ChantierData data) {
    final prixVenduInitialCents = data.chantier.prixVenduInitialCents;
    final travauxSupAcceptesCents = _sommePrixVendu(data.travauxSupAcceptes);
    final potentielTravauxSupCents = _sommePrixVendu(data.travauxSupProposes);
    final prixVenduCents = prixVenduInitialCents + travauxSupAcceptesCents;
    final depensesCents = DepensesCalculator.compute(data).totalCents;
    final rentabiliteCents = prixVenduCents - depensesCents;

    return RentabiliteResult(
      prixVenduInitialCents: prixVenduInitialCents,
      travauxSupAcceptesCents: travauxSupAcceptesCents,
      prixVenduCents: prixVenduCents,
      potentielTravauxSupCents: potentielTravauxSupCents,
      depensesCents: depensesCents,
      rentabiliteCents: rentabiliteCents,
      margePct: margePct(rentabiliteCents, prixVenduCents),
    );
  }

  /// rentabilite / prixVendu × 100 (1 décimale), null si prixVendu ≤ 0.
  static double? margePct(int rentabiliteCents, int prixVenduCents) =>
      prixVenduCents > 0
      ? Rounding.toDecimals(rentabiliteCents / prixVenduCents * 100, 1)
      : null;

  static int _sommePrixVendu(Iterable<TravauxSupplementaire> travauxSup) =>
      travauxSup.fold<int>(0, (somme, ts) => somme + ts.prixVenduCents);
}
