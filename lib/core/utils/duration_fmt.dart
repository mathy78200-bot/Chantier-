import '../constants/defaults.dart';
import 'rounding.dart';

/// Formatage et saisie des durées. Les durées sont des `int` en minutes ;
/// l'UI saisit en heures / quarts d'heure.
abstract final class DurationFmt {
  /// « 7 h 30 », « 45 min », « 0 h ».
  static String format(int minutes) {
    final signe = minutes < 0 ? '-' : '';
    final abs = minutes.abs();
    final h = abs ~/ 60;
    final m = abs % 60;
    if (h == 0 && m == 0) return '0 h';
    if (h == 0) return '$signe$m min';
    if (m == 0) return '$signe$h h';
    return '$signe$h h ${m.toString().padLeft(2, '0')}';
  }

  /// « 7,5 h » (une décimale).
  static String formatDecimal(int minutes) {
    final heures = Rounding.toDecimals(minutes / 60, 1);
    return '${heures.toString().replaceAll('.', ',')} h';
  }

  /// « 3,5 j » à partir de la journée type.
  static String formatJours(
    int minutes, {
    int minutesJourneeType = Defaults.minutesJourneeType,
  }) {
    final jours = Rounding.toDecimals(minutes / minutesJourneeType, 1);
    return '${jours.toString().replaceAll('.', ',')} j';
  }

  static double toHeures(int minutes) => minutes / 60;

  static int fromHeures(double heures) => Rounding.toMinutes(heures * 60);

  /// Arrondit au quart d'heure le plus proche.
  static int arrondiQuartHeure(int minutes) =>
      Rounding.halfUp(minutes / Defaults.quartHeureMinutes) *
      Defaults.quartHeureMinutes;

  /// Saisie utilisateur (« 7h30 », « 7 h 30 », « 7:30 », « 7,5 », « 45min »)
  /// → minutes. Retourne null si la saisie est invalide.
  static int? parse(String saisie) {
    final s = saisie.trim().toLowerCase().replaceAll(' ', '');
    if (s.isEmpty) return null;
    final minSeul = RegExp(r'^(\d+)min$').firstMatch(s);
    if (minSeul != null) return int.parse(minSeul.group(1)!);
    final hm = RegExp(r'^(\d+)[h:](\d{1,2})?$').firstMatch(s);
    if (hm != null) {
      final h = int.parse(hm.group(1)!);
      final m = int.tryParse(hm.group(2) ?? '0') ?? 0;
      if (m >= 60) return null;
      return h * 60 + m;
    }
    final dec = double.tryParse(s.replaceAll(',', '.').replaceAll('h', ''));
    if (dec == null || dec < 0) return null;
    return fromHeures(dec);
  }
}
