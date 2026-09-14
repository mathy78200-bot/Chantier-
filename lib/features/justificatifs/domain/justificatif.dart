import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/constants/enums.dart';

part 'justificatif.freezed.dart';
part 'justificatif.g.dart';

/// Justificatif (`chantiers/{cid}/justificatifs/{id}`).
///
/// Fichier Storage : `users/{uid}/chantiers/{cid}/justificatifs/{id}.{ext}`.
/// §9.5 : le fichier local en attente est reconstruit depuis `id` + `mimeType`
/// (`<appDocuments>/justificatifs/{id}.{ext}`), jamais persisté à part.
@freezed
abstract class Justificatif with _$Justificatif {
  const Justificatif._();

  const factory Justificatif({
    required String id,
    required String chantierId,
    String? depenseId,
    String? storagePath,
    @Default(UploadStatus.pending) UploadStatus uploadStatus,
    @Default('image/jpeg') String mimeType,
    @Default(0) int sizeBytes,
    DateTime? takenAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? deletedReason,
  }) = _Justificatif;

  factory Justificatif.fromJson(Map<String, dynamic> json) =>
      _$JustificatifFromJson(json);

  static const Map<String, String> extensionsParMime = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'application/pdf': 'pdf',
  };

  static bool mimeAutorise(String mime) => extensionsParMime.containsKey(mime);

  bool get estSupprime => deletedAt != null;

  String get extension => extensionsParMime[mimeType] ?? 'bin';

  /// Nom de fichier déterministe (local et Storage).
  String get nomFichier => '$id.$extension';

  bool get estEnAttente => uploadStatus != UploadStatus.uploaded;
}
