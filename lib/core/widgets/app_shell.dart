import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/providers/repository_providers.dart';
import '../errors/app_exception.dart';
import '../router/app_router.dart';

/// Coquille de l'application : barre de navigation à quatre onglets, bouton
/// ＋ contextuel et affichage des écritures refusées (§9.2).
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Accueil',
    ),
    NavigationDestination(
      icon: Icon(Icons.construction_outlined),
      selectedIcon: Icon(Icons.construction),
      label: 'Chantiers',
    ),
    NavigationDestination(
      icon: Icon(Icons.insights_outlined),
      selectedIcon: Icon(Icons.insights),
      label: 'Rentabilité',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Réglages',
    ),
  ];

  /// Actions du ＋ sur une fiche chantier (formulaires de l'étape 2).
  static const List<({String libelle, IconData icone})> _actionsChantier = [
    (libelle: 'Dépense', icone: Icons.receipt_long_outlined),
    (libelle: 'Déplacement', icone: Icons.directions_car_outlined),
    (libelle: 'Heures', icone: Icons.schedule_outlined),
    (libelle: 'Tâche', icone: Icons.checklist_outlined),
    (libelle: 'Travaux sup', icone: Icons.add_business_outlined),
    (libelle: 'Justificatif', icone: Icons.photo_camera_outlined),
  ];

  /// `/chantiers/{id}` exactement (ni la liste, ni `/modifier`).
  static final RegExp _ficheChantier = RegExp(r'^/chantiers/[^/]+$');

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<EcritureRefuseeException>>(writeErrorsProvider, (
      _,
      next,
    ) {
      if (next.hasValue) _afficherMessage(next.requireValue.message);
    });

    return Scaffold(
      body: widget.navigationShell,
      floatingActionButton: _boutonPlus(context),
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        destinations: _destinations,
        onDestinationSelected: (index) => widget.navigationShell.goBranch(
          index,
          // Re-taper l'onglet courant ramène à la racine de la branche.
          initialLocation: index == widget.navigationShell.currentIndex,
        ),
      ),
    );
  }

  /// Bouton ＋ selon l'emplacement courant.
  ///
  /// §9.1 : ce widget est construit par `StatefulShellRoute.builder`, donc
  /// sous un `RouteBase.builder` : `GoRouterState.of(context)` est valide et
  /// le shell est reconstruit à chaque navigation. `uri.path` est utilisé
  /// plutôt que `matchedLocation`, qui reste en retard après un `push` dans
  /// une branche.
  Widget? _boutonPlus(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location == Routes.chantiers) {
      return FloatingActionButton(
        onPressed: () => context.push(Routes.nouveauChantier),
        tooltip: 'Nouveau chantier',
        child: const Icon(Icons.add),
      );
    }
    if (_ficheChantier.hasMatch(location) &&
        location != Routes.nouveauChantier) {
      return FloatingActionButton(
        onPressed: _ouvrirActionsChantier,
        tooltip: 'Ajouter au chantier',
        child: const Icon(Icons.add),
      );
    }
    return null;
  }

  Future<void> _ouvrirActionsChantier() {
    return showModalBottomSheet<void>(
      context: context,
      // La feuille prend la hauteur de son contenu (six actions visibles d'un
      // coup, sans défilement) ; le défilement ne sert qu'en paysage.
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Ajouter au chantier',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              for (final action in _actionsChantier)
                ListTile(
                  leading: Icon(action.icone),
                  title: Text(action.libelle),
                  minVerticalPadding: 4,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _afficherMessage('Disponible à l\'étape 2');
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _afficherMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
