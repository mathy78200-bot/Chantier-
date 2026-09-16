# CLAUDE.md — Suivi de rentabilité des chantiers

> Fichier de contexte pour Claude Code. À placer à la racine du dépôt.
> Il résume tout ce qui a été validé (architecture v2, squelette) et fixe les
> règles de travail. Lis-le entièrement avant toute modification.

---

## 1. Le produit en trois phrases

Application mobile Flutter (Android / iOS) conçue par un patron de chantier
pour des patrons de chantier : suivre la **rentabilité réelle** de chaque
chantier, comparer **prévu et réel**, savoir **où l'argent se perd**, et
**améliorer les estimations** avec l'expérience. Simple, rapide, utilisable
sur le terrain, hors-ligne. Aucune fonction gadget : chaque fonctionnalité
doit apporter un gain de temps, d'argent ou de fiabilité.

Les 7 questions auxquelles l'app répond :
1. Ce chantier va-t-il être rentable ?
2. Qu'est-ce qui était prévu, que se passe-t-il réellement ?
3. Où est-ce que je perds de l'argent ?
4. Combien de temps prend réellement cette tâche ?
5. Combien de personnes prévoir ?
6. Mes estimations s'améliorent-elles ?
7. Puis-je retrouver et exploiter mes données facilement ?

---

## 2. Règles inviolables (ne jamais contourner, même « pour simplifier »)

| # | Règle | Où c'est garanti |
|---|---|---|
| R1 | **Rentabilité = prix vendu − dépenses.** Les heures et l'effectif ne sont **jamais** convertis en coût. | `RentabiliteCalculator` ; aucun autre calcul ne touche `rentabiliteCents` |
| R2 | **HT et TTC ne sont jamais additionnés.** `Chantier.modePrix` est figé à la création ; `ParametresUtilisateur.modePrixParDefaut` (défaut `ht`) ne sert qu'à pré-remplir. | Règle Firestore `unchanged('modePrix')` ; `AgregatsCalculator` produit un bloc par mode |
| R3 | **Travaux sup** : `accepte` → dans le prix vendu ; `propose` → potentiel affiché à part ; `refuse` → historique. Jamais de proposé/refusé dans le CA ni la rentabilité. | `RentabiliteCalculator.compute` |
| R4 | **Une dépense appartient toujours à un chantier.** Pas de collection racine de dépenses. | Structure `chantiers/{id}/depenses` + règle `chantierId == cid` |
| R5 | **La bibliothèque ne modifie jamais le passé.** Une tâche de chantier copie ses valeurs (`*Snapshot`) + `bibliothequeVersion`. Les calculs n'utilisent que l'instance. | `TacheChantier`, `EstimationCalculator` |
| R6 | **Soft delete uniquement** (`deletedAt`, `deletedReason`). Corbeille permanente. Aucune Cloud Function en V1. Aucun `delete` physique autorisé par les règles. | `FirestoreSubcollectionRepository`, règles `allow delete: if false` |
| R7 | **Hors-ligne prioritaire.** Écritures optimistes non attendues, IDs UUID côté client, aucune agrégation serveur, aucune transaction sur le chemin critique. | `main.dart` (cache illimité), repositories (`unawaited`) |
| R8 | **Projection = indicateur secondaire.** Elle ne remplace jamais l'écart réel et n'entre jamais dans la couleur principale ni dans la rentabilité. | `ProjectionCalculator` séparé de `EcartCalculator` |
| R9 | **Une seule règle d'arrondi** pour double → minutes / centimes : `Rounding.toMinutes`, `Rounding.toCents`, `Rounding.toDecimals` (half-up, jamais bankers rounding). | `core/utils/rounding.dart` |
| R10 | **Le prévisionnel est complet sans tâche** si prix vendu, budget, heures prévues et effectif sont renseignés (globaux ou dérivés des tâches). Les tâches sont optionnelles. | `CompletudeCalculator` |
| R11 | **Quatre statuts exactement** : `aFaireSigner`, `aVenir`, `enCours`, `termine`. « À faire signer » = potentiel, jamais CA vendu. | `StatutChantier`, `AgregatsCalculator` |
| R12 | **Aucune fonctionnalité hors architecture validée.** Toute nouveauté → proposer d'abord, coder après validation. | Discipline |

---

## 3. Conventions techniques

