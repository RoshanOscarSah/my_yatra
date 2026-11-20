/// The six fixed experience categories (decision C-07: 6 categories).
enum Experience {
  nature('Nature'),
  culture('Culture'),
  adventure('Adventure'),
  food('Food'),
  history('History'),
  spiritual('Spiritual');

  const Experience(this.label);
  final String label;

  static Experience? fromName(String? name) {
    for (final e in Experience.values) {
      if (e.name == name) return e;
    }
    return null;
  }

  static List<Experience> listFrom(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .map((e) => fromName(e?.toString()))
        .whereType<Experience>()
        .toList();
  }
}

enum Season {
  spring('Spring (Mar–May)'),
  summer('Summer / monsoon (Jun–Aug)'),
  autumn('Autumn (Sep–Nov)'),
  winter('Winter (Dec–Feb)');

  const Season(this.label);
  final String label;

  String get short => name[0].toUpperCase() + name.substring(1);

  static Season? fromName(String? name) {
    for (final s in Season.values) {
      if (s.name == name) return s;
    }
    return null;
  }

  static List<Season> listFrom(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .map((e) => fromName(e?.toString()))
        .whereType<Season>()
        .toList();
  }

  static Season current([DateTime? now]) {
    final m = (now ?? DateTime.now()).month;
    if (m >= 3 && m <= 5) return Season.spring;
    if (m >= 6 && m <= 8) return Season.summer;
    if (m >= 9 && m <= 11) return Season.autumn;
    return Season.winter;
  }
}

/// Nepal's seven provinces with their official district counts.
class Province {
  final int number;
  final String name;
  final int districtCount;
  const Province(this.number, this.name, this.districtCount);

  static const all = [
    Province(1, 'Koshi', 14),
    Province(2, 'Madhesh', 8),
    Province(3, 'Bagmati', 13),
    Province(4, 'Gandaki', 11),
    Province(5, 'Lumbini', 12),
    Province(6, 'Karnali', 10),
    Province(7, 'Sudurpashchim', 9),
  ];

  static Province of(int number) =>
      all.firstWhere((p) => p.number == number, orElse: () => all.first);

  static String nameOf(int number) => of(number).name;
}

/// Cost levels used by districts and the budget filter.
class CostLevel {
  static const labels = {1: 'Budget', 2: 'Moderate', 3: 'Premium'};
  static const ranges = {
    1: 'NPR 1,500–3,000 per day',
    2: 'NPR 3,000–6,000 per day',
    3: 'NPR 6,000+ per day',
  };
  /// Lowest usual spend per day (NPR) for each level.
  static const minPerDay = {1: 1500, 2: 3000, 3: 6000};
  static String label(int level) => labels[level] ?? 'Unknown';
  static String range(int level) => ranges[level] ?? '';
}
