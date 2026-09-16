/// Chemins Firestore et Storage (voir CLAUDE.md §5).
abstract final class FirestorePaths {
  static const String users = 'users';
  static const String chantiers = 'chantiers';
  static const String categories = 'categories';
  static const String bibliothequeTaches = 'bibliothequeTaches';

  static const String previsionnel = 'previsionnel';
  static const String previsionnelDocId = 'main';
  static const String taches = 'taches';
  static const String depenses = 'depenses';
  static const String heures = 'heures';
  static const String travauxSup = 'travauxSup';
  static const String justificatifs = 'justificatifs';

  static String user(String uid) => '$users/$uid';

  static String chantiersDe(String uid) => '${user(uid)}/$chantiers';

  static String chantier(String uid, String cid) => '${chantiersDe(uid)}/$cid';

  static String sousCollection(String uid, String cid, String nom) =>
      '${chantier(uid, cid)}/$nom';

  static String previsionnelDoc(String uid, String cid) =>
      '${sousCollection(uid, cid, previsionnel)}/$previsionnelDocId';

  static String categoriesDe(String uid) => '${user(uid)}/$categories';

  static String bibliothequeDe(String uid) =>
      '${user(uid)}/$bibliothequeTaches';

  /// `users/{uid}/chantiers/{cid}/justificatifs/{id}.{ext}` (Storage).
  static String storageJustificatif(
    String uid,
    String cid,
    String id,
    String extension,
  ) => '${sousCollection(uid, cid, justificatifs)}/$id.$extension';
}
