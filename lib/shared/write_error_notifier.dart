import 'dart:async';

import '../core/errors/app_exception.dart';

/// Signature du rapporteur d'erreur d'écriture injecté dans les repositories.
typedef WriteErrorHandler = void Function(Object error, StackTrace stackTrace);

/// §9.2 — les écritures optimistes (`unawaited`) ne remontent pas leurs
/// erreurs : les repositories les signalent ici, l'UI écoute [erreurs] et
/// affiche « une modification n'a pas pu être enregistrée ».
class WriteErrorNotifier {
  final StreamController<EcritureRefuseeException> _controller =
      StreamController<EcritureRefuseeException>.broadcast();

  Stream<EcritureRefuseeException> get erreurs => _controller.stream;

  void signaler(Object error, StackTrace stackTrace) {
    if (_controller.isClosed) return;
    _controller.add(EcritureRefuseeException(error));
  }

  void dispose() => _controller.close();
}
