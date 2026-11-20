import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/district_seed.dart';
import '../models/models.dart';
import 'firestore_utils.dart';

/// districts/{id} and districts/{id}/places/{id}. Read: signed in. Write: admin.
class DistrictRepository {
  final FirebaseFirestore _db;
  DistrictRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('districts');

  Stream<List<District>> districts() => _col.snapshots().map((q) =>
      q.docs.map((d) => District.fromMap(d.id, d.data())).toList());

  Stream<List<Place>> places(String districtId) => _col
      .doc(districtId)
      .collection('places')
      .snapshots()
      .map((q) => q.docs.map((d) => Place.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => a.name.compareTo(b.name)));

  Future<List<Place>> allPlaces() async {
    final q = await _db.collectionGroup('places').get();
    return q.docs.map((d) => Place.fromMap(d.id, d.data())).toList();
  }

  /// The bundled seed, used until an admin has seeded Firestore.
  static List<District> seedDistricts() => districtSeed
      .map((s) => District(
            id: s.id,
            name: s.name,
            svgLabel: s.svgLabel,
            province: s.province,
            lat: s.lat,
            lng: s.lng,
            description: s.description,
            experienceTypes: s.types,
            bestSeasons: s.seasons,
            costLevel: s.cost,
            transport: s.transport,
            safetyNotes: s.safety,
            festivals: s.festivals.map((f) => Festival(f.name, f.month)).toList(),
            foods: s.foods,
            lessExplored: s.lessExplored,
          ))
      .toList();

  static List<Place> seedPlaces(String districtId) {
    final s = districtSeed.where((d) => d.id == districtId).firstOrNull;
    if (s == null) return [];
    return [
      for (var i = 0; i < s.places.length; i++)
        Place(
          id: '$districtId-$i',
          districtId: districtId,
          name: s.places[i].name,
          experienceType: s.places[i].type,
          description: s.places[i].description,
        ),
    ];
  }

  /// Admin: write all 77 districts and their places (US-15.1 seed).
  Future<void> seed({required String adminUid, required String adminName}) async {
    var batch = _db.batch();
    var ops = 0;
    Future<void> flush() async {
      await batch.commit();
      batch = _db.batch();
      ops = 0;
    }

    for (final d in seedDistricts()) {
      batch.set(_col.doc(d.id), d.toMap());
      ops++;
      for (final p in seedPlaces(d.id)) {
        batch.set(_col.doc(d.id).collection('places').doc(p.id), p.toMap());
        ops++;
      }
      if (ops > 400) await flush();
    }
    batch.set(_db.collection('changeLog').doc(), {
      'entity': 'district',
      'entityId': '*',
      'field': 'seed',
      'oldValue': '',
      'newValue': '77 districts seeded',
      'adminUid': adminUid,
      'adminName': adminName,
      'at': FieldValue.serverTimestamp(),
    });
    await flush();
  }

  /// Admin: save a district and log every changed field (US-15.1, US-15.4).
  Future<void> saveDistrict(District updated, District? old,
      {required String adminUid, required String adminName}) async {
    final batch = _db.batch();
    final newMap = updated.toMap()..remove('updatedAt');
    final oldMap = old?.toMap()?..remove('updatedAt');
    batch.set(_col.doc(updated.id),
        {...newMap, 'updatedAt': FieldValue.serverTimestamp()});
    newMap.forEach((k, v) {
      final before = oldMap?[k];
      if (before.toString() != v.toString()) {
        batch.set(_db.collection('changeLog').doc(), {
          'entity': 'district',
          'entityId': updated.id,
          'field': k,
          'oldValue': before?.toString() ?? '',
          'newValue': v.toString(),
          'adminUid': adminUid,
          'adminName': adminName,
          'at': FieldValue.serverTimestamp(),
        });
      }
    });
    await softWrite(batch.commit());
  }

  Future<void> savePlace(Place p, Place? old,
      {required String adminUid, required String adminName}) async {
    final batch = _db.batch();
    final ref = _col.doc(p.districtId).collection('places').doc(p.id);
    batch.set(ref, p.toMap());
    batch.set(_db.collection('changeLog').doc(), {
      'entity': 'place',
      'entityId': '${p.districtId}/${p.id}',
      'field': old == null ? 'created' : 'updated',
      'oldValue': old == null
          ? ''
          : '${old.name} · ${old.experienceType.label} · ${old.description}',
      'newValue': '${p.name} · ${p.experienceType.label} · ${p.description}',
      'adminUid': adminUid,
      'adminName': adminName,
      'at': FieldValue.serverTimestamp(),
    });
    await softWrite(batch.commit());
  }

  Future<void> deletePlace(Place p,
      {required String adminUid, required String adminName}) async {
    final batch = _db.batch();
    batch.delete(_col.doc(p.districtId).collection('places').doc(p.id));
    batch.set(_db.collection('changeLog').doc(), {
      'entity': 'place',
      'entityId': '${p.districtId}/${p.id}',
      'field': 'deleted',
      'oldValue': p.name,
      'newValue': '',
      'adminUid': adminUid,
      'adminName': adminName,
      'at': FieldValue.serverTimestamp(),
    });
    await softWrite(batch.commit());
  }

  String newPlaceId(String districtId) =>
      _col.doc(districtId).collection('places').doc().id;
}
