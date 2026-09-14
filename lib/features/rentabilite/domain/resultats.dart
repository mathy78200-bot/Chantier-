/// Types de résultats des calculateurs. Dart pur, immuables.
///
/// Conventions : montants en centimes (`int`), durées en minutes (`int`),
/// pourcentages en `double` arrondis à 1 décimale (`Rounding.toDecimals`),
/// `null` = non calculable (donnée manquante ou division par zéro).
library;

import '../../../core/constants/enums.dart';
import '../../travaux_sup/domain/travaux_supplementaire.dart';

/// Σ dépenses (tous types) et répartitions.
class DepensesResult {
  const DepensesResult({
    required this.totalCents,
    required this.parTypeCents,
    required this.parTravauxSupCents,
    required this.parTacheCents,
    required this.horsTravauxSupCents,
    required this.nbDepenses,
  });

  static const DepensesResult vide = DepensesResult(
    totalCents: 0,
    parTypeCents: {},
    parTravauxSupCents: {},
    parTacheCents: {},
    horsTravauxSupCents: 0,
    nbDepenses: 0,
  );

  /// Σ montantCents, tous types confondus (entre dans la rentabilité).
  final int totalCents;

  /// Par type de dépense (types absents = 0).
  final Map<TypeDepense, int> parTypeCents;

  /// Par `travauxSupId` (comptées aussi dans [totalCents], une seule fois).
  final Map<String, int> parTravauxSupCents;

  /// Par `tacheId`.
  final Map<String, int> parTacheCents;

  /// Dépenses sans `travauxSupId`.
  final int horsTravauxSupCents;

  final int nbDepenses;

  int pourType(TypeDepense type) => parTypeCents[type] ?? 0;
}

/// Σ heures : durée (Σ minutesParPersonne) et charge (Σ nb × minutes).
class HeuresResult {
  const HeuresResult({
    required this.dureeMinutes,
    required this.chargeMinutes,
    required this.chargeParTacheMinutes,
    required this.dureeParTravauxSupMinutes,
    required this.chargeParTravauxSupMinutes,
    required this.nbSaisies,
  });

  static const HeuresResult vide = HeuresResult(
    dureeMinutes: 0,
    chargeMinutes: 0,
    chargeParTacheMinutes: {},
    dureeParTravauxSupMinutes: {},
    chargeParTravauxSupMinutes: {},
    nbSaisies: 0,
  );

  /// Durée : Σ minutesParPersonne.
  final int dureeMinutes;

  /// Charge : Σ nbPersonnes × minutesParPersonne (personne-minutes).
  final int chargeMinutes;

  final Map<String, int> chargeParTacheMinutes;
  final Map<String, int> dureeParTravauxSupMinutes;
  final Map<String, int> chargeParTravauxSupMinutes;
  final int nbSaisies;

  /// Effectif moyen constaté (charge / durée), null sans heures.
  double? get effectifMoyen =>
      dureeMinutes == 0 ? null : chargeMinutes / dureeMinutes;
}

/// R1 — rentabilité = prix vendu − dépenses. Aucun coût d'heures.
class RentabiliteResult {
  const RentabiliteResult({
    required this.prixVenduInitialCents,
    required this.travauxSupAcceptesCents,
    required this.prixVenduCents,
    required this.potentielTravauxSupCents,
    required this.depensesCents,
    required this.rentabiliteCents,
    required this.margePct,
  });

  final int prixVenduInitialCents;

  /// Σ prixVenduCents des TS acceptés (R3).
  final int travauxSupAcceptesCents;

  /// prixVenduInitialCents + travauxSupAcceptesCents.
  final int prixVenduCents;

  /// Σ prixVenduCents des TS proposés — affiché à part, jamais dans le CA.
  final int potentielTravauxSupCents;

  /// Σ dépenses, tous types.
  final int depensesCents;

  /// prixVenduCents − depensesCents.
  final int rentabiliteCents;

  /// rentabilite / prixVendu × 100 (1 décimale), null si prixVendu ≤ 0.
  final double? margePct;

  bool get estNegative => rentabiliteCents < 0;
}

/// Prévisionnel consolidé : valeurs globales, sinon dérivées des tâches,
/// puis augmentées des travaux sup acceptés.
class PrevisionnelResult {
  const PrevisionnelResult({
    required this.budgetDepensesCents,
    required this.budgetTotalCents,
    required this.budgetParTypeCents,
    required this.heuresPrevuesMinutes,
    required this.heuresPrevuesTotalMinutes,
    required this.chargePrevueMinutes,
    required this.chargePrevueTotalMinutes,
    required this.effectifPrevu,
    required this.dureePrevueJours,
    required this.budgetDeriveParType,
    required this.heuresDeriveesDesTaches,
    required this.chargeDeriveeDesTaches,
    required this.effectifDeriveDesTaches,
    required this.dureeDeriveeDesDates,
  });

