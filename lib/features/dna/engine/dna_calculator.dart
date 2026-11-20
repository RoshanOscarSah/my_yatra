// Journey DNA engine (US-4.1, US-4.4, US-5.1, US-5.3).
//
// Pure Dart: no Flutter or Firebase imports, so it can be unit-tested with the
// five personas (test/dna_calculator_test.dart).
//
// Formula (report §8.4):
//   interest(c) = 1 if chosen in onboarding, 0.5 if only the travel style
//                 points to c, else 0
//   visits(c)   = share of the user's visited districts whose experience
//                 types include c
//   activity(c) = share of recorded activities tagged c
//   score(c)    = 100 × (0.4·interest + 0.4·visits + 0.2·activity)
//
// Type = "<top category> Explorer"; if the top two are within 10 points the
// traveller is a "Mixed Traveller".

import '../../../core/models/experience.dart';

/// Travel style options from onboarding step 02 and the category each one
/// points to.
const Map<String, Experience?> travelStyleCategory = {
  'relaxing': Experience.nature,
  'sightseeing': Experience.culture,
  'adventure': Experience.adventure,
  'food': Experience.food,
  'heritage': Experience.history,
  'pilgrimage': Experience.spiritual,
};

class DnaInput {
  final Set<Experience> interests;
  final String? travelStyle;

  /// Experience types of each visited district (one list per district).
  final List<List<Experience>> visitedDistrictTypes;

  /// Every activity tag recorded on visits.
  final List<Experience> activities;

  const DnaInput({
    required this.interests,
    this.travelStyle,
    this.visitedDistrictTypes = const [],
    this.activities = const [],
  });
}

class DnaResult {
  final Map<Experience, double> scores; // 0..100
  final Map<Experience, double> visitShare; // 0..1
  final Map<Experience, double> activityShare; // 0..1
  final String type;
  final Experience? topCategory;
  final bool isMixed;
  final int visitCount;
  final String explanation;
  final String gapSummary;
  final DateTime updatedAt;

  const DnaResult({
    required this.scores,
    required this.visitShare,
    required this.activityShare,
    required this.type,
    required this.topCategory,
    required this.isMixed,
    required this.visitCount,
    required this.explanation,
    required this.gapSummary,
    required this.updatedAt,
  });

  /// A category counts as "tried" once any visit or activity touches it.
  Set<Experience> get tried => Experience.values
      .where((c) => (visitShare[c] ?? 0) > 0 || (activityShare[c] ?? 0) > 0)
      .toSet();

  Set<Experience> get notTried =>
      Experience.values.where((c) => !tried.contains(c)).toSet();

  /// Gaps: categories with no or very few visits (< 15% of visits).
  Set<Experience> get gaps => Experience.values
      .where((c) => (visitShare[c] ?? 0) < DnaCalculator.gapThreshold)
      .toSet();

  List<Experience> get ranked {
    final list = Experience.values.toList();
    list.sort((a, b) => (scores[b] ?? 0).compareTo(scores[a] ?? 0));
    return list;
  }

  Map<String, dynamic> toMap() => {
        'type': type,
        'topCategory': topCategory?.name,
        'isMixed': isMixed,
        'scores': {for (final e in scores.entries) e.key.name: e.value},
        'visitShare': {for (final e in visitShare.entries) e.key.name: e.value},
        'gaps': gaps.map((e) => e.name).toList(),
        'explanation': explanation,
        'gapSummary': gapSummary,
        'visitCount': visitCount,
        'updatedAt': updatedAt.toIso8601String(),
      };
}

class DnaCalculator {
  static const double interestWeight = 0.4;
  static const double visitWeight = 0.4;
  static const double activityWeight = 0.2;
  static const double mixedMargin = 10;
  static const double gapThreshold = 0.15;

  static String typeName(Experience c) => switch (c) {
        Experience.nature => 'Nature Explorer',
        Experience.culture => 'Cultural Explorer',
        Experience.adventure => 'Adventure Explorer',
        Experience.food => 'Food Explorer',
        Experience.history => 'History Explorer',
        Experience.spiritual => 'Spiritual Explorer',
      };

