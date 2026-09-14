import '../../../core/constants/enums.dart';
import 'bibliotheque_tache.dart';
import 'categorie.dart';

abstract interface class BibliothequeRepository {
  Stream<List<BibliothequeTache>> watchTaches({bool inclureInactives = false});

  Stream<List<Categorie>> watchCategories({
    DomaineCategorie? domaine,
    bool inclureInactives = false,
  });

  /// Création : `version` forcée à 1.
  Future<void> creerTache(BibliothequeTache tache);

  /// Modification : écrit `tache.version + 1` (R5, règle Firestore).
  Future<void> modifierTache(BibliothequeTache tache);

  /// Archivage (`actif = false`) : pas de suppression physique (R6).
  Future<void> archiverTache(String id, {bool actif = false});

  Future<void> upsertCategorie(Categorie categorie);

  Future<void> archiverCategorie(String id, {bool actif = false});
}
