import 'package:flutter_test/flutter_test.dart';
import 'package:my_yatra/core/data/district_seed.dart';
import 'package:my_yatra/core/models/experience.dart';
import 'package:my_yatra/features/recommendations/engine/recommender.dart';

List<RecDistrict> _all() => districtSeed
    .map((d) => RecDistrict(
          id: d.id,
          name: d.name,
          province: d.province,
          types: d.types,
          seasons: d.seasons,
          costLevel: d.cost,
          lat: d.lat,
          lng: d.lng,
          lessExplored: d.lessExplored,
        ))
    .toList();

void main() {
  final districts = _all();
  final kathmandu = districts.firstWhere((d) => d.id == 'kathmandu');
  final scores = {
    Experience.nature: 90.0,
    Experience.culture: 20.0,
    Experience.adventure: 10.0,
    Experience.food: 0.0,
    Experience.history: 0.0,
    Experience.spiritual: 0.0,
  };

  RecInput input({Set<String> visited = const {}, Set<String> excluded = const {}}) =>
      RecInput(
        districts: districts,
        visitedIds: visited,
        excludedIds: excluded,
        dnaScores: scores,
        untried: {Experience.spiritual, Experience.history},
        interests: {Experience.nature},
        start: kathmandu,
      );

  test('seed has 77 districts with correct province counts', () {
    expect(districtSeed.length, 77);
    final counts = <int, int>{};
    for (final d in districtSeed) {
      counts[d.province] = (counts[d.province] ?? 0) + 1;
    }
    expect(counts, {1: 14, 2: 8, 3: 13, 4: 11, 5: 12, 6: 10, 7: 9});
    expect(districtSeed.map((d) => d.id).toSet().length, 77);
  });

  test('visited districts never appear (TC-20)', () {
    final visited = {'kaski', 'chitwan', 'ilam', 'kathmandu'};
    final recs = Recommender.rank(input(visited: visited));
    expect(recs.any((r) => visited.contains(r.district.id)), isFalse);
    expect(recs.length, 77 - visited.length);
  });

  test('ranked descending and every card has a reason (TC-19)', () {
    final recs = Recommender.rank(input());
    for (var i = 1; i < recs.length; i++) {
      expect(recs[i - 1].score >= recs[i].score, isTrue);
    }
    expect(recs.every((r) => r.reason.startsWith('Picked because')), isTrue);
  });

  test('not interested districts are excluded (TC-24)', () {
    final recs = Recommender.rank(input(excluded: {'mugu'}));
    expect(recs.any((r) => r.district.id == 'mugu'), isFalse);
  });

  test('filters narrow the list (TC-21)', () {
    const f = RecFilters(budget: 1, season: Season.winter, distance: 'near');
    final recs = Recommender.rank(input(), filters: f);
    expect(recs, isNotEmpty);
    for (final r in recs) {
      expect(r.district.costLevel <= 1, isTrue);
      expect(r.district.seasons.contains(Season.winter), isTrue);
      expect(r.distanceKm! < 150, isTrue);
    }
    final less = Recommender.rank(input(),
        filters: const RecFilters(lessExploredOnly: true));
    expect(less.every((r) => r.district.lessExplored), isTrue);
  });

  test('weekly picks stable within a week, change next week (TC-23)', () {
    final recs = Recommender.rank(input());
    final mon = DateTime(2026, 11, 16);
    final fri = DateTime(2026, 11, 20);
    final next = DateTime(2026, 11, 23);
    final a = Recommender.weeklyPicks(recs, 'uid-1', mon).map((r) => r.district.id).toList();
    final b = Recommender.weeklyPicks(recs, 'uid-1', fri).map((r) => r.district.id).toList();
    expect(a, b);
    expect(a.length, 3);
    var changed = false;
    for (var w = 1; w <= 4; w++) {
      final c = Recommender.weeklyPicks(recs, 'uid-1', next.add(Duration(days: 7 * (w - 1))))
          .map((r) => r.district.id)
          .toList();
      if (c.toString() != a.toString()) changed = true;
    }
    expect(changed, isTrue);
  });

  test('ISO week numbers', () {
    expect(Recommender.isoWeek(DateTime(2026, 1, 1)), 1);
    expect(Recommender.isoWeek(DateTime(2026, 11, 19)), 47);
  });
}
