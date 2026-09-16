import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/enums.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/kpi_card.dart';
import '../../../core/widgets/status_chip.dart';
import '../../rentabilite/domain/resultats.dart';
import '../../rentabilite/presentation/kpis_providers.dart';

/// Accueil : agrégats des chantiers en activité, un bloc par mode de prix
/// (R2 : HT et TTC ne sont jamais additionnés). Aucun calcul ici : tout vient
/// de [agregatsProvider].
class AccueilScreen extends ConsumerWidget {
  const AccueilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agregats = ref.watch(agregatsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Accueil')),
      body: AsyncView(
        value: agregats,
        builder: (a) {
          if (a.estVide) {
            return EmptyState(
              icone: Icons.construction_outlined,
              titre: 'Aucun chantier en activité',
              message:
                  'Créez votre premier chantier pour suivre sa rentabilité.',
              action: FilledButton.icon(
                onPressed: () => context.go(Routes.chantiers),
                icon: const Icon(Icons.list_alt),
                label: const Text('Voir les chantiers'),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              for (final mode in a.modes) _BlocMode(agregat: a.pour(mode)!),
            ],
          );
        },
      ),
    );
  }
}

/// Bloc d'un mode de prix : KPIs, potentiel et chantiers à surveiller.
class _BlocMode extends StatelessWidget {
  const _BlocMode({required this.agregat});

  final AgregatMode agregat;

  @override
  Widget build(BuildContext context) {
    final mode = agregat.mode;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final nb = agregat.nbChantiers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TitreSection(
          'Chantiers ${mode.libelle}',
          sousTitre: nb == 0
              ? 'Aucun chantier en cours ou terminé'
              : '$nb chantier${nb > 1 ? 's' : ''} en cours ou terminé'
                    '${nb > 1 ? 's' : ''}',
        ),
        KpiCard(
          titre: 'CA vendu',
          valeur: Money.format(agregat.caVenduCents, mode: mode),
          icone: Icons.sell_outlined,
        ),
        KpiCard(
          titre: 'Dépenses',
          valeur: Money.format(agregat.depensesCents, mode: mode),
          icone: Icons.receipt_long_outlined,
        ),
        KpiCard(
          titre: 'Rentabilité',
          valeur: Money.format(agregat.rentabiliteCents, mode: mode),
          sousTitre: 'Prix vendu − dépenses',
          couleur: agregat.rentabiliteCents < 0 ? CouleurEtat.rouge : null,
          icone: Icons.savings_outlined,
        ),
        KpiCard(
          titre: 'Marge moyenne',
          valeur: Money.formatPct(agregat.margeMoyennePct),
          sousTitre: 'Pondérée par le CA vendu',
          icone: Icons.percent,
        ),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.edit_note),
                title: const Text('À faire signer'),
                subtitle: const Text('Potentiel, hors CA vendu'),
                trailing: Text(
                  '${agregat.aFaireSignerNb} · '
                  '${Money.format(agregat.aFaireSignerCents, mode: mode)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.event),
                title: const Text('À venir'),
                subtitle: const Text('Signés, non commencés'),
                trailing: Text(
                  '${agregat.aVenirNb} · '
                  '${Money.format(agregat.aVenirCents, mode: mode)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        _TitreSection('À surveiller (${mode.libelle})'),
        if (agregat.aSurveiller.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              'Aucun chantier à surveiller.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (final (i, c) in agregat.aSurveiller.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  _LigneASurveiller(c),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _LigneASurveiller extends StatelessWidget {
  const _LigneASurveiller(this.chantier);

  final ChantierASurveiller chantier;

  @override
  Widget build(BuildContext context) {
    final mentions = [
      chantier.couleur.libelle,
      if (chantier.projectionRouge) 'projection en dérive',
    ];
    return ListTile(
      leading: CouleurEtatDot(chantier.couleur, taille: 14),
      title: Text(chantier.nom),
      subtitle: Text(mentions.join(' · ')),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.go(Routes.chantier(chantier.chantierId)),
    );
  }
}

class _TitreSection extends StatelessWidget {
  const _TitreSection(this.titre, {this.sousTitre});

  final String titre;
  final String? sousTitre;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titre,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (sousTitre != null)
            Text(
              sousTitre!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
