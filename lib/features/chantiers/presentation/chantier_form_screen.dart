import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/defaults.dart';
import '../../../core/constants/enums.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../shared/providers/data_providers.dart';
import '../../../shared/providers/repository_providers.dart';
import '../domain/chantier.dart';

/// Création (`chantierId == null`) ou modification d'un chantier.
///
/// - R2 : le mode de prix est pré-rempli depuis les paramètres à la création
///   et **désactivé** en modification ;
/// - R7 : l'écriture est optimiste (`unawaited`), la navigation est
///   immédiate ;
/// - en modification, l'entité chargée est mise à jour par `copyWith` pour
///   conserver `createdAt`, le statut et les dates réelles.
class ChantierFormScreen extends ConsumerStatefulWidget {
  const ChantierFormScreen({super.key, this.chantierId});

  final String? chantierId;

  @override
  ConsumerState<ChantierFormScreen> createState() => _ChantierFormScreenState();
}

class _ChantierFormScreenState extends ConsumerState<ChantierFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nom = TextEditingController();
  final TextEditingController _clientNom = TextEditingController();
  final TextEditingController _clientTelephone = TextEditingController();
  final TextEditingController _adresse = TextEditingController();
  final TextEditingController _prixVendu = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  /// Mode choisi par l'utilisateur ; tant qu'il vaut `null` à la création, le
  /// mode par défaut des paramètres est suivi.
  ModePrix? _modePrix;
  DateTime? _dateDevis;
  DateTime? _dateDebutPrevue;
  DateTime? _dateFinPrevue;
  String? _erreurDates;

  /// Entité chargée en modification (dernière valeur du flux).
  Chantier? _chantierCharge;
  bool _prerempli = false;

  @override
  void dispose() {
    _nom.dispose();
    _clientNom.dispose();
    _clientTelephone.dispose();
    _adresse.dispose();
    _prixVendu.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// Pré-remplit les champs une seule fois à partir du chantier chargé.
  void _preremplir(Chantier chantier) {
    _nom.text = chantier.nom;
    _clientNom.text = chantier.clientNom;
    _clientTelephone.text = chantier.clientTelephone ?? '';
    _adresse.text = chantier.adresse;
    _prixVendu.text = chantier.prixVenduInitialCents == 0
        ? ''
        : _montantSaisie(chantier.prixVenduInitialCents);
    _notes.text = chantier.notes;
    _modePrix = chantier.modePrix;
    _dateDevis = chantier.dateDevis;
    _dateDebutPrevue = chantier.dateDebutPrevue;
    _dateFinPrevue = chantier.dateFinPrevue;
    _prerempli = true;
  }

  /// Centimes → texte de saisie sans symbole (« 12 500,00 »), le suffixe du
  /// champ portant déjà « € HT / TTC ».
  static String _montantSaisie(int cents) =>
      NumberFormat('#,##0.00', 'fr_FR').format(cents / 100);

  String? _validerNom(String? valeur) =>
      (valeur?.trim().isEmpty ?? true) ? 'Le nom est obligatoire.' : null;

  String? _validerPrix(String? valeur) {
    if (valeur == null || valeur.trim().isEmpty) return null;
    final cents = Money.parse(valeur);
    if (cents == null) return 'Montant invalide (ex. 12 500,00).';
    if (cents < 0) return 'Le prix ne peut pas être négatif.';
    return null;
  }

  bool _validerDates() {
    final debut = _dateDebutPrevue;
    final fin = _dateFinPrevue;
    final invalide = debut != null && fin != null && fin.isBefore(debut);
    setState(() {
      _erreurDates = invalide
          ? 'La fin prévue doit être postérieure ou égale au début prévu.'
          : null;
    });
    return !invalide;
  }

  String? _texteOuNull(TextEditingController c) {
    final texte = c.text.trim();
    return texte.isEmpty ? null : texte;
  }

  void _enregistrer(ModePrix modePrix) {
    final formulaireValide = _formKey.currentState!.validate();
    final datesValides = _validerDates();
    if (!formulaireValide || !datesValides) return;

    final prixVenduCents = Money.parse(_prixVendu.text) ?? 0;
    final Chantier chantier;
    final charge = _chantierCharge;
    if (charge == null) {
      chantier = Chantier(
        id: const Uuid().v4(),
        nom: _nom.text.trim(),
        modePrix: modePrix,
        clientNom: _clientNom.text.trim(),
        clientTelephone: _texteOuNull(_clientTelephone),
        adresse: _adresse.text.trim(),
        prixVenduInitialCents: prixVenduCents,
        dateDevis: _dateDevis,
        dateDebutPrevue: _dateDebutPrevue,
        dateFinPrevue: _dateFinPrevue,
        notes: _notes.text.trim(),
      );
    } else {
      // R2 : `modePrix` n'est jamais modifié.
      chantier = charge.copyWith(
        nom: _nom.text.trim(),
        clientNom: _clientNom.text.trim(),
        clientTelephone: _texteOuNull(_clientTelephone),
        adresse: _adresse.text.trim(),
        prixVenduInitialCents: prixVenduCents,
        dateDevis: _dateDevis,
        dateDebutPrevue: _dateDebutPrevue,
        dateFinPrevue: _dateFinPrevue,
        notes: _notes.text.trim(),
      );
    }

    try {
      unawaited(ref.read(chantierRepositoryProvider).upsert(chantier));
    } on AppException catch (e) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }

    if (charge == null) {
      // `go` remplace la pile : le formulaire (navigateur racine) se ferme et
      // la fiche du nouveau chantier s'ouvre dans la branche Chantiers.
      context.go(Routes.chantier(chantier.id));
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.chantierId;
    if (id == null) {
      // Création : le mode suit les paramètres tant qu'il n'est pas choisi.
      final parDefaut = ref
          .watch(parametresProvider)
          .valueOrNull
          ?.modePrixParDefaut;
      return _scaffold(
        titre: 'Nouveau chantier',
        body: _formulaire(
          modePrix: _modePrix ?? parDefaut ?? Defaults.modePrix,
          modeModifiable: true,
        ),
      );
    }

    final chantier = ref.watch(chantierProvider(id));
    return _scaffold(
      titre: 'Modifier le chantier',
      body: AsyncView(
        value: chantier,
        builder: (c) {
          if (c == null) {
            return EmptyState(
              icone: Icons.search_off,
              titre: 'Chantier introuvable',
              action: FilledButton(
                onPressed: () => context.pop(),
                child: const Text('Retour'),
              ),
            );
          }
          _chantierCharge = c;
          if (!_prerempli) _preremplir(c);
          return _formulaire(modePrix: c.modePrix, modeModifiable: false);
        },
      ),
    );
  }

  Widget _scaffold({required String titre, required Widget body}) => Scaffold(
    appBar: AppBar(title: Text(titre)),
    body: body,
  );

  Widget _formulaire({
    required ModePrix modePrix,
    required bool modeModifiable,
  }) {
    final theme = Theme.of(context);
    // `SingleChildScrollView` plutôt que `ListView` : tous les champs restent
    // montés, donc `Form.validate()` les vérifie tous, même hors écran.
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nom,
              decoration: const InputDecoration(labelText: 'Nom du chantier *'),
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              validator: _validerNom,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _clientNom,
              decoration: const InputDecoration(labelText: 'Client'),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _clientTelephone,
              decoration: const InputDecoration(
                labelText: 'Téléphone du client',
              ),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _adresse,
              decoration: const InputDecoration(labelText: 'Adresse'),
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            Text('Mode de prix', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<ModePrix>(
              segments: [
                for (final mode in ModePrix.values)
                  ButtonSegment(value: mode, label: Text(mode.libelle)),
              ],
              selected: {modePrix},
              onSelectionChanged: modeModifiable
                  ? (selection) => setState(() => _modePrix = selection.first)
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                modeModifiable
                    ? 'Figé à la création : tous les montants du chantier '
                          'seront saisis dans ce mode.'
                    : 'Le mode de prix ne peut plus être modifié.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _prixVendu,
              decoration: InputDecoration(
                labelText: 'Prix vendu initial',
                suffixText: '€ ${modePrix.libelle}',
                helperText: 'Montant du devis, hors travaux supplémentaires.',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: _validerPrix,
            ),
            const SizedBox(height: 24),
            _ChampDate(
              libelle: 'Date du devis',
              valeur: _dateDevis,
              onChanged: (d) => setState(() => _dateDevis = d),
            ),
            const SizedBox(height: 16),
            _ChampDate(
              libelle: 'Début prévu',
              valeur: _dateDebutPrevue,
              onChanged: (d) => setState(() => _dateDebutPrevue = d),
            ),
            const SizedBox(height: 16),
            _ChampDate(
              libelle: 'Fin prévue',
              valeur: _dateFinPrevue,
              onChanged: (d) => setState(() => _dateFinPrevue = d),
            ),
            if (_erreurDates != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _erreurDates!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notes'),
              textCapitalization: TextCapitalization.sentences,
              minLines: 2,
              maxLines: 6,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => _enregistrer(modePrix),
              icon: const Icon(Icons.check),
              label: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Champ de date métier : sélecteur natif, valeur stockée à minuit UTC
/// (`DateFmt.jourUtc`), affichée en `DateFmt.court`.
class _ChampDate extends StatelessWidget {
  const _ChampDate({
    required this.libelle,
    required this.valeur,
    required this.onChanged,
  });

  final String libelle;
  final DateTime? valeur;
  final ValueChanged<DateTime?> onChanged;

  Future<void> _choisir(BuildContext context) async {
    final choisie = await showDatePicker(
      context: context,
      initialDate: valeur ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (choisie != null) onChanged(DateFmt.jourUtc(choisie));
  }

  @override
  Widget build(BuildContext context) {
    final date = valeur;
    return InkWell(
      onTap: () => _choisir(context),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: libelle,
          suffixIcon: date == null
              ? const Icon(Icons.calendar_today_outlined)
              : IconButton(
                  tooltip: 'Effacer la date',
                  icon: const Icon(Icons.clear),
                  onPressed: () => onChanged(null),
                ),
        ),
        isEmpty: date == null,
        child: Text(date == null ? '' : DateFmt.court(date)),
      ),
    );
  }
}
