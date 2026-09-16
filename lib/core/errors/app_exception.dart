/// Exceptions métier. Messages en français (affichés tels quels dans l'UI).
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NonAuthentifieException extends AppException {
  const NonAuthentifieException() : super('Utilisateur non connecté.');
}

class ValidationException extends AppException {
  const ValidationException(super.message);
}

class TransitionInvalideException extends AppException {
  const TransitionInvalideException(this.depuis, this.vers)
    : super('Transition de statut impossible : $depuis → $vers.');

  final String depuis;
  final String vers;
}

/// Une écriture optimiste a été refusée après coup (§9.2).
class EcritureRefuseeException extends AppException {
  const EcritureRefuseeException(this.cause)
    : super('Une modification n\'a pas pu être enregistrée.');

  final Object cause;
}

class AuthException extends AppException {
  const AuthException(this.code, super.message);

  final String code;

  /// Traduction des codes Firebase Auth les plus courants.
  factory AuthException.fromCode(String code) {
    final message = switch (code) {
      'invalid-email' => 'Adresse e-mail invalide.',
      'user-disabled' => 'Ce compte a été désactivé.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => 'E-mail ou mot de passe incorrect.',
      'email-already-in-use' => 'Un compte existe déjà avec cet e-mail.',
      'weak-password' => 'Mot de passe trop faible (6 caractères minimum).',
      'network-request-failed' => 'Pas de connexion réseau.',
      'too-many-requests' => 'Trop de tentatives, réessayez plus tard.',
      _ => 'Erreur d\'authentification ($code).',
    };
    return AuthException(code, message);
  }
}
