import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/enums.dart';
import '../../../core/errors/app_exception.dart';
import '../../../shared/firestore_codec.dart';
import '../../../shared/firestore_paths.dart';
import '../../../shared/firestore_subcollection_repository.dart';
import '../../../shared/write_error_notifier.dart';
import '../domain/bibliotheque_repository.dart';
import '../domain/bibliotheque_tache.dart';
import '../domain/categorie.dart';

/// Bibliothèque de tâches (`users/{uid}/bibliothequeTaches/{id}`) et
/// catégories (`users/{uid}/categories/{id}`).
///
/// R5 : la bibliothèque ne modifie jamais le passé — `version` est
/// incrémentée à chaque modification (règle Firestore : `version + 1`).
/// R6 : archivage (`actif = false`), jamais de suppression physique.
class FirestoreBibliothequeRepository
    with EcritureOptimiste
    implements BibliothequeRepository {
  FirestoreBibliothequeRepository({
    required this.firestore,
    required this.uid,
    WriteErrorHandler? onWriteError,
  }) : onWriteError = onWriteError ?? journaliserErreurEcriture;

  final FirebaseFirestore firestore;
  final String uid;

  @override
  final WriteErrorHandler onWriteError;

  CollectionReference<Map<String, dynamic>> get taches =>
      firestore.collection(FirestorePaths.bibliothequeDe(uid));

  CollectionReference<Map<String, dynamic>> get categories =>
      firestore.collection(FirestorePaths.categoriesDe(uid));

  @override
  Stream<List<BibliothequeTache>> watchTaches({bool inclureInactives = false}) {
    Query<Map<String, dynamic>> query = taches;
    if (!inclureInactives) {
      query = query.where('actif', isEqualTo: true);
    }
    return query
        .orderBy('libelle')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((d) => BibliothequeTache.fromJson(FirestoreCodec.fromDoc(d)))
              .toList(growable: false),
        );
  }

  @override
  Stream<List<Categorie>> watchCategories({
    DomaineCategorie? domaine,
    bool inclureInactives = false,
  }) {
    Query<Map<String, dynamic>> query = categories;
    if (domaine != null) {
      query = query.where('domaine', isEqualTo: domaine.name);
    }
    if (!inclureInactives) {
      query = query.where('actif', isEqualTo: true);
    }
    return query
        .orderBy('ordre')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((d) => Categorie.fromJson(FirestoreCodec.fromDoc(d)))
              .toList(growable: false),
        );
  }

  /// Invariants vérifiés avant écriture (§9.2).
  void validerTache(BibliothequeTache tache) {
    if (tache.id.trim().isEmpty) {
      throw const ValidationException('Identifiant manquant.');
    }
    if (tache.libelle.trim().isEmpty) {
      throw const ValidationException(
        'Le libellé de la tâche est obligatoire.',
      );
    }
    if (!tache.minutesParUnite.isFinite || tache.minutesParUnite < 0) {
      throw const ValidationException(
        'Le temps par unité ne peut pas être négatif.',
      );
    }
    if (tache.effectifDefaut < 1) {
      throw const ValidationException(
        'L\'effectif par défaut doit être d\'au moins une personne.',
      );
    }
    if (tache.version < 1) {
      throw const ValidationException('La version doit être d\'au moins 1.');
    }
  }

  /// Invariants vérifiés avant écriture (§9.2).
  void validerCategorie(Categorie categorie) {
    if (categorie.id.trim().isEmpty) {
      throw const ValidationException('Identifiant manquant.');
    }
    if (categorie.libelle.trim().isEmpty) {
      throw const ValidationException(
        'Le libellé de la catégorie est obligatoire.',
      );
    }
    if (categorie.ordre < 0) {
      throw const ValidationException('L\'ordre ne peut pas être négatif.');
    }
    for (final sousCategorie in categorie.sousCategories) {
      if (sousCategorie.id.trim().isEmpty) {
        throw const ValidationException(
          'Identifiant de sous-catégorie manquant.',
        );
      }
      if (sousCategorie.libelle.trim().isEmpty) {
        throw const ValidationException(
          'Le libellé d\'une sous-catégorie est obligatoire.',
        );
      }
    }
  }

  /// Création : `version` forcée à 1.
  @override
  Future<void> creerTache(BibliothequeTache tache) {
    final creation = tache.copyWith(version: 1);
    validerTache(creation);
    final ref = taches.doc(creation.id);
    final data = FirestoreCodec.toDoc(creation.toJson());
    ecrire(() => ref.set(data, SetOptions(merge: true)));
    return termine;
  }

  /// Modification : écrit `tache.version + 1` (R5, règle Firestore).
  @override
  Future<void> modifierTache(BibliothequeTache tache) {
    final modification = tache.copyWith(version: tache.version + 1);
    validerTache(modification);
    final ref = taches.doc(modification.id);
    final data = FirestoreCodec.toDoc(modification.toJson());
    ecrire(() => ref.set(data, SetOptions(merge: true)));
    return termine;
  }

  @override
  Future<void> archiverTache(String id, {bool actif = false}) {
    ecrire(() => taches.doc(id).update(_champsActif(actif)));
    return termine;
  }

  @override
  Future<void> upsertCategorie(Categorie categorie) {
    validerCategorie(categorie);
    final ref = categories.doc(categorie.id);
    final data = FirestoreCodec.toDoc(categorie.toJson());
    ecrire(() => ref.set(data, SetOptions(merge: true)));
    return termine;
  }

  @override
  Future<void> archiverCategorie(String id, {bool actif = false}) {
    ecrire(() => categories.doc(id).update(_champsActif(actif)));
    return termine;
  }

  static Map<String, Object?> _champsActif(bool actif) => {
    'actif': actif,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
