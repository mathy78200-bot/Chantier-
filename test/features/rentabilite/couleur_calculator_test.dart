/// §6 : couleur = gris si prévisionnel incomplet ; rouge si rentabilité < 0
///      ou écart > seuilRouge (15) ; orange si > seuilOrange (5) ; vert sinon.
/// R8 : la projection n'entre jamais dans la couleur principale.
library;

import 'package:chantiers/core/constants/enums.dart';
import 'package:chantiers/features/rentabilite/domain/couleur_calculator.dart';
import 'package:chantiers/features/rentabilite/domain/resultats.dart';
import 'package:chantiers/features/rentabilite/domain/seuils.dart';
import 'package:flutter_test/flutter_test.dart';

const CompletudeResult _complet = CompletudeResult(pct: 100, manquants: []);
const CompletudeResult _incomplet = CompletudeResult(
  pct: 78,
  manquants: [ChampPrevisionnel.budget],
);

/// Rentabilité de 10 000 € de prix vendu moins [depensesCents].
RentabiliteResult _rentabilite(int depensesCents) => RentabiliteResult(
  prixVenduInitialCents: 1000000,
  travauxSupAcceptesCents: 0,
  prixVenduCents: 1000000,
  potentielTravauxSupCents: 0,
  depensesCents: depensesCents,
  rentabiliteCents: 1000000 - depensesCents,
  margePct: null,
);

EcartResult _ecart(double? pct) => EcartResult(
  ecartDepensesCents: pct == null ? null : 0,
  ecartDepensesPct: pct,
  ecartParTypeCents: const {},
  ecartHeuresMinutes: null,
  ecartHeuresPct: null,
  ecartChargeMinutes: null,
  ecartChargePct: null,
);

CouleurEtat _couleur({
  CompletudeResult completude = _complet,
  int depensesCents = 500000,
  double? ecartPct = 0.0,
  Seuils seuils = Seuils.defaut,
}) => CouleurCalculator.compute(
  completude: completude,
  rentabilite: _rentabilite(depensesCents),
  ecart: _ecart(ecartPct),
  seuils: seuils,
);

void main() {
  group('CouleurCalculator.compute', () {
    test('gris si prévisionnel incomplet, même avec rentabilité négative et '
        'écart énorme', () {
      expect(
        _couleur(
          completude: _incomplet,
          depensesCents: 2000000,
          ecartPct: 250.0,
        ),
        CouleurEtat.gris,
      );
      expect(_couleur(completude: _incomplet), CouleurEtat.gris);
    });

    test('rouge si rentabilité < 0, même avec un écart dans le budget', () {
      expect(
        _couleur(depensesCents: 1000001, ecartPct: -10.0),
        CouleurEtat.rouge,
      );
    });

    test('rentabilité exactement 0 : pas négative, la couleur dépend de '
        'l\'écart', () {
      expect(_couleur(depensesCents: 1000000, ecartPct: 0.0), CouleurEtat.vert);
      expect(
        _couleur(depensesCents: 1000000, ecartPct: 20.0),
        CouleurEtat.rouge,
      );
    });

    test('rouge si écart > 15', () {
      expect(_couleur(ecartPct: 16.0), CouleurEtat.rouge);
      expect(_couleur(ecartPct: 250.0), CouleurEtat.rouge);
    });

    test('orange si écart > 5 (et ≤ 15)', () {
      expect(_couleur(ecartPct: 6.0), CouleurEtat.orange);
      expect(_couleur(ecartPct: 10.0), CouleurEtat.orange);
    });

    test('vert sinon (écart 0, négatif, ou ≤ 5)', () {
      expect(_couleur(ecartPct: 0.0), CouleurEtat.vert);
      expect(_couleur(ecartPct: -30.0), CouleurEtat.vert);
      expect(_couleur(ecartPct: 4.9), CouleurEtat.vert);
    });

    test('seuils exacts : 5,0 → vert, 5,1 → orange ; 15,0 → orange, '
        '15,1 → rouge', () {
      expect(_couleur(ecartPct: 5.0), CouleurEtat.vert);
      expect(_couleur(ecartPct: 5.1), CouleurEtat.orange);
      expect(_couleur(ecartPct: 15.0), CouleurEtat.orange);
      expect(_couleur(ecartPct: 15.1), CouleurEtat.rouge);
    });

    test('seuils personnalisés Seuils(orangePct: 10, rougePct: 30)', () {
      const seuils = Seuils(orangePct: 10, rougePct: 30);

      expect(_couleur(ecartPct: 10.0, seuils: seuils), CouleurEtat.vert);
      expect(_couleur(ecartPct: 10.1, seuils: seuils), CouleurEtat.orange);
      expect(_couleur(ecartPct: 20.0, seuils: seuils), CouleurEtat.orange);
      expect(_couleur(ecartPct: 30.0, seuils: seuils), CouleurEtat.orange);
      expect(_couleur(ecartPct: 30.1, seuils: seuils), CouleurEtat.rouge);
      // Avec les seuils par défaut, 20 % serait rouge.
      expect(_couleur(ecartPct: 20.0), CouleurEtat.rouge);
    });

    test('prévisionnel complet mais écart non calculable (budget 0) : vert, '
        'seule la rentabilité peut alerter', () {
      expect(_couleur(ecartPct: null), CouleurEtat.vert);
      expect(
        _couleur(ecartPct: null, depensesCents: 1500000),
        CouleurEtat.rouge,
      );
    });

    test('Seuils.defaut = 5 / 15 / 20', () {
      expect(Seuils.defaut.orangePct, 5);
      expect(Seuils.defaut.rougePct, 15);
      expect(Seuils.defaut.projectionPct, 20);
    });
  });

  group('CouleurCalculator.pourEcart', () {
    test('null → gris', () {
      expect(
        CouleurCalculator.pourEcart(null, Seuils.defaut),
        CouleurEtat.gris,
      );
    });

    test('mêmes seuils que la couleur principale', () {
      expect(
        CouleurCalculator.pourEcart(-50.0, Seuils.defaut),
        CouleurEtat.vert,
      );
      expect(CouleurCalculator.pourEcart(5.0, Seuils.defaut), CouleurEtat.vert);
      expect(
        CouleurCalculator.pourEcart(5.1, Seuils.defaut),
        CouleurEtat.orange,
      );
      expect(
        CouleurCalculator.pourEcart(15.0, Seuils.defaut),
        CouleurEtat.orange,
      );
      expect(
        CouleurCalculator.pourEcart(15.1, Seuils.defaut),
        CouleurEtat.rouge,
      );
    });

    test('seuils personnalisés', () {
      const seuils = Seuils(orangePct: 10, rougePct: 30);

      expect(CouleurCalculator.pourEcart(10.0, seuils), CouleurEtat.vert);
      expect(CouleurCalculator.pourEcart(10.1, seuils), CouleurEtat.orange);
      expect(CouleurCalculator.pourEcart(30.1, seuils), CouleurEtat.rouge);
    });
  });
}
