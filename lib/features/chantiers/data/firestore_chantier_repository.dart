import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/enums.dart';
import '../../../core/errors/app_exception.dart';
import '../../../shared/firestore_codec.dart';
import '../../../shared/firestore_paths.dart';
import '../../../shared/firestore_subcollection_repository.dart';
import '../../../shared/write_error_notifier.dart';
import '../domain/chantier.dart';
import '../domain/chantier_repository.dart';
import '../domain/previsionnel.dart';

/// Chantiers de l'utilisateur (`users/{uid}/chantiers/{cid}`) et leur
/// prévisionnel (`chantiers/{cid}/previsionnel/main`).
///
/// R6 : soft delete uniquement. R7 : écritures optimistes non attendues.
/// §9.12 : `set(merge: true)` / `update`, jamais de `set` complet.
class FirestoreChantierRepository
    with EcritureOptimiste
    implements ChantierRepository {
  FirestoreChantierRepository({
    required this.firestore,
    required this.uid,
    WriteErrorHandler? onWriteError,
  }) : onWriteError = onWriteError ?? journaliserErreurEcriture;

  final FirebaseFirestore firestore;
  final String uid;

  @override
  final WriteErrorHandler onWriteError;

  CollectionReference<Map<String, dynamic>> get collection =>
      firestore.collection(FirestorePaths.chantiersDe(uid));

  DocumentReference<Map<String, dynamic>> document(String id) =>
      collection.doc(id);

  DocumentReference<Map<String, dynamic>> previsionnelDocument(
    String chantierId,
  ) => firestore.doc(FirestorePaths.previsionnelDoc(uid, chantierId));

  Chantier _depuisDocument(DocumentSnapshot<Map<String, dynamic>> snapshot) =>
      Chantier.fromJson(FirestoreCodec.fromDoc(snapshot));

  List<Chantier> _depuisSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) => snapshot.docs.map(_depuisDocument).toList(growable: false);

  /// §9.3 : tri secondaire stable sur `nom` (réordonnancement d'`updatedAt`
  /// à la synchronisation des écritures hors-ligne).
  @override
  Stream<List<Chantier>> watchActifs() => collection
      .where('deletedAt', isNull: true)
      .orderBy('updatedAt', descending: true)
      .orderBy('nom')
      .snapshots()
      .map(_depuisSnapshot);

  @override
  Stream<List<Chantier>> watchCorbeille() => collection
      .where('deletedAt', isNull: false)
      .orderBy('deletedAt', descending: true)
      .snapshots()
      .map(_depuisSnapshot);

  @override
  Stream<Chantier?> watchById(String id) => document(id)
      .snapshots()
      .map((snapshot) => snapshot.exists ? _depuisDocument(snapshot) : null);

  /// Le document `previsionnel/main` ne stocke pas `chantierId` (§5) : il est
  /// injecté à la lecture s'il est absent.
  @override
  Stream<Previsionnel?> watchPrevisionnel(String chantierId) =>
      previsionnelDocument(chantierId).snapshots().map((snapshot) {
        if (!snapshot.exists) return null;
        final json = FirestoreCodec.fromDoc(snapshot);
        json.putIfAbsent('chantierId', () => chantierId);
        return Previsionnel.fromJson(json);
      });

  /// Invariants vérifiés avant écriture (§9.2).
  void validerChantier(Chantier chantier) {
    if (chantier.id.trim().isEmpty) {
      throw const ValidationException('Identifiant manquant.');
    }
    if (chantier.nom.trim().isEmpty) {
      throw const ValidationException('Le nom du chantier est obligatoire.');
    }
    if (chantier.prixVenduInitialCents < 0) {
      throw const ValidationException(
        'Le prix vendu ne peut pas être négatif.',
      );
    }
  }

  /// Invariants vérifiés avant écriture (§9.2).
  void validerPrevisionnel(Previsionnel previsionnel) {
    if (previsionnel.chantierId.trim().isEmpty) {
      throw const ValidationException(
        'Le prévisionnel doit être rattaché à un chantier.',
      );
    }
    final budget = previsionnel.budgetDepensesCents;
    if (budget != null && budget < 0) {
      throw const ValidationException(
        'Le budget de dépenses ne peut pas être négatif.',
      );
    }
    final typesConnus = TypeDepense.values.map((t) => t.name).toSet();
    for (final entry in previsionnel.budgetParTypeCents.entries) {
      if (!typesConnus.contains(entry.key)) {
        throw ValidationException(
          'Type de dépense inconnu dans le budget : ${entry.key}.',
        );
      }
      if (entry.value < 0) {
        throw const ValidationException(
          'Un budget par type ne peut pas être négatif.',
        );
      }
    }
    final heures = previsionnel.heuresPrevuesMinutes;
    if (heures != null && heures < 0) {
      throw const ValidationException(
        'Les heures prévues ne peuvent pas être négatives.',
      );
    }
    final charge = previsionnel.heuresPersonnesPrevuesMinutes;
    if (charge != null && charge < 0) {
      throw const ValidationException(
        'La charge prévue ne peut pas être négative.',
      );
    }
    final effectif = previsionnel.effectifPrevu;
    if (effectif != null && effectif < 1) {
      throw const ValidationException(
        'L\'effectif prévu doit être d\'au moins une personne.',
      );
    }
    final duree = previsionnel.dureePrevueJours;
    if (duree != null && duree < 0) {
      throw const ValidationException(
        'La durée prévue ne peut pas être négative.',
      );
    }
  }

  @override
  Future<void> upsert(Chantier chantier) {
    validerChantier(chantier);
    final ref = document(chantier.id);
    final data = FirestoreCodec.toDoc(chantier.toJson());
    ecrire(() => ref.set(data, SetOptions(merge: true)));
    return termine;
  }

  @override
  Future<void> upsertPrevisionnel(Previsionnel previsionnel) {
    validerPrevisionnel(previsionnel);
    final ref = previsionnelDocument(previsionnel.chantierId);
    // `chantierId` est porté par le chemin, pas par le document (§5).
    final data = FirestoreCodec.toDoc(previsionnel.toJson())
      ..remove('chantierId');
    ecrire(() => ref.set(data, SetOptions(merge: true)));
    return termine;
  }

  @override
  Future<void> softDelete(String id, {String? reason}) {
    ecrire(
      () => document(id)
          .update(FirestoreSubcollectionRepository.champsSoftDelete(reason)),
    );
    return termine;
  }

  @override
  Future<void> restore(String id) {
    ecrire(
      () =>
          document(id).update(FirestoreSubcollectionRepository.champsRestore()),
    );
    return termine;
  }
}
