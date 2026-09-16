import 'package:flutter/material.dart';

/// État vide d'une liste ou d'un écran : icône, titre, message et action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icone,
    required this.titre,
    this.message,
    this.action,
  });

  final IconData icone;
  final String titre;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 64, color: scheme.outline),
            const SizedBox(height: 16),
            Text(
              titre,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (action != null)
              Padding(padding: const EdgeInsets.only(top: 24), child: action),
          ],
        ),
      ),
    );
  }
}
