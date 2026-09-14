/// Interface générique des sous-collections d'un chantier (dépenses, heures,
/// tâches, travaux sup, justificatifs).
///
/// R6 : soft delete uniquement. R7 : écritures optimistes, non attendues.
abstract interface class ChantierSubcollectionRepository<T> {
  /// Éléments non supprimés du chantier.
  Stream<List<T>> watchActifs(String chantierId);

  /// Éléments supprimés (corbeille) du chantier.
  Stream<List<T>> watchCorbeille(String chantierId);

  /// Création ou mise à jour par champs (`set(merge: true)`).
  Future<void> upsert(T entite);

  Future<void> softDelete(String chantierId, String id, {String? reason});

  Future<void> restore(String chantierId, String id);
}