  /// Budget global saisi, sinon Σ budgets par type, sinon null.
  final int? budgetDepensesCents;

  /// budgetDepensesCents + Σ TS[accepte].budgetDepensesCents.
  final int? budgetTotalCents;

  final Map<TypeDepense, int> budgetParTypeCents;

  /// Durée prévue : globale, sinon Σ tâches principales.
  final int? heuresPrevuesMinutes;

  /// heuresPrevuesMinutes + Σ TS[accepte].heuresPrevuesMinutes.
  final int? heuresPrevuesTotalMinutes;

  /// Charge prévue (personne-minutes) : globale, sinon dérivée.
  final int? chargePrevueMinutes;
  final int? chargePrevueTotalMinutes;

  /// Effectif : global, sinon max des tâches principales.
  final int? effectifPrevu;

  /// Durée en jours : globale, sinon jours ouvrés entre les dates prévues.
  final int? dureePrevueJours;

  final bool budgetDeriveParType;
  final bool heuresDeriveesDesTaches;
  final bool chargeDeriveeDesTaches;
  final bool effectifDeriveDesTaches;
  final bool dureeDeriveeDesDates;
}

/// Écarts réel − prévu. `ecartDepensesPct` est l'indicateur PRINCIPAL.
class EcartResult {
  const EcartResult({
    required this.ecartDepensesCents,
    required this.ecartDepensesPct,
    required this.ecartParTypeCents,
    required this.ecartHeuresMinutes,
    required this.ecartHeuresPct,
    required this.ecartChargeMinutes,
    required this.ecartChargePct,
  });

  /// depenses − budgetTotal, null sans budget.
  final int? ecartDepensesCents;

  /// (depenses − budgetTotal) / budgetTotal × 100, null si budget null ou 0.
  final double? ecartDepensesPct;

  /// Par type, pour les types ayant un budget.
  final Map<TypeDepense, int> ecartParTypeCents;

  final int? ecartHeuresMinutes;
  final double? ecartHeuresPct;
  final int? ecartChargeMinutes;
  final double? ecartChargePct;
}

/// Champs du prévisionnel suivis par la complétude (R10).
enum ChampPrevisionnel {
  prixVendu('Prix vendu', obligatoire: true),
  budget('Budget dépenses', obligatoire: true),
  heuresPrevues('Heures prévues', obligatoire: true),
  effectif('Effectif prévu', obligatoire: true),
  duree('Durée prévue', obligatoire: false);

  const ChampPrevisionnel(this.libelle, {required this.obligatoire});

  final String libelle;
  final bool obligatoire;
}

/// Complétude du prévisionnel : % = (nbOb × 2 + nbRec) / 9 × 100.
class CompletudeResult {
  const CompletudeResult({required this.pct, required this.manquants});

  /// 0 à 100, entier (half-up).
  final int pct;

  /// Champs non renseignés (ni globaux, ni dérivés).
  final List<ChampPrevisionnel> manquants;

  List<ChampPrevisionnel> get manquantsObligatoires =>
      manquants.where((c) => c.obligatoire).toList(growable: false);

  List<ChampPrevisionnel> get manquantsRecommandes =>
      manquants.where((c) => !c.obligatoire).toList(growable: false);

  /// Tous les champs obligatoires sont renseignés.
  bool get estComplet => manquantsObligatoires.isEmpty;
}

/// R8 — projection = indicateur SECONDAIRE, jamais dans la couleur principale
/// ni dans la rentabilité.
class ProjectionResult {
  const ProjectionResult({
    required this.avancementPct,
    required this.depensesProjeteesCents,
    required this.ecartProjeteCents,
    required this.ecartProjetePct,
    required this.couleur,
  });

  /// Mention obligatoire à côté de toute projection (§9.7).
  static const String mention =
      'Projection indicative fondée sur l\'avancement des heures ; '
      'les achats de début de chantier la surestiment.';

  /// heures / heuresPrevuesTotal × 100, plafonné à 100 (1 décimale).
  final double avancementPct;

  /// depenses / avancement.
  final int depensesProjeteesCents;

  /// depensesProjetees − budgetTotal, null sans budget.
  final int? ecartProjeteCents;
  final double? ecartProjetePct;

  /// Couleur propre à la projection (gris sans budget).
  final CouleurEtat couleur;
}

