import 'dart:math' as math;

import '../../../core/constants/enums.dart';
import '../../../core/utils/date_utils.dart';
import '../../chantiers/domain/previsionnel.dart';
import '../../taches/domain/tache_chantier.dart';
import '../../travaux_sup/domain/travaux_supplementaire.dart';
import 'chantier_data.dart';
import 'resultats.dart';

/// Prévisionnel consolidé : valeur globale saisie, sinon dérivée des tâches
/// principales (ou des dates prévues), puis augmentée des travaux sup
/// acceptés.
///
/// R10 : les tâches sont optionnelles ; sans prévisionnel, tout est dérivé ou
/// null.
abstract final class PrevisionnelCalculator {
  static PrevisionnelResult compute(ChantierData data) {
    final previsionnel = data.previsionnel;
    final principales = data.tachesPrincipales;
    final acceptes = data.travauxSupAcceptes;

    // Budget : global, sinon Σ budgets par type.
    final budgetGlobal = previsionnel?.budgetDepensesCents;
    final budgetParType = previsionnel?.sommeBudgetsParType;
    final budgetDeriveParType = budgetGlobal == null && budgetParType != null;
    final budgetDepensesCents = budgetGlobal ?? budgetParType;
    final budgetTotalCents = budgetDepensesCents == null
        ? null
        : budgetDepensesCents + _sommeBudgetsTravauxSup(acceptes);

    // Heures prévues (durée) : globales, sinon Σ tâches principales.
    final heuresGlobales = previsionnel?.heuresPrevuesMinutes;
    final heuresTaches = _sommeNullable(
      principales.map((t) => t.dureePrevueMinutes),
    );
    final heuresDeriveesDesTaches =
        heuresGlobales == null && heuresTaches != null;
    final heuresPrevuesMinutes = heuresGlobales ?? heuresTaches;
    final heuresPrevuesTotalMinutes = heuresPrevuesMinutes == null
        ? null
        : heuresPrevuesMinutes + _sommeHeuresTravauxSup(acceptes);

    // Effectif : global, sinon max des tâches principales.
    final effectifGlobal = previsionnel?.effectifPrevu;
    final effectifTaches = _maxEffectif(principales);
    final effectifDeriveDesTaches =
        effectifGlobal == null && effectifTaches != null;
    final effectifPrevu = effectifGlobal ?? effectifTaches;

    // Charge prévue : globale, sinon Σ tâches principales, sinon
    // heures × effectif si les deux sont connus.
    final chargeGlobale = previsionnel?.heuresPersonnesPrevuesMinutes;
    final chargeTaches = _sommeNullable(
      principales.map((t) => t.chargePrevueMinutes),
    );
    final int? chargePrevueMinutes;
    final bool chargeDeriveeDesTaches;
    if (chargeGlobale != null) {
      chargePrevueMinutes = chargeGlobale;
      chargeDeriveeDesTaches = false;
    } else if (chargeTaches != null) {
      chargePrevueMinutes = chargeTaches;
      chargeDeriveeDesTaches = true;
    } else if (heuresPrevuesMinutes != null && effectifPrevu != null) {
      chargePrevueMinutes = heuresPrevuesMinutes * effectifPrevu;
      chargeDeriveeDesTaches =
          heuresDeriveesDesTaches || effectifDeriveDesTaches;
    } else {
      chargePrevueMinutes = null;
      chargeDeriveeDesTaches = false;
    }
    final chargePrevueTotalMinutes = chargePrevueMinutes == null
        ? null
        : chargePrevueMinutes + _sommeChargeTravauxSup(acceptes);

    // Durée en jours : globale, sinon jours ouvrés entre les dates prévues.
    final dureeGlobale = previsionnel?.dureePrevueJours;
    final dateDebut = data.chantier.dateDebutPrevue;
    final dateFin = data.chantier.dateFinPrevue;
    final dureeDates = dateDebut != null && dateFin != null
        ? DateFmt.joursOuvres(dateDebut, dateFin)
        : null;
    final dureeDeriveeDesDates = dureeGlobale == null && dureeDates != null;
    final dureePrevueJours = dureeGlobale ?? dureeDates;

    return PrevisionnelResult(
      budgetDepensesCents: budgetDepensesCents,
      budgetTotalCents: budgetTotalCents,
      budgetParTypeCents: _budgetParType(previsionnel),
      heuresPrevuesMinutes: heuresPrevuesMinutes,
      heuresPrevuesTotalMinutes: heuresPrevuesTotalMinutes,
      chargePrevueMinutes: chargePrevueMinutes,
      chargePrevueTotalMinutes: chargePrevueTotalMinutes,
      effectifPrevu: effectifPrevu,
      dureePrevueJours: dureePrevueJours,
      budgetDeriveParType: budgetDeriveParType,
      heuresDeriveesDesTaches: heuresDeriveesDesTaches,
      chargeDeriveeDesTaches: chargeDeriveeDesTaches,
      effectifDeriveDesTaches: effectifDeriveDesTaches,
      dureeDeriveeDesDates: dureeDeriveeDesDates,
    );
  }

  /// Budgets par type (clés `TypeDepense.name`) → `Map<TypeDepense, int>`.
  /// Les clés inconnues sont ignorées ; seuls les types budgétés figurent.
  static Map<TypeDepense, int> _budgetParType(Previsionnel? previsionnel) {
    if (previsionnel == null) return const {};
    final parNom = TypeDepense.values.asNameMap();
    final result = <TypeDepense, int>{};
    for (final entry in previsionnel.budgetParTypeCents.entries) {
      final type = parNom[entry.key];
      if (type != null) result[type] = entry.value;
    }
    return Map.unmodifiable(result);
  }

  /// Σ des valeurs non nulles, ou null si aucune valeur n'est dérivable.
  static int? _sommeNullable(Iterable<int?> valeurs) {
    int? somme;
    for (final v in valeurs) {
      if (v != null) somme = (somme ?? 0) + v;
    }
    return somme;
  }

  /// Max des effectifs (saisi ou snapshot) des tâches, null si aucun.
  static int? _maxEffectif(Iterable<TacheChantier> taches) {
    int? max;
    for (final t in taches) {
      final effectif = t.effectifEffectif;
      if (effectif != null) {
        max = max == null ? effectif : math.max(max, effectif);
      }
    }
    return max;
  }

  static int _sommeBudgetsTravauxSup(Iterable<TravauxSupplementaire> ts) =>
      ts.fold<int>(0, (s, t) => s + (t.budgetDepensesCents ?? 0));

  static int _sommeHeuresTravauxSup(Iterable<TravauxSupplementaire> ts) =>
      ts.fold<int>(0, (s, t) => s + (t.heuresPrevuesMinutes ?? 0));

  /// Charge prévue d'un TS : heures prévues × (effectif prévu, sinon 1).
  static int _sommeChargeTravauxSup(Iterable<TravauxSupplementaire> ts) =>
      ts.fold<int>(
        0,
        (s, t) => s + (t.heuresPrevuesMinutes ?? 0) * (t.effectifPrevu ?? 1),
      );
}
