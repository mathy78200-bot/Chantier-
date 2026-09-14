import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/constants/enums.dart';

part 'bibliotheque_tache.freezed.dart';
part 'bibliotheque_tache.g.dart';

/// Tâche de bibliothèque (`users/{uid}/bibliothequeTaches/{id}`).
///
/// R5 : la bibliothèque ne modifie jamais le passé ; `version` est incrémentée
/// à chaque modification (règle Firestore : `version + 1` uniquement).
@freezed
abstract class BibliothequeTache with _$BibliothequeTache {
  const BibliothequeTache._();

  const factory BibliothequeTache({
    required String id,
    required String libelle,
    String? categorieId,
    String? sousCategorieId,
    @Default(Unite.u) Unite unite,

    /// Minutes par unité pour une personne.
    @Default(0.0) double minutesParUnite,
    @Default(1) int effectifDefaut,
    @Default(1) int version,
    @Default(true) bool actif,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _BibliothequeTache;

  factory BibliothequeTache.fromJson(Map<String, dynamic> json) =>
      _$BibliothequeTacheFromJson(json);
}
