/// Test de rendu de `ChantiersListScreen` : état vide, lignes avec statut et
/// prix vendu initial suivi du mode, pastille de couleur depuis les KPIs
/// (gris tant qu'ils ne sont pas chargés) et filtre par statut.
library;

import 'package:chantiers/core/constants/enums.dart';
import 'package:chantiers/core/theme/app_theme.dart';
import 'package:chantiers/core/utils/money.dart';
import 'package:chantiers/core/widgets/status_chip.dart';
import 'package:chantiers/features/chantiers/domain/chantier.dart';
import 'package:chantiers/features/chantiers/presentation/chantiers_list_screen.dart';
import 'package:chantiers/features/rentabilite/domain/chantier_kpis.dart';
import 'package:chantiers/features/rentabilite/domain/seuils.dart';
import 'package:chantiers/features/rentabilite/presentation/kpis_providers.dart';
import 'package:chantiers/shared/providers/data_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fixtures/fixtures.dart';

Widget _app(List<Chantier> chantiers, {ChantierKpis? kpis}) => ProviderScope(
  overrides: [
    chantiersActifsProvider.overrideWith((ref) => Stream.value(chantiers)),
    chantierKpisProvider.overrideWith(
      (ref, id) => kpis == null || kpis.chantierId != id
          ? const AsyncLoading()
          : AsyncData(kpis),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    home: const ChantiersListScreen(),
  ),
);

void main() {
  testWidgets('état vide', (tester) async {
    await tester.pumpWidget(_app(const []));
    await tester.pump();

    expect(find.text('Aucun chantier'), findsOneWidget);
    expect(find.text('Nouveau chantier'), findsOneWidget);
  });

  testWidgets('lignes, pastille et filtre par statut', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final enCours = Fixtures.chantier();
    final aVenir = Fixtures.chantier(
      id: 'chantier-2',
      nom: 'Extension Martin',
      modePrix: ModePrix.ttc,
      statut: StatutChantier.aVenir,
      prixVenduInitialCents: 500000,
    );
    // Prévisionnel complet, sans dépense → vert.
    final kpis = ChantierKpis.compute(
      Fixtures.data(
        chantier: enCours,
        previsionnel: Fixtures.previsionnelComplet(),
      ),
      Seuils.defaut,
    );

    await tester.pumpWidget(_app([enCours, aVenir], kpis: kpis));
    await tester.pump();

    expect(find.text('Rénovation Dupont'), findsOneWidget);
    expect(find.text(Money.format(1000000, mode: ModePrix.ht)), findsOneWidget);
    expect(find.text('Extension Martin'), findsOneWidget);
    expect(find.text(Money.format(500000, mode: ModePrix.ttc)), findsOneWidget);

    final pastilles = tester
        .widgetList<CouleurEtatDot>(find.byType(CouleurEtatDot))
        .map((d) => d.couleur)
        .toList();
    expect(pastilles, [CouleurEtat.vert, CouleurEtat.gris]);

    final puceAVenir = find.widgetWithText(
      FilterChip,
      StatutChantier.aVenir.libelle,
    );
    await tester.ensureVisible(puceAVenir);
    await tester.tap(puceAVenir);
    await tester.pumpAndSettle();
    expect(find.text('Rénovation Dupont'), findsNothing);
    expect(find.text('Extension Martin'), findsOneWidget);

    final puceTermine = find.widgetWithText(
      FilterChip,
      StatutChantier.termine.libelle,
    );
    await tester.ensureVisible(puceTermine);
    await tester.tap(puceTermine);
    await tester.pumpAndSettle();
    expect(find.text('Aucun chantier « Terminé »'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
