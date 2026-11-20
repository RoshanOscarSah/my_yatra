import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/models.dart';
import 'firestore_utils.dart';

/// Everything under users/{uid} (private to the owner, see firestore.rules).
class UserRepository {
  final String uid;
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  UserRepository(this.uid, {FirebaseFirestore? db, FirebaseStorage? storage})
      : _db = db ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  DocumentReference<Map<String, dynamic>> get _user =>
      _db.collection('users').doc(uid);
  CollectionReference<Map<String, dynamic>> get _visits =>
      _user.collection('visits');
  CollectionReference<Map<String, dynamic>> get _journal =>
      _user.collection('journal');
  CollectionReference<Map<String, dynamic>> get _recFeedback =>
      _user.collection('recFeedback');
  CollectionReference<Map<String, dynamic>> get _itineraries =>
      _user.collection('itineraries');

  // ---------------- Profile ----------------

  Stream<UserProfile?> profile() => _user.snapshots().map(
      (s) => s.exists ? UserProfile.fromMap(uid, s.data()!) : null);

  Future<void> updateProfile(Map<String, dynamic> data) =>
      softWrite(_user.set(data, SetOptions(merge: true)));

  // ---------------- Visits ----------------

  Stream<List<Visit>> visits() => _visits.snapshots().map((q) =>
      q.docs.map((d) => Visit.fromMap(d.id, d.data())).toList());

  Future<void> saveVisit(Visit v, {bool isNew = false}) async {
    await softWrite(_visits.doc(v.districtId).set(v.toMap()));
    if (isNew) await _bumpStat(v.districtId, 1);
  }

  Future<void> deleteVisit(String districtId) async {
    await softWrite(_visits.doc(districtId).delete());
    await _bumpStat(districtId, -1);
  }

  /// Aggregate totals only (NFR-14): no user id is stored with the count.
  Future<void> _bumpStat(String districtId, int by) => softWrite(_db
      .collection('stats')
      .doc('districtVisits')
      .set({districtId: FieldValue.increment(by)}, SetOptions(merge: true)));

  // ---------------- Journal ----------------

  Stream<List<JournalEntry>> journal() => _journal.snapshots().map((q) => q
      .docs
      .map((d) => JournalEntry.fromMap(d.id, d.data()))
      .toList()
    ..sort((a, b) => b.startDate.compareTo(a.startDate)));

  String newJournalId() => _journal.doc().id;

  Future<void> saveJournal(JournalEntry e) =>
      softWrite(_journal.doc(e.id).set(e.toMap()));

  Future<void> deleteJournal(JournalEntry e) async {
    for (final p in e.photoPaths) {
      try {
        await _storage.ref(p).delete();
      } catch (_) {}
    }
    await softWrite(_journal.doc(e.id).delete());
  }

  /// Uploads a compressed photo and returns (downloadUrl, storagePath).
  Future<(String, String)> uploadPhoto(
      String entryId, Uint8List bytes, String ext) async {
    final type = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      _ => 'image/jpeg',
    };
    final path =
        'users/$uid/journal/$entryId/${DateTime.now().microsecondsSinceEpoch}.$ext';
    final ref = _storage.ref(path);
    await ref.putData(bytes, SettableMetadata(contentType: type));
    return (await ref.getDownloadURL(), path);
  }

  Future<void> deletePhoto(String path) async {
    try {
      await _storage.ref(path).delete();
    } catch (_) {}
  }

  // ---------------- Journey DNA ----------------

  Future<void> saveDna(Map<String, dynamic> dna) =>
      softWrite(_user.collection('dna').doc('current').set(dna));

  // ---------------- Recommendation feedback ----------------

  Stream<Map<String, String>> recFeedback() => _recFeedback.snapshots().map(
      (q) => {for (final d in q.docs) d.id: d.data()['value'].toString()});

  Future<void> setRecFeedback(String districtId, String value) => softWrite(
      _recFeedback.doc(districtId).set({
        'value': value,
        'at': FieldValue.serverTimestamp(),
      }));

  Future<void> clearRecFeedback(String districtId) =>
      softWrite(_recFeedback.doc(districtId).delete());

  // ---------------- Itineraries ----------------

  Stream<List<Itinerary>> itineraries() => _itineraries.snapshots().map((q) =>
      q.docs.map((d) => Itinerary.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => a.startDate.compareTo(b.startDate)));

  String newItineraryId() => _itineraries.doc().id;

  Future<void> saveItinerary(Itinerary i) =>
      softWrite(_itineraries.doc(i.id).set(i.toMap()));

  Future<void> deleteItinerary(String id) =>
      softWrite(_itineraries.doc(id).delete());

  // ---------------- Delete account (US-1.6) ----------------

  /// Order: subcollections → photos → public content → user doc.
  /// The caller then deletes the Auth user.
  Future<void> deleteAllData() async {
    final journal = await _journal.get();
    for (final d in journal.docs) {
      final e = JournalEntry.fromMap(d.id, d.data());
      for (final p in e.photoPaths) {
        await deletePhoto(p);
      }
    }
    for (final name in [
      'visits',
      'journal',
      'dna',
      'recFeedback',
      'itineraries',
    ]) {
      final snap = await _user.collection(name).get();
      final batch = _db.batch();
      for (final d in snap.docs) {
        if (name == 'visits') {
          batch.set(
              _db.collection('stats').doc('districtVisits'),
              {d.id: FieldValue.increment(-1)},
              SetOptions(merge: true));
        }
        batch.delete(d.reference);
      }
      await batch.commit();
    }
    final reviews =
        await _db.collection('reviews').where('uid', isEqualTo: uid).get();
    for (final d in reviews.docs) {
      await d.reference.delete();
    }
    await _user.delete();
  }
}
