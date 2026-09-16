import 'package:cloud_firestore/cloud_firestore.dart';

/// Conversion entre le JSON des entités (`toJson` / `fromJson`, dates en
/// ISO 8601) et les documents Firestore (`Timestamp`, `serverTimestamp`).
///
/// Il n'y a pas de DTO : ce codec + `toJson`/`fromJson` jouent ce rôle.
/// **Tout nouveau champ `DateTime` doit être ajouté à [dateFields]** et validé
/// dans les règles Firestore (`isTs` / `isTsOpt`).
abstract final class FirestoreCodec {
  /// Champs date de toutes les entités, convertis ISO 8601 → Timestamp.
  static const Set<String> dateFields = {
    // Communs
    'createdAt',
    'updatedAt',
    'deletedAt',
    // Chantier
    'dateDevis',
    'dateSignature',
    'dateDebutPrevue',
    'dateFinPrevue',
    'dateDebutReelle',
    'dateFinReelle',
    // Dépense, saisie d'heures
    'date',
    // Travaux sup
    'dateProposition',
    'dateDecision',
    // Justificatif
    'takenAt',
  };

  /// JSON d'entité → données de document.
  ///
  /// - les champs de [dateFields] passent d'ISO 8601 à `Timestamp` ;
  /// - `updatedAt` est toujours un `serverTimestamp` ;
  /// - `createdAt` est un `serverTimestamp` s'il est absent (création),
  ///   inchangé sinon ;
  /// - `id` est retiré (c'est l'identifiant du document).
  static Map<String, Object?> toDoc(
    Map<String, dynamic> json, {
    Set<String> dateFields = dateFields,
  }) {
    final doc = <String, Object?>{};
    json.forEach((key, value) {
      if (key == 'id') return;
      doc[key] = dateFields.contains(key) ? toTimestamp(value) : value;
    });
    doc['updatedAt'] = FieldValue.serverTimestamp();
    if (json['createdAt'] == null) {
      doc['createdAt'] = FieldValue.serverTimestamp();
    }
    return doc;
  }

  /// Document → JSON d'entité (`Timestamp` → ISO 8601 UTC, `id` ajouté).
  static Map<String, dynamic> fromDoc(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) => fromData(snapshot.data() ?? const {}, id: snapshot.id);

  static Map<String, dynamic> fromData(
    Map<String, dynamic> data, {
    String? id,
  }) {
    final json = <String, dynamic>{};
    data.forEach((key, value) {
      json[key] = _fromFirestoreValue(value);
    });
    if (id != null) json['id'] = id;
    return json;
  }

  static Object? toTimestamp(Object? value) => switch (value) {
    null => null,
    Timestamp() => value,
    DateTime() => Timestamp.fromDate(value),
    String() => Timestamp.fromDate(DateTime.parse(value)),
    _ => value,
  };

  static Object? _fromFirestoreValue(Object? value) => switch (value) {
    Timestamp() => value.toDate().toUtc().toIso8601String(),
    Map() => value.map(
      (k, v) => MapEntry(k.toString(), _fromFirestoreValue(v)),
    ),
    List() => value.map(_fromFirestoreValue).toList(),
    _ => value,
  };
}
