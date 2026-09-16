/// Test de rendu de `ChantierDetailScreen` : les KPIs calculés sont affichés
/// tels quels (formatés), la projection et la mention « (TS supprimé) »
/// (§9.8) apparaissent, sans débordement à largeur téléphone.
library;

import 'package:chantiers/core/constants/enums.dart';
import 'package:chantiers/core/theme/app_theme.dart';
import 'package:chantiers/core/utils/money.dart';
import 'package:chantiers/features/chantiers/presentation/chantier_detail_screen.dart';
import 'package:chantiers/features/rentabilite/domain/chantier_kpis.dart';
import 'package:chantiers/features/rentabilite/domain/resultats.dart';
import 'package:chantiers/features/rentabilite/domain/seuils.dart';
import 'package:chantiers/features/rentabilite/presentation/kpis_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../fixtures/fixtures.dart';

ChantierKpis _kpisComplets() => ChantierKpis.compute(
  Fixtures.data(
    previsionnel: Fixtures.previsionnelComplet(),
    depenses: [
      Fixtures.depense(id: 'dep-1', montantCents: 250000),
      Fixtures.depense(
        id: 'dep-2',
        type: TypeDepense.repas,
        montantCents: 4500,
        travauxSupId: 'ts-fantome',
      ),
    ],
    // 2 × 8 h = 16 h sur 80 h prévues → avancement 20 % → projection.
    heures: [
      Fixtures.heures(id: 'h-1', nbPersonnes: 2),
      Fixtures.heures(id: 'h-2', nbPersonnes: 2),
    ],
    taches: [Fixtures.tache(minutesParUniteSnapshot: 30)],
    travauxSup: [
      Fixtures.travauxSup(),
      Fixtures.travauxSup(
        id: 'ts-2',
        libelle: 'Peinture plafond',
        statut: StatutTravauxSup.propose,
        prixVenduCents: 50000,
      ),
    ],
  ),
  Seuils.defaut,
);

Widget _app(ChantierKpis kpis) => ProviderScope(
  overrides: [chantierKpisProvider.overrideWith((ref, id) => AsyncData(kpis))],
  child: MaterialApp(
    theme: AppTheme.light(),
    home: ChantierDetailScreen(chantierId: kpis.chantierId),
  ),
);

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  testWidgets('affiche les KPIs, la projection et « (TS supprimé) »', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final kpis = _kpisComplets();
    await tester.pumpWidget(_app(kpis));
    await tester.pump();

    expect(find.text('Rénovation Dupont'), findsWidgets);
    expect(find.text('Prix vendu'), findsOneWidget);
    // 10 000 + TS accepté 2 000.
    expect(find.text(Money.format(1200000, mode: ModePrix.ht)), findsWidgets);
    expect(find.text('Rentabilité'), findsOneWidget);
    expect(find.text('Écart dépenses'), findsOneWidget);
    expect(find.text('Potentiel TS proposés'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Projection'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(ProjectionResult.mention), findsOneWidget);
    expect(find.text('Indicateur secondaire'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.textContaining('(TS supprimé)'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('(TS supprimé)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sans budget : « Budget non renseigné » et pas de projection', (
    tester,
  ) async {
    final kpis = ChantierKpis.compute(Fixtures.data(), Seuils.defaut);
    await tester.pumpWidget(_app(kpis));
    await tester.pump();

    expect(find.text('Budget non renseigné'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Aucune dépense'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Projection'), findsNothing);
    expect(find.text('Aucune dépense'), findsOneWidget);
    expect(find.text('Compléter (étape 3)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chantier introuvable : message et retour', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chantierKpisProvider.overrideWith(
            (ref, id) => AsyncError(
              StateError('Chantier introuvable'),
              StackTrace.empty,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ChantierDetailScreen(chantierId: 'inconnu'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Chantier introuvable'), findsOneWidget);
    expect(find.text('Retour aux chantiers'), findsOneWidget);
  });
}