- **Argent** : `int` en centimes, suffixe `Cents`. Jamais de `double`.
- **Durées** : `int` en minutes, suffixe `Minutes`. Saisie UI en heures / quarts d'heure via `DurationFmt`.
- **Quantités** : `double` (m, m², u). Conversion vers minutes uniquement via `Rounding`.
- **Dates** : UTC en base, affichées en local (`DateFmt`). Dates métier saisies par l'utilisateur ; `createdAt`/`updatedAt` = `serverTimestamp` (lus avec `estimate` si besoin).
- **IDs** : `Uuid().v4()` côté client.
- **Entités** : Freezed **4.x** (`abstract class X with _$X`, constructeur privé `const X._()` pour les getters — migration en bloc depuis la syntaxe 2.x, cf. §9.1 : freezed 2.x exige un `analyzer` incompatible avec Dart 3.13). Aucun import Firebase dans `domain/`.
- **Sérialisation** : json_serializable + `FirestoreCodec` (`shared/firestore_codec.dart`) qui convertit Timestamp ↔ ISO 8601 et gère `createdAt`/`updatedAt`. Les DTO n'existent pas comme classes séparées : le codec + `toJson`/`fromJson` jouent ce rôle. Les champs date à convertir sont listés dans `FirestoreCodec.toDoc` — **ajouter tout nouveau champ date à cette liste**.
- **Repositories** : interface dans `domain/`, implémentation Firestore dans `data/`. Sous-collections de chantier via `FirestoreSubcollectionRepository<T>` (générique : `watchActifs`, `watchCorbeille`, `upsert`, `softDelete`, `restore`).
- **État** : Riverpod 2 (`flutter_riverpod` 2.6) avec providers écrits à la main (`Provider`, `StreamProvider.family`, `AsyncNotifier`). `riverpod_generator` n'est **pas déclaré** (sa version 2.x est irrésolvable avec `freezed` 4 / `build_runner` 2.16) — ne pas introduire de providers générés sans décision explicite.
- **Navigation** : go_router 18 (API `StatefulShellRoute.indexedStack` inchangée depuis la 14), 4 branches, bouton ＋ contextuel dans `AppShell`. Le formulaire « nouveau chantier » est poussé sur le navigateur racine.
- **Calculs** : `features/rentabilite/domain/` est **Dart pur** (aucun import Flutter/Firebase). Point d'entrée : `ChantierKpis.compute(ChantierData, Seuils)`. L'UI reçoit un `ChantierKpis` et **ne recalcule jamais rien**.
- **Filtrage soft delete** : `ChantierData` exclut lui-même les éléments supprimés ; les repositories filtrent `deletedAt == null` côté requête (le champ est toujours écrit, à `null` explicite : Firestore ne retourne pas les documents où il est absent).
- **Erreurs d'écriture** (§9.2) : les repositories lancent les écritures avec `unawaited` et rendent une `Future` déjà complétée ; les refus arrivent dans `WriteErrorNotifier` (`shared/write_error_notifier.dart`) que `AppShell` affiche en SnackBar. Les invariants des règles sont validés côté client avant écriture (`ValidationException`).
- **Langue** : code en anglais technique / français métier (noms d'entités et de champs en français, comme validé). UI 100 % français.
- **Lint** : `flutter_lints` + `prefer_single_quotes`, `always_declare_return_types`.

---

## 4. Arborescence (état actuel)

```
lib/
├── main.dart, app.dart, firebase_options.example.dart   # firebase_options.dart est gitignoré (flutterfire configure)
├── core/
│   ├── constants/{enums.dart, defaults.dart}
│   ├── utils/{rounding.dart, money.dart, duration_fmt.dart, date_utils.dart}
│   ├── errors/app_exception.dart
│   ├── router/app_router.dart          # Routes.*, routerProvider
│   ├── theme/app_theme.dart            # AppTheme.couleur(CouleurEtat)
│   └── widgets/{app_shell, kpi_card, status_chip, empty_state, async_view}.dart
├── shared/
│   ├── chantier_subcollection_repository.dart   # interface générique
│   ├── firestore_subcollection_repository.dart  # impl générique soft delete
│   ├── firestore_codec.dart, firestore_paths.dart, write_error_notifier.dart
│   └── providers/{firebase, repository, data}_providers.dart
└── features/
    ├── auth/           data/auth_repository ; presentation/{login_screen, auth_controller}
    ├── chantiers/      domain/{chantier, previsionnel, chantier_repository} ; data/ ; presentation/{list, detail, form}
    ├── depenses/       domain/{depense, depense_repository} ; data/
    ├── heures/         domain/{saisie_heures, heures_repository} ; data/
    ├── taches/         domain/{tache_chantier, tache_repository} ; data/
    ├── travaux_sup/    domain/{travaux_supplementaire, travaux_sup_repository} ; data/
    ├── justificatifs/  domain/{justificatif, justificatif_repository} ; data/{firestore_justificatif_repository, justificatif_storage}
    ├── bibliotheque/   domain/{bibliotheque_tache, categorie, bibliotheque_repository} ; data/
    ├── reglages/       domain/{parametres_utilisateur, parametres_repository} ; data/ ; presentation/
    ├── rentabilite/    domain/{seuils, chantier_data, resultats, chantier_kpis, 11 *_calculator} ; presentation/{kpis_providers, rentabilite_screen}
    ├── accueil/        presentation/accueil_screen
    └── corbeille/      (vide — à faire)
firebase/{firestore.rules, storage.rules, firestore.indexes.json, README.md}, firebase.json, README.md
test/{core/{rounding, money, duration_fmt}_test, shared/firestore_codec_test, fixtures/fixtures,
      features/rentabilite/*_calculator_test (11) + chantier_kpis_test, features/depenses/data/*_test,
      features/*/presentation/*_screen_test (tests de rendu)}
```

---

## 5. Modèle de données (résumé — détail dans l'architecture v2)

```
users/{uid}                        { email, createdAt, parametres: {modePrixParDefaut, seuilOrangePct,
                                     seuilRougePct, seuilProjectionPct, baremeKmCents, effectifParDefaut,
                                     minutesJourneeType, entrepriseNom, updatedAt} }
├── categories/{id}                { libelle, domaine: depense|tache, ordre, actif, sousCategories[] }
├── bibliothequeTaches/{id}        { libelle, categorieId, sousCategorieId, unite, minutesParUnite (1 pers),
│                                    effectifDefaut, version (+1 par modif), actif }
└── chantiers/{cid}                { nom, clientNom, clientTelephone, adresse, statut, modePrix (FIGÉ),
    │                                prixVenduInitialCents, dateDevis, dateSignature, dateDebutPrevue,
    │                                dateFinPrevue, dateDebutReelle, dateFinReelle, notes, deletedAt, deletedReason }
    ├── previsionnel/main          { budgetDepensesCents, budgetParTypeCents{}, heuresPrevuesMinutes,
    │                                heuresPersonnesPrevuesMinutes, effectifPrevu, dureePrevueJours, commentaire }
    ├── taches/{id}                { libelle, categorie*, bibliothequeTacheId, bibliothequeVersion, unite,
    │                                quantitePrevue (double), minutesParUniteSnapshot, effectifDefautSnapshot,
    │                                heuresPrevuesMinutes, effectifPrevu, travauxSupId?, statut, ordre, deleted* }
    ├── depenses/{id}              { type, montantCents, date, libelle, fournisseur, categorie*, tacheId?,
    │                                travauxSupId?, justificatifIds[], distanceKm?, baremeKmCentsSnapshot?,
    │                                montantSaisiManuellement, commentaire, deleted* }
    ├── heures/{id}                { tacheId?, tacheLibelleSnapshot, travauxSupId?, date, nbPersonnes,
    │                                minutesParPersonne, commentaire, deleted* }
    ├── travauxSup/{id}            { libelle, description, statut: propose|accepte|refuse, prixVenduCents,
    │                                budgetDepensesCents?, heuresPrevuesMinutes?, effectifPrevu?,
    │                                dateProposition, dateDecision?, deleted* }
    └── justificatifs/{id}         { depenseId?, storagePath?, uploadStatus, mimeType, sizeBytes, takenAt, deleted* }
Storage : users/{uid}/chantiers/{cid}/justificatifs/{id}.{jpg|png|pdf}
```

Réel d'un travaux sup = Σ `depenses[travauxSupId]` et Σ `heures[travauxSupId]` (comptés **une seule fois** dans le chantier).

---

## 6. Calculs (formules de référence)

```
prixVendu        = prixVenduInitialCents + Σ TS[accepte].prixVenduCents
potentielTS      = Σ TS[propose].prixVenduCents                       (affiché à part)
depenses         = Σ depenses.montantCents                            (tous types)
rentabilite      = prixVendu − depenses
marge%           = prixVendu > 0 ? rentabilite / prixVendu × 100 : null

heures           = Σ minutesParPersonne                               (durée)
heuresPersonnes  = Σ nbPersonnes × minutesParPersonne                 (charge)

heuresPrevues    = previsionnel.heuresPrevuesMinutes ?? Σ tachesPrincipales.heuresPrevuesMinutes
budgetPrevuTotal = budget + Σ TS[accepte].budgetDepensesCents
heuresPrevuesTot = heuresPrevues + Σ TS[accepte].heuresPrevuesMinutes

ecartDepenses%   = (depenses − budgetPrevuTotal) / budgetPrevuTotal × 100      ← PRINCIPAL
couleur          : gris si prévisionnel incomplet ; rouge si rentabilité < 0 ou écart > seuilRouge (15) ;
                   orange si > seuilOrange (5) ; vert sinon

projection       : si enCours et avancement = heures/heuresPrevuesTot ≥ 20 % :
                   depensesProjetees = depenses / avancement ; ecartProjete% ; couleur séparée   ← SECONDAIRE

complétude       : obligatoires = prix vendu > 0, budget, heuresPrevues, effectif (globaux ou dérivés)
                   recommandé = durée ; % = (nbOb×2 + nbRec) / 9 × 100

estimation tâche : reel = heuresPersonnes(tâche) / quantitePrevue   (min/unité pour 1 personne)
                   ecart% = (reel − minutesParUniteSnapshot) / snapshot × 100   (arrondi 1 décimale)

accueil          : par ModePrix — caVendu, depenses, rentabilite, margeMoyenne% = rentab / caVendu (pondérée)
                   aFaireSigner (nb, Σ prixVenduInitial), aVenir (nb, Σ prixVendu), aSurveiller (rouge, orange, proj. rouge)
```

---

## 7. État du projet

### Fait (squelette compilé : `flutter analyze` sans problème, `flutter test` vert — Flutter 3.47.4 / Dart 3.13.3)
- pubspec, lint, build.yaml, `.gitignore`, `firebase.json`, règles Firestore/Storage v2, index composites.
- Entités Freezed, interfaces et implémentations Firestore de tous les repositories.
- 11 calculateurs purs + 12 suites de tests (formules §6 épinglées à la main) + tests arrondis / formatage / codec + test repository (`fake_cloud_firestore`) + tests de rendu des écrans.
- Providers Riverpod, router, shell 4 onglets + ＋ contextuel.
- Écrans de base : login, accueil, liste chantiers, création / modification chantier, fiche chantier (KPIs), rentabilité, réglages.
- Adaptations de versions (§9.1) : `freezed` 4, `go_router` 18, `intl: any`, `riverpod_generator` non déclaré.

### Étapes suivantes (dans l'ordre, une validation entre chaque)
1. ~~**Compilation et tests verts**~~ — fait (`pub get`, `build_runner`, `flutter analyze`, `flutter test`). Reste à lancer une fois `flutter create . --platforms=android,ios --org <votre org>` (dossiers de plateforme non versionnés tant que l'organisation n'est pas choisie) et `flutterfire configure`.
2. **Formulaires métier du ＋ contextuel** : dépense (+ variantes sous-traitance/repas/hôtel), déplacement (km × barème ou manuel), heures, tâche (libre ou depuis bibliothèque avec snapshot), travaux sup, justificatif (photo → local → queue). Listes correspondantes dans la fiche chantier.
3. **Prévisionnel** : formulaire mode simple + affichage de la complétude et des manquants.
4. **Transitions de statut** avec confirmations et dates automatiques.
5. **Corbeille** par chantier + globale, restauration, SnackBar « Annuler ».
6. **Bibliothèque et catégories** : CRUD, archivage, versionnage, bouton « reprendre la valeur constatée ».
7. **Onglet Rentabilité** : graphiques `fl_chart` sobres, analyse TS, courbe d'amélioration des estimations.
8. **UploadQueue** des justificatifs (retour réseau via `connectivity_plus`), badge « en attente d'envoi ».
9. Finitions : indicateurs `hasPendingWrites`, états vides, accessibilité, tests widgets.

---

## 8. Commandes

```bash
flutter create . --platforms=android,ios --org fr.votreentreprise --project-name chantiers
flutter pub get
flutterfire configure                                   # génère lib/firebase_options.dart
dart run build_runner build --delete-conflicting-outputs
flutter test                                            # tout
flutter test test/features/rentabilite                  # calculateurs seuls
firebase deploy --only firestore:rules,firestore:indexes,storage
firebase emulators:start                                # optionnel (auth 9099, firestore 8080, storage 9199)
flutter run
```

---

## 9. Analyse des principaux challenges et problèmes

### 9.1 Compilation : points levés
Le squelette compile et ses tests passent (Flutter 3.47.4 / Dart 3.13.3). Ce qui a été tranché :
- **Versions de packages** : `intl: any` (épinglé par `flutter_localizations`) ; `go_router` 18 (API `StatefulShellRoute` inchangée) ; `freezed` 2.x impossible (exige `analyzer < 8`, Dart 3.13 impose ≥ 13) → toutes les entités migrées d'un coup en syntaxe `abstract class X with _$X` (freezed 4.0.1) ; `riverpod_generator` 2.x irrésolvable → non déclaré.
- `DropdownButtonFormField(value:)` : non utilisé (`SegmentedButton` pour les enums).
- `fake_cloud_firestore` 4.2 supporte `where('deletedAt', isNull: false)` ; `watchCorbeille` testé tel quel. Attention : le fake matche `isNull: true` aussi pour un champ absent, contrairement à Firestore réel — d'où l'écriture systématique de `deletedAt: null`.
- `GoRouterState.of(context)` dans `AppShell` : le contexte est celui du `builder` de `StatefulShellRoute`, donc sous le shell ; à confirmer au premier `flutter run`.
- `cloud_firestore` 6.9 n'expose pas `ServerTimestampBehavior.estimate` : un document créé hors-ligne est relu avec `createdAt == null` jusqu'à la synchronisation ; le codec repose alors un `serverTimestamp` et les règles acceptent `createdAt == request.time` en mise à jour.

### 9.2 Hors-ligne : les écritures « non attendues » cachent les refus de règles
`unawaited(ref.set(...))` rend l'UI instantanée, mais **si une règle Firestore refuse l'écriture, l'erreur arrive plus tard et n'est vue nulle part**. Il faut :
- un handler global sur les `Future` d'écriture (log + SnackBar « une modification n'a pas pu être enregistrée »), ou un `WriteErrorNotifier` alimenté par les repositories ;
- valider côté client exactement ce que les règles valident (montants ≥ 0, `minutesParPersonne ≤ 1440`, `nbPersonnes ≥ 1`, statuts) pour que le refus reste théorique ;
- tester les règles avec l'émulateur (`@firebase/rules-unit-testing`) — aucun test de règles n'existe encore.