  static DnaResult calculate(DnaInput input, {DateTime? now}) {
    final styleCat = travelStyleCategory[input.travelStyle];
    final visitCount = input.visitedDistrictTypes.length;
    final activityCount = input.activities.length;

    final scores = <Experience, double>{};
    final visitShare = <Experience, double>{};
    final activityShare = <Experience, double>{};

    for (final c in Experience.values) {
      double interest = input.interests.contains(c) ? 1 : 0;
      if (interest == 0 && styleCat == c) interest = 0.5;

      final v = visitCount == 0
          ? 0.0
          : input.visitedDistrictTypes.where((t) => t.contains(c)).length /
              visitCount;
      final a = activityCount == 0
          ? 0.0
          : input.activities.where((t) => t == c).length / activityCount;

      visitShare[c] = v;
      activityShare[c] = a;
      scores[c] = _round(
          100 * (interestWeight * interest + visitWeight * v + activityWeight * a));
    }

    final ranked = Experience.values.toList()
      ..sort((a, b) {
        final d = scores[b]!.compareTo(scores[a]!);
        return d != 0 ? d : a.index.compareTo(b.index);
      });
    final top = ranked[0];
    final second = ranked[1];
    final hasSignal = scores[top]! > 0;
    final isMixed =
        !hasSignal || (scores[top]! - scores[second]!) < mixedMargin;
    final type = isMixed ? 'Mixed Traveller' : typeName(top);

    final partial = DnaResult(
      scores: scores,
      visitShare: visitShare,
      activityShare: activityShare,
      type: type,
      topCategory: hasSignal ? top : null,
      isMixed: isMixed,
      visitCount: visitCount,
      explanation: '',
      gapSummary: '',
      updatedAt: now ?? DateTime.now(),
    );

    return DnaResult(
      scores: scores,
      visitShare: visitShare,
      activityShare: activityShare,
      type: type,
      topCategory: partial.topCategory,
      isMixed: isMixed,
      visitCount: visitCount,
      explanation: explain(input, partial),
      gapSummary: summariseGaps(partial),
      updatedAt: partial.updatedAt,
    );
  }

  /// Template explanation (US-4.4). Every statement is taken from the
  /// user's own data, so it still works when no AI service is reachable.
  static String explain(DnaInput input, DnaResult r) {
    final parts = <String>[];
    final chosen = Experience.values.where(input.interests.contains).toList();
    if (chosen.isNotEmpty) {
      parts.add('You chose ${_list(chosen.map((e) => e.label.toLowerCase()))} '
          'as the kinds of places you enjoy.');
    } else {
      parts.add('You have not picked any interests yet.');
    }

    if (r.visitCount == 0) {
      parts.add('You have no visits recorded yet, so your DNA is based on '
          'your preferences only. Mark districts as visited to sharpen it.');
    } else {
      final top = r.ranked.first;
      final pct = ((r.visitShare[top] ?? 0) * 100).round();
      parts.add('Across your ${r.visitCount} visited '
          '${r.visitCount == 1 ? 'district' : 'districts'}, $pct% offered '
          '${top.label.toLowerCase()} experiences.');
    }

    if (r.isMixed && r.topCategory != null) {
      final a = r.ranked[0], b = r.ranked[1];
      parts.add('${a.label} (${r.scores[a]!.round()}) and ${b.label} '
          '(${r.scores[b]!.round()}) are close, so you come out as a '
          'Mixed Traveller.');
    } else if (r.topCategory != null) {
      final a = r.ranked[0];
      parts.add('${a.label} leads your scores with ${r.scores[a]!.round()} '
          'out of 100, which makes you a ${r.type}.');
    }
    return parts.join(' ');
  }

  /// Template gap summary (US-5.3).
  static String summariseGaps(DnaResult r) {
    if (r.visitCount == 0) {
      return 'Add the districts you have visited to see your exploration gaps.';
    }
    // Most-visited first, so the sentence matches the "explored" chart
    // (ties keep the DNA order).
    final explored = r.ranked
        .where((c) => (r.visitShare[c] ?? 0) >= gapThreshold)
        .toList()
      ..sort((a, b) {
        final byShare = (r.visitShare[b] ?? 0).compareTo(r.visitShare[a] ?? 0);
        return byShare != 0 ? byShare : r.ranked.indexOf(a).compareTo(r.ranked.indexOf(b));
      });
    final rare = r.ranked.where(r.gaps.contains).toList().reversed.toList();
    final parts = <String>[];
    if (explored.isNotEmpty) {
      parts.add('You have mostly explored '
          '${_list(explored.take(2).map((e) => e.label.toLowerCase()))} places.');
    }
    if (rare.isNotEmpty) {
      final none = rare.where((c) => (r.visitShare[c] ?? 0) == 0).toList();
      final few = rare.where((c) => (r.visitShare[c] ?? 0) > 0).toList();
      if (none.isNotEmpty) {
        parts.add('You have not yet tried '
            '${_list(none.map((e) => e.label.toLowerCase()))} experiences.');
      }
      if (few.isNotEmpty) {
        parts.add('You have rarely visited '
            '${_list(few.map((e) => e.label.toLowerCase()))} destinations.');
      }
      parts.add('Trying ${rare.first.label.toLowerCase()} districts next would '
          'broaden your Journey DNA the most.');
    } else {
      parts.add('You have a well-balanced travel history across all six '
          'categories.');
    }
    return parts.join(' ');
  }

  static double _round(double v) => (v * 10).round() / 10;

  static String _list(Iterable<String> items) {
    final l = items.toList();
    if (l.isEmpty) return '';
    if (l.length == 1) return l.first;
    return '${l.sublist(0, l.length - 1).join(', ')} and ${l.last}';
  }
}
