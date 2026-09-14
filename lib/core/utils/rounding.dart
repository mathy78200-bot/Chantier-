/// R9 — une seule règle d'arrondi pour double → entier : arrondi commercial
/// « half-up » (0,5 s'éloigne de zéro). Jamais de bankers rounding.
abstract final class Rounding {
  /// Compense les imprécisions binaires (ex. 2,675 × 100 = 267,49999…).
  static const double _epsilon = 1e-9;

  /// Arrondi half-up d'un double vers l'entier le plus proche.
  static int halfUp(double value) {
    if (value.isNaN || value.isInfinite) {
      throw ArgumentError.value(value, 'value', 'Valeur non finie');
    }
    final abs = value.abs() + _epsilon;
    final floor = abs.floor();
    final result = (abs - floor) >= 0.5 ? floor + 1 : floor;
    return value < 0 ? -result : result;
  }

  /// Minutes (double) → minutes entières.
  static int toMinutes(double minutes) => halfUp(minutes);

  /// Euros (double) → centimes entiers.
  static int toCents(double euros) => halfUp(euros * 100);

  /// Arrondi à `decimals` décimales (half-up).
  static double toDecimals(double value, int decimals) {
    if (decimals < 0) {
      throw ArgumentError.value(decimals, 'decimals', 'Doit être ≥ 0');
    }
    var factor = 1.0;
    for (var i = 0; i < decimals; i++) {
      factor *= 10;
    }
    return halfUp(value * factor) / factor;
  }
}
