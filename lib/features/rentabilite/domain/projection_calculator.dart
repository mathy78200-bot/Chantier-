import 'dart:math' as math;

import '../../../core/constants/enums.dart';
import '../../../core/utils/rounding.dart';
import 'chantier_data.dart';
import 'couleur_calculator.dart';
import 'ecart_calculator.dart';
import 'resultats.dart';
import 'seuils.dart';

/// R8 — projection = indicateur SECONDAIRE. N'entre jamais dans la couleur
/// principale ni dans la rentabilité.
///
/// Null si le chantier n'est pas en cours, si les heures prévues totales sont
/// inconnues ou nulles, ou si l'avancement est inférieur au seuil.
/// Biais assumé (§9.7) : les achats de début de chantier surestiment la
/// projection, d'où [ProjectionResult.mention].
abstract final class ProjectionCalculator {
  static ProjectionResult? compute({
    required ChantierData data,
    required DepensesResult depenses,
    required HeuresResult heures,
    required PrevisionnelResult previsionnel,
    required Seuils seuils,
  }) {
    if (data.chantier.statut != StatutChantier.enCours) return null;

    final heuresPrevuesTotal = previsionnel.heuresPrevuesTotalMinutes;
    if (heuresPrevuesTotal == null || heuresPrevuesTotal <= 0) return null;

    final avancementPct = math.min(
      100.0,
      Rounding.toDecimals(heures.dureeMinutes / heuresPrevuesTotal * 100, 1),
    );
    // Un avancement nul rendrait la division impossible même avec un seuil à 0.
    if (avancementPct <= 0 || avancementPct < seuils.projectionPct) return null;

    final depensesProjeteesCents = Rounding.halfUp(
      depenses.totalCents / (avancementPct / 100),
    );
    final budgetTotal = previsionnel.budgetTotalCents;
    final ecartProjetePct = EcartCalculator.ecartPct(
      depensesProjeteesCents,
      budgetTotal,
    );

    return ProjectionResult(
      avancementPct: avancementPct,
      depensesProjeteesCents: depensesProjeteesCents,
      ecartProjeteCents: EcartCalculator.ecartAbsolu(
        depensesProjeteesCents,
        budgetTotal,
      ),
      ecartProjetePct: ecartProjetePct,
      couleur: CouleurCalculator.pourEcart(ecartProjetePct, seuils),
    );
  }
}