### 9.3 `orderBy('updatedAt')` avec des écritures en attente
Un document créé hors-ligne a `updatedAt` = estimation locale ; à la synchronisation la valeur serveur diffère → réordonnancement visible de la liste. Acceptable, mais prévoir un tri secondaire stable (nom) et ne pas animer les listes sur ces changements.

### 9.4 Coût et charge des lectures : `tousKpisProvider` ouvre 6 flux par chantier
Pour l'accueil, chaque chantier actif = 6 listeners Firestore (chantier, prévisionnel, dépenses, heures, tâches, TS). Avec 50 chantiers dont 40 terminés, c'est 300 listeners et des centaines de lectures au démarrage.
Mesures prévues :
- l'accueil ne doit calculer que `enCours` + `aFaireSigner` + `aVenir` (les terminés n'y servent pas) ;
- l'onglet Rentabilité charge les terminés à la demande, sur une période ;
- si le volume l'exige plus tard : document `chantiers/{id}/agregats/main` maintenu **par le client à chaque écriture** (pas de Cloud Function en V1), lu seul pour les listes.
C'est le principal risque de performance et de facture Firestore de la V1.

### 9.5 Justificatifs : `localPath` n'est pas persisté
Le chemin local du fichier en attente n'est stocké nulle part de durable. Après un redémarrage, un justificatif `pending` ne retrouve plus son fichier. Solution à implémenter à l'étape 8 : **chemin local déterministe** `<appDocuments>/justificatifs/{id}.{ext}` reconstruit depuis l'ID + `mimeType`, et l'`UploadQueue` parcourt tous les `pending` au démarrage. Le fichier local est conservé jusqu'à `uploaded`.

