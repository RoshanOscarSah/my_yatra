import 'package:flutter_test/flutter_test.dart';
import 'package:my_yatra/core/models/experience.dart';
import 'package:my_yatra/features/dna/engine/dna_calculator.dart';

const n = Experience.nature, c = Experience.culture, a = Experience.adventure;
const f = Experience.food, h = Experience.history, s = Experience.spiritual;

void main() {
  group('DnaCalculator personas (TC-14)', () {
    test('Swati (nature with family) is a Nature Explorer', () {
      final r = DnaCalculator.calculate(const DnaInput(
        interests: {n},
        travelStyle: 'relaxing',
        visitedDistrictTypes: [
          [n, c],
          [n, a],
          [n, s],
        ],
        activities: [n, n, n],
      ));
      expect(r.type, 'Nature Explorer');
      expect(r.topCategory, n);
      expect(r.scores[n], 100);
    });

    test('L. B. Gurung (spiritual) is a Spiritual Explorer', () {
      final r = DnaCalculator.calculate(const DnaInput(
        interests: {s},
        travelStyle: 'pilgrimage',
        visitedDistrictTypes: [
          [s, c],
          [s, h],
          [s, n],
          [s],
        ],
        activities: [s, s, c],
      ));
      expect(r.type, 'Spiritual Explorer');
    });

    test('Bhagirath (culture + history equally) is a Mixed Traveller', () {
      final r = DnaCalculator.calculate(const DnaInput(
        interests: {c, h},
        travelStyle: 'heritage',
        visitedDistrictTypes: [
          [c, h],
          [c, h, s],
        ],
        activities: [c, h],
      ));
      expect(r.type, 'Mixed Traveller');
      expect(r.isMixed, isTrue);
      expect(r.explanation, contains('Mixed Traveller'));
    });

    test('Mukesh (adventure with friends) is an Adventure Explorer', () {
      final r = DnaCalculator.calculate(const DnaInput(
        interests: {a, f},
        travelStyle: 'adventure',
        visitedDistrictTypes: [
          [a, n],
          [a, f],
          [a, n],
          [a],
          [a, c],
          [n, a],
        ],
        activities: [a, a, a, f],
      ));
      expect(r.type, 'Adventure Explorer');
    });

    test('Neriah with no visits uses preferences only', () {
      final r = DnaCalculator.calculate(
          const DnaInput(interests: {c}, travelStyle: 'sightseeing'));
      expect(r.visitCount, 0);
      expect(r.type, 'Cultural Explorer');
      expect(r.explanation, contains('preferences only'));
      expect(r.gapSummary, contains('Add the districts'));
    });
  });

  test('gaps and tried categories (TC-17)', () {
    final r = DnaCalculator.calculate(const DnaInput(
      interests: {n},
      visitedDistrictTypes: [
        [n, c],
        [n],
      ],
    ));
    expect(r.tried, {n, c});
    expect(r.notTried, {a, f, h, s});
    expect(r.gaps.contains(a), isTrue);
    expect(r.gaps.contains(n), isFalse);
    expect(r.gapSummary, contains('not yet tried'));
  });

  test('nothing chosen and no visits is Mixed Traveller with zero scores', () {
    final r = DnaCalculator.calculate(const DnaInput(interests: {}));
    expect(r.type, 'Mixed Traveller');
    expect(r.scores.values.every((v) => v == 0), isTrue);
  });

  test('gap summary names the most-visited types, not the top DNA types', () {
    // The QA account from manual testing: culture and history interests,
    // but trips were mostly culture and nature.
    final r = DnaCalculator.calculate(const DnaInput(
      interests: {c, h},
      visitedDistrictTypes: [
        [n, f, c],
        [n, c, f],
        [c, h, n],
      ],
      activities: [n, h],
    ));
    expect(r.gapSummary, startsWith('You have mostly explored culture and nature places.'));
  });

  test('gap summary names every type when more than two tie', () {
    final r = DnaCalculator.calculate(const DnaInput(
      interests: {n},
      visitedDistrictTypes: [
        [n, c, h],
        [n, c, h],
      ],
    ));
    expect(r.gapSummary,
        startsWith('You have explored nature, culture and history places about equally.'));
  });
}
