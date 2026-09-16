import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/enums.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/duration_fmt.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/kpi_card.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../depenses/domain/depense.dart';
import '../../heures/domain/saisie_heures.dart';
import '../../rentabilite/domain/chantier_kpis.dart';
import '../../rentabilite/domain/resultats.dart';
import '../../rentabilite/presentation/kpis_providers.dart';
import '../../taches/domain/tache_chantier.dart';
import '../domain/chantier.dart';

/// Fiche d'un chantier : KPIs, prévisionnel, projection et listes en lecture
/// seule. Tout est affiché depuis un [ChantierKpis] : aucun calcul ici.
class ChantierDetailScreen extends ConsumerWidget {
  const ChantierDetailScreen({super.key, required this.chantierId});

  final String chantierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpis = ref.watch(chantierKpisProvider(chantierId));
    return Scaffold(
      appBar: AppBar(
        title: Text(kpis.valueOrNull?.chantier.nom ?? 'Chantier'),
        actions: [
          if (kpis.hasValue)
            PopupMenuButton<_Action>(
              tooltip: 'Actions',
              onSelected: (action) {
                switch (action) {
                  case _Action.modifier:
                    unawaited(
                      context.push(Routes.modifierChantier(chantierId)),
                    );
                  case _Action.supprimer:
                    unawaited(
                      _supprimer(context, ref, kpis.requireValue.chantier),
                    );
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _Action.modifier,
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Modifier'),
                  ),
                ),
                PopupMenuItem(
                  value: _Action.supprimer,
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('Supprimer'),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: AsyncView(
        value: kpis,
        error: (erreur, _) => EmptyState(
          icone: Icons.search_off,
          titre: erreur is StateError
              ? 'Chantier introuvable'
              : AsyncView.messageErreur(erreur),
          action: FilledButton(
            onPressed: () => context.go(Routes.chantiers),
            child: const Text('Retour aux chantiers'),
          ),
        ),
        builder: (k) => _Corps(k),
      ),
    );
  }

  /// R6 : soft delete après confirmation, puis retour à la liste.
  Future<void> _supprimer(
    BuildContext context,
    WidgetRef ref,
    Chantier chantier,
  ) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce chantier ?'),
        content: Text(
          '« ${chantier.nom} » sera placé dans la corbeille avec ses '
          'dépenses, heures et tâches. Vous pourrez le restaurer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true || !context.mounted) return;
    unawaited(
      ref
          .read(chantierRepositoryProvider)
          .softDelete(chantier.id, reason: 'Supprimé par l\'utilisateur'),
    );
    context.go(Routes.chantiers);
  }
}

enum _Action { modifier, supprimer }

/// Corps défilant de la fiche.
class _Corps extends StatelessWidget {
  const _Corps(this.kpis);

  final ChantierKpis kpis;

  @override
  Widget build(BuildContext context) {
    final data = kpis.data;
    final mode = kpis.modePrix;
    // §9.8 : TS supprimés → leurs dépenses / heures restent dans le chantier
    // et sont marquées « (TS supprimé) ».
    final idsTravauxSup = data.travauxSup.map((ts) => ts.id).toSet();
    bool tsSupprime(String? travauxSupId) =>
        travauxSupId != null && !idsTravauxSup.contains(travauxSupId);

    final depenses = [...data.depenses]
      ..sort((a, b) => b.date.compareTo(a.date));
    final heures = [...data.heures]..sort((a, b) => b.date.compareTo(a.date));
    final taches = [...data.taches]..sort((a, b) => a.ordre.compareTo(b.ordre));

    return CustomScrollView(
      slivers: [
        SliverList.list(
          children: [
            _EnTete(kpis),
            _GrilleKpis(children: _cartesKpis(mode)),
            _CartePrevisionnel(kpis),
            if (kpis.projection != null) _CarteProjection(kpis.projection!),
            _Titre('Dépenses (${depenses.length})'),
          ],
        ),
        if (depenses.isEmpty)
          const SliverToBoxAdapter(
            child: _ListeVide(Icons.receipt_long_outlined, 'Aucune dépense'),
          )
        else
          SliverList.builder(
            itemCount: depenses.length,
            itemBuilder: (context, i) => _LigneDepense(
              depenses[i],
              mode: mode,
              tsSupprime: tsSupprime(depenses[i].travauxSupId),
            ),
          ),
        SliverToBoxAdapter(child: _Titre('Heures (${heures.length})')),
        if (heures.isEmpty)
          const SliverToBoxAdapter(
            child: _ListeVide(
              Icons.schedule_outlined,
              'Aucune saisie d\'heures',
            ),
          )
        else
          SliverList.builder(
            itemCount: heures.length,
            itemBuilder: (context, i) => _LigneHeures(
              heures[i],
              tsSupprime: tsSupprime(heures[i].travauxSupId),
            ),
          ),
        SliverToBoxAdapter(child: _Titre('Tâches (${taches.length})')),
        if (taches.isEmpty)
          const SliverToBoxAdapter(
            child: _ListeVide(Icons.checklist_outlined, 'Aucune tâche'),
          )
        else
          SliverList.builder(
            itemCount: taches.length,
            itemBuilder: (context, i) => _LigneTache(taches[i]),
          ),
        SliverToBoxAdapter(
          child: _Titre('Travaux supplémentaires (${kpis.travauxSup.length})'),
        ),
        if (kpis.travauxSup.isEmpty)
          const SliverToBoxAdapter(
            child: _ListeVide(
              Icons.add_business_outlined,
              'Aucun travaux supplémentaire',
            ),
          )
        else
          SliverList.builder(
            itemCount: kpis.travauxSup.length,
            itemBuilder: (context, i) =>
                _LigneTravauxSup(kpis.travauxSup[i], mode: mode),
          ),
        // Espace pour le bouton ＋ du shell.
        const SliverPadding(padding: EdgeInsets.only(bottom: 96)),
      ],
    );
  }

  List<Widget> _cartesKpis(ModePrix mode) {
    final r = kpis.rentabilite;
    final ecart = kpis.ecart;
    final prev = kpis.previsionnel;
    final h = kpis.heures;

    final ecartPct = ecart.ecartDepensesPct;
    final ecartCents = ecart.ecartDepensesCents;
    final budgetTotal = prev.budgetTotalCents;
    final String valeurEcart;
    final String sousTitreEcart;
    if (ecartCents == null) {
      valeurEcart = '—';
      sousTitreEcart = 'Budget non renseigné';
    } else {
      valeurEcart = ecartPct == null
          ? Money.formatSigne(ecartCents, mode: mode)
          : '${ecartPct > 0 ? '+' : ''}${Money.formatPct(ecartPct)}';
      sousTitreEcart =
          '${Money.formatSigne(ecartCents, mode: mode)} · budget '
          '${Money.format(budgetTotal ?? 0, mode: mode)}';
    }

    final heuresPrevues = prev.heuresPrevuesTotalMinutes;
    return [
      KpiCard(
        titre: 'Prix vendu',
        valeur: Money.format(r.prixVenduCents, mode: mode),
        sousTitre: r.travauxSupAcceptesCents > 0
            ? 'dont TS acceptés '
                  '${Money.format(r.travauxSupAcceptesCents, mode: mode)}'
            : null,
        icone: Icons.sell_outlined,
      ),
      KpiCard(
        titre: 'Dépenses',
        valeur: Money.format(r.depensesCents, mode: mode),
        sousTitre:
            '${kpis.depenses.nbDepenses} dépense'
            '${kpis.depenses.nbDepenses > 1 ? 's' : ''}',
        icone: Icons.receipt_long_outlined,
      ),
      KpiCard(
        titre: 'Rentabilité',
        valeur: Money.format(r.rentabiliteCents, mode: mode),
        sousTitre: 'Prix vendu − dépenses',
        couleur: r.estNegative ? CouleurEtat.rouge : CouleurEtat.vert,
        icone: Icons.savings_outlined,
      ),
      KpiCard(
        titre: 'Marge',
        valeur: Money.formatPct(r.margePct),
        sousTitre: 'Rentabilité / prix vendu',
        icone: Icons.percent,
      ),
      KpiCard(
        titre: 'Écart dépenses',
        valeur: valeurEcart,
        sousTitre: sousTitreEcart,
        couleur: kpis.couleur,
        icone: Icons.compare_arrows,
      ),
      KpiCard(
        titre: 'Heures',
        valeur: DurationFmt.format(h.dureeMinutes),
        sousTitre:
            'Prévu ${heuresPrevues == null ? '—' : DurationFmt.format(heuresPrevues)}'
            ' · charge ${DurationFmt.format(h.chargeMinutes)}',
        icone: Icons.schedule_outlined,
      ),
      if (r.potentielTravauxSupCents > 0)
        KpiCard(
          titre: 'Potentiel TS proposés',
          valeur: Money.format(r.potentielTravauxSupCents, mode: mode),
          sousTitre: 'Hors CA tant que non acceptés',
          icone: Icons.hourglass_empty,
        ),
    ];
  }
}

/// En-tête : client, adresse, statut et couleur principale.
class _EnTete extends StatelessWidget {
  const _EnTete(this.kpis);

  final ChantierKpis kpis;

  @override
  Widget build(BuildContext context) {
    final c = kpis.chantier;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final debut = c.dateDebutPrevue;
    final fin = c.dateFinPrevue;
    final periode = switch ((debut, fin)) {
      (null, null) => null,
      (final d?, null) => 'Début prévu le ${DateFmt.court(d)}',
      (null, final f?) => 'Fin prévue le ${DateFmt.court(f)}',
      (final d?, final f?) =>
        'Prévu du ${DateFmt.court(d)} au ${DateFmt.court(f)}',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusChip(c.statut),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CouleurEtatDot(kpis.couleur, taille: 14),
                    const SizedBox(width: 6),
                    Text(
                      kpis.couleur.libelle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.couleur(kpis.couleur),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (c.clientNom.isNotEmpty) ...[
              const SizedBox(height: 12),
              _LigneInfo(
                Icons.person_outline,
                c.clientTelephone == null
                    ? c.clientNom
                    : '${c.clientNom} · ${c.clientTelephone}',
              ),
            ],
            if (c.adresse.isNotEmpty) ...[
              const SizedBox(height: 6),
              _LigneInfo(Icons.place_outlined, c.adresse),
            ],
            if (periode != null) ...[
              const SizedBox(height: 6),
              _LigneInfo(Icons.event_outlined, periode),
            ],
            if (c.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                c.notes,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LigneInfo extends StatelessWidget {
  const _LigneInfo(this.icone, this.texte);

  final IconData icone;
  final String texte;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 20, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(child: Text(texte)),
      ],
    );
  }
}

/// Une colonne sur téléphone, deux colonnes à partir de 600 px.
class _GrilleKpis extends StatelessWidget {
  const _GrilleKpis({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        if (contraintes.maxWidth < 600) {
          return Column(children: children);
        }
        final lignes = <Widget>[];
        for (var i = 0; i < children.length; i += 2) {
          lignes.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: children[i]),
                Expanded(
                  child: i + 1 < children.length
                      ? children[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          );
        }
        return Column(children: lignes);
      },
    );
  }
}

/// Complétude du prévisionnel (R10) et valeurs consolidées.
class _CartePrevisionnel extends StatelessWidget {
  const _CartePrevisionnel(this.kpis);

  final ChantierKpis kpis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final completude = kpis.completude;
    final prev = kpis.previsionnel;
    final mode = kpis.modePrix;
    final obligatoires = completude.manquantsObligatoires;
    final recommandes = completude.manquantsRecommandes;

    String derive(bool actif, String origine) => actif ? ' ($origine)' : '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prévisionnel',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: completude.pct / 100,
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${completude.pct} %',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _LigneCle(
              'Budget dépenses',
              prev.budgetTotalCents == null
                  ? '—'
                  : Money.format(prev.budgetTotalCents!, mode: mode) +
                        derive(prev.budgetDeriveParType, 'par type'),
            ),
            _LigneCle(
              'Heures prévues',
              prev.heuresPrevuesTotalMinutes == null
                  ? '—'
                  : DurationFmt.format(prev.heuresPrevuesTotalMinutes!) +
                        derive(prev.heuresDeriveesDesTaches, 'tâches'),
            ),
            _LigneCle(
              'Effectif prévu',
              prev.effectifPrevu == null
                  ? '—'
                  : '${prev.effectifPrevu} pers.'
                        '${derive(prev.effectifDeriveDesTaches, 'tâches')}',
            ),
            _LigneCle(
              'Durée prévue',
              prev.dureePrevueJours == null
                  ? '—'
                  : '${prev.dureePrevueJours} j'
                        '${derive(prev.dureeDeriveeDesDates, 'dates')}',
            ),
            const SizedBox(height: 12),
            if (completude.manquants.isEmpty)
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: AppTheme.couleur(CouleurEtat.vert),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Prévisionnel complet.')),
                ],
              )
            else ...[
              if (obligatoires.isNotEmpty)
                Text(
                  'Obligatoires manquants : '
                  '${obligatoires.map((c) => c.libelle).join(', ')}.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (recommandes.isNotEmpty)
                Text(
                  'Recommandé : '
                  '${recommandes.map((c) => c.libelle).join(', ')}.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Compléter (étape 3)'),
            ),
          ],
        ),
      ),
    );
  }
}

