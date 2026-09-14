import '../../../shared/chantier_subcollection_repository.dart';
import 'depense.dart';

abstract interface class DepenseRepository
    implements ChantierSubcollectionRepository<Depense> {
  /// Copie la dépense (nouvel id) vers `chantierCibleId`, réassigne ses
  /// justificatifs (copie sous le chantier cible, `depenseId` mis à jour,
  /// fichier Storage inchangé — §9.11) et supprime (soft) l'originale.
  Future<void> deplacerVers(Depense depense, String chantierCibleId);
}
