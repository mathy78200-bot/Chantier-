import '../../../core/errors/app_exception.dart';
import '../../../shared/firestore_paths.dart';
import '../../../shared/firestore_subcollection_repository.dart';
import '../domain/tache_chantier.dart';
import '../domain/tache_repository.dart';

/// Tâches d'un chantier (`chantiers/{cid}/taches/{id}`), triées par `ordre`
/// croissant.
///
/// R5 : la tâche porte ses propres valeurs (`*Snapshot`) ; ce repository ne
/// lit jamais la bibliothèque.
class FirestoreTacheRepository
    extends FirestoreSubcollectionRepository<TacheChantier>
    implements TacheRepository {
  FirestoreTacheRepository({
    required super.firestore,
    required super.uid,
    super.onWriteError,
  }) : super(
         sousCollection: FirestorePaths.taches,
         fromJson: TacheChantier.fromJson,
         toJson: (t) => t.toJson(),
         idOf: (t) => t.id,
         chantierIdOf: (t) => t.chantierId,
         orderBy: 'ordre',
         descending: false,
       );

  @override
  void valider(TacheChantier entite) {
    super.valider(entite);
    if (entite.libelle.trim().isEmpty) {
      throw const ValidationException(
        'Le libellé de la tâche est obligatoire.',
      );
    }
    if (!entite.quantitePrevue.isFinite || entite.quantitePrevue <= 0) {
      throw const ValidationException(
        'La quantité prévue doit être strictement positive.',
      );
    }
    final snapshot = entite.minutesParUniteSnapshot;
    if (snapshot != null && (!snapshot.isFinite || snapshot < 0)) {
      throw const ValidationException(
        'Le temps par unité ne peut pas être négatif.',
      );
    }
    final effectifSnapshot = entite.effectifDefautSnapshot;
    if (effectifSnapshot != null && effectifSnapshot < 1) {
      throw const ValidationException(
        'L\'effectif par défaut doit être d\'au moins une personne.',
      );
    }
    final heures = entite.heuresPrevuesMinutes;
    if (heures != null && heures < 0) {
      throw const ValidationException(
        'Les heures prévues ne peuvent pas être négatives.',
      );
    }
    final effectif = entite.effectifPrevu;
    if (effectif != null && effectif < 1) {
      throw const ValidationException(
        'L\'effectif prévu doit être d\'au moins une personne.',
      );
    }
    final version = entite.bibliothequeVersion;
    if (version != null && version < 1) {
      throw const ValidationException(
        'La version de bibliothèque doit être d\'au moins 1.',
      );
    }
    if (entite.ordre < 0) {
      throw const ValidationException('L\'ordre ne peut pas être négatif.');
    }
  }
}
