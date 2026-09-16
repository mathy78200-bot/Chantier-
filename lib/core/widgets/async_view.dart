import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_exception.dart';

/// Affiche une [AsyncValue] : chargement centré, erreur en français, ou
/// [builder] avec la donnée.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.builder,
    this.loading,
    this.error,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;

  /// Remplace l'indicateur de chargement par défaut.
  final Widget? loading;

  /// Remplace l'affichage d'erreur par défaut.
  final Widget Function(Object error, StackTrace stack)? error;

  /// Message affichable : celui de l'[AppException], sinon un texte générique.
  static String messageErreur(Object erreur) =>
      erreur is AppException ? erreur.message : 'Une erreur est survenue.';

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () =>
          loading ?? const Center(child: CircularProgressIndicator()),
      error: (erreur, stack) =>
          error?.call(erreur, stack) ?? _ErreurView(messageErreur(erreur)),
    );
  }
}

class _ErreurView extends StatelessWidget {
  const _ErreurView(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
