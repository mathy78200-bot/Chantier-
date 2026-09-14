# Chantiers — suivi de rentabilité

Application mobile Flutter (Android / iOS) pour suivre la **rentabilité réelle**
de chaque chantier : prévu vs réel, où l'argent se perd, amélioration des
estimations. Hors-ligne prioritaire, Firebase (Auth, Firestore, Storage).

Le contexte complet (règles métier, conventions, modèle de données, formules,
état du projet) est dans [`CLAUDE.md`](CLAUDE.md) : à lire avant toute
modification.

## Démarrage

```bash
flutter pub get
cp lib/firebase_options.example.dart lib/firebase_options.dart   # ou : flutterfire configure
dart run build_runner build
flutter analyze
flutter test
```

`lib/firebase_options.dart` est ignoré par git : générez-le avec
`flutterfire configure` (Firebase CLI + FlutterFire CLI) pour un vrai projet.
Les dossiers de plateforme se créent avec
`flutter create . --platforms=android,ios --org <votre.org> --project-name chantiers`.

## Déploiement Firebase

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
firebase emulators:start
```
