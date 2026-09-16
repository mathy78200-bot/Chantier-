import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/firestore_codec.dart';
import '../../../shared/firestore_paths.dart';
import '../../../shared/firestore_subcollection_repository.dart';
import '../../justificatifs/domain/justificatif.dart';
import '../domain/depense.dart';
import '../domain/depense_repository.dart';

/// Dépenses d'un chantier (`chantiers/{cid}/depenses/{id}`), triées par
/// `date` décroissante.
///
/// R4 : une dépense appartient toujours à un chantier.
class FirestoreDepenseRepository
    extends FirestoreSubcollectionRepository<Depense>
    implements DepenseRepository {
  FirestoreDepenseRepository({
    required super.firestore,
    required super.uid,
    super.onWriteError,
  }) : super(
         sousCollection: FirestorePaths.depenses,
         fromJson: Depense.fromJson,
         toJson: (d) => d.toJson(),
         idOf: (d) => d.id,
         chantierIdOf: (d) => d.chantierId,
         orderBy: 'date',
       );

  static const Uuid _uuid = Uuid();

  @override
  void valider(Depense entite) {
    super.valider(entite);
    if (entite.montantCents < 0) {
      throw const ValidationException(
        'Le montant d\'une dépense ne peut pas être négatif.',
      );
    }
    final km = entite.distanceKm;
    if (km != null && (!km.isFinite || km < 0)) {
      throw const ValidationException('La distance ne peut pas être négative.');
    }
    final bareme = entite.baremeKmCentsSnapshot;
    if (bareme != null && bareme < 0) {
      throw const ValidationException(
        'Le barème kilométrique ne peut pas être négatif.',
      );
    }
  }

  /// Référence d'un justificatif d'un chantier.
  DocumentReference<Map<String, dynamic>> _justificatif(
    String chantierId,
    String id,
  ) => firestore.doc(
    '${FirestorePaths.sousCollection(uid, chantierId, FirestorePaths.justificatifs)}/$id',
  );

  /// §9.11 — copie la dépense (nouvel id UUID) sous le chantier cible, copie
  /// ses justificatifs sous le chantier cible (même id, `depenseId` réassigné,
  /// `storagePath` inchangé) et supprime (soft) l'originale et ses
  /// justificatifs, en un seul `WriteBatch` (pas de transaction, R7).
  ///
  /// Les justificatifs sont lus depuis le cache local en priorité ; la lecture
  /// et l'écriture s'exécutent en arrière-plan, la `Future` rendue est déjà
  /// complétée. Les erreurs remontent à `onWriteError`.
  @override
  Future<void> deplacerVers(Depense depense, String chantierCibleId) {
    if (chantierCibleId.trim().isEmpty) {
      throw const ValidationException('Chantier de destination manquant.');
    }
    if (chantierCibleId == depense.chantierId) {
      throw const ValidationException(
        'La dépense est déjà rattachée à ce chantier.',
      );
    }
    final nouvelId = _uuid.v4();
    final copie = depense.copyWith(
      id: nouvelId,
      chantierId: chantierCibleId,
      createdAt: null,
      updatedAt: null,
      deletedAt: null,
      deletedReason: null,
    );
    valider(copie);
    final raison = 'Déplacée vers $chantierCibleId';

    ecrire(() async {
      final batch = firestore.batch();
      batch.set(
        document(chantierCibleId, nouvelId),
        FirestoreCodec.toDoc(toJson(copie)),
        SetOptions(merge: true),
      );

      for (final justificatifId in depense.justificatifIds) {
        final origine = _justificatif(depense.chantierId, justificatifId);
        final snapshot = await _lire(origine);
        if (snapshot == null || !snapshot.exists) continue;
        final justificatif =
            Justificatif.fromJson(FirestoreCodec.fromDoc(snapshot)).copyWith(
              chantierId: chantierCibleId,
              depenseId: nouvelId,
              createdAt: null,
              updatedAt: null,
              deletedAt: null,
              deletedReason: null,
            );
        batch.set(
          _justificatif(chantierCibleId, justificatifId),
          FirestoreCodec.toDoc(justificatif.toJson()),
          SetOptions(merge: true),
        );
        batch.update(
          origine,
          FirestoreSubcollectionRepository.champsSoftDelete(raison),
        );
      }

      batch.update(
        document(depense.chantierId, depense.id),
        FirestoreSubcollectionRepository.champsSoftDelete(raison),
      );
      await batch.commit();
    });
    return termine;
  }

  /// Lecture cache d'abord (hors-ligne), serveur sinon.
  Future<DocumentSnapshot<Map<String, dynamic>>?> _lire(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      final cache = await ref.get(const GetOptions(source: Source.cache));
      if (cache.exists) return cache;
    } on FirebaseException {
      // Absent du cache : on interroge le serveur ci-dessous.
    }
    return ref.get();
  }
}
