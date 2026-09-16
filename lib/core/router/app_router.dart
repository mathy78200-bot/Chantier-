import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accueil/presentation/accueil_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/chantiers/presentation/chantier_detail_screen.dart';
import '../../features/chantiers/presentation/chantier_form_screen.dart';
import '../../features/chantiers/presentation/chantiers_list_screen.dart';
import '../../features/reglages/presentation/reglages_screen.dart';
import '../../features/rentabilite/presentation/rentabilite_screen.dart';
import '../../shared/providers/firebase_providers.dart';
import '../widgets/app_shell.dart';

/// Chemins de l'application. Les écrans naviguent uniquement via ces
/// constantes / fonctions, jamais avec des chaînes en dur.
abstract final class Routes {
  static const String login = '/login';
  static const String accueil = '/accueil';
  static const String chantiers = '/chantiers';
  static const String nouveauChantier = '/chantiers/nouveau';
  static const String rentabilite = '/rentabilite';
  static const String reglages = '/reglages';

  /// Fiche d'un chantier (branche Chantiers du shell).
  static String chantier(String id) => '$chantiers/$id';

  /// Formulaire de modification (navigateur racine, par-dessus le shell).
  static String modifierChantier(String id) => '${chantier(id)}/modifier';

  /// Segment de paramètre des routes `:id`.
  static const String _idParam = ':id';
}

/// Navigateur racine : accueille le shell et les formulaires plein écran.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// Adapte un flux en [Listenable] pour `GoRouter.refreshListenable` : chaque
/// événement réévalue `redirect`.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

/// Routeur de l'application (go_router, `StatefulShellRoute.indexedStack` à
/// quatre branches). Créé une seule fois : la connexion est lue avec
/// `ref.read` dans `redirect`, jamais `ref.watch` (sinon le routeur serait
/// reconstruit et perdrait sa pile à chaque changement d'authentification).
final routerProvider = Provider<GoRouter>((ref) {
  // Rafraîchissement branché sur `authStateChanges` via son provider : même
  // source que `uidProvider` lu dans `redirect`, donc aucun décalage entre
  // les deux abonnements, et surchargeable dans les tests.
  final changementsAuth = StreamController<User?>.broadcast();
  ref.listen<AsyncValue<User?>>(authStateChangesProvider, (_, next) {
    if (next.hasValue) changementsAuth.add(next.value);
  });
  final refresh = GoRouterRefreshStream(changementsAuth.stream);
  ref.onDispose(() {
    refresh.dispose();
    unawaited(changementsAuth.close());
  });

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.accueil,
    refreshListenable: refresh,
    redirect: (context, state) {
      final connecte = ref.read(uidProvider) != null;
      final surLogin = state.matchedLocation == Routes.login;
      if (!connecte) return surLogin ? null : Routes.login;
      if (surLogin || state.uri.path == '/') return Routes.accueil;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      // Formulaires plein écran sur le navigateur racine (par-dessus le
      // shell). Déclarés avant le shell : `/chantiers/nouveau` doit primer
      // sur `/chantiers/:id`.
      GoRoute(
        path: Routes.nouveauChantier,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ChantierFormScreen(),
      ),
      GoRoute(
        path: Routes.modifierChantier(Routes._idParam),
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            ChantierFormScreen(chantierId: state.pathParameters['id']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.accueil,
                builder: (context, state) => const AccueilScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.chantiers,
                builder: (context, state) => const ChantiersListScreen(),
                routes: [
                  GoRoute(
                    path: Routes._idParam,
                    builder: (context, state) => ChantierDetailScreen(
                      chantierId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.rentabilite,
                builder: (context, state) => const RentabiliteScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.reglages,
                builder: (context, state) => const ReglagesScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
