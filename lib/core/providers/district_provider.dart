import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../repositories/district_repository.dart';

/// Loads the 77 districts once and keeps them in sync.
/// Until an admin seeds Firestore, the bundled seed data is shown.
class DistrictProvider extends ChangeNotifier {
  final DistrictRepository repo;
  StreamSubscription<List<District>>? _sub;
  List<District> _districts = DistrictRepository.seedDistricts();
  bool _fromFirestore = false;
  bool _loaded = false;

  DistrictProvider({DistrictRepository? repo, bool listen = true})
      : repo = repo ?? DistrictRepository() {
    _index();
    if (!listen) return;
    _sub = this.repo.districts().listen((list) {
      _loaded = true;
      if (list.isNotEmpty) {
        _districts = list;
        _fromFirestore = true;
      }
      _index();
      notifyListeners();
    }, onError: (_) {
      _loaded = true;
      notifyListeners();
    });
  }

  final Map<String, District> _byId = {};
  final Map<String, String> _labelToId = {};

  void _index() {
    _districts.sort((a, b) => a.name.compareTo(b.name));
    _byId
      ..clear()
      ..addEntries(_districts.map((d) => MapEntry(d.id, d)));
    _labelToId
      ..clear()
      ..addEntries(_districts.map((d) => MapEntry(d.svgLabel, d.id)));
  }

  List<District> get districts => List.unmodifiable(_districts);
  Map<String, String> get labelToId => _labelToId;
  bool get fromFirestore => _fromFirestore;
  bool get loaded => _loaded;
  District? byId(String? id) => id == null ? null : _byId[id];

  List<District> inProvince(int p) =>
      _districts.where((d) => d.province == p).toList();

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
