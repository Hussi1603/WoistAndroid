import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../format.dart';
import '../models/person.dart';

/// Datenmodell in Firestore:
///
///  users/{uid}      – privates Profil: name, code, sharing, sharingWith{uid: name}
///  codes/{code}     – Einladungs-Code -> {uid, name} (nur einzeln abrufbar)
///  locations/{uid}  – Standort: name, lat, lng, accuracy, battery, charging,
///                     updatedAt, sharing, viewers[uid...]
///
/// Wie bei "Wo ist?" von Apple teilt jede Person ihren Standort aktiv mit
/// anderen. Wer den Code der Partnerin eingibt, teilt den EIGENEN Standort
/// mit ihr. Sie macht dasselbe mit deinem Code – dann seht ihr euch gegenseitig.
class Backend {
  Backend._();
  static final instance = Backend._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  static const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String get uid => _auth.currentUser!.uid;

  DocumentReference<Map<String, dynamic>> get _me => _db.doc('users/$uid');
  DocumentReference<Map<String, dynamic>> get _myLocation =>
      _db.doc('locations/$uid');

  Future<User> ensureSignedIn() async {
    final current = _auth.currentUser;
    if (current != null) return current;
    final cred = await _auth.signInAnonymously();
    return cred.user!;
  }

  Stream<Profile?> profileStream() => _me
      .snapshots()
      .map((s) => s.exists ? Profile.fromDoc(s) : null);

  /// Alle Personen, die ihren Standort mit mir teilen.
  Stream<List<Person>> friendsStream() => _db
      .collection('locations')
      .where('viewers', arrayContains: uid)
      .snapshots()
      .map((q) => q.docs.map(Person.fromDoc).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())));

  Future<void> createProfile(String name) async {
    final rnd = Random.secure();
    for (var attempt = 0; attempt < 10; attempt++) {
      final code = List.generate(
          6, (_) => _codeAlphabet[rnd.nextInt(_codeAlphabet.length)]).join();
      final codeRef = _db.doc('codes/$code');
      final ok = await _db.runTransaction<bool>((tx) async {
        final existing = await tx.get(codeRef);
        if (existing.exists) return false;
        tx.set(codeRef, {'uid': uid, 'name': name});
        tx.set(_me, {
          'name': name,
          'code': code,
          'sharing': true,
          'sharingWith': <String, String>{},
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.set(
          _myLocation,
          {'name': name, 'sharing': true, 'viewers': <String>[]},
          SetOptions(merge: true),
        );
        return true;
      });
      if (ok) return;
    }
    throw Exception('Konnte keinen freien Code erzeugen. Bitte erneut versuchen.');
  }

  /// Teilt meinen Standort mit der Person, der [rawCode] gehört.
  /// Gibt den Namen der Person zurück.
  Future<String> shareWithCode(String rawCode) async {
    final code = normalizeCode(rawCode);
    if (code.length != 6) throw Exception('Der Code hat 6 Zeichen.');
    final snap = await _db.doc('codes/$code').get();
    if (!snap.exists) throw Exception('Code nicht gefunden.');
    final otherUid = snap.data()!['uid'] as String;
    final otherName = (snap.data()!['name'] as String?) ?? 'Unbekannt';
    if (otherUid == uid) throw Exception('Das ist dein eigener Code 😉');

    final batch = _db.batch();
    batch.set(
      _myLocation,
      {'viewers': FieldValue.arrayUnion([otherUid])},
      SetOptions(merge: true),
    );
    batch.update(_me, {'sharingWith.$otherUid': otherName});
    await batch.commit();
    return otherName;
  }

  Future<void> stopSharingWith(String otherUid) async {
    final batch = _db.batch();
    batch.update(_myLocation, {
      'viewers': FieldValue.arrayRemove([otherUid])
    });
    batch.update(_me, {'sharingWith.$otherUid': FieldValue.delete()});
    await batch.commit();
  }

  Future<void> setSharing(bool sharing) async {
    final batch = _db.batch();
    batch.update(_me, {'sharing': sharing});
    batch.set(_myLocation, {'sharing': sharing}, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> rename(String name, String code) async {
    final batch = _db.batch();
    batch.update(_me, {'name': name});
    batch.set(_myLocation, {'name': name}, SetOptions(merge: true));
    if (code.isNotEmpty) batch.update(_db.doc('codes/$code'), {'name': name});
    await batch.commit();
  }

  Future<void> uploadLocation({
    required double lat,
    required double lng,
    required double accuracy,
    int? battery,
    bool charging = false,
  }) {
    return _myLocation.set({
      'lat': lat,
      'lng': lng,
      'accuracy': accuracy,
      'battery': battery,
      'charging': charging,
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  /// Löscht alle Daten und das (anonyme) Konto.
  Future<void> deleteAccount(String code) async {
    final batch = _db.batch();
    batch.delete(_myLocation);
    batch.delete(_me);
    if (code.isNotEmpty) batch.delete(_db.doc('codes/$code'));
    await batch.commit();
    await _auth.currentUser?.delete();
  }
}
