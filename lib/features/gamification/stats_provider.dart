import 'package:flutter/foundation.dart';

import '../../core/providers/district_provider.dart';
import '../../core/providers/journal_provider.dart';
import '../../core/providers/visit_provider.dart';
import 'engine/stats.dart';

/// Travel statistics and badge state computed from existing providers
/// (US-8.3, US-9.1). No extra data is stored.
class StatsProvider extends ChangeNotifier {
  UserStats _stats = UserStats.compute(const [], const []);
  List<StatsVisit> _visits = const [];
  Set<String> _unlocked = {};
  final List<Badge> _newlyUnlocked = [];
  bool _initialised = false;

  UserStats get stats => _stats;
  List<StatsVisit> get statsVisits => _visits;

  List<Badge> get allBadges => [...milestoneBadges, ...districtChallenges];
  List<Badge> get unlockedBadges =>
      allBadges.where((b) => b.isUnlocked(_stats)).toList();

  /// Badges earned since the last call (for the "badge earned" notice).
  List<Badge> takeNewlyUnlocked() {
    final l = List<Badge>.from(_newlyUnlocked);
    _newlyUnlocked.clear();
    return l;
  }

  void update(DistrictProvider d, VisitProvider v, JournalProvider j) {
    if (!v.loaded) return;
    _visits = [
      for (final x in v.visits)
        if (d.byId(x.districtId) != null)
          StatsVisit(
            districtId: x.districtId,
            province: d.byId(x.districtId)!.province,
            districtTypes: d.byId(x.districtId)!.experienceTypes,
            date: x.date,
          ),
    ];
    _stats = UserStats.compute(_visits,
        [for (final e in j.entries) StatsJournal(e.districtId, e.startDate)]);
    final now = unlockedBadges.map((b) => b.id).toSet();
    if (_initialised) {
      for (final b in allBadges) {
        if (now.contains(b.id) && !_unlocked.contains(b.id)) {
          _newlyUnlocked.add(b);
        }
      }
    }
    _unlocked = now;
    _initialised = true;
    notifyListeners();
  }
}
