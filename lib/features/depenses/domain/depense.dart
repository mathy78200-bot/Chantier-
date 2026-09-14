import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/constants/enums.dart';
import '../../../core/utils/rounding.dart';

part 'depense.freezed.dart';
part 'depense.g.dart';

/// Dépense (`chantiers/{cid}/depenses/{id}`).
///
/// R4 : appartient toujours à un chantier (`chantierId == cid`).
/// Déplacement : `montantCents = distanceKm × baremeKmCentsSnapshot` sauf si
/// `montantSaisiManuellement`.
@freezed
abstract class Depense with _$Depense {
  const Depense._();

  const factory Depense({
    required String id,
    required String chantierId,
    required DateTime date,
    @Default(TypeDepense.materiaux) TypeDepense type,
    @Default(0) int montantCents,
    @Default('') String libelle,
    String? fournisseur,
    String? categorieId,
    String? sousCategorieId,
    String? tacheId,
    String? travauxSupId,
    @Default(<String>[]) List<String> justificatifIds,
    double? distanceKm,
    int? baremeKmCentsSnapshot,
    @Default(false) bool montantSaisiManuellement,
    @Default('') String commentaire,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? deletedReason,
  }) = _Depense;

  factory Depense.fromJson(Map<String, dynamic> json) =>
      _$DepenseFromJson(json);

  bool get estSupprime => deletedAt != null;

  bool get estDeplacementAuBareme =>
      type == TypeDepense.deplacement &&
      !montantSaisiManuellement &&
      distanceKm != null &&
      baremeKmCentsSnapshot != null;

  /// Montant d'un déplacement au barème : km × barème (centimes/km).
  static int montantKmCents(double distanceKm, int baremeKmCents) =>
      Rounding.halfUp(distanceKm * baremeKmCents);
}
