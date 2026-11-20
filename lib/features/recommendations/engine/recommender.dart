// Rule-based recommendation engine (US-6.1 to US-6.7). Pure Dart.
//
// for each district d NOT visited and NOT marked not_interested / reported:
//   dnaMatch  = avg DNA score over d.experienceTypes             (0..1)
//   gapFill   = 1 if d covers a category the user hasn't tried   (0/1)
//   fit       = share of budget / season / distance prefs met    (0..1)
//   lessBonus = d.lessExplored ? 1 : 0
//   score     = 0.45·dnaMatch + 0.25·gapFill + 0.20·fit + 0.10·lessBonus
// reason = sentence built from the 1–2 biggest terms.
//
// Decision (US-6.3): distance is measured as straight-line km between the
// approximate centres of the starting district and the candidate:
// near < 150 km, medium 150–350 km, far > 350 km.
//
// Behind this Dart interface the engine can later move to a Python Cloud
// Function (decision C-05) without changing the UI.

import 'dart:math';

import '../../../core/models/experience.dart';

class RecDistrict {
  final String id;
  final String name;
  final int province;
  final List<Experience> types;
  final List<Season> seasons;
  final int costLevel;
  final double lat;
  final double lng;
  final bool lessExplored;

  const RecDistrict({
    required this.id,
    required this.name,
    required this.province,
    required this.types,
    required this.seasons,
    required this.costLevel,
    required this.lat,
    required this.lng,
    required this.lessExplored,
  });
}

class RecFilters {
  final int? budget; // max cost level
  final String? distance; // near / medium / far
  final Season? season;
  final bool lessExploredOnly;

  const RecFilters({
    this.budget,
    this.distance,
    this.season,
    this.lessExploredOnly = false,
  });

  RecFilters copyWith({
    int? budget,
    String? distance,
    Season? season,
    bool? lessExploredOnly,
    bool clearBudget = false,
    bool clearDistance = false,
    bool clearSeason = false,
  }) =>
      RecFilters(
        budget: clearBudget ? null : (budget ?? this.budget),
        distance: clearDistance ? null : (distance ?? this.distance),
        season: clearSeason ? null : (season ?? this.season),
        lessExploredOnly: lessExploredOnly ?? this.lessExploredOnly,
      );
}

class RecInput {
  final List<RecDistrict> districts;
  final Set<String> visitedIds;
  final Set<String> excludedIds; // not interested + reported
  final Map<Experience, double> dnaScores; // 0..100
  final Set<Experience> untried;
  final Set<Experience> interests;
  final RecDistrict? start;

  const RecInput({
    required this.districts,
    required this.visitedIds,
    this.excludedIds = const {},
    required this.dnaScores,
    required this.untried,
    this.interests = const {},
    this.start,
  });
}

class Recommendation {
  final RecDistrict district;
  final double score; // 0..1
  final double dnaMatch;
  final double gapFill;
  final double fit;
  final double lessBonus;
  final Experience? matchedCategory;
  final Experience? gapCategory;
  final String reason;
  final double? distanceKm;

  const Recommendation({
    required this.district,
    required this.score,
    required this.dnaMatch,
    required this.gapFill,
    required this.fit,
    required this.lessBonus,
    required this.matchedCategory,
    required this.gapCategory,
    required this.reason,
    required this.distanceKm,
  });
}

class Recommender {
  static const wDna = 0.45;
  static const wGap = 0.25;
  static const wFit = 0.20;
  static const wLess = 0.10;

  static double distanceKm(RecDistrict a, RecDistrict b) {
    const r = 6371.0;
    double rad(double d) => d * pi / 180;
    final dLat = rad(b.lat - a.lat);
    final dLng = rad(b.lng - a.lng);
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(rad(a.lat)) * cos(rad(b.lat)) * sin(dLng / 2) * sin(dLng / 2);
    return 2 * r * asin(sqrt(h));
  }

  static String distanceBand(double km) {
    if (km < 150) return 'near';
    if (km <= 350) return 'medium';
    return 'far';
  }

  /// True when the district passes the hard filters chosen on the page.
  static bool passes(RecDistrict d, RecFilters f, RecDistrict? start) {
    if (f.lessExploredOnly && !d.lessExplored) return false;
    if (f.budget != null && d.costLevel > f.budget!) return false;
    if (f.season != null && !d.seasons.contains(f.season)) return false;
    if (f.distance != null && start != null) {
      if (distanceBand(distanceKm(start, d)) != f.distance) return false;
    }
    return true;
  }

