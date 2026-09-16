import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';

/// Instances Firebase. À surcharger dans les tests (`ProviderScope.overrides`).
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final firebaseStorageProvider = Provider<FirebaseStorage>(
  (ref) => FirebaseStorage.instance,
);

/// État d'authentification. Le flux émet l'utilisateur courant dès
/// l'abonnement, puis chaque connexion / déconnexion.
final authStateChangesProvider = StreamProvider<User?>(
  (ref) => ref.watch(firebaseAuthProvider).authStateChanges(),
);

/// Uid de l'utilisateur connecté, `null` sinon.
///
/// Source de vérité : [authStateChangesProvider]. Tant que ce flux n'a rien
/// émis (démarrage à froid), l'utilisateur restauré de façon synchrone par le
/// SDK (`currentUser`) fait foi : cela évite un passage par l'écran de
/// connexion à chaque lancement. Dès la première émission, seul le flux compte.
final uidProvider = Provider<String?>((ref) {
  final etat = ref.watch(authStateChangesProvider);
  if (etat.isLoading && !etat.hasValue) {
    return ref.watch(firebaseAuthProvider).currentUser?.uid;
  }
  return etat.valueOrNull?.uid;
});

/// Uid obligatoire pour construire un repository.
///
/// Lève [NonAuthentifieException] si personne n'est connecté ; le provider
/// appelant est reconstruit automatiquement au changement d'uid.
String requireUid(Ref ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) throw const NonAuthentifieException();
  return uid;
}
