import 'chantier.dart';
import 'previsionnel.dart';

/// Accès aux chantiers de l'utilisateur courant et à leur prévisionnel.
///
/// Écritures optimistes (R7) : les méthodes d'écriture rendent la main
/// immédiatement ; l'UI ne les attend jamais.
abstract interface class ChantierRepository {
  /// Chantiers non supprimés, triés par `updatedAt` décroissant puis `nom`.
  Stream<List<Chantier>> watchActifs();

  /// Corbeille (`deletedAt != null`).
  Stream<List<Chantier>> watchCorbeille();

  /// Un chantier (supprimé ou non), null s'il n'existe pas.
  Stream<Chantier?> watchById(String id);

  Stream<Previsionnel?> watchPrevisionnel(String chantierId);

  /// Création ou mise à jour par champs (`set(merge: true)`, §9.12).
  Future<void> upsert(Chantier chantier);

  Future<void> upsertPrevisionnel(Previsionnel previsionnel);

  Future<void> softDelete(String id, {String? reason});

  Future<void> restore(String id);
}
