import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/constants/defaults.dart';
import '../../../core/constants/enums.dart';

part 'parametres_utilisateur.freezed.dart';
part 'parametres_utilisateur.g.dart';

/// Paramètres utilisateur (`users/{uid}.parametres`).
///
/// `modePrixParDefaut` ne sert qu'à pré-remplir le formulaire de création
/// (R2 : le mode d'un chantier est figé ensuite).
@freezed
abstract class ParametresUtilisateur with _$ParametresUtilisateur {
  const ParametresUtilisateur._();

  const factory ParametresUtilisateur({
    @Default(Defaults.modePrix) ModePrix modePrixParDefaut,
    @Default(Defaults.seuilOrangePct) double seuilOrangePct,
    @Default(Defaults.seuilRougePct) double seuilRougePct,
    @Default(Defaults.seuilProjectionPct) double seuilProjectionPct,
    @Default(Defaults.baremeKmCents) int baremeKmCents,
    @Default(Defaults.effectifParDefaut) int effectifParDefaut,
    @Default(Defaults.minutesJourneeType) int minutesJourneeType,
    @Default('') String entrepriseNom,
    DateTime? updatedAt,
  }) = _ParametresUtilisateur;

  factory ParametresUtilisateur.fromJson(Map<String, dynamic> json) =>
      _$ParametresUtilisateurFromJson(json);

  static const ParametresUtilisateur defaut = ParametresUtilisateur();
}
