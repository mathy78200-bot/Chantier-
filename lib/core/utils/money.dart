import 'package:intl/intl.dart';

import '../constants/enums.dart';
import 'rounding.dart';

/// Formatage et saisie des montants. Les montants sont des `int` en centimes.
abstract final class Money {
  static final NumberFormat _euros = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '€',
    decimalDigits: 2,
  );
  static final NumberFormat _pct = NumberFormat('0.0', 'fr_FR');

  /// « 1 234,56 € », suivi de « HT » / « TTC » si `mode` est fourni.
  static String format(int cents, {ModePrix? mode}) {
    final s = _euros.format(cents / 100);
    return mode == null ? s : '$s ${mode.libelle}';
  }

  /// Comme [format] mais avec un « + » explicite pour les valeurs positives.
  static String formatSigne(int cents, {ModePrix? mode}) {
    final s = format(cents, mode: mode);
    return cents > 0 ? '+$s' : s;
  }

  /// « 12,3 % » ou « — » si null.
  static String formatPct(double? pct) =>
      pct == null ? '—' : '${_pct.format(pct)} %';

  /// Saisie utilisateur (« 1 234,56 », « 1234.5 », « 12 € ») → centimes.
  /// Retourne null si la saisie n'est pas un nombre.
  static int? parse(String saisie) {
    final nettoyee = saisie
        .replaceAll('€', '')
        .replaceAll(RegExp(r'\s'), '')
        .replaceAll(',', '.');
    if (nettoyee.isEmpty) return null;
    final valeur = double.tryParse(nettoyee);
    if (valeur == null) return null;
    return Rounding.toCents(valeur);
  }
}
