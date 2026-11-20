import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models/models.dart';
import '../../core/providers/district_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/visit_provider.dart';
import '../../core/repositories/user_repository.dart';
import 'engine/dna_calculator.dart';

/// Journey DNA that recomputes whenever visits, activities or preferences
/// change (US-4.3), via ChangeNotifierProxyProvider3. The result is saved to
/// users/{uid}/dna/current.
class DnaProvider extends ChangeNotifier {
  final UserRepository? repo;
  DnaResult? _result;
  String _signature = '';
  Timer? _saveTimer;

  DnaProvider(this.repo);

  DnaResult? get result => _result;

  void update(ProfileProvider profile, VisitProvider visits,
      DistrictProvider districts) {
    final p = profile.profile;
    if (p == null) return;
    final types = <List<Experience>>[];
    final activities = <Experience>[];
    for (final v in visits.visits) {
      final d = districts.byId(v.districtId);
      if (d != null) types.add(d.experienceTypes);
      activities.addAll(v.places.expand((pl) => pl.activities));
    }
    final input = DnaInput(
      interests: p.interests.toSet(),
      travelStyle: p.habits.style,
      visitedDistrictTypes: types,
      activities: activities,
    );
    final sig = [
      p.interests.map((e) => e.name).join(','),
      p.habits.style,
      for (final v in visits.visits)
        '${v.districtId}:${v.activities.map((e) => e.name).join('+')}',
      districts.fromFirestore,
    ].join('|');
    if (sig == _signature && _result != null) return;
    _signature = sig;
    _result = DnaCalculator.calculate(input);
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), () {
      final r = _result;
      if (r != null) repo?.saveDna(r.toMap());
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
