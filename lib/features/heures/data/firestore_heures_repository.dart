import '../../../core/constants/defaults.dart';
import '../../../core/errors/app_exception.dart';
import '../../../shared/firestore_paths.dart';
import '../../../shared/firestore_subcollection_repository.dart';
import '../domain/heures_repository.dart';
import '../domain/saisie_heures.dart';

/// Saisies d'heures d'un chantier (`chantiers/{cid}/heures/{id}`), triées par
/// `date` décroissante.
///
/// R1 : les heures ne sont jamais converties en coût.
class FirestoreHeuresRepository
    extends FirestoreSubcollectionRepository<SaisieHeures>
    implements HeuresRepository {
  FirestoreHeuresRepository({
    required super.firestore,
    required super.uid,
    super.onWriteError,
  }) : super(
         sousCollection: FirestorePaths.heures,
         fromJson: SaisieHeures.fromJson,
         toJson: (h) => h.toJson(),
         idOf: (h) => h.id,
         chantierIdOf: (h) => h.chantierId,
         orderBy: 'date',
       );

  /// Bornes des règles Firestore : `nbPersonnes ≥ 1`,
  /// `0 ≤ minutesParPersonne ≤ 1440`.
  @override
  void valider(SaisieHeures entite) {
    super.valider(entite);
    if (entite.nbPersonnes < Defaults.nbPersonnesMin) {
      throw const ValidationException(
        'Le nombre de personnes doit être d\'au moins 1.',
      );
    }
    if (entite.minutesParPersonne < 0) {
      throw const ValidationException(
        'La durée par personne ne peut pas être négative.',
      );
    }
    if (entite.minutesParPersonne > Defaults.minutesParPersonneMax) {
      throw const ValidationException(
        'La durée par personne ne peut pas dépasser 24 h par saisie.',
      );
    }
  }
}
