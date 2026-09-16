/// Tests de `FirestoreCodec` : JSON d'entité (dates ISO 8601) ↔ document
/// Firestore (`Timestamp`, `serverTimestamp`).
library;

import 'package:chantiers/features/depenses/domain/depense.dart';
import 'package:chantiers/shared/firestore_codec.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/fixtures.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    // Installe la fabrique de `FieldValue` du fake (nécessaire pour
    // `FieldValue.serverTimestamp()` hors plateforme).
    firestore = FakeFirebaseFirestore();
  });

  final jour = DateTime.utc(2026, 3, 2, 8, 30);
  final iso = jour.toIso8601String();
  final ts = Timestamp.fromDate(jour);

  group('toDoc', () {
    test('convertit les champs date ISO 8601 en Timestamp', () {
      final doc = FirestoreCodec.toDoc({
        'id': 'dep-1',
        'date': iso,
        'dateProposition': iso,
        'takenAt': iso,
        'montantCents': 100,
      });

      expect(doc['date'], ts);
      expect(doc['dateProposition'], ts);
      expect(doc['takenAt'], ts);
      expect(doc['montantCents'], 100);
    });

    test('retire id', () {
      final doc = FirestoreCodec.toDoc({'id': 'dep-1', 'libelle': 'x'});

      expect(doc.containsKey('id'), isFalse);
      expect(doc['libelle'], 'x');
    });

    test(
      'pose serverTimestamp sur updatedAt, même si une valeur est fournie',
      () {
        final sans = FirestoreCodec.toDoc({'id': 'a'});
        final avec = FirestoreCodec.toDoc({'id': 'a', 'updatedAt': iso});

        expect(sans['updatedAt'], FieldValue.serverTimestamp());
        expect(avec['updatedAt'], FieldValue.serverTimestamp());
      },
    );

    test('pose serverTimestamp sur createdAt s\'il est absent ou null', () {
      final absent = FirestoreCodec.toDoc({'id': 'a'});
      final nul = FirestoreCodec.toDoc({'id': 'a', 'createdAt': null});

      expect(absent['createdAt'], FieldValue.serverTimestamp());
      expect(nul['createdAt'], FieldValue.serverTimestamp());
    });

    test('laisse createdAt existant (converti en Timestamp)', () {
      final doc = FirestoreCodec.toDoc({'id': 'a', 'createdAt': iso});

      expect(doc['createdAt'], ts);
      expect(doc['createdAt'], isNot(isA<FieldValue>()));
    });

    test('conserve les dates null explicites (deletedAt, dateDecision)', () {
      final doc = FirestoreCodec.toDoc({
        'id': 'a',
        'deletedAt': null,
        'dateDecision': null,
      });

      expect(doc.containsKey('deletedAt'), isTrue);
      expect(doc['deletedAt'], isNull);
      expect(doc.containsKey('dateDecision'), isTrue);
      expect(doc['dateDecision'], isNull);
    });

    test('accepte un DateTime ou un Timestamp déjà converti', () {
      final doc = FirestoreCodec.toDoc({'date': jour, 'takenAt': ts});

      expect(doc['date'], ts);
      expect(doc['takenAt'], ts);
    });

    test('laisse intacts les champs non date (listes, maps, nombres)', () {
      final doc = FirestoreCodec.toDoc({
        'justificatifIds': ['j-1', 'j-2'],
        'budgetParTypeCents': {'materiaux': 100, 'repas': 20},
        'distanceKm': 12.5,
        'actif': true,
        'libelle': '2026-03-02T08:30:00.000Z',
      });

      expect(doc['justificatifIds'], ['j-1', 'j-2']);
      expect(doc['budgetParTypeCents'], {'materiaux': 100, 'repas': 20});
      expect(doc['distanceKm'], 12.5);
      expect(doc['actif'], isTrue);
      // Une chaîne ressemblant à une date hors de dateFields n'est pas
      // convertie.
      expect(doc['libelle'], '2026-03-02T08:30:00.000Z');
    });

    test('respecte une liste de champs date personnalisée', () {
      final doc = FirestoreCodec.toDoc(
        {'date': iso, 'autreDate': iso},
        dateFields: const {'autreDate'},
      );

      expect(doc['date'], iso);
      expect(doc['autreDate'], ts);
    });

    test('ne modifie pas le JSON d\'origine', () {
      final json = <String, dynamic>{'id': 'a', 'date': iso};
      FirestoreCodec.toDoc(json);

      expect(json, {'id': 'a', 'date': iso});
    });

    test('dateFields contient tous les champs date des entités', () {
      expect(
        FirestoreCodec.dateFields,
        containsAll(const [
          'createdAt',
          'updatedAt',
          'deletedAt',
          'dateDevis',
          'dateSignature',
          'dateDebutPrevue',
          'dateFinPrevue',
          'dateDebutReelle',
          'dateFinReelle',
          'date',
          'dateProposition',
          'dateDecision',
          'takenAt',
        ]),
      );
    });
  });

  group('fromData', () {
    test('convertit Timestamp en ISO 8601 UTC', () {
      final json = FirestoreCodec.fromData({'date': ts, 'montantCents': 5});

      expect(json['date'], '2026-03-02T08:30:00.000Z');
      expect(json['montantCents'], 5);
    });

    test('convertit une date locale en ISO UTC (suffixe Z)', () {
      final locale = DateTime(2026, 7, 14, 15, 45);
      final json = FirestoreCodec.fromData({
        'date': Timestamp.fromDate(locale),
      });

      final valeur = json['date'] as String;
      expect(valeur, endsWith('Z'));
      expect(valeur, locale.toUtc().toIso8601String());
      expect(DateTime.parse(valeur), locale.toUtc());
    });

    test('convertit les Timestamp dans les maps et listes imbriquées', () {
      final json = FirestoreCodec.fromData({
        'imbrique': {
          'quand': ts,
          'profond': {'encore': ts, 'nombre': 1},
        },
        'liste': [ts, 'texte', 2, null],
        'listeDeMaps': [
          {'quand': ts},
          {'quand': null},
        ],
      });

      expect(json['imbrique'], {
        'quand': iso,
        'profond': {'encore': iso, 'nombre': 1},
      });
      expect(json['liste'], [iso, 'texte', 2, null]);
      expect(json['listeDeMaps'], [
        {'quand': iso},
        {'quand': null},
      ]);
    });

    test('ajoute id quand il est fourni, pas sinon', () {
      expect(FirestoreCodec.fromData({'a': 1}, id: 'x'), {'a': 1, 'id': 'x'});
      expect(FirestoreCodec.fromData({'a': 1}), {'a': 1});
    });

    test('laisse intacts les autres types et les null', () {
      final json = FirestoreCodec.fromData({
        'entier': 3,
        'reel': 1.5,
        'bool': false,
        'texte': 'abc',
        'nul': null,
        'liste': ['a', 'b'],
      });

      expect(json, {
        'entier': 3,
        'reel': 1.5,
        'bool': false,
        'texte': 'abc',
        'nul': null,
        'liste': ['a', 'b'],
      });
    });

    test('produit une map à clés String pour json_serializable', () {
      final json = FirestoreCodec.fromData({
        'map': <Object, Object?>{'k': 1},
      });

      expect(json['map'], isA<Map<String, dynamic>>());
    });
  });

  group('fromDoc / aller-retour Firestore', () {
    test(
      'fromDoc ajoute l\'id du document et convertit les Timestamp',
      () async {
        final ref = firestore.doc('users/u/chantiers/c/depenses/dep-1');
        await ref.set({'date': ts, 'montantCents': 7});

        final json = FirestoreCodec.fromDoc(await ref.get());

        expect(json['id'], 'dep-1');
        expect(json['date'], iso);
        expect(json['montantCents'], 7);
      },
    );

    test('fromDoc d\'un document absent ne contient que l\'id', () async {
      final ref = firestore.doc('users/u/chantiers/c/depenses/absent');

      expect(FirestoreCodec.fromDoc(await ref.get()), {'id': 'absent'});
    });

    test('les serverTimestamp deviennent des Timestamp à l\'écriture, '
        'et une entité fait l\'aller-retour', () async {
      final depense = Fixtures.depense(id: 'dep-1', date: jour);
      final ref = firestore.doc('users/u/chantiers/c/depenses/dep-1');
      final avant = DateTime.now();

      await ref.set(FirestoreCodec.toDoc(depense.toJson()));

      final data = (await ref.get()).data()!;
      expect(data['createdAt'], isA<Timestamp>());
      expect(data['updatedAt'], isA<Timestamp>());
      final createdAt = (data['createdAt'] as Timestamp).toDate();
      expect(
        createdAt.isAfter(avant.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(data['date'], ts);
      expect(data.containsKey('id'), isFalse);

      final relue = Depense.fromJson(FirestoreCodec.fromDoc(await ref.get()));
      expect(relue.createdAt, isNotNull);
      expect(relue.updatedAt, isNotNull);
      expect(relue.date, jour);
      expect(relue.copyWith(createdAt: null, updatedAt: null), depense);
    });

    test('une deuxième écriture conserve createdAt relu', () async {
      final ref = firestore.doc('users/u/chantiers/c/depenses/dep-1');
      await ref.set(FirestoreCodec.toDoc(Fixtures.depense().toJson()));
      final createdAt = (await ref.get()).data()!['createdAt'];

      final relue = Depense.fromJson(FirestoreCodec.fromDoc(await ref.get()));
      await ref.set(
        FirestoreCodec.toDoc(relue.copyWith(montantCents: 1).toJson()),
        SetOptions(merge: true),
      );

      final data = (await ref.get()).data()!;
      expect(data['createdAt'], createdAt);
      expect(data['montantCents'], 1);
    });
  });
}
