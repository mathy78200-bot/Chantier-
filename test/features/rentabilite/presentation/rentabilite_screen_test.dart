/// Test de rendu de `RentabiliteScreen` : regroupement par mode de prix (R2),
/// une ligne par chantier avec prix vendu, dépenses, rentabilité et marge
/// (aucun total calculé dans l'UI), état vide.
library;

import 'package:chantiers/core/constants/enums.dart';
import 'package:chantiers/core/theme/app_theme.dart';
import 'package:chantiers/core/utils/money.dart';
import 'package:chantiers/features/rentabilite/domain/chantier_kpis.dart';
import 'package:chantiers/features/rentabilite/domain/seuils.dart';
import 'package:chantiers/features/rentabilite/presentation/kpis_providers.dart';
import 'package:chantiers/features/rentabilite/presentation/rentabilite_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fixtures/fixtures.dart';

Widget _app(List<ChantierKpis> kpis) => ProviderScope(
  overrides: [rentabiliteKpisProvider.overrideWith((ref) => AsyncData(kpis))],
  child: MaterialApp(theme: AppTheme.light(), home: const RentabiliteScreen()),
);

void main() {
  testWidgets('état vide', (tester) async {
    await tester.pumpWidget(_app(const []));
    await tester.pump();

    expect(find.text('Aucun chantier en cours ou terminé'), findsOneWidget);
  });

  testWidgets('une ligne par chantier, HT puis TTC', (tester) async {
    final ttc = ChantierKpis.compute(
      Fixtures.data(
        chantier: Fixtures.chantier(
          id: 'chantier-2',
          nom: 'Extension Martin',
          modePrix: ModePrix.ttc,
          statut: StatutChantier.termine,
          prixVenduInitialCents: 500000,
        ),
        depenses: [Fixtures.depense(montantCents: 600000)],
      ),
      Seuils.defaut,
    );
    final ht = ChantierKpis.compute(
      Fixtures.data(depenses: [Fixtures.depense(montantCents: 250000)]),
      Seuils.defaut,
    );

    // TTC fourni en premier : l'écran affiche tout de même HT avant TTC.
    await tester.pumpWidget(_app([ttc, ht]));
    await tester.pump();

    final titreHt = tester.getTopLeft(find.text('Chantiers HT'));
    final titreTtc = tester.getTopLeft(find.text('Chantiers TTC'));
    expect(titreHt.dy, lessThan(titreTtc.dy));

    String fmtHt(int cents) => Money.format(cents, mode: ModePrix.ht);
    String fmtTtc(int cents) => Money.format(cents, mode: ModePrix.ttc);
    expect(
      find.text('Vendu ${fmtHt(1000000)} · dépenses ${fmtHt(250000)}'),
      findsOneWidget,
    );
    expect(find.text('Rentabilité +${fmtHt(750000)}'), findsOneWidget);
    expect(find.text(Money.formatPct(75)), findsOneWidget);
    expect(find.text('Rentabilité ${fmtTtc(-100000)}'), findsOneWidget);
    expect(find.text(Money.formatPct(-20)), findsOneWidget);
    expect(
      find.text('Graphiques et analyse détaillée : étape 7.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
