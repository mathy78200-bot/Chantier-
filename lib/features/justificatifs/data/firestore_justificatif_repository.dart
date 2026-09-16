import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/defaults.dart';
import '../../../core/constants/enums.dart';
import '../../../core/errors/app_exception.dart';
import '../../../shared/firestore_paths.dart';
import '../../../shared/firestore_subcollection_repository.dart';
import '../domain/justificatif.dart';
import '../domain/justificatif_repository.dart';

/// Justificatifs d'un chantier (`chantiers/{cid}/justificatifs/{id}`), triés
/// par `createdAt` décroissant.
///
/// Le fichier lui-même est géré par `JustificatifStorage` ; ce repository ne
/// manipule que les métadonnées et le statut d'envoi.
class FirestoreJustificatifRepository
    extends FirestoreSubcollectionRepository<Justificatif>
    implements JustificatifRepository {
  FirestoreJustificatifRepository({
    required super.firestore,
    required super.uid,
    super.onWriteError,
  }) : super(
         sousCollection: FirestorePaths.justificatifs,
         fromJson: Justificatif.fromJson,
         toJson: (j) => j.toJson(),
         idOf: (j) => j.id,
         chantierIdOf: (j) => j.chantierId,
         orderBy: 'createdAt',
       );

  /// Statuts « non envoyé » parcourus par l'`UploadQueue` (étape 8).
  static final List<String> statutsEnAttente = [
    UploadStatus.pending.name,
    UploadStatus.uploading.name,
    UploadStatus.failed.name,
  ];

  /// Bornes des règles : type MIME autorisé, `0 ≤ sizeBytes ≤ 10 Mo` (§9.6).
  @override
  void valider(Justificatif entite) {
    super.valider(entite);
    if (!Justificatif.mimeAutorise(entite.mimeType)) {
      throw ValidationException(
        'Type de fichier non autorisé (${entite.mimeType}) : '
        'JPEG, PNG ou PDF uniquement.',
      );
    }
    if (entite.sizeBytes < 0) {
      throw const ValidationException(
        'La taille du fichier ne peut pas être négative.',
      );
    }
    if (entite.sizeBytes > Defaults.justificatifMaxBytes) {
      throw const ValidationException(
        'Le fichier dépasse la taille maximale de 10 Mo.',
      );
    }
  }

  @override
  Stream<List<Justificatif>> watchEnAttente(String chantierId) =>
      collection(chantierId)
          .where('deletedAt', isNull: true)
          .where('uploadStatus', whereIn: statutsEnAttente)
          .snapshots()
          .map(depuisSnapshot);

  @override
  Future<void> changerStatut(
    String chantierId,
    String id,
    UploadStatus statut, {
    String? storagePath,
  }) {
    final champs = <String, Object?>{
      'uploadStatus': statut.name,
      'storagePath': ?storagePath,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    ecrire(() => document(chantierId, id).update(champs));
    return termine;
  }
}
