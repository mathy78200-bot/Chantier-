import 'package:flutter/material.dart';

import '../constants/enums.dart';
import '../theme/app_theme.dart';
import 'status_chip.dart';

/// Carte d'indicateur : un titre, une grande valeur, un sous-titre optionnel.
///
/// La valeur est reçue déjà formatée (`Money`, `DurationFmt`, …) : le widget
/// ne calcule rien.
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.titre,
    required this.valeur,
    this.sousTitre,
    this.couleur,
    this.icone,
    this.onTap,
  });

  final String titre;
  final String valeur;
  final String? sousTitre;

  /// Couleur d'état (point + valeur) ; neutre si `null`.
  final CouleurEtat? couleur;
  final IconData? icone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final couleur = this.couleur;
    final accent = couleur == null ? null : AppTheme.couleur(couleur);

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (icone != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(icone, size: 28, color: accent ?? scheme.primary),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (couleur != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: CouleurEtatDot(couleur, taille: 10),
                          ),
                        Expanded(
                          child: Text(
                            titre,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      valeur,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: accent ?? scheme.onSurface,
                      ),
                    ),
                    if (sousTitre != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          sousTitre!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
