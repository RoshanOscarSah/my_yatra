import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import 'firestore_utils.dart';

/// Shared collections: reviews, alerts, feedback, changeLog, stats.
class CommunityRepository {
  final FirebaseFirestore _db;
  CommunityRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  // ---------------- Reviews (US-13.1, US-15.7) ----------------

  Stream<List<Review>> reviewsFor(String districtId) => _db
      .collection('reviews')
      .where('districtId', isEqualTo: districtId)
      .snapshots()
      .map((q) => q.docs.map((d) => Review.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime.now())
            .compareTo(a.createdAt ?? DateTime.now())));

  Stream<List<Review>> allReviews() => _db
      .collection('reviews')
      .snapshots()
      .map((q) => q.docs.map((d) => Review.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime.now())
            .compareTo(a.createdAt ?? DateTime.now())));

  /// One review per user per district: id = {districtId}_{uid}.
  Future<void> saveReview(Review r) => softWrite(_db
      .collection('reviews')
      .doc('${r.districtId}_${r.uid}')
      .set(r.toMap()));

  Future<void> deleteReview(Review r) =>
      softWrite(_db.collection('reviews').doc(r.id).delete());

  Future<void> adminDeleteReview(Review r,
      {required String adminUid, required String adminName}) async {
    final batch = _db.batch();
    batch.delete(_db.collection('reviews').doc(r.id));
    batch.set(_db.collection('changeLog').doc(), {
      'entity': 'review',
      'entityId': r.id,
      'field': 'deleted',
      'oldValue': '${r.rating}★ "${r.text}" by ${r.displayName}',
      'newValue': '',
      'adminUid': adminUid,
      'adminName': adminName,
      'at': FieldValue.serverTimestamp(),
    });
    await softWrite(batch.commit());
  }

  // ---------------- Alerts (US-12.1, US-15.6) ----------------

  /// Active alerts only: expired ones are hidden (TC-33).
  Stream<List<SafetyAlert>> activeAlerts(String districtId) => _db
      .collection('alerts')
      .where('districtId', isEqualTo: districtId)
      .snapshots()
      .map((q) => q.docs
          .map((d) => SafetyAlert.fromMap(d.id, d.data()))
          .where((a) => a.isActive())
          .toList());

  Stream<List<SafetyAlert>> allAlerts() => _db
      .collection('alerts')
      .snapshots()
      .map((q) => q.docs.map((d) => SafetyAlert.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => b.expiresAt.compareTo(a.expiresAt)));

  static String _when(DateTime t) => DateFormat('d MMM y, h:mm a').format(t);

  Future<void> saveAlert(SafetyAlert a, SafetyAlert? old,
      {required String adminUid, required String adminName}) async {
    final ref = a.id.isEmpty
        ? _db.collection('alerts').doc()
        : _db.collection('alerts').doc(a.id);
    final batch = _db.batch();
    batch.set(ref, a.toMap());
    batch.set(_db.collection('changeLog').doc(), {
      'entity': 'alert',
      'entityId': '${a.districtId}/${ref.id}',
      'field': old == null ? 'created' : 'updated',
      'oldValue': old == null ? '' : '${old.message} (until ${_when(old.expiresAt)})',
      'newValue': '${a.message} (until ${_when(a.expiresAt)})',
      'adminUid': adminUid,
      'adminName': adminName,
      'at': FieldValue.serverTimestamp(),
    });
    await softWrite(batch.commit());
  }

  Future<void> deleteAlert(SafetyAlert a,
      {required String adminUid, required String adminName}) async {
    final batch = _db.batch();
    batch.delete(_db.collection('alerts').doc(a.id));
    batch.set(_db.collection('changeLog').doc(), {
      'entity': 'alert',
      'entityId': '${a.districtId}/${a.id}',
      'field': 'deleted',
      'oldValue': a.message,
      'newValue': '',
      'adminUid': adminUid,
      'adminName': adminName,
      'at': FieldValue.serverTimestamp(),
    });
    await softWrite(batch.commit());
  }

  // ---------------- Feedback (US-14.x, US-15.5) ----------------

  Future<void> sendFeedback(FeedbackItem f) =>
      softWrite(_db.collection('feedback').doc().set(f.toMap()));

  Stream<List<FeedbackItem>> myFeedback(String uid) => _db
      .collection('feedback')
      .where('uid', isEqualTo: uid)
      .snapshots()
      .map((q) => q.docs.map((d) => FeedbackItem.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime.now())
            .compareTo(a.createdAt ?? DateTime.now())));

  Stream<List<FeedbackItem>> inbox() => _db
      .collection('feedback')
      .snapshots()
      .map((q) => q.docs.map((d) => FeedbackItem.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime.now())
            .compareTo(a.createdAt ?? DateTime.now())));

  Future<void> setFeedbackStatus(String id, String status) => softWrite(
      _db.collection('feedback').doc(id).update({
        'status': status,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      }));

  // ---------------- Admin: change log & stats ----------------

  Stream<List<ChangeLogEntry>> changeLog() => _db
      .collection('changeLog')
      .orderBy('at', descending: true)
      .limit(500)
      .snapshots()
      .map((q) =>
          q.docs.map((d) => ChangeLogEntry.fromMap(d.id, d.data())).toList());

  Stream<Map<String, int>> districtVisitTotals() => _db
      .collection('stats')
      .doc('districtVisits')
      .snapshots()
      .map((s) => {
            for (final e in (s.data() ?? {}).entries)
              e.key: (e.value as num?)?.toInt() ?? 0
          });
}
