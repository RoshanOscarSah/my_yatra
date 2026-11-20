import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../repositories/user_repository.dart';

/// Streams users/{uid}/visits. Progress = distinct districtIds / 77.
class VisitProvider extends ChangeNotifier {
  final UserRepository? repo;
  StreamSubscription<List<Visit>>? _sub;
  Map<String, Visit> _visits = {};
  bool _loaded = false;

  VisitProvider(this.repo) {
    final r = repo;
    if (r == null) {
      _loaded = true;
      return;
    }
    _sub = r.visits().listen((list) {
      _visits = {for (final v in list) v.districtId: v};
      _loaded = true;
      notifyListeners();
    });
  }

  bool get loaded => _loaded;
  List<Visit> get visits => _visits.values.toList();
  Set<String> get visitedIds => _visits.keys.toSet();
  Visit? visitFor(String districtId) => _visits[districtId];
  bool isVisited(String districtId) => _visits.containsKey(districtId);
  int get count => _visits.length;
  double get progress => count / 77;

  /// Mark visited (US-3.2). Future dates are rejected.
  Future<void> addVisit(String districtId, DateTime? date) async {
    if (date != null && date.isAfter(DateTime.now())) {
      throw ArgumentError('The visit date cannot be in the future.');
    }
    final existing = _visits[districtId];
    final v = existing?.copyWith(date: date, clearDate: date == null) ??
        Visit(districtId: districtId, date: date);
    _visits[districtId] = v;
    notifyListeners();
    await repo?.saveVisit(v, isNew: existing == null);
  }

  Future<void> addVisits(Iterable<String> ids) async {
    for (final id in ids) {
      if (!_visits.containsKey(id)) await addVisit(id, null);
    }
  }

  Future<void> removeVisit(String districtId) async {
    _visits.remove(districtId);
    notifyListeners();
    await repo?.deleteVisit(districtId);
  }

  /// US-3.4: places and activity types recorded on a visit.
  Future<void> savePlaces(String districtId, List<VisitPlace> places) async {
    final v = _visits[districtId];
    if (v == null) return;
    final updated = v.copyWith(places: places);
    _visits[districtId] = updated;
    notifyListeners();
    await repo?.saveVisit(updated);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
