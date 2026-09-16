import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/firestore_codec.dart';
import '../../../shared/firestore_paths.dart';
import '../../../shared/firestore_subcollection_repository.dart';
import '../../../shared/write_error_notifier.dart';
import '../domain/parametres_repository.dart';
import '../domain/parametres_utilisateur.dart';

/// Paramètres de l'utilisateur, champ `parametres` du document `users/{uid}`.
class FirestoreParametresRepository
    with EcritureOptimiste
    implements ParametresRepository {
  FirestoreParametresRepository({
    required this.firestore,
    required this.uid,
    WriteErrorHandler? onWriteError,
  }) : onWriteError = onWriteError ?? journaliserErreurEcriture;

  static const String champParametres = 'parametres';

  final FirebaseFirestore firestore;
  final String uid;

  @override
  final WriteErrorHandler onWriteError;

  DocumentReference<Map<String, dynamic>> get document =>
      firestore.doc(FirestorePaths.user(uid));

  /// Paramètres lus depuis les données du document (défaut si absents).
  static ParametresUtilisateur depuisDonnees(Map<String, dynamic>? data) {
    final brut = data?[champParametres];
    if (brut is! Map) return ParametresUtilisateur.defaut;
    return ParametresUtilisateur.fromJson(
      FirestoreCodec.fromData(Map<String, dynamic>.from(brut)),
    );
  }

  /// Données Firestore du champ `parametres` (dates → `Timestamp`,
  /// `updatedAt` serveur). Le codec ajoute un `createdAt` aux JSON qui n'en
  /// ont pas : il est retiré, le modèle §5 n'en prévoit pas ici.
  static Map<String, Object?> versDonnees(ParametresUtilisateur parametres) =>
      FirestoreCodec.toDoc(parametres.toJson())..remove('createdAt');

  @override
  Stream<ParametresUtilisateur> watch() =>
      document.snapshots().map((snapshot) => depuisDonnees(snapshot.data()));

  /// Invariants vérifiés avant écriture (§9.2).
  void valider(ParametresUtilisateur parametres) {
    if (!parametres.seuilOrangePct.isFinite || parametres.seuilOrangePct < 0) {
      throw const ValidationException(
        'Le seuil orange doit être un pourcentage positif.',
      );
    }
    if (!parametres.seuilRougePct.isFinite || parametres.seuilRougePct < 0) {
      throw const ValidationException(
        'Le seuil rouge doit être un pourcentage positif.',
      );
    }
    if (parametres.seuilRougePct < parametres.seuilOrangePct) {
      throw const ValidationException(
        'Le seuil rouge doit être supérieur ou égal au seuil orange.',
      );
    }
    if (!parametres.seuilProjectionPct.isFinite ||
        parametres.seuilProjectionPct < 0 ||
        parametres.seuilProjectionPct > 100) {
      throw const ValidationException(
        'Le seuil de projection doit être compris entre 0 et 100 %.',
      );
    }
    if (parametres.baremeKmCents < 0) {
      throw const ValidationException(
        'Le barème kilométrique ne peut pas être négatif.',
      );
    }
    if (parametres.effectifParDefaut < 1) {
      throw const ValidationException(
        'L\'effectif par défaut doit être d\'au moins une personne.',
      );
    }
    if (parametres.minutesJourneeType < 1) {
      throw const ValidationException(
        'La journée type doit durer au moins une minute.',
      );
    }
  }

  @override
  Future<void> save(ParametresUtilisateur parametres) {
    valider(parametres);
    final data = <String, Object?>{champParametres: versDonnees(parametres)};
    ecrire(() => document.set(data, SetOptions(merge: true)));
    return termine;
  }

  /// Crée `users/{uid}` (email, `createdAt`, paramètres par défaut) s'il
  /// n'existe pas. La lecture préalable n'est pas sur le chemin critique :
  /// tout s'exécute en arrière-plan et la `Future` rendue est déjà complétée.
  /// Si la lecture échoue (hors-ligne sans cache), rien n'est écrit pour ne
  /// pas écraser des paramètres existants ; l'initialisation sera retentée à
  /// la prochaine connexion.
  @override
  Future<void> initialiserUtilisateur({required String email}) {
    final ref = document;
    ecrire(() async {
      final snapshot = await ref.get();
      if (snapshot.exists) return;
      await ref.set(<String, Object?>{
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        champParametres: versDonnees(ParametresUtilisateur.defaut),
      }, SetOptions(merge: true));
    });
    return termine;
  }
}