  /// Ranked recommendations. Visited and excluded districts never appear.
  static List<Recommendation> rank(RecInput input,
      {RecFilters filters = const RecFilters(), RecFilters? prefs}) {
    final result = <Recommendation>[];
    final p = prefs ?? filters;

    for (final d in input.districts) {
      if (input.visitedIds.contains(d.id)) continue;
      if (input.excludedIds.contains(d.id)) continue;
      if (!passes(d, filters, input.start)) continue;

      // DNA match
      Experience? best;
      double sum = 0;
      for (final t in d.types) {
        final s = (input.dnaScores[t] ?? 0) / 100;
        sum += s;
        if (best == null || s > (input.dnaScores[best] ?? 0) / 100) best = t;
      }
      final dnaMatch = d.types.isEmpty ? 0.0 : sum / d.types.length;

      // Gap fill
      Experience? gapCat;
      for (final t in d.types) {
        if (input.untried.contains(t)) {
          gapCat = t;
          break;
        }
      }
      final gapFill = gapCat == null ? 0.0 : 1.0;

      // Fit with saved preferences
      double? km;
      if (input.start != null) km = distanceKm(input.start!, d);
      int checks = 0, met = 0;
      if (p.budget != null) {
        checks++;
        if (d.costLevel <= p.budget!) met++;
      }
      if (p.season != null) {
        checks++;
        if (d.seasons.contains(p.season)) met++;
      }
      if (p.distance != null && km != null) {
        checks++;
        if (distanceBand(km) == p.distance) met++;
      }
      final fit = checks == 0 ? 1.0 : met / checks;

      final less = d.lessExplored ? 1.0 : 0.0;
      final score = wDna * dnaMatch + wGap * gapFill + wFit * fit + wLess * less;

      result.add(Recommendation(
        district: d,
        score: score,
        dnaMatch: dnaMatch,
        gapFill: gapFill,
        fit: fit,
        lessBonus: less,
        matchedCategory: best,
        gapCategory: gapCat,
        reason: _reason(d, dnaMatch, gapFill, fit, less, best, gapCat,
            input.interests, km),
        distanceKm: km,
      ));
    }

    result.sort((a, b) {
      final c = b.score.compareTo(a.score);
      return c != 0 ? c : a.district.name.compareTo(b.district.name);
    });
    return result;
  }

  static String _reason(
    RecDistrict d,
    double dnaMatch,
    double gapFill,
    double fit,
    double less,
    Experience? best,
    Experience? gap,
    Set<Experience> interests,
    double? km,
  ) {
    final terms = <MapEntry<String, double>>[
      MapEntry('dna', wDna * dnaMatch),
      MapEntry('gap', wGap * gapFill),
      MapEntry('fit', wFit * fit),
      MapEntry('less', wLess * less),
    ]..sort((a, b) => b.value.compareTo(a.value));

    String phrase(String key) {
      switch (key) {
        case 'dna':
          if (best == null) return 'it suits your Journey DNA';
          final liked = interests.contains(best) ? 'you love' : 'your DNA leans to';
          return 'it offers ${best.label.toLowerCase()} experiences $liked';
        case 'gap':
          return 'it fills your ${gap!.label.toLowerCase()} gap';
        case 'fit':
          return km == null
              ? 'it fits your budget and season'
              : 'it fits your plans (about ${km.round()} km away)';
        case 'less':
          return 'it is less explored by travellers';
      }
      return '';
    }

    final picked = terms.where((t) => t.value > 0).take(2).toList();
    if (picked.isEmpty) return 'A new district for you to discover.';
    final text = picked.map((t) => phrase(t.key)).join(' and ');
    return 'Picked because ${text[0].toLowerCase()}${text.substring(1)}.';
  }

  // ---------------- Weekly picks (US-6.5) ----------------

  /// ISO-8601 week number.
  static int isoWeek(DateTime date) {
    final d = DateTime.utc(date.year, date.month, date.day);
    final thursday = d.add(Duration(days: 4 - (d.weekday)));
    final firstDay = DateTime.utc(thursday.year, 1, 1);
    return 1 + thursday.difference(firstDay).inDays ~/ 7;
  }

  /// Stable string hash (FNV-1a) so picks are identical on every platform.
  static int stableHash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h;
  }

  /// Three picks from the top 10 that stay the same all week and change the
  /// next week. Visited / rejected districts are already excluded by [rank].
  static List<Recommendation> weeklyPicks(
      List<Recommendation> ranked, String uid, DateTime now,
      {int count = 3}) {
    final pool = ranked.take(10).toList();
    if (pool.length <= count) return pool;
    final seed = now.year * 100 + isoWeek(now) + stableHash(uid);
    final rnd = Random(seed);
    pool.shuffle(rnd);
    return pool.take(count).toList();
  }
}
