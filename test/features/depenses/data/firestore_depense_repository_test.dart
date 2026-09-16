/// Tests de `FirestoreDepenseRepository` sur `fake_cloud_firestore`.
///
/// Vérifie le contrat de `FirestoreSubcollectionRepository` (R4, R6, R7,
/// §9.2, §9.11, §9.12) : chemin des documents, conversion des dates, soft
/// delete / corbeille / restauration, écriture par champs (`merge`),
/// validations avant écriture, écritures optimistes non attendues et
/// déplacement d'une dépense vers un autre chantier.
library;

import 'package:chantiers/core/constants/enums.dart';
import 'package:chantiers/core/errors/app_exception.dart';
import 'package:chantiers/features/depenses/data/firestore_depense_repository.dart';
import 'package:chantiers/features/depenses/domain/depense.dart';
import 'package:chantiers/features/justificatifs/domain/justificatif.dart';
import 'package:chantiers/shared/firestore_codec.dart';
import 'package:chantiers/shared/firestore_paths.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fixtures/fixtures.dart';

const String uid = 'user-1';
const String cid = Fixtures.chantierId;
const String cidCible = 'chantier-2';

/// Règles refusant toute écriture : simule un refus de règle Firestore
/// (§9.2) pour vérifier que l'erreur remonte à `onWriteError` sans faire
/// échouer l'appelant.
const String reglesLectureSeule = '''
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read: if true;
      allow write: if false;
    }
  }
}
''';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreDepenseRepository repo;
  late List<Object> erreurs;

  FirestoreDepenseRepository construire(FakeFirebaseFirestore fs) =>
      FirestoreDepenseRepository(
        firestore: fs,
        uid: uid,
        onWriteError: (error, _) => erreurs.add(error),
      );

  setUp(() {
    firestore = FakeFirebaseFirestore();
    erreurs = <Object>[];
    repo = construire(firestore);
  });

  /// Chemin d'une dépense (`users/{uid}/chantiers/{cid}/depenses/{id}`).
  String cheminDepense(String chantierId, String id) =>
      '${FirestorePaths.sousCollection(uid, chantierId, FirestorePaths.depenses)}/$id';

  /// Chemin d'un justificatif d'un chantier.
  String cheminJustificatif(String chantierId, String id) =>
      '${FirestorePaths.sousCollection(uid, chantierId, FirestorePaths.justificatifs)}/$id';

  Future<Map<String, dynamic>?> lireDepense(
    String chantierId,
    String id,
  ) async => (await firestore.doc(cheminDepense(chantierId, id)).get()).data();

  Future<Map<String, dynamic>?> lireJustificatif(
    String chantierId,
    String id,
  ) async =>
      (await firestore.doc(cheminJustificatif(chantierId, id)).get()).data();

  /// Laisse s'exécuter les écritures optimistes lancées en arrière-plan.
  Future<void> attendreEcritures() => pumpEventQueue();

  group('upsert', () {
    test(
      'crée le document sous users/{uid}/chantiers/{cid}/depenses/{id} '
      'avec date en Timestamp, deletedAt null explicite et horodatages',
      () async {
        final depense = Fixtures.depense(
          id: 'dep-1',
          montantCents: 12345,
          date: DateTime.utc(2026, 3, 2, 8, 30),
        );

        await repo.upsert(depense);
        await attendreEcritures();

        expect(erreurs, isEmpty);
        final snapshot = await firestore
            .doc('users/$uid/chantiers/$cid/depenses/dep-1')
            .get();
        expect(snapshot.exists, isTrue);
        final data = snapshot.data()!;

        // L'id est celui du document, pas un champ.
        expect(data.containsKey('id'), isFalse);
        expect(data['chantierId'], cid);
        expect(data['montantCents'], 12345);
        expect(data['type'], TypeDepense.materiaux.name);
        expect(data['libelle'], 'Dépense dep-1');
        expect(data['justificatifIds'], isEmpty);

        // Date métier convertie ISO 8601 → Timestamp.
        expect(data['date'], isA<Timestamp>());
        expect(
          (data['date'] as Timestamp).toDate().toUtc(),
          DateTime.utc(2026, 3, 2, 8, 30),
        );

        // Soft delete : `deletedAt` présent à null (requête `isNull: true`).
        expect(data.containsKey('deletedAt'), isTrue);
        expect(data['deletedAt'], isNull);
        expect(data['deletedReason'], isNull);

        // Horodatages posés par le serveur (résolus par le fake).
        expect(data['createdAt'], isA<Timestamp>());
        expect(data['updatedAt'], isA<Timestamp>());
      },
    );

    test(
      'la dépense relue par watchActifs est équivalente à celle écrite',
      () async {
        final depense = Fixtures.depense(
          id: 'dep-1',
          type: TypeDepense.deplacement,
          distanceKm: 42.5,
          baremeKmCentsSnapshot: 60,
          montantCents: 2550,
        );

        await repo.upsert(depense);
        await attendreEcritures();

        final actifs = await repo.watchActifs(cid).first;
        expect(actifs, hasLength(1));
        final relue = actifs.single;
        expect(relue.id, 'dep-1');
        expect(relue.chantierId, cid);
        expect(relue.date, Fixtures.jour);
        expect(relue.date.isUtc, isTrue);
        expect(relue.type, TypeDepense.deplacement);
        expect(relue.distanceKm, 42.5);
        expect(relue.baremeKmCentsSnapshot, 60);
        expect(relue.montantCents, 2550);
        expect(relue.estDeplacementAuBareme, isTrue);
        expect(relue.createdAt, isNotNull);
        expect(relue.updatedAt, isNotNull);
        expect(relue.deletedAt, isNull);
        // Hors horodatages serveur, l'entité est identique.
        expect(relue.copyWith(createdAt: null, updatedAt: null), depense);
      },
    );

    test(
      'ne touche que les champs envoyés (merge) et conserve createdAt',
      () async {
        await repo.upsert(Fixtures.depense(id: 'dep-1', montantCents: 10000));
        await attendreEcritures();

        // Champ inconnu du modèle, posé par un autre client : doit survivre.
        await firestore.doc(cheminDepense(cid, 'dep-1')).update({
          'champExterne': 'conservé',
        });
        final avant = (await lireDepense(cid, 'dep-1'))!;
        final createdAtInitial = avant['createdAt'] as Timestamp;

        // Modification à partir de l'entité relue (createdAt renseigné).
        final relue = (await repo.watchActifs(cid).first).single;
        await repo.upsert(
          relue.copyWith(montantCents: 25000, libelle: 'Carrelage'),
        );
        await attendreEcritures();

        expect(erreurs, isEmpty);
        final apres = (await lireDepense(cid, 'dep-1'))!;
        expect(apres['montantCents'], 25000);
        expect(apres['libelle'], 'Carrelage');
        expect(apres['champExterne'], 'conservé');
        expect(apres['createdAt'], createdAtInitial);
        expect(apres['updatedAt'], isA<Timestamp>());
        expect(apres['deletedAt'], isNull);
      },
    );

    test(
      'rend la main immédiatement, avant la fin de l\'écriture (R7)',
      () async {
        // Aucune attente sur l'écriture : la Future rendue est déjà complétée
        // et ne lance pas, même si l'écriture n'est pas encore visible.
        final future = repo.upsert(Fixtures.depense(id: 'dep-1'));
        expect(future, completes);
        await future;
        await attendreEcritures();
        expect(await lireDepense(cid, 'dep-1'), isNotNull);
        expect(erreurs, isEmpty);
      },
    );

    test('une écriture refusée par les règles ne fait pas échouer upsert : '
        'l\'erreur est signalée à onWriteError (§9.2)', () async {
      final fsLectureSeule = FakeFirebaseFirestore(
        securityRules: reglesLectureSeule,
      );
      final repoRefuse = construire(fsLectureSeule);

      await expectLater(
        repoRefuse.upsert(Fixtures.depense(id: 'dep-1')),
        completes,
      );
      await attendreEcritures();

      expect(erreurs, hasLength(1));
      final snapshot = await fsLectureSeule
          .doc(cheminDepense(cid, 'dep-1'))
          .get();
      expect(snapshot.exists, isFalse);
    });
  });

  group('validation (§9.2)', () {
    test(
      'ValidationException si montantCents < 0, rien n\'est écrit',
      () async {
        final depense = Fixtures.depense(id: 'dep-neg', montantCents: -1);

        expect(() => repo.upsert(depense), throwsA(isA<ValidationException>()));
        await attendreEcritures();

        expect(await lireDepense(cid, 'dep-neg'), isNull);
        expect(erreurs, isEmpty);
      },
    );

    test('ValidationException si chantierId absent (R4)', () async {
      final depense = Fixtures.depense(id: 'dep-1', chantierId: '');

      expect(() => repo.upsert(depense), throwsA(isA<ValidationException>()));
      expect(
        () => repo.upsert(Fixtures.depense(id: 'dep-1', chantierId: '   ')),
        throwsA(isA<ValidationException>()),
      );
      await attendreEcritures();
      expect(erreurs, isEmpty);
    });

    test('ValidationException si id vide', () {
      expect(
        () => repo.upsert(Fixtures.depense(id: '')),
        throwsA(isA<ValidationException>()),
      );
    });

    test('ValidationException si distance ou barème négatifs', () {
      expect(
        () => repo.upsert(
          Fixtures.depense(
            id: 'dep-km',
            type: TypeDepense.deplacement,
            distanceKm: -3,
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => repo.upsert(
          Fixtures.depense(
            id: 'dep-km',
            type: TypeDepense.deplacement,
            distanceKm: 3,
            baremeKmCentsSnapshot: -1,
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('le message de validation est en français', () {
      expect(
        () => repo.upsert(Fixtures.depense(id: 'dep-neg', montantCents: -1)),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('négatif'),
          ),
        ),
      );
    });
  });

  group('watchActifs / watchCorbeille', () {
    test('watchActifs renvoie les dépenses triées par date décroissante '
        'et exclut une dépense supprimée', () async {
      await repo.upsert(
        Fixtures.depense(id: 'dep-ancienne', date: DateTime.utc(2026, 3, 1)),
      );
      await repo.upsert(
        Fixtures.depense(id: 'dep-recente', date: DateTime.utc(2026, 3, 5)),
      );
      await repo.upsert(
        Fixtures.depense(id: 'dep-supprimee', date: DateTime.utc(2026, 3, 3)),
      );
      await attendreEcritures();
      await repo.softDelete(cid, 'dep-supprimee', reason: 'Doublon');
      await attendreEcritures();

      expect(erreurs, isEmpty);
      final actifs = await repo.watchActifs(cid).first;
      expect(actifs.map((d) => d.id), ['dep-recente', 'dep-ancienne']);
      expect(actifs.every((d) => !d.estSupprime), isTrue);
    });

    test('watchActifs ne mélange pas les chantiers (R4)', () async {
      await repo.upsert(Fixtures.depense(id: 'dep-1', chantierId: cid));
      await repo.upsert(Fixtures.depense(id: 'dep-2', chantierId: cidCible));
      await attendreEcritures();

      final actifs1 = await repo.watchActifs(cid).first;
      final actifs2 = await repo.watchActifs(cidCible).first;
      expect(actifs1.map((d) => d.id), ['dep-1']);
      expect(actifs2.map((d) => d.id), ['dep-2']);
    });

    test('softDelete pose deletedAt / deletedReason et watchCorbeille '
        'renvoie la dépense', () async {
      await repo.upsert(Fixtures.depense(id: 'dep-1'));
      await attendreEcritures();

      await repo.softDelete(cid, 'dep-1', reason: 'Erreur de saisie');
      await attendreEcritures();

      expect(erreurs, isEmpty);
      final data = (await lireDepense(cid, 'dep-1'))!;
      expect(data['deletedAt'], isA<Timestamp>());
      expect(data['deletedReason'], 'Erreur de saisie');
      // Le document n'est jamais supprimé physiquement (R6).
      expect(data['montantCents'], 10000);

      final corbeille = await repo.watchCorbeille(cid).first;
      expect(corbeille, hasLength(1));
      expect(corbeille.single.id, 'dep-1');
      expect(corbeille.single.estSupprime, isTrue);
      expect(corbeille.single.deletedReason, 'Erreur de saisie');

      expect(await repo.watchActifs(cid).first, isEmpty);
    });

    test('watchCorbeille exclut les dépenses actives', () async {
      await repo.upsert(Fixtures.depense(id: 'dep-active'));
      await repo.upsert(Fixtures.depense(id: 'dep-supprimee'));
      await attendreEcritures();
      await repo.softDelete(cid, 'dep-supprimee');
      await attendreEcritures();

      final corbeille = await repo.watchCorbeille(cid).first;
      expect(corbeille.map((d) => d.id), ['dep-supprimee']);
      expect(corbeille.single.deletedReason, isNull);
    });

    test('restore remet la dépense dans watchActifs avec deletedAt null '
        'explicite', () async {
      await repo.upsert(Fixtures.depense(id: 'dep-1'));
      await attendreEcritures();
      await repo.softDelete(cid, 'dep-1', reason: 'Test');
      await attendreEcritures();
      expect(await repo.watchActifs(cid).first, isEmpty);

      await repo.restore(cid, 'dep-1');
      await attendreEcritures();

      expect(erreurs, isEmpty);
      final data = (await lireDepense(cid, 'dep-1'))!;
      expect(data.containsKey('deletedAt'), isTrue);
      expect(data['deletedAt'], isNull);
      expect(data['deletedReason'], isNull);

      final actifs = await repo.watchActifs(cid).first;
      expect(actifs.map((d) => d.id), ['dep-1']);
      expect(actifs.single.estSupprime, isFalse);
      expect(await repo.watchCorbeille(cid).first, isEmpty);
    });

    test('le flux watchActifs se met à jour après un softDelete', () async {
      await repo.upsert(Fixtures.depense(id: 'dep-1'));
      await attendreEcritures();

      final emissions = <List<String>>[];
      final abonnement = repo
          .watchActifs(cid)
          .listen((liste) => emissions.add(liste.map((d) => d.id).toList()));
      await attendreEcritures();

      await repo.softDelete(cid, 'dep-1');
      await attendreEcritures();
      await abonnement.cancel();

      expect(emissions.first, ['dep-1']);
      expect(emissions.last, isEmpty);
    });

    test('softDelete d\'un document inexistant signale l\'erreur à '
        'onWriteError sans lancer', () async {
      await expectLater(repo.softDelete(cid, 'inconnu'), completes);
      await attendreEcritures();

      expect(erreurs, hasLength(1));
      expect(
        erreurs.single,
        isA<FirebaseException>().having((e) => e.code, 'code', 'not-found'),
      );
    });
  });

  group('deplacerVers (§9.11)', () {
    const storagePathOrigine =
        'users/$uid/chantiers/$cid/justificatifs/j-1.jpg';

    Future<Depense> preparerDepenseAvecJustificatif({
      List<String> justificatifIds = const ['j-1'],
    }) async {
      final depense =
          Fixtures.depense(
            id: 'dep-1',
            montantCents: 4200,
            date: DateTime.utc(2026, 3, 4),
          ).copyWith(
            libelle: 'Facture carrelage',
            fournisseur: 'Point P',
            justificatifIds: justificatifIds,
          );
      await repo.upsert(depense);

      const justificatif = Justificatif(
        id: 'j-1',
        chantierId: cid,
        depenseId: 'dep-1',
        storagePath: storagePathOrigine,
        uploadStatus: UploadStatus.uploaded,
        sizeBytes: 2048,
      );
      await firestore
          .doc(cheminJustificatif(cid, 'j-1'))
          .set(FirestoreCodec.toDoc(justificatif.toJson()));
      await attendreEcritures();
      expect(erreurs, isEmpty);
      return depense;
    }

    test('copie la dépense sous le chantier cible avec un nouvel id, '
        'supprime (soft) l\'originale et copie le justificatif avec '
        'depenseId réassigné', () async {
      final depense = await preparerDepenseAvecJustificatif();

      await expectLater(repo.deplacerVers(depense, cidCible), completes);
      await attendreEcritures();
      expect(erreurs, isEmpty);

      // Nouvelle dépense sous le chantier cible, nouvel id.
      final actifsCible = await repo.watchActifs(cidCible).first;
      expect(actifsCible, hasLength(1));
      final copie = actifsCible.single;
      expect(copie.id, isNot('dep-1'));
      expect(copie.id, isNotEmpty);
      expect(copie.chantierId, cidCible);
      expect(copie.montantCents, 4200);
      expect(copie.libelle, 'Facture carrelage');
      expect(copie.fournisseur, 'Point P');
      expect(copie.date, DateTime.utc(2026, 3, 4));
      expect(copie.justificatifIds, ['j-1']);
      expect(copie.estSupprime, isFalse);
      expect(copie.createdAt, isNotNull);

      final docCopie = (await lireDepense(cidCible, copie.id))!;
      expect(docCopie['chantierId'], cidCible);
      expect(docCopie['deletedAt'], isNull);

      // Originale soft-deleted, jamais supprimée physiquement (R6).
      expect(await repo.watchActifs(cid).first, isEmpty);
      final corbeille = await repo.watchCorbeille(cid).first;
      expect(corbeille.map((d) => d.id), ['dep-1']);
      expect(corbeille.single.deletedReason, 'Déplacée vers $cidCible');
      final docOrigine = (await lireDepense(cid, 'dep-1'))!;
      expect(docOrigine['deletedAt'], isA<Timestamp>());
      expect(docOrigine['montantCents'], 4200);

      // Justificatif copié sous le chantier cible : même id, depenseId mis à
      // jour, storagePath inchangé (le fichier reste sous le chantier
      // d'origine).
      final justifCible = (await lireJustificatif(cidCible, 'j-1'))!;
      expect(justifCible['chantierId'], cidCible);
      expect(justifCible['depenseId'], copie.id);
      expect(justifCible['storagePath'], storagePathOrigine);
      expect(justifCible['uploadStatus'], UploadStatus.uploaded.name);
      expect(justifCible['sizeBytes'], 2048);
      expect(justifCible['deletedAt'], isNull);
      expect(justifCible['createdAt'], isA<Timestamp>());

      // Justificatif d'origine soft-deleted.
      final justifOrigine = (await lireJustificatif(cid, 'j-1'))!;
      expect(justifOrigine['deletedAt'], isA<Timestamp>());
      expect(justifOrigine['deletedReason'], 'Déplacée vers $cidCible');
      expect(justifOrigine['depenseId'], 'dep-1');
    });

    test('ignore un id de justificatif sans document', () async {
      final depense = await preparerDepenseAvecJustificatif(
        justificatifIds: const ['j-1', 'j-inconnu'],
      );

      await repo.deplacerVers(depense, cidCible);
      await attendreEcritures();

      expect(erreurs, isEmpty);
      final copie = (await repo.watchActifs(cidCible).first).single;
      expect(copie.justificatifIds, ['j-1', 'j-inconnu']);
      expect(await lireJustificatif(cidCible, 'j-1'), isNotNull);
      expect(await lireJustificatif(cidCible, 'j-inconnu'), isNull);
      expect(await repo.watchActifs(cid).first, isEmpty);
    });

    test('fonctionne sans justificatif', () async {
      final depense = Fixtures.depense(id: 'dep-1');
      await repo.upsert(depense);
      await attendreEcritures();

      await repo.deplacerVers(depense, cidCible);
      await attendreEcritures();

      expect(erreurs, isEmpty);
      expect(await repo.watchActifs(cidCible).first, hasLength(1));
      expect(await repo.watchCorbeille(cid).first, hasLength(1));
    });

    test(
      'rend la main immédiatement (R7) : la Future est déjà complétée',
      () async {
        final depense = await preparerDepenseAvecJustificatif();

        final future = repo.deplacerVers(depense, cidCible);
        expect(future, completes);
        await future;
        await attendreEcritures();
        expect(erreurs, isEmpty);
      },
    );

    test(
      'ValidationException si le chantier cible est vide ou identique',
      () async {
        final depense = Fixtures.depense(id: 'dep-1');
        await repo.upsert(depense);
        await attendreEcritures();

        expect(
          () => repo.deplacerVers(depense, ''),
          throwsA(isA<ValidationException>()),
        );
        expect(
          () => repo.deplacerVers(depense, cid),
          throwsA(isA<ValidationException>()),
        );
        await attendreEcritures();

        // Rien n'a bougé.
        expect(erreurs, isEmpty);
        expect(await repo.watchActifs(cid).first, hasLength(1));
        expect(await repo.watchCorbeille(cid).first, isEmpty);
      },
    );

    test('n\'écrit rien si la copie est invalide', () async {
      final depense = Fixtures.depense(id: 'dep-1', montantCents: -5);

      expect(
        () => repo.deplacerVers(depense, cidCible),
        throwsA(isA<ValidationException>()),
      );
      await attendreEcritures();

      expect(erreurs, isEmpty);
      expect(await repo.watchActifs(cidCible).first, isEmpty);
    });
  });
}
