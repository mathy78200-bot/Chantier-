/// Test de rendu de `ChantierFormScreen` en création : mode de prix
/// pré-rempli depuis les paramètres (R2), validation du nom et du prix.
library;

import 'package:chantiers/core/constants/enums.dart';
import 'package:chantiers/core/theme/app_theme.dart';
import 'package:chantiers/features/chantiers/presentation/chantier_form_screen.dart';
import 'package:chantiers/features/reglages/domain/parametres_utilisateur.dart';
import 'package:chantiers/shared/providers/data_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(ParametresUtilisateur parametres) => ProviderScope(
  overrides: [
    parametresProvider.overrideWith((ref) => Stream.value(parametres)),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: const ChantierFormScreen()),
);

void main() {
  testWidgets('mode de prix pré-rempli depuis les paramètres (TTC)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const ParametresUtilisateur(modePrixParDefaut: ModePrix.ttc)),
    );
    await tester.pump();

    expect(find.text('Nouveau chantier'), findsOneWidget);
    final segments = tester.widget<SegmentedButton<ModePrix>>(
      find.byType(SegmentedButton<ModePrix>),
    );
    expect(segments.selected, {ModePrix.ttc});
    expect(segments.onSelectionChanged, isNotNull);
    expect(find.text('€ TTC'), findsOneWidget);
  });

  testWidgets('validation : nom obligatoire et prix invalide', (tester) async {
    await tester.pumpWidget(_app(ParametresUtilisateur.defaut));
    await tester.pump();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Prix vendu initial'),
      'abc',
    );
    await tester.scrollUntilVisible(
      find.text('Enregistrer'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();

    expect(find.text('Le nom est obligatoire.'), findsOneWidget);
    expect(find.text('Montant invalide (ex. 12 500,00).'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
