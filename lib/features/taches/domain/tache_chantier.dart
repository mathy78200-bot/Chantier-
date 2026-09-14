import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/constants/enums.dart';
import '../../../core/utils/rounding.dart';

part 'tache_chantier.freezed.dart';
part 'tache_chantier.g.dart';

/// Tâche d'un chantier (`chantiers/{cid}/taches/{id}`).
///
/// R5 : copie ses valeurs de bibliothèque (`*Snapshot` + `bibliothequeVersion`)
/// au moment de la création ; les calculs n'utilisent que l'instance.
/// Une tâche liée à un travaux sup (`travauxSupId`) n'est pas « principale ».
@freezed
abstract class TacheChantier with _$TacheChantier {
  const TacheChantier._();

  const factory TacheChantier({
    required String id,
    required String chantierId,
    required String libelle,
    String? categorieId,
    String? sousCategorieId,
    String? bibliothequeTacheId,
    int? bibliothequeVersion,
    @Default(Unite.u) Unite unite,
    @Default(1.0) double quantitePrevue,

    /// Minutes par unité pour une personne (copie de la bibliothèque).
    double? minutesParUniteSnapshot,
    int? effectifDefautSnapshot,

    /// Durée prévue saisie directement (prioritaire sur la dérivation).
    int? heuresPrevuesMinutes,
    int? effectifPrevu,
    String? travauxSupId,
    @Default(StatutTache.aFaire) StatutTache statut,
    @Default(0) int ordre,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? deletedReason,
  }) = _TacheChantier;

  factory TacheChantier.fromJson(Map<String, dynamic> json) =>
      _$TacheChantierFromJson(json);

  bool get estSupprime => deletedAt != null;

  bool get estPrincipale => travauxSupId == null;

  /// Effectif retenu pour la tâche (saisi, sinon snapshot bibliothèque).
  int? get effectifEffectif => effectifPrevu ?? effectifDefautSnapshot;

  /// Charge prévue en personne-minutes : snapshot × quantité, ou durée saisie
  /// × effectif. Null si rien ne permet de la dériver.
  int? get chargePrevueMinutes {
    if (heuresPrevuesMinutes != null) {
      return heuresPrevuesMinutes! * (effectifEffectif ?? 1);
    }
    final snapshot = minutesParUniteSnapshot;
    if (snapshot == null) return null;
    return Rounding.toMinutes(snapshot * quantitePrevue);
  }

  /// Durée prévue en minutes : saisie, sinon charge / effectif.
  int? get dureePrevueMinutes {
    if (heuresPrevuesMinutes != null) return heuresPrevuesMinutes;
    final snapshot = minutesParUniteSnapshot;
    if (snapshot == null) return null;
    final effectif = effectifEffectif ?? 1;
    return Rounding.toMinutes(snapshot * quantitePrevue / effectif);
  }
}
