// Modèle de `lib/firebase_options.dart` (fichier gitignoré).
//
// Le vrai fichier est généré par `flutterfire configure` avec les clés du
// projet Firebase (Android / iOS). Ce modèle permet de compiler sans projet
// configuré : `currentPlatform` lève alors une erreur explicite au démarrage.
//
// Pour compiler sans configurer Firebase :
//   cp lib/firebase_options.example.dart lib/firebase_options.dart

import 'package:firebase_core/firebase_core.dart';

/// Options Firebase par plateforme (voir `flutterfire configure`).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
    'Lancez « flutterfire configure » pour générer '
    'lib/firebase_options.dart',
  );
}