/// R8 : projection = indicateur secondaire, avec sa propre couleur et la
/// mention obligatoire (§9.7).
class _CarteProjection extends StatelessWidget {
  const _CarteProjection(this.projection);

  final ProjectionResult projection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ecartCents = projection.ecartProjeteCents;
    final ecartPct = projection.ecartProjetePct;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Projection',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                CouleurEtatDot(projection.couleur, taille: 14),
                const SizedBox(width: 6),
                Text(
                  projection.couleur.libelle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.couleur(projection.couleur),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Text(
              'Indicateur secondaire',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _LigneCle('Avancement', Money.formatPct(projection.avancementPct)),
            _LigneCle(
              'Dépenses projetées',
              Money.format(projection.depensesProjeteesCents),
            ),
            _LigneCle(
              'Écart projeté',
              ecartCents == null
                  ? '—'
                  : '${Money.formatSigne(ecartCents)}'
                        '${ecartPct == null ? '' : ' (${Money.formatPct(ecartPct)})'}',
            ),
            const SizedBox(height: 12),
            Text(
              ProjectionResult.mention,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LigneCle extends StatelessWidget {
  const _LigneCle(this.cle, this.valeur);

  final String cle;
  final String valeur;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              cle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              valeur,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Titre extends StatelessWidget {
  const _Titre(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        texte,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// État vide compact d'une liste de la fiche.
class _ListeVide extends StatelessWidget {
  const _ListeVide(this.icone, this.texte);

  final IconData icone;
  final String texte;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Icon(icone, size: 20, color: scheme.outline),
          const SizedBox(width: 8),
          Text(texte, style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

const String _suffixeTsSupprime = ' (TS supprimé)';

class _LigneDepense extends StatelessWidget {
  const _LigneDepense(
    this.depense, {
    required this.mode,
    required this.tsSupprime,
  });

  final Depense depense;
  final ModePrix mode;
  final bool tsSupprime;

  static IconData _icone(TypeDepense type) => switch (type) {
    TypeDepense.materiaux => Icons.hardware_outlined,
    TypeDepense.sousTraitance => Icons.engineering_outlined,
    TypeDepense.repas => Icons.restaurant_outlined,
    TypeDepense.hotel => Icons.hotel_outlined,
    TypeDepense.deplacement => Icons.directions_car_outlined,
    TypeDepense.autre => Icons.receipt_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final libelle = depense.libelle.isEmpty
        ? depense.type.libelle
        : depense.libelle;
    return ListTile(
      leading: Icon(_icone(depense.type)),
      title: Text('$libelle${tsSupprime ? _suffixeTsSupprime : ''}'),
      subtitle: Text(
        '${DateFmt.court(depense.date)} · ${depense.type.libelle}'
        '${depense.fournisseur == null ? '' : ' · ${depense.fournisseur}'}',
      ),
      trailing: Text(
        Money.format(depense.montantCents, mode: mode),
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _LigneHeures extends StatelessWidget {
  const _LigneHeures(this.saisie, {required this.tsSupprime});

  final SaisieHeures saisie;
  final bool tsSupprime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tache = saisie.tacheLibelleSnapshot ?? 'Sans tâche';
    return ListTile(
      leading: const Icon(Icons.schedule_outlined),
      title: Text(
        '${saisie.nbPersonnes} pers. × '
        '${DurationFmt.format(saisie.minutesParPersonne)}',
      ),
      subtitle: Text(
        '${DateFmt.court(saisie.date)} · $tache'
        '${tsSupprime ? _suffixeTsSupprime : ''}',
      ),
      trailing: Text(
        DurationFmt.format(saisie.chargeMinutes),
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _LigneTache extends StatelessWidget {
  const _LigneTache(this.tache);

  final TacheChantier tache;

  static final NumberFormat _quantite = NumberFormat.decimalPattern('fr_FR');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duree = tache.dureePrevueMinutes;
    return ListTile(
      leading: const Icon(Icons.checklist_outlined),
      title: Text(tache.libelle),
      subtitle: Text(
        '${_quantite.format(tache.quantitePrevue)} ${tache.unite.libelle}'
        ' · ${tache.statut.libelle}',
      ),
      trailing: Text(
        duree == null ? '—' : DurationFmt.format(duree),
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _LigneTravauxSup extends StatelessWidget {
  const _LigneTravauxSup(this.analyse, {required this.mode});

  final TravauxSupAnalyse analyse;
  final ModePrix mode;

  @override
  Widget build(BuildContext context) {
    final ts = analyse.travauxSup;
    return ListTile(
      leading: const Icon(Icons.add_business_outlined),
      title: Text(ts.libelle),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: TravauxSupChip(ts.statut),
          ),
          Text(
            'Prix ${Money.format(ts.prixVenduCents, mode: mode)} · '
            'dépenses réelles ${Money.format(analyse.depensesCents, mode: mode)}',
          ),
        ],
      ),
      isThreeLine: true,
    );
  }
}