### 9.6 Compression et taille des photos
Limite règles : 10 Mo. Une photo de téléphone moderne fait 3–8 Mo : compresser systématiquement (`flutter_image_compress`, ~1 600 px, qualité 80) **avant** de créer le document, et renseigner `sizeBytes` après compression, sinon la règle Firestore (`sizeBytes ≤ 10485760`) et Storage refuseront.

### 9.7 Projection biaisée par les achats de début de chantier
Assumé et documenté : `depenses / avancement` surestime quand le matériel est acheté d'un bloc. La projection reste secondaire, avec la mention obligatoire. Évolution possible (hors V1) : projeter uniquement les types de dépenses « proportionnelles » (main-d'œuvre sous-traitée, repas, déplacements) et prendre le matériel au réel.

### 9.8 Suppression d'un travaux sup accepté
Son soft delete fait baisser le prix vendu global et laisse ses dépenses/heures dans le chantier (elles restent réelles). C'est voulu, mais surprenant : confirmation forte obligatoire, et afficher « (TS supprimé) » sur les lignes concernées.

### 9.9 Versionnage de la bibliothèque hors-ligne
La règle n'autorise que `version + 1`. Deux modifications hors-ligne sur deux téléphones donnent la même version cible → la seconde est refusée à la synchronisation (cf. 9.2). Cas rare en mono-utilisateur ; à surveiller si multi-appareils devient courant.

