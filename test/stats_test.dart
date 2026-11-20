import 'package:flutter_test/flutter_test.dart';
import 'package:my_yatra/core/models/experience.dart';
import 'package:my_yatra/features/gamification/engine/stats.dart';

void main() {
  final visits = [
    StatsVisit(districtId: 'kathmandu', province: 3, districtTypes: [Experience.culture, Experience.spiritual], date: DateTime(2025, 4, 1)),
    StatsVisit(districtId: 'lalitpur', province: 3, districtTypes: [Experience.culture], date: DateTime(2026, 1, 3)),
    StatsVisit(districtId: 'bhaktapur', province: 3, districtTypes: [Experience.history]),
    const StatsVisit(districtId: 'kaski', province: 4, districtTypes: [Experience.nature]),
  ];

  test('statistics (TC-27)', () {
    final s = UserStats.compute(visits, [StatsJournal('kaski', DateTime(2026, 5, 1))]);
    expect(s.visitedCount, 4);
    expect(s.percent.toStringAsFixed(1), '5.2');
    expect(s.provincesCovered, 2);
    expect(s.journeys, 4);
    expect(s.journeysPerYear['2026'], 2);
    expect(s.journeysPerYear['Before MyYatra'], 1);
    expect(s.topCategory, Experience.culture);
  });

  test('badges unlock at milestones (TC-28)', () {
    final s = UserStats.compute(visits, []);
    final first = milestoneBadges.firstWhere((b) => b.id == 'first');
    final five = milestoneBadges.firstWhere((b) => b.id == 'five');
    expect(first.isUnlocked(s), isTrue);
    expect(five.isUnlocked(s), isFalse);
    expect(five.progress(s), closeTo(0.8, 0.001));
    final bagmati = districtChallenges.firstWhere((b) => b.id == 'province-3');
    expect(bagmati.isUnlocked(s), isTrue);
  });

  test('gap challenge targets a gap in the least explored province', () {
    final s = UserStats.compute(visits, []);
    final ch = GapChallenge.generate(
      gaps: [Experience.adventure],
      perProvince: s.perProvince,
      districtExists: (c, p) => p == 6,
    );
    expect(ch.single.province, 6);
    expect(ch.single.isComplete(visits), isFalse);
    expect(
      ch.single.isComplete([
        const StatsVisit(districtId: 'dolpa', province: 6, districtTypes: [Experience.adventure])
      ]),
      isTrue,
    );
  });
}
