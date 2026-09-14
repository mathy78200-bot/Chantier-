import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/constants/enums.dart';

part 'travaux_supplementaire.freezed.dart';
part 'travaux_supplementaire.g.dart';

/// Travaux supplémentaires (`chantiers/{cid}/travauxSup/{id}`).
///
/// R3 : seul `accepte` entre dans le prix vendu ; `propose` = potentiel
/// affiché à part ; `refuse` = historique.
/// Réel d'un TS = Σ dépenses / heures portant son `travauxSupId`, comptées une
/// seule fois dans le chantier.
@freezed
abstract class TravauxSupplementaire with _$TravauxSupplementaire {
  const TravauxSupplementaire._();

  const factory TravauxSupplementaire({
    required String id,
    required String chantierId,
    required String libelle,
    required DateTime dateProposition,
    @Default('') String description,
    @Default(StatutTravauxSup.propose) StatutTravauxSup statut,
    @Default(0) int prixVenduCents,
    int? budgetDepensesCents,
    int? heuresPrevuesMinutes,
    int? effectifPrevu,
    DateTime? dateDecision,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? deletedReason,
  }) = _TravauxSupplementaire;

  factory TravauxSupplementaire.fromJson(Map<String, dynamic> json) =>
      _$TravauxSupplementaireFromJson(json);

  bool get estSupprime => deletedAt != null;

  bool get estAccepte => statut == StatutTravauxSup.accepte;

  bool get estPropose => statut == StatutTravauxSup.propose;
}
