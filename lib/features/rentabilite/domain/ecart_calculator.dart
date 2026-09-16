import '../../../core/constants/enums.dart';
import '../../../core/utils/rounding.dart';
import 'resultats.dart';

/// Écarts réel − prévu. `ecartDepensesPct` est l'indicateur PRINCIPAL.
///
/// R8 : ce calculateur ne connaît pas la projection ; un écart est null dès
/// que le prévu correspondant manque (ou vaut 0 pour un pourcentage).
abstract final class EcartCalculator {
  static EcartResult compute({
    required DepensesResult depenses,
    required HeuresResult heures,
    required PrevisionnelResult previsionnel,
  }) {
    final budgetTotal = previsionnel.budgetTotalCents;
    final heuresPrevuesTotal = previsionnel.heuresPrevuesTotalMinutes;
    final chargePrevueTotal = previsionnel.chargePrevueTotalMinutes;

    final ecartParTypeCents = <TypeDepense, int>{
      for (final budget in previsionnel.budgetParTypeCents.entries)
        budget.key: depenses.pourType(budget.key) - budget.value,
    };

    return EcartResult(
      ecartDepensesCents: ecartAbsolu(depenses.totalCents, budgetTotal),
      ecartDepensesPct: ecartPct(depenses.totalCents, budgetTotal),
      ecartParTypeCents: Map.unmodifiable(ecartParTypeCents),
      ecartHeuresMinutes: ecartAbsolu(heures.dureeMinutes, heuresPrevuesTotal),
      ecartHeuresPct: ecartPct(heures.dureeMinutes, heuresPrevuesTotal),
      ecartChargeMinutes: ecartAbsolu(heures.chargeMinutes, chargePrevueTotal),
      ecartChargePct: ecartPct(heures.chargeMinutes, chargePrevueTotal),
    );
  }

  /// reel − prevu, null sans prévu.
  static int? ecartAbsolu(int reel, int? prevu) =>
      prevu == null ? null : reel - prevu;

  /// (reel − prevu) / prevu × 100 (1 décimale), null si prevu null ou ≤ 0.
  static double? ecartPct(int reel, int? prevu) => prevu == null || prevu <= 0
      ? null
      : Rounding.toDecimals((reel - prevu) / prevu * 100, 1);
}
