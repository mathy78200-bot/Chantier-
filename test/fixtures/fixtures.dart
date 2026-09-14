/// Constructeurs de fixtures pour les tests (valeurs par défaut réalistes).
library;

import 'package:chantiers/core/constants/enums.dart';
import 'package:chantiers/features/chantiers/domain/chantier.dart';
import 'package:chantiers/features/chantiers/domain/previsionnel.dart';
import 'package:chantiers/features/depenses/domain/depense.dart';
import 'package:chantiers/features/heures/domain/saisie_heures.dart';
import 'package:chantiers/features/rentabilite/domain/chantier_data.dart';
import 'package:chantiers/features/taches/domain/tache_chantier.dart';
import 'package:chantiers/features/travaux_sup/domain/travaux_supplementaire.dart';

abstract final class Fixtures {
  static const String chantierId = 'chantier-1';
  static final DateTime jour = DateTime.utc(2026, 3, 2);

  static Chantier chantier({
    String id = chantierId,
    String nom = 'Rénovation Dupont',
    ModePrix modePrix = ModePrix.ht,
    StatutChantier statut = StatutChantier.enCours,
    int prixVenduInitialCents = 1000000,
    DateTime? dateDebutPrevue,
    DateTime? dateFinPrevue,
    DateTime? deletedAt,
  }) =>
      Chantier(
        id: id,
        nom: nom,
        modePrix: modePrix,
        statut: statut,
        prixVenduInitialCents: prixVenduInitialCents,
        dateDebutPrevue: dateDebutPrevue,
        dateFinPrevue: dateFinPrevue,
        deletedAt: deletedAt,
      );

  static Previsionnel previsionnel({
    String chantierId = chantierId,
    int? budgetDepensesCents,
    Map<String, int> budgetParTypeCents = const {},
    int? heuresPrevuesMinutes,
    int? heuresPersonnesPrevuesMinutes,
    int? effectifPrevu,
    int? dureePrevueJours,
  }) =>
      Previsionnel(
        chantierId: chantierId,
        budgetDepensesCents: budgetDepensesCents,
        budgetParTypeCents: budgetParTypeCents,
        heuresPrevuesMinutes: heuresPrevuesMinutes,
        heuresPersonnesPrevuesMinutes: heuresPersonnesPrevuesMinutes,
        effectifPrevu: effectifPrevu,
        dureePrevueJours: dureePrevueJours,
      );

  /// Prévisionnel complet : budget 6 000 €, 80 h, 2 personnes, 5 jours.
  static Previsionnel previsionnelComplet({String chantierId = chantierId}) =>
      previsionnel(
        chantierId: chantierId,
        budgetDepensesCents: 600000,
        heuresPrevuesMinutes: 80 * 60,
        effectifPrevu: 2,
        dureePrevueJours: 5,
      );

  static Depense depense({
    String id = 'dep-1',
    String chantierId = chantierId,
    TypeDepense type = TypeDepense.materiaux,
    int montantCents = 10000,
    DateTime? date,
    String? tacheId,
    String? travauxSupId,
    double? distanceKm,
    int? baremeKmCentsSnapshot,
    bool montantSaisiManuellement = false,
    DateTime? deletedAt,
  }) =>
      Depense(
        id: id,
        chantierId: chantierId,
        date: date ?? jour,
        type: type,
        montantCents: montantCents,
        libelle: 'Dépense $id',
        tacheId: tacheId,
        travauxSupId: travauxSupId,
        distanceKm: distanceKm,
        baremeKmCentsSnapshot: baremeKmCentsSnapshot,
        montantSaisiManuellement: montantSaisiManuellement,
        deletedAt: deletedAt,
      );

  static SaisieHeures heures({
    String id = 'h-1',
    String chantierId = chantierId,
    int nbPersonnes = 1,
    int minutesParPersonne = 480,
    DateTime? date,
    String? tacheId,
    String? travauxSupId,
    DateTime? deletedAt,
  }) =>
      SaisieHeures(
        id: id,
        chantierId: chantierId,
        date: date ?? jour,
        nbPersonnes: nbPersonnes,
        minutesParPersonne: minutesParPersonne,
        tacheId: tacheId,
        travauxSupId: travauxSupId,
        deletedAt: deletedAt,
      );

  static TacheChantier tache({
    String id = 't-1',
    String chantierId = chantierId,
    String libelle = 'Pose carrelage',
    Unite unite = Unite.m2,
    double quantitePrevue = 20,
    double? minutesParUniteSnapshot,
    int? effectifDefautSnapshot,
    int? heuresPrevuesMinutes,
    int? effectifPrevu,
    String? bibliothequeTacheId,
    int? bibliothequeVersion,
    String? travauxSupId,
    DateTime? deletedAt,
  }) =>
      TacheChantier(
        id: id,
        chantierId: chantierId,
        libelle: libelle,
        unite: unite,
        quantitePrevue: quantitePrevue,
        minutesParUniteSnapshot: minutesParUniteSnapshot,
        effectifDefautSnapshot: effectifDefautSnapshot,
        heuresPrevuesMinutes: heuresPrevuesMinutes,
        effectifPrevu: effectifPrevu,
        bibliothequeTacheId: bibliothequeTacheId,
        bibliothequeVersion: bibliothequeVersion,
        travauxSupId: travauxSupId,
        deletedAt: deletedAt,
      );

  static TravauxSupplementaire travauxSup({
    String id = 'ts-1',
    String chantierId = chantierId,
    String libelle = 'Cloison supplémentaire',
    StatutTravauxSup statut = StatutTravauxSup.accepte,
    int prixVenduCents = 200000,
    int? budgetDepensesCents,
    int? heuresPrevuesMinutes,
    int? effectifPrevu,
    DateTime? deletedAt,
  }) =>
      TravauxSupplementaire(
        id: id,
        chantierId: chantierId,
        libelle: libelle,
        dateProposition: jour,
        statut: statut,
        prixVenduCents: prixVenduCents,
        budgetDepensesCents: budgetDepensesCents,
        heuresPrevuesMinutes: heuresPrevuesMinutes,
        effectifPrevu: effectifPrevu,
        deletedAt: deletedAt,
      );

  static ChantierData data({
    Chantier? chantier,
    Previsionnel? previsionnel,
    List<Depense> depenses = const [],
    List<SaisieHeures> heures = const [],
    List<TacheChantier> taches = const [],
    List<TravauxSupplementaire> travauxSup = const [],
  }) =>
      ChantierData(
        chantier: chantier ?? Fixtures.chantier(),
        previsionnel: previsionnel,
        depenses: depenses,
        heures: heures,
        taches: taches,
        travauxSup: travauxSup,
      );
}
