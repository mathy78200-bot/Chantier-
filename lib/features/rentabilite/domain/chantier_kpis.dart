import '../../../core/constants/enums.dart';
import '../../chantiers/domain/chantier.dart';
import 'chantier_data.dart';
import 'completude_calculator.dart';
import 'couleur_calculator.dart';
import 'depenses_calculator.dart';
import 'ecart_calculator.dart';
import 'estimation_calculator.dart';
import 'heures_calculator.dart';
import 'previsionnel_calculator.dart';
import 'projection_calculator.dart';
import 'rentabilite_calculator.dart';
import 'resultats.dart';
import 'seuils.dart';
import 'travaux_sup_calculator.dart';

/// Point d'entrée des calculs d'un chantier. Dart pur.
///
/// L'UI reçoit un [ChantierKpis] et **ne recalcule jamais rien**.
class ChantierKpis {
  const ChantierKpis({
    required this.data,
    required this.depenses,
    required this.heures,
    required this.previsionnel,
    required this.rentabilite,
    required this.ecart,
    required this.completude,
    required this.couleur,
    required this.projection,
    required this.estimations,
    required this.travauxSup,
  });

  /// Enchaîne les calculateurs dans l'ordre de leurs dépendances.
  factory ChantierKpis.compute(ChantierData data, Seuils seuils) {
    final depenses = DepensesCalculator.compute(data);
    final heures = HeuresCalculator.compute(data);
    final previsionnel = PrevisionnelCalculator.compute(data);
    final rentabilite = RentabiliteCalculator.compute(data);
    final ecart = EcartCalculator.compute(
      depenses: depenses,
      heures: heures,
      previsionnel: previsionnel,
    );
    final completude = CompletudeCalculator.compute(
      data: data,
      previsionnel: previsionnel,
      rentabilite: rentabilite,
    );
    final couleur = CouleurCalculator.compute(
      completude: completude,
      rentabilite: rentabilite,
      ecart: ecart,
      seuils: seuils,
    );
    final projection = ProjectionCalculator.compute(
      data: data,
      depenses: depenses,
      heures: heures,
      previsionnel: previsionnel,
      seuils: seuils,
    );
    final estimations = EstimationCalculator.compute(data, heures);
    final travauxSup = TravauxSupCalculator.compute(data, depenses, heures);
    return ChantierKpis(
      data: data,
      depenses: depenses,
      heures: heures,
      previsionnel: previsionnel,
      rentabilite: rentabilite,
      ecart: ecart,
      completude: completude,
      couleur: couleur,
      projection: projection,
      estimations: estimations,
      travauxSup: travauxSup,
    );
  }

  final ChantierData data;
  final DepensesResult depenses;
  final HeuresResult heures;
  final PrevisionnelResult previsionnel;
  final RentabiliteResult rentabilite;
  final EcartResult ecart;
  final CompletudeResult completude;

  /// Couleur PRINCIPALE (gris / vert / orange / rouge), hors projection (R8).
  final CouleurEtat couleur;

  /// Null si le chantier n'est pas en cours ou si l'avancement est
  /// insuffisant.
  final ProjectionResult? projection;
  final List<EstimationTache> estimations;
  final List<TravauxSupAnalyse> travauxSup;

  Chantier get chantier => data.chantier;
  String get chantierId => data.chantier.id;
  ModePrix get modePrix => data.chantier.modePrix;
  StatutChantier get statut => data.chantier.statut;

  bool get projectionRouge => projection?.couleur == CouleurEtat.rouge;
}
