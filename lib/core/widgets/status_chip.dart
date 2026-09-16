import 'package:flutter/material.dart';

import '../constants/enums.dart';
import '../theme/app_theme.dart';

/// Pastille du statut d'un chantier (R11 : quatre statuts).
class StatusChip extends StatelessWidget {
  const StatusChip(this.statut, {super.key});

  final StatutChantier statut;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color fond, Color texte, IconData icone) = switch (statut) {
      StatutChantier.aFaireSigner => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        Icons.edit_note,
      ),
      StatutChantier.aVenir => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
        Icons.event,
      ),
      StatutChantier.enCours => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        Icons.construction,
      ),
      StatutChantier.termine => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
        Icons.check_circle_outline,
      ),
    };
    return Chip(
      avatar: Icon(icone, size: 18, color: texte),
      label: Text(statut.libelle),
      labelStyle: TextStyle(color: texte, fontWeight: FontWeight.w600),
      backgroundColor: fond,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// Point coloré de l'état d'un chantier (couleur PRINCIPALE, R8).
class CouleurEtatDot extends StatelessWidget {
  const CouleurEtatDot(this.couleur, {super.key, this.taille = 12});

  final CouleurEtat couleur;
  final double taille;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: couleur.libelle,
      child: Container(
        width: taille,
        height: taille,
        decoration: BoxDecoration(
          color: AppTheme.couleur(couleur),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Pastille du statut d'un travaux sup (R3 : proposé / accepté / refusé).
class TravauxSupChip extends StatelessWidget {
  const TravauxSupChip(this.statut, {super.key});

  final StatutTravauxSup statut;

  @override
  Widget build(BuildContext context) {
    final (Color couleur, IconData icone) = switch (statut) {
      StatutTravauxSup.propose => (
        AppTheme.couleur(CouleurEtat.orange),
        Icons.hourglass_empty,
      ),
      StatutTravauxSup.accepte => (
        AppTheme.couleur(CouleurEtat.vert),
        Icons.check,
      ),
      StatutTravauxSup.refuse => (
        AppTheme.couleur(CouleurEtat.gris),
        Icons.close,
      ),
    };
    return Chip(
      avatar: Icon(icone, size: 18, color: couleur),
      label: Text(statut.libelle),
      labelStyle: TextStyle(color: couleur, fontWeight: FontWeight.w600),
      backgroundColor: couleur.withValues(alpha: 0.12),
      side: BorderSide(color: couleur),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
