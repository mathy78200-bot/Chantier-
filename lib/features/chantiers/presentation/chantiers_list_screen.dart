import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/enums.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../shared/providers/data_providers.dart';
import '../../rentabilite/presentation/kpis_providers.dart';
import '../domain/chantier.dart';

/// Liste des chantiers actifs, filtrable par statut (R11 : quatre statuts).
///
/// §9.3 : la liste est un `ListView.builder` sans animation, le
/// réordonnancement d'`updatedAt` à la synchronisation reste discret.
class ChantiersListScreen extends ConsumerStatefulWidget {
  const ChantiersListScreen({super.key});

  @override
  ConsumerState<ChantiersListScreen> createState() =>
      _ChantiersListScreenState();
}

class _ChantiersListScreenState extends ConsumerState<ChantiersListScreen> {
  /// `null` = tous les statuts.
  StatutChantier? _filtre;

  @override
  Widget build(BuildContext context) {
    final chantiers = ref.watch(chantiersActifsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chantiers'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _Filtres(
            filtre: _filtre,
            onChanged: (statut) => setState(() => _filtre = statut),
          ),
        ),
      ),
      body: AsyncView(
        value: chantiers,
        builder: (liste) {
          if (liste.isEmpty) {
            return EmptyState(
              icone: Icons.construction_outlined,
              titre: 'Aucun chantier',
              message: 'Créez votre premier chantier pour commencer le suivi.',
              action: FilledButton.icon(
                onPressed: () => context.push(Routes.nouveauChantier),
                icon: const Icon(Icons.add),
                label: const Text('Nouveau chantier'),
              ),
            );
          }
          final filtre = _filtre;
          final visibles = filtre == null
              ? liste
              : liste.where((c) => c.statut == filtre).toList(growable: false);
          if (visibles.isEmpty) {
            return EmptyState(
              icone: Icons.filter_alt_off_outlined,
              titre: 'Aucun chantier « ${filtre!.libelle} »',
              message: 'Changez de filtre pour voir les autres chantiers.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: visibles.length,
            itemBuilder: (context, index) => _LigneChantier(
              visibles[index],
              key: ValueKey(visibles[index].id),
            ),
          );
        },
      ),
    );
  }
}

/// Puces de filtre : « Tous » puis les quatre statuts.
class _Filtres extends StatelessWidget {
  const _Filtres({required this.filtre, required this.onChanged});

  final StatutChantier? filtre;
  final ValueChanged<StatutChantier?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            FilterChip(
              label: const Text('Tous'),
              selected: filtre == null,
              onSelected: (_) => onChanged(null),
            ),
            for (final statut in StatutChantier.values) ...[
              const SizedBox(width: 8),
              FilterChip(
                label: Text(statut.libelle),
                selected: filtre == statut,
                onSelected: (_) => onChanged(statut),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LigneChantier extends StatelessWidget {
  const _LigneChantier(this.chantier, {super.key});

  final Chantier chantier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: _PastilleEtat(chantier.id),
      title: Text(
        chantier.nom,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chantier.clientNom.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(chantier.clientNom),
            ),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(chantier.statut),
              Text(
                Money.format(
                  chantier.prixVenduInitialCents,
                  mode: chantier.modePrix,
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.go(Routes.chantier(chantier.id)),
    );
  }
}

/// Point de couleur principale du chantier ; gris tant que les KPIs ne sont
/// pas chargés. Les six flux (§9.4) ne sont ouverts que pour les lignes
/// affichées : `ListView.builder` détruit les lignes hors écran et les
/// providers `autoDispose` se ferment avec elles.
class _PastilleEtat extends ConsumerWidget {
  const _PastilleEtat(this.chantierId);

  final String chantierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couleur =
        ref.watch(chantierKpisProvider(chantierId)).valueOrNull?.couleur ??
        CouleurEtat.gris;
    return SizedBox(
      width: 24,
      height: 48,
      child: Center(child: CouleurEtatDot(couleur, taille: 16)),
    );
  }
}
