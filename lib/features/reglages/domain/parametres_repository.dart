import 'parametres_utilisateur.dart';

abstract interface class ParametresRepository {
  /// Paramètres de l'utilisateur courant (valeurs par défaut si absents).
  Stream<ParametresUtilisateur> watch();

  Future<void> save(ParametresUtilisateur parametres);

  /// Crée `users/{uid}` (email, createdAt, paramètres par défaut) s'il
  /// n'existe pas encore. Appelé après connexion.
  Future<void> initialiserUtilisateur({required String email});
}
