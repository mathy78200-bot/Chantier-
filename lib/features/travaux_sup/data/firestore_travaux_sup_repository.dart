import '../../../core/errors/app_exception.dart';
import '../../../shared/firestore_paths.dart';
import '../../../shared/firestore_subcollection_repository.dart';
import '../domain/travaux_sup_repository.dart';
import '../domain/travaux_supplementaire.dart';

/// Travaux supplémentaires d'un chantier (`chantiers/{cid}/travauxSup/{id}`),
/// triés par `dateProposition` décroissante.
///
/// R3 : le statut décide seul de l'entrée dans le prix vendu ; ce repository
/// ne calcule rien.
class FirestoreTravauxSupRepository
    extends FirestoreSubcollectionRepository<TravauxSupplementaire>
    implements TravauxSupRepository {
  FirestoreTravauxSupRepository({
    required super.firestore,
    required super.uid,
    super.onWriteError,
  }) : super(
         sousCollection: FirestorePaths.travauxSup,
         fromJson: TravauxSupplementaire.fromJson,
         toJson: (ts) => ts.toJson(),
         idOf: (ts) => ts.id,
         chantierIdOf: (ts) => ts.chantierId,
         orderBy: 'dateProposition',
       );

  @override
  void valider(TravauxSupplementaire entite) {
    super.valider(entite);
    if (entite.libelle.trim().isEmpty) {
      throw const ValidationException(
        'Le libellé des travaux supplémentaires est obligatoire.',
      );
    }
    if (entite.prixVenduCents < 0) {
      throw const ValidationException(
        'Le prix vendu ne peut pas être négatif.',
      );
    }
    final budget = entite.budgetDepensesCents;
    if (budget != null && budget < 0) {
      throw const ValidationException(
        'Le budget de dépenses ne peut pas être négatif.',
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
  }
}
