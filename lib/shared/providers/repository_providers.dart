import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/bibliotheque/data/firestore_bibliotheque_repository.dart';
import '../../features/bibliotheque/domain/bibliotheque_repository.dart';
import '../../features/chantiers/data/firestore_chantier_repository.dart';
import '../../features/chantiers/domain/chantier_repository.dart';
import '../../features/depenses/data/firestore_depense_repository.dart';
import '../../features/depenses/domain/depense_repository.dart';
import '../../features/heures/data/firestore_heures_repository.dart';
import '../../features/heures/domain/heures_repository.dart';
import '../../features/justificatifs/data/firestore_justificatif_repository.dart';
import '../../features/justificatifs/data/justificatif_storage.dart';
import '../../features/justificatifs/domain/justificatif_repository.dart';
import '../../features/reglages/data/firestore_parametres_repository.dart';
import '../../features/reglages/domain/parametres_repository.dart';
import '../../features/taches/data/firestore_tache_repository.dart';
import '../../features/taches/domain/tache_repository.dart';
import '../../features/travaux_sup/data/firestore_travaux_sup_repository.dart';
import '../../features/travaux_sup/domain/travaux_sup_repository.dart';
import '../write_error_notifier.dart';
import 'firebase_providers.dart';

/// §9.2 — collecteur des erreurs d'écritures optimistes. Les repositories y
/// signalent les refus tardifs (règles Firestore) ; `AppShell` l'écoute via
/// [writeErrorsProvider].
final writeErrorNotifierProvider = Provider<WriteErrorNotifier>((ref) {
  final notifier = WriteErrorNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
});

/// Flux des écritures refusées, à consommer avec `ref.listen` dans l'UI.
final writeErrorsProvider = StreamProvider<EcritureRefuseeException>(
  (ref) => ref.watch(writeErrorNotifierProvider).erreurs,
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(firebaseAuthProvider)),
);

// Les repositories ci-dessous exigent un utilisateur connecté (`requireUid`) :
// ils sont reconstruits à chaque changement d'uid et lèvent
// `NonAuthentifieException` hors connexion. Les types exposés sont les
// interfaces du domaine, jamais les implémentations Firestore.

final chantierRepositoryProvider = Provider<ChantierRepository>(
  (ref) => FirestoreChantierRepository(
    firestore: ref.watch(firestoreProvider),
    uid: requireUid(ref),
    onWriteError: ref.watch(writeErrorNotifierProvider).signaler,
  ),
);

final depenseRepositoryProvider = Provider<DepenseRepository>(
  (ref) => FirestoreDepenseRepository(
    firestore: ref.watch(firestoreProvider),
    uid: requireUid(ref),
    onWriteError: ref.watch(writeErrorNotifierProvider).signaler,
  ),
);

final heuresRepositoryProvider = Provider<HeuresRepository>(
  (ref) => FirestoreHeuresRepository(
    firestore: ref.watch(firestoreProvider),
    uid: requireUid(ref),
    onWriteError: ref.watch(writeErrorNotifierProvider).signaler,
  ),
);

final tacheRepositoryProvider = Provider<TacheRepository>(
  (ref) => FirestoreTacheRepository(
    firestore: ref.watch(firestoreProvider),
    uid: requireUid(ref),
    onWriteError: ref.watch(writeErrorNotifierProvider).signaler,
  ),
);

final travauxSupRepositoryProvider = Provider<TravauxSupRepository>(
  (ref) => FirestoreTravauxSupRepository(
    firestore: ref.watch(firestoreProvider),
    uid: requireUid(ref),
    onWriteError: ref.watch(writeErrorNotifierProvider).signaler,
  ),
);

final justificatifRepositoryProvider = Provider<JustificatifRepository>(
  (ref) => FirestoreJustificatifRepository(
    firestore: ref.watch(firestoreProvider),
    uid: requireUid(ref),
    onWriteError: ref.watch(writeErrorNotifierProvider).signaler,
  ),
);

final justificatifStorageProvider = Provider<JustificatifStorage>(
  (ref) => JustificatifStorage(
    storage: ref.watch(firebaseStorageProvider),
    uid: requireUid(ref),
  ),
);

final bibliothequeRepositoryProvider = Provider<BibliothequeRepository>(
  (ref) => FirestoreBibliothequeRepository(
    firestore: ref.watch(firestoreProvider),
    uid: requireUid(ref),
    onWriteError: ref.watch(writeErrorNotifierProvider).signaler,
  ),
);

final parametresRepositoryProvider = Provider<ParametresRepository>(
  (ref) => FirestoreParametresRepository(
    firestore: ref.watch(firestoreProvider),
    uid: requireUid(ref),
    onWriteError: ref.watch(writeErrorNotifierProvider).signaler,
  ),
);
