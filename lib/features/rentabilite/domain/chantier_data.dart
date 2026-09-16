import '../../chantiers/domain/chantier.dart';
import '../../chantiers/domain/previsionnel.dart';
import '../../depenses/domain/depense.dart';
import '../../heures/domain/saisie_heures.dart';
import '../../taches/domain/tache_chantier.dart';
import '../../travaux_sup/domain/travaux_supplementaire.dart';

/// Données d'entrée des calculs d'un chantier. Dart pur.
///
/// Les éléments supprimés (soft delete) sont exclus dès la construction :
/// aucun calculateur n'a à filtrer `deletedAt`.
class ChantierData {
  ChantierData({
    required this.chantier,
    this.previsionnel,
    Iterable<Depense> depenses = const [],
    Iterable<SaisieHeures> heures = const [],
    Iterable<TacheChantier> taches = const [],
    Iterable<TravauxSupplementaire> travauxSup = const [],
  }) : depenses = List.unmodifiable(depenses.where((d) => !d.estSupprime)),
       heures = List.unmodifiable(heures.where((h) => !h.estSupprime)),
       taches = List.unmodifiable(taches.where((t) => !t.estSupprime)),
       travauxSup = List.unmodifiable(
         travauxSup.where((ts) => !ts.estSupprime),
       );

  final Chantier chantier;
  final Previsionnel? previsionnel;
  final List<Depense> depenses;
  final List<SaisieHeures> heures;
  final List<TacheChantier> taches;
  final List<TravauxSupplementaire> travauxSup;

  String get chantierId => chantier.id;

  /// Tâches hors travaux sup.
  List<TacheChantier> get tachesPrincipales =>
      taches.where((t) => t.estPrincipale).toList(growable: false);

  List<TravauxSupplementaire> get travauxSupAcceptes =>
      travauxSup.where((ts) => ts.estAccepte).toList(growable: false);

  List<TravauxSupplementaire> get travauxSupProposes =>
      travauxSup.where((ts) => ts.estPropose).toList(growable: false);

  List<Depense> depensesDuTravauxSup(String travauxSupId) =>
      depenses.where((d) => d.travauxSupId == travauxSupId).toList();

  List<SaisieHeures> heuresDuTravauxSup(String travauxSupId) =>
      heures.where((h) => h.travauxSupId == travauxSupId).toList();

  List<SaisieHeures> heuresDeLaTache(String tacheId) =>
      heures.where((h) => h.tacheId == tacheId).toList();
}
