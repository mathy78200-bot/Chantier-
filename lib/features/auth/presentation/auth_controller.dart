import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/firebase_providers.dart';
import '../../../shared/providers/repository_providers.dart';

/// Connexion, inscription et déconnexion.
///
/// `state` reflète l'opération en cours (`loading`) et son éventuelle erreur
/// (`AuthException`, message en français, via `AsyncValue.guard`). La
/// navigation n'est pas pilotée ici : le routeur écoute `authStateChanges`.
class AuthController extends AsyncNotifier<void> {
  /// Délai maximal d'attente de l'uid après connexion (voir [_attendreUid]).
  static const Duration _delaiUid = Duration(seconds: 5);

  @override
  FutureOr<void> build() {}

  Future<void> signIn({required String email, required String password}) =>
      _executer(() async {
        await ref
            .read(authRepositoryProvider)
            .signIn(email: email, password: password);
        await _initialiserUtilisateur(email);
      });

  Future<void> signUp({required String email, required String password}) =>
      _executer(() async {
        await ref
            .read(authRepositoryProvider)
            .signUp(email: email, password: password);
        await _initialiserUtilisateur(email);
      });

  /// Après déconnexion, `authStateChanges` émet `null` : `uidProvider` passe
  /// à `null` et tous les providers qui en dépendent (repositories, flux de
  /// données, KPIs) sont reconstruits ; aucune invalidation manuelle n'est
  /// nécessaire.
  Future<void> signOut() =>
      _executer(() => ref.read(authRepositoryProvider).signOut());

  Future<void> _executer(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
  }

  /// Crée `users/{uid}` s'il n'existe pas. Ne bloque jamais la connexion :
  /// une erreur est journalisée, le document sera créé au premier réglage.
  Future<void> _initialiserUtilisateur(String email) async {
    try {
      final uid = await _attendreUid();
      if (uid == null) {
        developer.log(
          'Uid indisponible après connexion : initialisation utilisateur '
          'différée.',
          name: 'auth',
        );
        return;
      }
      await ref
          .read(parametresRepositoryProvider)
          .initialiserUtilisateur(email: email.trim());
    } catch (erreur, stack) {
      developer.log(
        'Initialisation du document utilisateur impossible.',
        name: 'auth',
        error: erreur,
        stackTrace: stack,
      );
    }
  }

  /// Le flux `authStateChanges` peut émettre après la résolution de `signIn` :
  /// attend (au plus [_delaiUid]) que [uidProvider] reflète la connexion.
  Future<String?> _attendreUid() {
    final immediat = ref.read(uidProvider);
    if (immediat != null) return Future.value(immediat);

    final completer = Completer<String?>();
    final abonnement = ref.listen<String?>(uidProvider, (_, uid) {
      if (uid != null && !completer.isCompleted) completer.complete(uid);
    });
    return completer.future
        .timeout(_delaiUid, onTimeout: () => null)
        .whenComplete(abonnement.close);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);
