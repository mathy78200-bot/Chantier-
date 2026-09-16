import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/constants/defaults.dart';
import '../../../core/errors/app_exception.dart';
import '../../../shared/firestore_paths.dart';
import '../domain/justificatif.dart';

/// Envoi des fichiers de justificatifs vers Firebase Storage
/// (`users/{uid}/chantiers/{cid}/justificatifs/{id}.{ext}`).
///
/// Contrairement aux écritures Firestore, la `Future` d'[upload] **est**
/// attendue — par l'`UploadQueue` (étape 8), jamais par l'UI — pour passer le
/// justificatif de `uploading` à `uploaded` ou `failed`.
class JustificatifStorage {
  JustificatifStorage({required this.storage, required this.uid});

  final FirebaseStorage storage;
  final String uid;

  /// Chemin Storage du fichier d'un justificatif.
  String cheminDe(Justificatif justificatif) =>
      FirestorePaths.storageJustificatif(
        uid,
        justificatif.chantierId,
        justificatif.id,
        justificatif.extension,
      );

  /// Envoie [bytes] et retourne le chemin Storage à enregistrer dans
  /// `storagePath`. Lève une [ValidationException] si le type MIME n'est pas
  /// autorisé ou si le fichier dépasse 10 Mo (§9.6, miroir des règles).
  Future<String> upload({
    required Justificatif justificatif,
    required Uint8List bytes,
  }) async {
    if (!Justificatif.mimeAutorise(justificatif.mimeType)) {
      throw ValidationException(
        'Type de fichier non autorisé (${justificatif.mimeType}) : '
        'JPEG, PNG ou PDF uniquement.',
      );
    }
    if (bytes.isEmpty) {
      throw const ValidationException('Le fichier est vide.');
    }
    if (bytes.length > Defaults.justificatifMaxBytes) {
      throw const ValidationException(
        'Le fichier dépasse la taille maximale de 10 Mo.',
      );
    }
    final chemin = cheminDe(justificatif);
    await storage
        .ref(chemin)
        .putData(bytes, SettableMetadata(contentType: justificatif.mimeType));
    return chemin;
  }
}
