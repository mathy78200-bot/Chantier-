import 'enums.dart';

/// Valeurs par défaut et bornes métier (miroir des règles Firestore).
abstract final class Defaults {
  static const ModePrix modePrix = ModePrix.ht;

  /// Seuils d'écart dépenses (%) — couleur orange / rouge.
  static const double seuilOrangePct = 5;
  static const double seuilRougePct = 15;

  /// Avancement minimal (%) pour afficher la projection (R8, secondaire).
  static const double seuilProjectionPct = 20;

  /// Barème kilométrique par défaut : 0,60 €/km.
  static const int baremeKmCents = 60;

  static const int effectifParDefaut = 2;

  /// Journée type : 7 h.
  static const int minutesJourneeType = 420;

  /// Bornes validées dans les règles Firestore.
  static const int minutesParPersonneMax = 1440;
  static const int nbPersonnesMin = 1;
  static const int justificatifMaxBytes = 10 * 1024 * 1024;

  /// Pas de saisie des durées dans l'UI.
  static const int quartHeureMinutes = 15;
}
