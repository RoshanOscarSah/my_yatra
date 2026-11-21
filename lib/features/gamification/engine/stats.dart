// Travel statistics, badges and challenges (US-8.3, US-9.1, US-9.2). Pure Dart.
//
// Badges extend Hariyo Naksha's achievements.dart: the old
// `isUnlocked(visited, total)` signature becomes `isUnlocked(UserStats)`.

import '../../../core/models/experience.dart';

class StatsVisit {
  final String districtId;
  final int province;
  final List<Experience> districtTypes;
  final DateTime? date;
  const StatsVisit({
    required this.districtId,
    required this.province,
    required this.districtTypes,
    this.date,
  });
}

class StatsJournal {
  final String districtId;
  final DateTime startDate;
  const StatsJournal(this.districtId, this.startDate);
}

class UserStats {
  static const totalDistricts = 77;

  final int visitedCount;
  final Map<int, int> perProvince; // province -> visited districts
  final int journeys;
  final Map<String, int> journeysPerYear; // "2025" / "Before MyYatra"
  final Experience? topCategory; // null when there is no visit or a tie
  final bool topTied; // two or more categories share the top count
  final Map<Experience, int> perCategory; // visited districts per category
  final Set<String> visitedIds;

  const UserStats({
    required this.visitedCount,
    required this.perProvince,
    required this.journeys,
    required this.journeysPerYear,
    required this.topCategory,
    this.topTied = false,
    required this.perCategory,
    required this.visitedIds,
  });

  double get percent => visitedCount / totalDistricts * 100;
  int get provincesCovered => perProvince.values.where((v) => v > 0).length;

  static UserStats compute(List<StatsVisit> visits, List<StatsJournal> journal) {
    final ids = <String>{};
    final perProvince = <int, int>{for (var p = 1; p <= 7; p++) p: 0};
    final perCategory = <Experience, int>{for (final e in Experience.values) e: 0};
    final perYear = <String, int>{};

    for (final v in visits) {
      if (!ids.add(v.districtId)) continue;
      perProvince[v.province] = (perProvince[v.province] ?? 0) + 1;
      for (final t in v.districtTypes.toSet()) {
        perCategory[t] = perCategory[t]! + 1;
      }
    }

    // A journey is a journal entry, or a visit without any journal entry for
    // that district (so one trip with both is counted once).
    final journalDistricts = journal.map((j) => j.districtId).toSet();
    var journeys = 0;
    for (final j in journal) {
      journeys++;
      final y = j.startDate.year.toString();
      perYear[y] = (perYear[y] ?? 0) + 1;
    }
    for (final v in visits) {
      if (journalDistricts.contains(v.districtId)) continue;
      journeys++;
      final y = v.date?.year.toString() ?? 'Before MyYatra';
      perYear[y] = (perYear[y] ?? 0) + 1;
    }

    Experience? top;
    for (final e in Experience.values) {
      if (perCategory[e]! > 0 &&
          (top == null || perCategory[e]! > perCategory[top]!)) {
        top = e;
      }
    }
    // A tie has no single "most explored" category; the screen shows "Mixed".
    final topTied = top != null &&
        Experience.values.where((e) => perCategory[e] == perCategory[top]).length > 1;

    return UserStats(
      visitedCount: ids.length,
      perProvince: perProvince,
      journeys: journeys,
      journeysPerYear: perYear,
      topCategory: topTied ? null : top,
      topTied: topTied,
      perCategory: perCategory,
      visitedIds: ids,
    );
  }
}

class Badge {
  final String id;
  final String title;
  final String description;
  final String icon; // material icon key resolved in the UI
  final bool Function(UserStats s) isUnlocked;
  final double Function(UserStats s) progress; // 0..1

  const Badge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.isUnlocked,
    required this.progress,
  });
}

double _ratio(int a, int b) => b == 0 ? 0 : (a / b).clamp(0, 1).toDouble();

Badge _milestone(String id, String title, int n, String icon) => Badge(
      id: id,
      title: title,
      description: n == 1
          ? 'Visit your first district'
          : n == UserStats.totalDistricts
              ? 'Visit all 77 districts'
              : 'Visit $n districts',
      icon: icon,
      isUnlocked: (s) => s.visitedCount >= n,
      progress: (s) => _ratio(s.visitedCount, n),
    );

/// Milestone badges.
final List<Badge> milestoneBadges = [
  _milestone('first', 'First Step', 1, 'flag'),
  _milestone('five', 'Wanderer', 5, 'hiking'),
  _milestone('ten', 'Explorer', 10, 'explore'),
  _milestone('twentyfive', 'Adventurer', 25, 'landscape'),
  _milestone('fifty', 'Voyager', 50, 'flight'),
  _milestone('all', 'Pioneer', UserStats.totalDistricts, 'stars'),
];

/// District-based challenges: three districts in each province, plus one
/// district in every province.
final List<Badge> districtChallenges = [
  for (final p in Province.all)
    Badge(
      id: 'province-${p.number}',
      title: '${p.name} Hopper',
      description: 'Visit 3 districts in ${p.name} Province',
      icon: 'map',
      isUnlocked: (s) => (s.perProvince[p.number] ?? 0) >= 3,
      progress: (s) => _ratio(s.perProvince[p.number] ?? 0, 3),
    ),
  Badge(
    id: 'seven-provinces',
    title: 'Seven Provinces',
    description: 'Visit at least one district in every province',
    icon: 'public',
    isUnlocked: (s) => s.provincesCovered >= 7,
    progress: (s) => _ratio(s.provincesCovered, 7),
  ),
];

/// A challenge generated from the user's own exploration gaps (US-9.2).
class GapChallenge {
  final Experience category;
  final int province;
  const GapChallenge(this.category, this.province);

  String get id => 'gap-${category.name}-$province';

  String get title =>
      'Visit a ${category.label} district in ${Province.nameOf(province)}';

  bool isComplete(List<StatsVisit> visits) => visits.any(
      (v) => v.province == province && v.districtTypes.contains(category));

  /// Builds challenges from DNA gaps and the least-explored provinces,
  /// only where a matching district exists.
  static List<GapChallenge> generate({
    required List<Experience> gaps,
    required Map<int, int> perProvince,
    required bool Function(Experience c, int province) districtExists,
    int max = 3,
  }) {
    final provinces = Province.all.map((p) => p.number).toList()
      ..sort((a, b) {
        final ra = (perProvince[a] ?? 0) / Province.of(a).districtCount;
        final rb = (perProvince[b] ?? 0) / Province.of(b).districtCount;
        return ra.compareTo(rb);
      });
    final out = <GapChallenge>[];
    for (final g in gaps) {
      for (final p in provinces) {
        if (districtExists(g, p)) {
          out.add(GapChallenge(g, p));
          break;
        }
      }
      if (out.length >= max) break;
    }
    return out;
  }
}
