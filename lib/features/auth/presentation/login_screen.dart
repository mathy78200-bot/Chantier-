import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/async_view.dart';
import 'auth_controller.dart';

/// Connexion ou création de compte par e-mail et mot de passe.
///
/// La navigation n'est pas pilotée ici : le routeur redirige vers l'accueil
/// dès que `authStateChanges` émet un utilisateur connecté.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _motDePasse = TextEditingController();
  bool _motDePasseVisible = false;

  @override
  void dispose() {
    _email.dispose();
    _motDePasse.dispose();
    super.dispose();
  }

  String? _validerEmail(String? valeur) {
    final email = valeur?.trim() ?? '';
    if (email.isEmpty) return 'Saisissez votre adresse e-mail.';
    if (!email.contains('@') || !email.contains('.')) {
      return 'Adresse e-mail invalide.';
    }
    return null;
  }

  String? _validerMotDePasse(String? valeur) {
    if (valeur == null || valeur.isEmpty) {
      return 'Saisissez votre mot de passe.';
    }
    if (valeur.length < 6) return '6 caractères minimum.';
    return null;
  }

  void _seConnecter() {
    if (!_formKey.currentState!.validate()) return;
    unawaited(
      ref
          .read(authControllerProvider.notifier)
          .signIn(email: _email.text, password: _motDePasse.text),
    );
  }

  void _creerCompte() {
    if (!_formKey.currentState!.validate()) return;
    unawaited(
      ref
          .read(authControllerProvider.notifier)
          .signUp(email: _email.text, password: _motDePasse.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final etat = ref.watch(authControllerProvider);
    final enCours = etat.isLoading;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.construction, size: 64, color: scheme.primary),
                      const SizedBox(height: 12),
                      Text(
                        'Chantiers',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Suivi de rentabilité des chantiers',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _email,
                        enabled: !enCours,
                        decoration: const InputDecoration(
                          labelText: 'Adresse e-mail',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        validator: _validerEmail,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _motDePasse,
                        enabled: !enCours,
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _motDePasseVisible
                                ? 'Masquer le mot de passe'
                                : 'Afficher le mot de passe',
                            icon: Icon(
                              _motDePasseVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () => setState(
                              () => _motDePasseVisible = !_motDePasseVisible,
                            ),
                          ),
                        ),
                        obscureText: !_motDePasseVisible,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _seConnecter(),
                        validator: _validerMotDePasse,
                      ),
                      if (etat.hasError) ...[
                        const SizedBox(height: 16),
                        _MessageErreur(AsyncView.messageErreur(etat.error!)),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: enCours ? null : _seConnecter,
                        child: enCours
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text('Se connecter'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: enCours ? null : _creerCompte,
                        child: const Text('Créer un compte'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bandeau d'erreur d'authentification (message déjà en français).
class _MessageErreur extends StatelessWidget {
  const _MessageErreur(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
