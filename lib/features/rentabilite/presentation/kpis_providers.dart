import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/enums.dart';
import '../../../shared/providers/data_providers.dart';
import '../../chantiers/domain/chantier.dart';
import '../../reglages/domain/parametres_utilisateur.dart';
import '../domain/agregats_calculator.dart';
import '../domain/chantier_data.dart';
import '../domain/chantier_kpis.dart';
import '../domain/resultats.dart';
import '../domain/seuils.dart';

/// Providers de calcul. L'UI reçoit des [ChantierKpis] / [Agregats] prêts à
/// afficher et **ne recalcule jamais rien** : tout passe par
/// `ChantierKpis.compute` et `AgregatsCalculator.compute` (Dart pur).

/// Seuils issus des paramètres utilisateur ; valeurs par défaut tant que le
/// document `users/{uid}` n'est pas chargé.
final seuilsProvider = Provider<Seuils>((ref) {
  final parametres =
      ref.watch(parametresProvider).valueOrNull ?? ParametresUtilisateur.defaut;
  return Seuils.fromParametres(parametres);
});

/// Données d'entrée des calculs d'un chantier : combine les six flux
/// (chantier, prévisionnel, dépenses, heures, tâches, travaux sup).
///
/// - erreur dès qu'un flux est en erreur ;
/// - chargement tant qu'un flux n'a encore rien émis (le prévisionnel peut
///   valoir `null`, mais son flux doit avoir répondu) ;
/// - `StateError('Chantier introuvable')` si le document n'existe pas ;
/// - données sinon (les éléments supprimés sont exclus par [ChantierData]).
final chantierDataProvider = Provider.autoDispose
    .family<AsyncValue<ChantierData>, String>((ref, chantierId) {
      final chantier = ref.watch(chantierProvider(chantierId));
      final previsionnel = ref.watch(previsionnelProvider(chantierId));
      final depenses = ref.watch(depensesProvider(chantierId));
      final heures = ref.watch(heuresProvider(chantierId));
      final taches = ref.watch(tachesProvider(chantierId));
      final travauxSup = ref.watch(travauxSupProvider(chantierId));

      final flux = <AsyncValue<Object?>>[
        chantier,
        previsionnel,
        depenses,
        heures,
        taches,
        travauxSup,
      ];
      for (final f in flux) {
        if (f.hasError) {
          return AsyncError(f.error!, f.stackTrace ?? StackTrace.current);
        }
      }
      if (flux.any((f) => !f.hasValue)) return const AsyncLoading();

      final c = chantier.requireValue;
      if (c == null) {
        return AsyncError(
          StateError('Chantier introuvable'),
          StackTrace.current,
        );
      }
      return AsyncData(
        ChantierData(
          chantier: c,
          previsionnel: previsionnel.requireValue,
          depenses: depenses.requireValue,
          heures: heures.requireValue,
          taches: taches.requireValue,
          travauxSup: travauxSup.requireValue,
        ),
      );
    });

/// KPIs d'un chantier = `ChantierKpis.compute(data, seuils)`.
final chantierKpisProvider = Provider.autoDispose
    .family<AsyncValue<ChantierKpis>, String>((ref, chantierId) {
      final seuils = ref.watch(seuilsProvider);
      return ref
          .watch(chantierDataProvider(chantierId))
          .whenData((data) => ChantierKpis.compute(data, seuils));
    });

/// §9.4 — chantiers pris en compte par l'accueil : en cours, à venir et à
/// faire signer. Les terminés n'y servent pas et ne sont pas chargés.
const Set<StatutChantier> _statutsAccueil = {
  StatutChantier.enCours,
  StatutChantier.aVenir,
  StatutChantier.aFaireSigner,
};

/// Chantiers de l'onglet Rentabilité : activité réelle (en cours, terminés).
const Set<StatutChantier> _statutsRentabilite = {
  StatutChantier.enCours,
  StatutChantier.termine,
};

final chantiersAccueilProvider =
    Provider.autoDispose<AsyncValue<List<Chantier>>>(
      (ref) => ref
          .watch(chantiersActifsProvider)
          .whenData(
            (liste) => liste
                .where((c) => _statutsAccueil.contains(c.statut))
                .toList(growable: false),
          ),
    );

/// KPIs des chantiers de l'accueil.
///
/// Coût (§9.4) : chaque chantier ouvre **6 listeners Firestore** (chantier,
/// prévisionnel, dépenses, heures, tâches, travaux sup) via
/// [chantierDataProvider] ; ce provider est `autoDispose` pour qu'ils se
/// ferment dès que l'accueil n'est plus écouté (déconnexion notamment).
final tousKpisProvider = Provider.autoDispose<AsyncValue<List<ChantierKpis>>>(
  (ref) => _combinerKpis(ref, ref.watch(chantiersAccueilProvider)),
);

/// Agrégats de l'accueil, un bloc par mode de prix (R2).
final agregatsProvider = Provider.autoDispose<AsyncValue<Agregats>>(
  (ref) => ref.watch(tousKpisProvider).whenData(AgregatsCalculator.compute),
);

/// KPIs des chantiers en cours et terminés, chargés à la demande par
/// l'onglet Rentabilité (même coût de 6 listeners par chantier ; le filtrage
/// par période des terminés viendra avec l'étape 7).
final rentabiliteKpisProvider =
    Provider.autoDispose<AsyncValue<List<ChantierKpis>>>(
      (ref) => _combinerKpis(
        ref,
        ref
            .watch(chantiersActifsProvider)
            .whenData(
              (liste) => liste
                  .where((c) => _statutsRentabilite.contains(c.statut))
                  .toList(growable: false),
            ),
      ),
    );

/// Combine les KPIs des [chantiers] : seuls ceux disponibles (`data`) sont
/// retenus ; chargement tant qu'aucun n'est disponible et qu'au moins un
/// charge ; erreur si aucun n'est disponible et qu'au moins un est en erreur.
AsyncValue<List<ChantierKpis>> _combinerKpis(
  Ref ref,
  AsyncValue<List<Chantier>> chantiers,
) {
  return chantiers.when(
    loading: () => const AsyncLoading(),
    error: (erreur, stack) => AsyncError(erreur, stack),
    data: (liste) {
      final kpis = <ChantierKpis>[];
      var enChargement = 0;
      ({Object erreur, StackTrace stack})? premiereErreur;
      for (final chantier in liste) {
        final kpi = ref.watch(chantierKpisProvider(chantier.id));
        if (kpi.hasValue) {
          kpis.add(kpi.requireValue);
        } else if (kpi.hasError) {
          premiereErreur ??= (
            erreur: kpi.error!,
            stack: kpi.stackTrace ?? StackTrace.current,
          );
        } else {
          enChargement++;
        }
      }
      if (kpis.isEmpty && enChargement > 0) return const AsyncLoading();
      if (kpis.isEmpty && premiereErreur != null) {
        return AsyncError(premiereErreur.erreur, premiereErreur.stack);
      }
      return AsyncData(List.unmodifiable(kpis));
    },
  );
}
