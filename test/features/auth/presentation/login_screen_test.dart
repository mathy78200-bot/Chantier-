/// Test de rendu de `LoginScreen` : titre, validation des champs avant tout
/// appel d'authentification, boutons « Se connecter » / « Créer un compte ».
library;

import 'package:chantiers/core/theme/app_theme.dart';
import 'package:chantiers/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('validation locale des champs', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light(), home: const LoginScreen()),
      ),
    );

    expect(find.text('Chantiers'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Créer un compte'), findsOneWidget);

    await tester.tap(find.text('Se connecter'));
    await tester.pump();
    expect(find.text('Saisissez votre adresse e-mail.'), findsOneWidget);
    expect(find.text('Saisissez votre mot de passe.'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Adresse e-mail'),
      'patron',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mot de passe'),
      '123',
    );
    await tester.tap(find.text('Créer un compte'));
    await tester.pump();
    expect(find.text('Adresse e-mail invalide.'), findsOneWidget);
    expect(find.text('6 caractères minimum.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
