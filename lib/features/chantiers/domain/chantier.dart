import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/constants/enums.dart';

part 'chantier.freezed.dart';
part 'chantier.g.dart';

/// Chantier (`users/{uid}/chantiers/{cid}`).
///
/// R2 : `modePrix` est figé à la création (règle Firestore `unchanged`).
/// R6 : soft delete via `deletedAt` / `deletedReason`.
@freezed
abstract class Chantier with _$Chantier {
  const Chantier._();

  const factory Chantier({
    required String id,
    required String nom,
    required ModePrix modePrix,
    @Default(StatutChantier.aFaireSigner) StatutChantier statut,
    @Default('') String clientNom,
    String? clientTelephone,
    @Default('') String adresse,
    @Default(0) int prixVenduInitialCents,
    DateTime? dateDevis,
    DateTime? dateSignature,
    DateTime? dateDebutPrevue,
    DateTime? dateFinPrevue,
    DateTime? dateDebutReelle,
    DateTime? dateFinReelle,
    @Default('') String notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? deletedReason,
  }) = _Chantier;

  factory Chantier.fromJson(Map<String, dynamic> json) =>
      _$ChantierFromJson(json);

  bool get estSupprime => deletedAt != null;

  bool get estSigne => statut.estSigne;
}
