import 'package:intl/intl.dart';

/// Dates : UTC en base, affichées en local. Les dates métier saisies par
/// l'utilisateur sont normalisées à minuit UTC ([jourUtc]).
abstract final class DateFmt {
  static const String locale = 'fr_FR';

  /// « 14/09/2026 ».
  static String court(DateTime d) =>
      DateFormat('dd/MM/yyyy', locale).format(_pourAffichage(d));

  /// « 14 septembre 2026 ».
  static String long(DateTime d) =>
      DateFormat('d MMMM yyyy', locale).format(_pourAffichage(d));

  /// « septembre 2026 ».
  static String moisAnnee(DateTime d) =>
      DateFormat('MMMM yyyy', locale).format(_pourAffichage(d));

  /// « 14/09/2026 08:30 » (horodatages techniques).
  static String courtHeure(DateTime d) =>
      DateFormat('dd/MM/yyyy HH:mm', locale).format(d.toLocal());

  /// Date métier : jour local (année, mois, jour) → minuit UTC.
  static DateTime jourUtc(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  static DateTime aujourdhuiUtc() => jourUtc(DateTime.now());

  /// Nombre de jours calendaires entre deux dates métier (inclusif).
  static int joursInclusifs(DateTime debut, DateTime fin) =>
      jourUtc(fin).difference(jourUtc(debut)).inDays + 1;

  /// Nombre de jours ouvrés (lundi → vendredi) entre deux dates (inclusif).
  static int joursOuvres(DateTime debut, DateTime fin) {
    var d = jourUtc(debut);
    final f = jourUtc(fin);
    if (f.isBefore(d)) return 0;
    var n = 0;
    while (!d.isAfter(f)) {
      if (d.weekday <= DateTime.friday) n++;
      d = d.add(const Duration(days: 1));
    }
    return n;
  }

  static bool memeJour(DateTime a, DateTime b) => jourUtc(a) == jourUtc(b);

  /// Une date métier stockée à minuit UTC doit être affichée telle quelle
  /// (la conversion locale ferait reculer d'un jour à l'ouest de Greenwich).
  static DateTime _pourAffichage(DateTime d) =>
      d.isUtc &&
          d.hour == 0 &&
          d.minute == 0 &&
          d.second == 0 &&
          d.millisecond == 0
      ? d
      : d.toLocal();
}
