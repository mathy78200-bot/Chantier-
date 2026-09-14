import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/constants/enums.dart';

part 'categorie.freezed.dart';
part 'categorie.g.dart';

/// Catégorie de dépense ou de tâche (`users/{uid}/categories/{id}`), avec ses
/// sous-catégories embarquées.
@freezed
abstract class Categorie with _$Categorie {
  const Categorie._();

  const factory Categorie({
    required String id,
    required String libelle,
    required DomaineCategorie domaine,
    @Default(0) int ordre,
    @Default(true) bool actif,
    @Default(<SousCategorie>[]) List<SousCategorie> sousCategories,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _Categorie;

  factory Categorie.fromJson(Map<String, dynamic> json) =>
      _$CategorieFromJson(json);

  List<SousCategorie> get sousCategoriesActives =>
      sousCategories.where((s) => s.actif).toList(growable: false);
}

@freezed
abstract class SousCategorie with _$SousCategorie {
  const factory SousCategorie({
    required String id,
    required String libelle,
    @Default(0) int ordre,
    @Default(true) bool actif,
  }) = _SousCategorie;

  factory SousCategorie.fromJson(Map<String, dynamic> json) =>
      _$SousCategorieFromJson(json);
}
