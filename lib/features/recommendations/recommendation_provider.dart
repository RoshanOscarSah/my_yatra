import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models/models.dart';
import '../../core/providers/district_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/visit_provider.dart';
import '../../core/repositories/user_repository.dart';
import '../dna/dna_provider.dart';
import 'engine/recommender.dart';

/// Ranked, explained, filterable recommendations (Sprint 5).
class RecommendationProvider extends ChangeNotifier {
  final UserRepository? repo;
  StreamSubscription<Map<String, String>>? _sub;
  Map<String, String> _feedback = {};

  RecommendationProvider(this.repo) {
    _sub = repo?.recFeedback().listen((m) {
      _feedback = m;
      _recompute();
    });
  }

  DistrictProvider? _districts;
  VisitProvider? _visits;
  ProfileProvider? _profile;
  DnaProvider? _dna;

  RecFilters _filters = const RecFilters();
  bool _filtersTouched = false;
  List<Recommendation> _all = [];
  List<Recommendation> _filtered = [];

  RecFilters get filters => _filters;
  List<Recommendation> get recommendations => _filtered;
  List<Recommendation> get unfiltered => _all;
  Map<String, String> get feedback => _feedback;
  Set<String> get recommendedIds =>
      _all.take(10).map((r) => r.district.id).toSet();

  /// Setup is complete when interests and planning exist (US-6.1).
  bool get setupComplete {
    final p = _profile?.profile;
    return p != null && p.interests.isNotEmpty;
  }

  RecFilters get savedPrefs {
    final pl = _profile?.profile?.planning;
    return RecFilters(
        budget: pl?.budget, distance: pl?.distance, season: pl?.season);
  }

  void update(DistrictProvider d, VisitProvider v, ProfileProvider p,
      DnaProvider dna) {
    _districts = d;
    _visits = v;
    _profile = p;
    _dna = dna;
    if (!_filtersTouched) _filters = savedPrefs; // US-2.3 / TC-09
    _recompute();
  }

  void setFilters(RecFilters f) {
    _filters = f;
    _filtersTouched = true;
    _recompute();
  }

  void resetFilters() {
    _filtersTouched = false;
    _filters = savedPrefs;
    _recompute();
  }

  RecDistrict toRec(District d) => RecDistrict(
        id: d.id,
        name: d.name,
        province: d.province,
        types: d.experienceTypes,
        seasons: d.bestSeasons,
        costLevel: d.costLevel,
        lat: d.lat,
        lng: d.lng,
        lessExplored: d.lessExplored,
      );

  void _recompute() {
    final d = _districts, v = _visits, dna = _dna?.result, p = _profile?.profile;
    if (d == null || v == null || dna == null || p == null) return;
    final start = d.byId(p.planning.startDistrictId);
    final input = RecInput(
      districts: d.districts.map(toRec).toList(),
      visitedIds: v.visitedIds,
      excludedIds: _feedback.entries
          .where((e) => e.value == 'not_interested' || e.value == 'reported')
          .map((e) => e.key)
          .toSet(),
      dnaScores: dna.scores,
      untried: dna.notTried,
      interests: p.interests.toSet(),
      start: start == null ? null : toRec(start),
    );
    _all = Recommender.rank(input, prefs: savedPrefs);
    _filtered = Recommender.rank(input, filters: _filters, prefs: savedPrefs);
    notifyListeners();
  }

  List<Recommendation> weeklyPicks(DateTime now) =>
      Recommender.weeklyPicks(_all, repo?.uid ?? '', now);

  Future<void> markHelpful(String id) async {
    _feedback = {..._feedback, id: 'helpful'};
    _recompute();
    await repo?.setRecFeedback(id, 'helpful');
  }

  Future<void> markNotInterested(String id) async {
    _feedback = {..._feedback, id: 'not_interested'};
    _recompute();
    await repo?.setRecFeedback(id, 'not_interested');
  }

  Future<void> markReported(String id) async {
    _feedback = {..._feedback, id: 'reported'};
    _recompute();
    await repo?.setRecFeedback(id, 'reported');
  }

  Future<void> undo(String id) async {
    _feedback = Map.of(_feedback)..remove(id);
    _recompute();
    await repo?.clearRecFeedback(id);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
