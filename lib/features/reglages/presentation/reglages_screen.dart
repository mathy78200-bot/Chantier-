import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/defaults.dart';
import '../../../core/constants/enums.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/duration_fmt.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/async_view.dart';
import '../../../shared/providers/data_providers.dart';
import '../../../shared/providers/firebase_providers.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/parametres_utilisateur.dart';

/// Réglages : paramètres utilisateur (seuils, barème, valeurs par défaut) et
/// compte. L'enregistrement est optimiste (R7) : `unawaited(save(...))`.
class ReglagesScreen extends ConsumerStatefulWidget {
  const ReglagesScreen({super.key});

  @override
  ConsumerState<ReglagesScreen> createState() => _ReglagesScreenState();
}

class _ReglagesScreenState extends ConsumerState<ReglagesScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _entrepriseNom = TextEditingController();
  final TextEditingController _seuilOrange = TextEditingController();
  final TextEditingController _seuilRouge = TextEditingController();
  final TextEditingController _seuilProjection = TextEditingController();
  final TextEditingController _baremeKm = TextEditingController();
  final TextEditingController _effectif = TextEditingController();
  final TextEditingController _journeeType = TextEditingController();

  ModePrix _modePrix = Defaults.modePrix;

  /// Dernière valeur du flux, base du `copyWith` à l'enregistrement.
  ParametresUtilisateur _parametres = ParametresUtilisateur.defaut;
  bool _prerempli = false;

  static final NumberFormat _pct = NumberFormat('0.##', 'fr_FR');
  static final NumberFormat _euros = NumberFormat('0.00', 'fr_FR');

  @override
  void dispose() {
    _entrepriseNom.dispose();
    _seuilOrange.dispose();
    _seuilRouge.dispose();
    _seuilProjection.dispose();
    _baremeKm.dispose();
    _effectif.dispose();
    _journeeType.dispose();
    super.dispose();
  }

  /// Pré-remplit les champs une seule fois à partir des paramètres chargés.
  void _preremplir(ParametresUtilisateur p) {
    _entrepriseNom.text = p.entrepriseNom;
    _seuilOrange.text = _pct.format(p.seuilOrangePct);
    _seuilRouge.text = _pct.format(p.seuilRougePct);
    _seuilProjection.text = _pct.format(p.seuilProjectionPct);
    _baremeKm.text = _euros.format(p.baremeKmCents / 100);
    _effectif.text = '${p.effectifParDefaut}';
    _journeeType.text = DurationFmt.format(p.minutesJourneeType);
    _modePrix = p.modePrixParDefaut;
    _prerempli = true;
  }

  /// Saisie « 12,5 » / « 12.5 % » → double, null si invalide.
  static double? _parsePct(String saisie) => double.tryParse(
    saisie.trim().replaceAll('%', '').replaceAll(' ', '').replaceAll(',', '.'),
  );

  String? _validerPct(String? valeur, {double max = 1000}) {
    final pct = _parsePct(valeur ?? '');
    if (pct == null || pct < 0 || pct > max) {
      return 'Pourcentage invalide (0 à ${_pct.format(max)}).';
    }
    return null;
  }

  String? _validerSeuilRouge(String? valeur) {
    final erreur = _validerPct(valeur);
    if (erreur != null) return erreur;
    final orange = _parsePct(_seuilOrange.text);
    final rouge = _parsePct(valeur ?? '');
    if (orange != null && rouge != null && rouge <= orange) {
      return 'Le seuil rouge doit être supérieur au seuil orange.';
    }
    return null;
  }

  String? _validerBareme(String? valeur) {
    final cents = Money.parse(valeur ?? '');
    if (cents == null || cents < 0) return 'Montant invalide (ex. 0,60).';
    return null;
  }

  String? _validerEffectif(String? valeur) {
    final effectif = int.tryParse(valeur?.trim() ?? '');
    if (effectif == null || effectif < 1) return 'Au moins 1 personne.';
    return null;
  }

  String? _validerJourneeType(String? valeur) {
    final minutes = DurationFmt.parse(valeur ?? '');
    if (minutes == null ||
        minutes < 1 ||
        minutes > Defaults.minutesParPersonneMax) {
      return 'Durée invalide (ex. 7 h 30, entre 1 min et 24 h).';
    }
    return null;
  }

  void _enregistrer() {
    if (!_formKey.currentState!.validate()) return;
    final nouveaux = _parametres.copyWith(
      entrepriseNom: _entrepriseNom.text.trim(),
      modePrixParDefaut: _modePrix,
      seuilOrangePct: _parsePct(_seuilOrange.text)!,
      seuilRougePct: _parsePct(_seuilRouge.text)!,
      seuilProjectionPct: _parsePct(_seuilProjection.text)!,
      baremeKmCents: Money.parse(_baremeKm.text)!,
      effectifParDefaut: int.parse(_effectif.text.trim()),
      minutesJourneeType: DurationFmt.parse(_journeeType.text)!,
    );
    try {
      unawaited(ref.read(parametresRepositoryProvider).save(nouveaux));
    } on AppException catch (e) {
      _afficher(e.message);
      return;
    }
    FocusScope.of(context).unfocus();
    _afficher('Paramètres enregistrés');
  }

  void _afficher(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final parametres = ref.watch(parametresProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: AsyncView(
        value: parametres,
        builder: (p) {
          _parametres = p;
          if (!_prerempli) _preremplir(p);
          return _formulaire();
        },
      ),
    );
  }

  Widget _formulaire() {
    final theme = Theme.of(context);
    final email = ref.watch(firebaseAuthProvider).currentUser?.email;
    final deconnexionEnCours = ref.watch(authControllerProvider).isLoading;

    // `SingleChildScrollView` plutôt que `ListView` : tous les champs restent
    // montés, donc `Form.validate()` les vérifie tous, même hors écran.
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TitreSection('Entreprise'),
            TextFormField(
              controller: _entrepriseNom,
              decoration: const InputDecoration(
                labelText: 'Nom de l\'entreprise',
              ),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            Text('Mode de prix par défaut', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<ModePrix>(
              segments: [
                for (final mode in ModePrix.values)
                  ButtonSegment(value: mode, label: Text(mode.libelle)),
              ],
              selected: {_modePrix},
              onSelectionChanged: (selection) =>
                  setState(() => _modePrix = selection.first),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Pré-rempli à la création d\'un chantier ; le mode d\'un '
                'chantier existant ne change jamais.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            _TitreSection('Seuils d\'alerte (écart dépenses)'),
            TextFormField(
              controller: _seuilOrange,
              decoration: const InputDecoration(
                labelText: 'Seuil orange',
                suffixText: '%',
                helperText: 'Au-delà de cet écart, le chantier passe orange.',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              validator: _validerPct,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _seuilRouge,
              decoration: const InputDecoration(
                labelText: 'Seuil rouge',
                suffixText: '%',
                helperText: 'Au-delà de cet écart, le chantier passe rouge.',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              validator: _validerSeuilRouge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _seuilProjection,
              decoration: const InputDecoration(
                labelText: 'Avancement minimal pour la projection',
                suffixText: '%',
                helperText:
                    'La projection (indicateur secondaire) n\'apparaît '
                    'qu\'à partir de cet avancement des heures.',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              validator: (v) => _validerPct(v, max: 100),
            ),
            _TitreSection('Valeurs par défaut'),
            TextFormField(
              controller: _baremeKm,
              decoration: const InputDecoration(
                labelText: 'Barème kilométrique',
                suffixText: '€ / km',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              validator: _validerBareme,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _effectif,
              decoration: const InputDecoration(
                labelText: 'Effectif par défaut',
                suffixText: 'pers.',
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              validator: _validerEffectif,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _journeeType,
              decoration: const InputDecoration(
                labelText: 'Journée type',
                helperText:
                    'Ex. 7 h 30 — sert à convertir les heures en jours.',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _enregistrer(),
              validator: _validerJourneeType,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _enregistrer,
              icon: const Icon(Icons.check),
              label: const Text('Enregistrer'),
            ),
            _TitreSection('Données'),
            const Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                enabled: false,
                leading: Icon(Icons.delete_outline),
                title: Text('Corbeille'),
                subtitle: Text('Disponible à l\'étape 5'),
              ),
            ),
            _TitreSection('Compte'),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Connecté en tant que'),
                subtitle: Text(email ?? '—'),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: deconnexionEnCours
                  ? null
                  : () => unawaited(
                      ref.read(authControllerProvider.notifier).signOut(),
                    ),
              icon: const Icon(Icons.logout),
              label: const Text('Se déconnecter'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitreSection extends StatelessWidget {
  const _TitreSection(this.titre);

  final String titre;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 12),
      child: Text(
        titre,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}
