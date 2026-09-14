import '../../../core/constants/defaults.dart';
import '../../reglages/domain/parametres_utilisateur.dart';

/// Seuils utilisés par les calculateurs (issus des paramètres utilisateur).
class Seuils {
  const Seuils({
    this.orangePct = Defaults.seuilOrangePct,
    this.rougePct = Defaults.seuilRougePct,
    this.projectionPct = Defaults.seuilProjectionPct,
  });

  factory Seuils.fromParametres(ParametresUtilisateur p) => Seuils(
        orangePct: p.seuilOrangePct,
        rougePct: p.seuilRougePct,
        projectionPct: p.seuilProjectionPct,
      );

  /// Écart dépenses (%) au-delà duquel le chantier passe orange.
  final double orangePct;

  /// Écart dépenses (%) au-delà duquel le chantier passe rouge.
  final double rougePct;

  /// Avancement minimal (%) pour calculer une projection.
  final double projectionPct;

  static const Seuils defaut = Seuils();
}
