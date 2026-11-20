import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../repositories/user_repository.dart';

/// users/{uid}/itineraries (US-10.1).
class ItineraryProvider extends ChangeNotifier {
  final UserRepository? repo;
  StreamSubscription<List<Itinerary>>? _sub;
  List<Itinerary> _items = [];

  ItineraryProvider(this.repo) {
    _sub = repo?.itineraries().listen((l) {
      _items = l;
      notifyListeners();
    });
  }

  List<Itinerary> get items => _items;
  Itinerary? byId(String id) => _items.where((i) => i.id == id).firstOrNull;
  String newId() => repo?.newItineraryId() ?? DateTime.now().millisecondsSinceEpoch.toString();

  Future<void> save(Itinerary i) async {
    _items = [..._items.where((x) => x.id != i.id), i]
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    notifyListeners();
    await repo?.saveItinerary(i);
  }

  Future<void> delete(String id) async {
    _items = _items.where((x) => x.id != id).toList();
    notifyListeners();
    await repo?.deleteItinerary(id);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