/// Comparaison estimation ↔ réel d'une tâche (min/unité pour 1 personne).
class EstimationTache {
  const EstimationTache({
    required this.tacheId,
    required this.libelle,
    required this.unite,
    required this.quantitePrevue,
    required this.minutesParUniteSnapshot,
    required this.minutesParUniteReel,
    required this.ecartPct,
    required this.chargeReelleMinutes,
    required this.bibliothequeTacheId,
    required this.bibliothequeVersion,
  });

  final String tacheId;
  final String libelle;
  final Unite unite;
  final double quantitePrevue;

  /// Valeur de bibliothèque copiée à la création (R5).
  final double? minutesParUniteSnapshot;

  /// chargeReelle / quantitePrevue (1 décimale), null si quantité ≤ 0 ou
  /// aucune heure saisie.
  final double? minutesParUniteReel;

  /// (reel − snapshot) / snapshot × 100 (1 décimale), null si l'un manque.
  final double? ecartPct;

  final int chargeReelleMinutes;
  final String? bibliothequeTacheId;
  final int? bibliothequeVersion;

  /// Une valeur constatée existe et diffère du snapshot (bouton « reprendre »).
  bool get valeurConstateeDisponible =>
      minutesParUniteReel != null && minutesParUniteReel != minutesParUniteSnapshot;
}

/// Analyse d'un travaux sup : prévu vs réel, réel = Σ dépenses / heures liées.
class TravauxSupAnalyse {
  const TravauxSupAnalyse({
    required this.travauxSup,
    required this.depensesCents,
    required this.dureeMinutes,
    required this.chargeMinutes,
    required this.rentabiliteCents,
    required this.margePct,
    required this.ecartDepensesCents,
    required this.ecartDepensesPct,
    required this.ecartHeuresMinutes,
    required this.ecartHeuresPct,
  });

  final TravauxSupplementaire travauxSup;
  final int depensesCents;
  final int dureeMinutes;
  final int chargeMinutes;

  /// prixVenduCents − depensesCents (indicatif ; seul le TS accepté entre
  /// dans la rentabilité du chantier).
  final int rentabiliteCents;
  final double? margePct;
  final int? ecartDepensesCents;
  final double? ecartDepensesPct;
  final int? ecartHeuresMinutes;
  final double? ecartHeuresPct;

  String get id => travauxSup.id;
  StatutTravauxSup get statut => travauxSup.statut;
}

/// Chantier signalé sur l'accueil.
class ChantierASurveiller {
  const ChantierASurveiller({
    required this.chantierId,
    required this.nom,
    required this.couleur,
    required this.projectionRouge,
  });

  final String chantierId;
  final String nom;
  final CouleurEtat couleur;
  final bool projectionRouge;
}

/// Agrégats d'un mode de prix (R2 : jamais de somme HT + TTC).
class AgregatMode {
  const AgregatMode({
    required this.mode,
    required this.nbChantiers,
    required this.caVenduCents,
    required this.depensesCents,
    required this.rentabiliteCents,
    required this.margeMoyennePct,
    required this.aFaireSignerNb,
    required this.aFaireSignerCents,
    required this.aVenirNb,
    required this.aVenirCents,
    required this.aSurveiller,
  });

  final ModePrix mode;

  /// Chantiers entrant dans le CA vendu (en cours, terminé).
  final int nbChantiers;

  /// Σ prixVendu des chantiers en cours / terminés.
  final int caVenduCents;
  final int depensesCents;
  final int rentabiliteCents;

  /// rentabilite / caVendu × 100 (pondérée, 1 décimale), null si CA = 0.
  final double? margeMoyennePct;

  /// « À faire signer » : nombre et Σ prixVenduInitial (potentiel, R11).
  final int aFaireSignerNb;
  final int aFaireSignerCents;

  /// « À venir » : nombre et Σ prixVendu (signé, non commencé).
  final int aVenirNb;
  final int aVenirCents;

  /// Rouges, oranges et projections rouges (ordre : rouge, orange, proj.).
  final List<ChantierASurveiller> aSurveiller;

  int get nbRouges =>
      aSurveiller.where((c) => c.couleur == CouleurEtat.rouge).length;

  int get nbOranges =>
      aSurveiller.where((c) => c.couleur == CouleurEtat.orange).length;

  int get nbProjectionsRouges =>
      aSurveiller.where((c) => c.projectionRouge).length;
}

/// Agrégats de l'accueil : un bloc par mode de prix présent.
class Agregats {
  const Agregats({required this.parMode});

  static const Agregats vide = Agregats(parMode: {});

  final Map<ModePrix, AgregatMode> parMode;

  AgregatMode? pour(ModePrix mode) => parMode[mode];

  bool get estVide => parMode.isEmpty;

  /// Modes présents, HT en premier.
  List<ModePrix> get modes =>
      ModePrix.values.where(parMode.containsKey).toList(growable: false);
}