### 9.10 Transitions de statut non contraintes par les règles
Les règles valident les valeurs, pas les transitions. `StatutChantier.canTransitionTo` doit être appliqué **dans l'UI et dans un service métier** avant écriture ; les dates (`dateSignature`, `dateDebutReelle`, `dateFinReelle`) sont posées par ce service, pas par les écrans.

### 9.11 `deplacerVers` et les justificatifs
La copie d'une dépense vers un autre chantier réassigne `depenseId` sur les justificatifs mais le fichier Storage reste sous le chemin du chantier d'origine (règle Storage : pas de delete, pas de move). Acceptable en V1 ; l'ID du justificatif reste la clé.

### 9.12 Deux appareils, last-write-wins
Mono-utilisateur, documents petits : conflits improbables. Mais **toujours écrire par champs modifiés** (`set(..., merge: true)` ou `update`), jamais un `set` complet, sinon un téléphone hors-ligne écrase l'autre. Les repositories actuels respectent cela ; ne pas y déroger.

### 9.13 iOS : temps de build Firebase
Les pods Firestore compilent lentement. Utiliser les frameworks précompilés :
`pod 'FirebaseFirestore', :git => 'https://github.com/invertase/firestore-ios-sdk-frameworks.git', :tag => '<version>'` dans le Podfile, `platform :ios, '13.0'`.

