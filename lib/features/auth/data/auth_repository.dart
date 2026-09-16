import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/errors/app_exception.dart';

/// Authentification Firebase (e-mail / mot de passe).
///
/// Les [FirebaseAuthException] sont traduites en [AuthException] (messages
/// en français, `AuthException.fromCode`).
class AuthRepository {
  const AuthRepository(this._auth);

  final FirebaseAuth _auth;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signIn({required String email, required String password}) =>
      _traduire(
        () => _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ),
      );

  Future<void> signUp({required String email, required String password}) =>
      _traduire(
        () => _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ),
      );

  Future<void> signOut() => _traduire(_auth.signOut);

  Future<void> _traduire(Future<Object?> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromCode(e.code);
    }
  }
}
