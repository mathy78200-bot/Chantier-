import 'package:freezed_annotation/freezed_annotation.dart';

part 'saisie_heures.freezed.dart';
part 'saisie_heures.g.dart';

/// Saisie d'heures (`chantiers/{cid}/heures/{id}`).
///
/// R1 : jamais convertie en coût.
/// Durée = `minutesParPersonne` ; charge = `nbPersonnes × minutesParPersonne`.
@freezed
abstract class SaisieHeures with _$SaisieHeures {
  const SaisieHeures._();

  const factory SaisieHeures({
    required String id,
    required String chantierId,
    required DateTime date,
    String? tacheId,
    String? tacheLibelleSnapshot,
    String? travauxSupId,
    @Default(1) int nbPersonnes,
    @Default(0) int minutesParPersonne,
    @Default('') String commentaire,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? deletedReason,
  }) = _SaisieHeures;

  factory SaisieHeures.fromJson(Map<String, dynamic> json) =>
      _$SaisieHeuresFromJson(json);

  bool get estSupprime => deletedAt != null;

  /// Charge en personne-minutes.
  int get chargeMinutes => nbPersonnes * minutesParPersonne;
}
