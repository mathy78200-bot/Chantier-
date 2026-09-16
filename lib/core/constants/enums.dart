/// Énumérations métier partagées.
///
/// Sérialisées par leur `name` (json_serializable) : ne jamais renommer une
/// valeur sans migration des documents existants.
library;

/// R11 — quatre statuts exactement.
///
/// « À faire signer » = potentiel (jamais CA vendu). « À venir » = signé mais
/// non commencé. « En cours » et « Terminé » = activité réelle.
enum StatutChantier {
  aFaireSigner('À faire signer'),
  aVenir('À venir'),
  enCours('En cours'),
  termine('Terminé');

  const StatutChantier(this.libelle);

  final String libelle;

  /// Transitions autorisées (§9.10 : appliquées dans l'UI et dans le service
  /// métier avant écriture ; les règles Firestore ne valident que les valeurs).
  Set<StatutChantier> get transitionsPossibles => switch (this) {
    StatutChantier.aFaireSigner => const {
      StatutChantier.aVenir,
      StatutChantier.enCours,
    },
    StatutChantier.aVenir => const {
      StatutChantier.enCours,
      StatutChantier.aFaireSigner,
    },
    StatutChantier.enCours => const {StatutChantier.termine},
    StatutChantier.termine => const {StatutChantier.enCours},
  };

  bool canTransitionTo(StatutChantier cible) =>
      cible != this && transitionsPossibles.contains(cible);

  /// Chantier signé (devis accepté) : à venir, en cours ou terminé.
  bool get estSigne => this != StatutChantier.aFaireSigner;

  /// Chantier dont le prix vendu entre dans le CA vendu des agrégats
  /// (activité réelle : en cours ou terminé). Les « à venir » sont comptés
  /// à part pour ne pas fausser la marge moyenne (aucune dépense encore).
  bool get compteDansCaVendu =>
      this == StatutChantier.enCours || this == StatutChantier.termine;
}

/// R2 — figé à la création du chantier, jamais additionné entre modes.
enum ModePrix {
  ht('HT'),
  ttc('TTC');

  const ModePrix(this.libelle);

  final String libelle;
}

enum TypeDepense {
  materiaux('Matériaux'),
  sousTraitance('Sous-traitance'),
  repas('Repas'),
  hotel('Hôtel'),
  deplacement('Déplacement'),
  autre('Autre');

  const TypeDepense(this.libelle);

  final String libelle;
}

/// R3 — `accepte` → prix vendu ; `propose` → potentiel à part ; `refuse` →
/// historique.
enum StatutTravauxSup {
  propose('Proposé'),
  accepte('Accepté'),
  refuse('Refusé');

  const StatutTravauxSup(this.libelle);

  final String libelle;
}

enum StatutTache {
  aFaire('À faire'),
  enCours('En cours'),
  terminee('Terminée');

  const StatutTache(this.libelle);

  final String libelle;
}

enum DomaineCategorie {
  depense('Dépense'),
  tache('Tâche');

  const DomaineCategorie(this.libelle);

  final String libelle;
}

/// Unité d'une tâche (quantités en `double`).
enum Unite {
  m('m'),
  m2('m²'),
  m3('m³'),
  u('u'),
  forfait('forfait');

  const Unite(this.libelle);

  final String libelle;
}

enum UploadStatus {
  pending('En attente d\'envoi'),
  uploading('Envoi en cours'),
  uploaded('Envoyé'),
  failed('Échec d\'envoi');

  const UploadStatus(this.libelle);

  final String libelle;
}

/// Couleur d'état d'un chantier (calculée par `CouleurCalculator`).
enum CouleurEtat {
  gris('Prévisionnel incomplet'),
  vert('Dans le budget'),
  orange('À surveiller'),
  rouge('Dérive');

  const CouleurEtat(this.libelle);

  final String libelle;
}
