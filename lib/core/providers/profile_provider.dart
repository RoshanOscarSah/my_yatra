import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../repositories/user_repository.dart';

/// Loads users/{uid} and exposes interests, habits and planning (S2).
class ProfileProvider extends ChangeNotifier {
  final UserRepository? repo;
  StreamSubscription<UserProfile?>? _sub;
  UserProfile? _profile;
  bool _loaded = false;

  ProfileProvider(this.repo) {
    final r = repo;
    if (r == null) {
      _loaded = true;
      return;
    }
    _sub = r.profile().listen((p) {
      _profile = p;
      _loaded = true;
      notifyListeners();
    }, onError: (_) {
      _loaded = true;
      notifyListeners();
    });
  }

  UserProfile? get profile => _profile;
  bool get loaded => _loaded;
  bool get isAdmin => _profile?.isAdmin ?? false;
  bool get gamificationOn => _profile?.gamificationOn ?? true;

  Future<void> update(Map<String, dynamic> data) async {
    await repo?.updateProfile(data);
  }

  Future<void> saveInterests(Set<Experience> interests) =>
      update({'interests': interests.map((e) => e.name).toList()});

  Future<void> saveHabits(TravelHabits h) => update({'habits': h.toMap()});

  Future<void> savePlanning(PlanningPrefs p) => update({'planning': p.toMap()});

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
