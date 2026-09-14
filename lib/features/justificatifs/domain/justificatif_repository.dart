import '../../../core/constants/enums.dart';
import '../../../shared/chantier_subcollection_repository.dart';
import 'justificatif.dart';

abstract interface class JustificatifRepository
    implements ChantierSubcollectionRepository<Justificatif> {
  /// Justificatifs non envoyés (`pending`, `uploading`, `failed`) du chantier,
  /// pour l'`UploadQueue` (étape 8) qui parcourt les chantiers actifs.
  Stream<List<Justificatif>> watchEnAttente(String chantierId);

  Future<void> changerStatut(
    String chantierId,
    String id,
    UploadStatus statut, {
    String? storagePath,
  });
}