### 9.14 Sécurité : périmètre réel
Isolation par `uid` correcte, invariants validés. Ce qui **n'est pas** couvert : quotas (un utilisateur peut créer un volume illimité de documents), App Check (à activer avant mise en production pour bloquer les clients non officiels), et la suppression de compte RGPD (parcours de toutes les sous-collections — à écrire côté client ou, plus tard, en fonction).

---

## 10. Règles de travail pour Claude Code

1. **Lire ce fichier et l'architecture v2 avant tout.** En cas de doute entre les deux, la v2 fait foi ; signaler l'écart.
2. **Ne rien ajouter qui ne soit pas dans l'architecture validée.** Proposer dans la réponse, coder après validation.
3. **Ne jamais toucher aux formules de `features/rentabilite/domain/`** sans test qui échoue d'abord et validation explicite.
4. **Tout calcul en Dart pur, testé.** Pas de logique dans les widgets. Un écran reçoit un `ChantierKpis` ou une entité, point.
5. **Chaque étape = compile + `flutter analyze` sans erreur + `flutter test` vert** avant de rendre la main.
6. **Champs date** : tout nouveau champ `DateTime` doit être ajouté à `FirestoreCodec.toDoc(dateFields)` et validé dans les règles (`isTs`/`isTsOpt`).
7. **Toute nouvelle collection ou champ** → mettre à jour dans le même commit : entité, règles Firestore, index si requête, tests.
8. **Écritures** : toujours via un repository, toujours `merge`/`update`, jamais attendre le `Future` dans l'UI, jamais de `delete`.
9. **Français** dans l'UI, les libellés d'enum et les messages d'erreur. Montants toujours affichés avec leur mode (HT/TTC) quand plusieurs chantiers sont concernés.
10. **Fin de tâche** : lister fichiers créés/modifiés, commandes lancées, tests, et points nécessitant une décision. Puis attendre.
