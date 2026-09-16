/// Test de rendu de `AccueilScreen` : un bloc par mode de prix (R2), montants
/// toujours suivis de HT / TTC (§10.9), état vide et chantiers à surveiller.
library;

import 'package:chantiers/core/constants/enums.dart';
import 'package:chantiers/core/theme/app_theme.dart';
import 'package:chantiers/core/utils/money.dart';
import 'package:chantiers/features/accueil/presentation/accueil_screen.dart';
import 'package:chantiers/features/rentabilite/domain/agregats_calculator.dart';
import 'package:chantiers/features/rentabilite/domain/chantier_kpis.dart';
import 'package:chantiers/features/rentabilite/domain/resultats.dart';
import 'package:chantiers/features/rentabilite/domain/seuils.dart';
import 'package:chantiers/features/rentabilite/presentation/kpis_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fixtures/fixtures.dart';

Widget _app(Agregats agregats) => ProviderScope(
  overrides: [agregatsProvider.overrideWith((ref) => AsyncData(agregats))],
  child: MaterialApp(theme: AppTheme.light(), home: const AccueilScreen()),
);

void main() {
  testWidgets('état vide', (tester) async {
    await tester.pumpWidget(_app(Agregats.vide));
    await tester.pump();

    expect(find.text('Aucun chantier en activité'), findsOneWidget);
    expect(find.text('Voir les chantiers'), findsOneWidget);
  });

  testWidgets('un bloc HT et un bloc TTC, chantier en dérive à surveiller', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // HT : en cours, budget 6 000 €, dépenses 9 000 € → écart +50 % → rouge ;
    // rentabilité = 10 000 − 9 000 = +1 000 €.
    final ht = ChantierKpis.compute(
      Fixtures.data(
        previsionnel: Fixtures.previsionnelComplet(),
        depenses: [Fixtures.depense(montantCents: 900000)],
      ),
      Seuils.defaut,
    );
    // TTC : à faire signer (potentiel, jamais CA vendu — R11).
    final ttc = ChantierKpis.compute(
      Fixtures.data(
        chantier: Fixtures.chantier(
          id: 'chantier-2',
          nom: 'Extension Martin',
          modePrix: ModePrix.ttc,
          statut: StatutChantier.aFaireSigner,
          prixVenduInitialCents: 500000,
        ),
      ),
      Seuils.defaut,
    );
    final agregats = AgregatsCalculator.compute([ht, ttc]);

    await tester.pumpWidget(_app(agregats));
    await tester.pump();

    expect(find.text('Chantiers HT'), findsOneWidget);
    String fmtHt(int cents) => Money.format(cents, mode: ModePrix.ht);
    String fmtTtc(int cents) => Money.format(cents, mode: ModePrix.ttc);
    expect(find.text(fmtHt(1000000)), findsOneWidget); // CA vendu HT
    expect(find.text(fmtHt(900000)), findsOneWidget); // dépenses HT
    expect(find.text(fmtHt(100000)), findsOneWidget); // rentabilité HT
    expect(find.text('Rénovation Dupont'), findsOneWidget); // à surveiller
    expect(find.text(CouleurEtat.rouge.libelle), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Chantiers TTC'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(fmtTtc(0)), findsWidgets); // CA vendu TTC = 0
    await tester.scrollUntilVisible(
      find.text('1 · ${fmtTtc(500000)}'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('1 · ${fmtTtc(500000)}'), findsOneWidget); // à signer
    expect(tester.takeException(), isNull);
  });
}
