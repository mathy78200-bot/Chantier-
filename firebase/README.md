# Firebase — règles et index

- Déployer : `firebase deploy --only firestore:rules,firestore:indexes,storage` (config dans `firebase.json` à la racine).
- Émulateurs : `firebase emulators:start` (auth 9099, firestore 8080, storage 9199, UI activée, `singleProjectMode`).
- Invariants garantis : isolation par `uid`, `modePrix` figé (R2), `chantierId == cid` (R4), aucun `delete` physique (R6), quatre statuts (R11) ; les transitions de statut ne sont pas contraintes (§9.10).
- Aucun test de règles n'existe encore (§9.2) : à écrire avec `@firebase/rules-unit-testing` sur l'émulateur avant mise en production, avec App Check (§9.14).
