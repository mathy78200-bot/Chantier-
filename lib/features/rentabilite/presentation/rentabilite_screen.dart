import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/enums.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/status_chip.dart';
import '../domain/chantier_kpis.dart';
import 'kpis_providers.dart';

/// Onglet Rentabilité : une ligne par chantier en cours ou terminé, regroupée
/// par mode de prix (R2). Aucun total n'est calculé ici ; les graphiques et
/// l'analyse détaillée arrivent à l'étape 7.
class RentabiliteScreen extends ConsumerWidget {
  const RentabiliteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpis = ref.watch(rentabiliteKpisProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Rentabilité')),
      body: AsyncView(
        value: kpis,
        builder: (liste) {
          if (liste.isEmpty) {
            return const EmptyState(
              icone: Icons.insights_outlined,
              titre: 'Aucun chantier en cours ou terminé',
              message:
                  'La rentabilité apparaît dès qu\'un chantier passe '
                  '« En cours ».',
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              for (final mode in ModePrix.values)
                if (liste.any((k) => k.modePrix == mode))
                  _BlocMode(
                    mode: mode,
                    kpis: liste
                        .where((k) => k.modePrix == mode)
                        .toList(growable: false),
                  ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.bar_chart_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Graphiques et analyse détaillée : étape 7.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BlocMode extends StatelessWidget {
  const _BlocMode({required this.mode, required this.kpis});

  final ModePrix mode;
  final List<ChantierKpis> kpis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
          child: Text(
            'Chantiers ${mode.libelle}',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          child: Column(
            children: [
              for (final (i, k) in kpis.indexed) ...[
                if (i > 0) const Divider(height: 1),
                _LigneChantier(k),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LigneChantier extends StatelessWidget {
  const _LigneChantier(this.kpis);

  final ChantierKpis kpis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final r = kpis.rentabilite;
    final mode = kpis.modePrix;
    final couleurRentabilite = AppTheme.couleur(
      r.estNegative ? CouleurEtat.rouge : CouleurEtat.vert,
    );

    return ListTile(
      leading: CouleurEtatDot(kpis.couleur, taille: 14),
      title: Text(
        kpis.chantier.nom,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: StatusChip(kpis.statut),
          ),
          Text(
            'Vendu ${Money.format(r.prixVenduCents, mode: mode)} · '
            'dépenses ${Money.format(r.depensesCents, mode: mode)}',
          ),
          Text(
            'Rentabilité ${Money.formatSigne(r.rentabiliteCents, mode: mode)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: couleurRentabilite,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      isThreeLine: true,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            Money.formatPct(r.margePct),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: couleurRentabilite,
            ),
          ),
          Text(
            'marge',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      onTap: () => context.go(Routes.chantier(kpis.chantierId)),
    );
  }
}
