import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show protected;

import '../core/errors/app_exception.dart';
import 'chantier_subcollection_repository.dart';
import 'firestore_codec.dart';
import 'firestore_paths.dart';
import 'write_error_notifier.dart';

/// Rapporteur d'erreur d'écriture par défaut : journal de développement.
void journaliserErreurEcriture(Object error, StackTrace stackTrace) {
  developer.log(
    'Écriture Firestore refusée ou échouée',
    name: 'chantiers.data',
    level: 1000,
    error: error,
    stackTrace: stackTrace,
  );
}

/// R7 / §9.2 — écritures optimistes partagées par tous les repositories
/// Firestore.
///
/// Une écriture n'est **jamais attendue** : hors-ligne, la `Future` Firestore
/// ne se complète qu'à la synchronisation. Elle est lancée avec `unawaited`
/// et ses erreurs (refus de règle, réseau) sont remontées à [onWriteError].
mixin EcritureOptimiste {
  /// Rapporteur d'erreur d'écriture (défaut : [journaliserErreurEcriture]).
  WriteErrorHandler get onWriteError;

  /// Lance [action] sans l'attendre ; toute erreur, synchrone ou différée,
  /// est transmise à [onWriteError] et n'est jamais propagée à l'appelant.
  @protected
  void ecrire(Future<void> Function() action) {
    final Future<void> future;
    try {
      future = action();
    } catch (error, stackTrace) {
      onWriteError(error, stackTrace);
      return;
    }
    unawaited(
      future.catchError(
        (Object error, StackTrace stackTrace) =>
            onWriteError(error, stackTrace),
      ),
    );
  }

  /// `Future` déjà complétée rendue par les méthodes d'écriture (R7).
  @protected
  Future<void> get termine => Future<void>.value();
}

/// Implémentation Firestore générique d'une sous-collection de chantier
/// (`users/{uid}/chantiers/{cid}/{sousCollection}/{id}`).
///
/// - R6 : soft delete uniquement (`deletedAt`, `deletedReason`), aucun
///   `delete()` ;
/// - R7 : écritures optimistes non attendues (voir [EcritureOptimiste]) ;
/// - §9.2 : [valider] lève une [ValidationException] **avant** toute écriture,
///   en miroir des invariants des règles Firestore ;
/// - §9.12 : `set(merge: true)` ou `update`, jamais de `set` complet.
class FirestoreSubcollectionRepository<T>
    with EcritureOptimiste
    implements ChantierSubcollectionRepository<T> {
  FirestoreSubcollectionRepository({
    required this.firestore,
    required this.uid,
    required this.sousCollection,
    required this.fromJson,
    required this.toJson,
    required this.idOf,
    required this.chantierIdOf,
    this.orderBy = 'updatedAt',
    this.descending = true,
    WriteErrorHandler? onWriteError,
  }) : onWriteError = onWriteError ?? journaliserErreurEcriture;

  final FirebaseFirestore firestore;
  final String uid;

  /// Nom de la sous-collection (`FirestorePaths.depenses`, …).
  final String sousCollection;

  final T Function(Map<String, dynamic> json) fromJson;
  final Map<String, dynamic> Function(T entite) toJson;
  final String Function(T entite) idOf;
  final String Function(T entite) chantierIdOf;

  /// Champ de tri de [watchActifs].
  final String orderBy;
  final bool descending;

  @override
  final WriteErrorHandler onWriteError;

  /// Référence de la sous-collection d'un chantier.
  CollectionReference<Map<String, dynamic>> collection(String chantierId) =>
      firestore.collection(
        FirestorePaths.sousCollection(uid, chantierId, sousCollection),
      );

  /// Référence d'un document de la sous-collection.
  DocumentReference<Map<String, dynamic>> document(
    String chantierId,
    String id,
  ) => collection(chantierId).doc(id);

  /// Entité lue depuis un document.
  T depuisDocument(DocumentSnapshot<Map<String, dynamic>> snapshot) =>
      fromJson(FirestoreCodec.fromDoc(snapshot));

  /// Liste d'entités lue depuis un résultat de requête.
  List<T> depuisSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) =>
      snapshot.docs.map(depuisDocument).toList(growable: false);

  @override
  Stream<List<T>> watchActifs(String chantierId) =>
      collection(chantierId)
          .where('deletedAt', isNull: true)
          .orderBy(orderBy, descending: descending)
          .snapshots()
          .map(depuisSnapshot);

  @override
  Stream<List<T>> watchCorbeille(String chantierId) =>
      collection(chantierId)
          .where('deletedAt', isNull: false)
          .orderBy('deletedAt', descending: true)
          .snapshots()
          .map(depuisSnapshot);

  /// Invariants vérifiés avant toute écriture (§9.2), en miroir des règles
  /// Firestore. Les sous-classes appellent `super.valider(entite)` puis
  /// ajoutent leurs propres contrôles. Lève une [ValidationException].
  void valider(T entite) {
    if (idOf(entite).trim().isEmpty) {
      throw const ValidationException('Identifiant manquant.');
    }
    if (chantierIdOf(entite).trim().isEmpty) {
      throw const ValidationException(
        'Cet élément doit être rattaché à un chantier.',
      );
    }
  }

  @override
  Future<void> upsert(T entite) {
    valider(entite);
    final ref = document(chantierIdOf(entite), idOf(entite));
    final data = FirestoreCodec.toDoc(toJson(entite));
    ecrire(() => ref.set(data, SetOptions(merge: true)));
    return termine;
  }

  @override
  Future<void> softDelete(String chantierId, String id, {String? reason}) {
    ecrire(() => document(chantierId, id).update(champsSoftDelete(reason)));
    return termine;
  }

  @override
  Future<void> restore(String chantierId, String id) {
    ecrire(() => document(chantierId, id).update(champsRestore()));
    return termine;
  }

  /// Champs d'un soft delete (R6). `updatedAt` est posé par le serveur.
  static Map<String, Object?> champsSoftDelete(String? reason) => {
    'deletedAt': FieldValue.serverTimestamp(),
    'deletedReason': reason,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  /// Champs d'une restauration : `null` **explicite**, car la requête
  /// `where('deletedAt', isNull: true)` ne retient que les documents où le
  /// champ est présent à `null`.
  static Map<String, Object?> champsRestore() => {
    'deletedAt': null,
    'deletedReason': null,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
