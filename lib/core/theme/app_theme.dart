import 'package:flutter/material.dart';

import '../constants/enums.dart';

/// Thème Material 3 de l'application : orange chantier sobre, cartes, gros
/// boutons et cibles tactiles larges (usage terrain, souvent avec des gants).
abstract final class AppTheme {
  /// Couleur de base : orange chantier désaturé.
  static const Color seed = Color(0xFFD9642B);

  static ThemeData light() => _theme(Brightness.light);

  static ThemeData dark() => _theme(Brightness.dark);

  /// Couleur d'état d'un chantier (gris / vert / orange / rouge), lisible sur
  /// fond clair comme sombre. Le texte posé dessus utilise [surCouleur].
  static Color couleur(CouleurEtat etat) => switch (etat) {
    CouleurEtat.gris => const Color(0xFF6F6F6F),
    CouleurEtat.vert => const Color(0xFF2E7D32),
    CouleurEtat.orange => const Color(0xFFE65100),
    CouleurEtat.rouge => const Color(0xFFC62828),
  };

  /// Couleur du texte posé sur [couleur] (toutes assez sombres pour du blanc).
  static Color surCouleur(CouleurEtat etat) => Colors.white;

  static ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    const grandBouton = Size.fromHeight(52);
    const texteBouton = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
    final forme = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    return ThemeData(
      colorScheme: scheme,
      appBarTheme: AppBarThemeData(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: forme,
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: grandBouton,
          textStyle: texteBouton,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: grandBouton,
          textStyle: texteBouton,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: grandBouton,
          textStyle: texteBouton,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      inputDecorationTheme: const InputDecorationThemeData(
        border: OutlineInputBorder(),
        filled: true,
      ),
      listTileTheme: const ListTileThemeData(minVerticalPadding: 12),
      navigationBarTheme: const NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: const BottomSheetThemeData(showDragHandle: true),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    );
  }
}
