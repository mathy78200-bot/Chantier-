import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/constants/enums.dart';

part 'previsionnel.freezed.dart';
part 'previsionnel.g.dart';

/// Prévisionnel d'un chantier (`chantiers/{cid}/previsionnel/main`).
///
/// R10 : complet sans tâche si prix vendu, budget, heures prévues et effectif
/// sont renseignés (ici, globaux) ou dérivés des tâches.
/// Les valeurs nulles signifient « non renseigné » (dérivation possible).
@freezed
abstract class Previsionnel with _$Previsionnel {
  const Previsionnel._();

  const factory Previsionnel({
    required String chantierId,
    int? budgetDepensesCents,

    /// Budget par type de dépense, clé = `TypeDepense.name`.
    @Default(<String, int>{}) Map<String, int> budgetParTypeCents,

    /// Durée prévue (Σ minutesParPersonne).
    int? heuresPrevuesMinutes,

    /// Charge prévue (Σ nbPersonnes × minutesParPersonne).
    int? heuresPersonnesPrevuesMinutes,
    int? effectifPrevu,
    int? dureePrevueJours,
    @Default('') String commentaire,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _Previsionnel;

  factory Previsionnel.fromJson(Map<String, dynamic> json) =>
      _$PrevisionnelFromJson(json);

  factory Previsionnel.vide(String chantierId) =>
      Previsionnel(chantierId: chantierId);

  int? budgetPourType(TypeDepense type) => budgetParTypeCents[type.name];

  /// Σ des budgets par type, ou null si aucun n'est renseigné.
  int? get sommeBudgetsParType => budgetParTypeCents.isEmpty
      ? null
      : budgetParTypeCents.values.fold<int>(0, (a, b) => a + b);
}
