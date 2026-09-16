import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/enums.dart';
import '../../features/bibliotheque/domain/bibliotheque_tache.dart';
import '../../features/bibliotheque/domain/categorie.dart';
import '../../features/chantiers/domain/chantier.dart';
import '../../features/chantiers/domain/previsionnel.dart';
import '../../features/depenses/domain/depense.dart';
import '../../features/heures/domain/saisie_heures.dart';
import '../../features/justificatifs/domain/justificatif.dart';
import '../../features/reglages/domain/parametres_utilisateur.dart';
import '../../features/taches/domain/tache_chantier.dart';
import '../../features/travaux_sup/domain/travaux_supplementaire.dart';
import 'repository_providers.dart';

/// Flux de données bruts (un flux Firestore par provider).
///
/// Tous `autoDispose` sauf [chantiersActifsProvider] et [parametresProvider],
/// utilisés en permanence (accueil, seuils). Chaque provider de chantier est
/// une `family` par `chantierId` : les six flux d'une fiche sont fermés dès
/// qu'elle n'est plus affichée (§9.4).

/// Chantiers non supprimés, triés par `updatedAt` décroissant puis `nom`.
final chantiersActifsProvider = StreamProvider<List<Chantier>>(
  (ref) => ref.watch(chantierRepositoryProvider).watchActifs(),
);

/// Corbeille des chantiers (R6).
final chantiersCorbeilleProvider = StreamProvider.autoDispose<List<Chantier>>(
  (ref) => ref.watch(chantierRepositoryProvider).watchCorbeille(),
);

/// Un chantier (supprimé ou non), `null` s'il n'existe pas.
final chantierProvider = StreamProvider.autoDispose.family<Chantier?, String>(
  (ref, id) => ref.watch(chantierRepositoryProvider).watchById(id),
);

/// Prévisionnel `chantiers/{id}/previsionnel/main`, `null` s'il est absent.
final previsionnelProvider = StreamProvider.autoDispose
    .family<Previsionnel?, String>(
      (ref, chantierId) =>
          ref.watch(chantierRepositoryProvider).watchPrevisionnel(chantierId),
    );

final depensesProvider = StreamProvider.autoDispose
    .family<List<Depense>, String>(
      (ref, chantierId) =>
          ref.watch(depenseRepositoryProvider).watchActifs(chantierId),
    );

final heuresProvider = StreamProvider.autoDispose
    .family<List<SaisieHeures>, String>(
      (ref, chantierId) =>
          ref.watch(heuresRepositoryProvider).watchActifs(chantierId),
    );

final tachesProvider = StreamProvider.autoDispose
    .family<List<TacheChantier>, String>(
      (ref, chantierId) =>
          ref.watch(tacheRepositoryProvider).watchActifs(chantierId),
    );

final travauxSupProvider = StreamProvider.autoDispose
    .family<List<TravauxSupplementaire>, String>(
      (ref, chantierId) =>
          ref.watch(travauxSupRepositoryProvider).watchActifs(chantierId),
    );

final justificatifsProvider = StreamProvider.autoDispose
    .family<List<Justificatif>, String>(
      (ref, chantierId) =>
          ref.watch(justificatifRepositoryProvider).watchActifs(chantierId),
    );

/// Paramètres de l'utilisateur (valeurs par défaut si le document est absent).
final parametresProvider = StreamProvider<ParametresUtilisateur>(
  (ref) => ref.watch(parametresRepositoryProvider).watch(),
);

/// Tâches actives de la bibliothèque (R5 : jamais utilisées par les calculs).
final bibliothequeTachesProvider =
    StreamProvider.autoDispose<List<BibliothequeTache>>(
      (ref) => ref.watch(bibliothequeRepositoryProvider).watchTaches(),
    );

/// Catégories actives d'un domaine (`null` = tous les domaines).
final categoriesProvider = StreamProvider.autoDispose
    .family<List<Categorie>, DomaineCategorie?>(
      (ref, domaine) => ref
          .watch(bibliothequeRepositoryProvider)
          .watchCategories(domaine: domaine),
    );
