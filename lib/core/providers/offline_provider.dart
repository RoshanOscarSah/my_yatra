import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineItem {
  final String key; // district:<id> / itinerary:<id>
  final String kind; // district / itinerary
  final String title;
  final DateTime savedAt;
  final Map<String, dynamic> data;
  final int bytes;

  const OfflineItem({
    required this.key,
    required this.kind,
    required this.title,
    required this.savedAt,
    required this.data,
    required this.bytes,
  });
}

/// "Save for offline" store (US-11.1). Content is written on the device and
/// its size is reported so travellers decide what to keep.
class OfflineProvider extends ChangeNotifier {
  static const _prefix = 'offline:';
  final Map<String, OfflineItem> _items = {};
  bool _loaded = false;

  OfflineProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final k in prefs.getKeys().where((k) => k.startsWith(_prefix))) {
        final raw = prefs.getString(k);
        if (raw == null) continue;
        final m = jsonDecode(raw) as Map<String, dynamic>;
        final key = k.substring(_prefix.length);
        _items[key] = OfflineItem(
          key: key,
          kind: m['kind'] as String,
          title: m['title'] as String,
          savedAt: DateTime.parse(m['savedAt'] as String),
          data: (m['data'] as Map).cast<String, dynamic>(),
          bytes: utf8.encode(raw).length,
        );
      }
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  bool get loaded => _loaded;
  List<OfflineItem> get items =>
      _items.values.toList()..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  int get totalBytes => _items.values.fold(0, (s, i) => s + i.bytes);
  bool isSaved(String key) => _items.containsKey(key);
  OfflineItem? get(String key) => _items[key];

  Future<void> save(String key, String kind, String title,
      Map<String, dynamic> data) async {
    final now = DateTime.now();
    final raw = jsonEncode({
      'kind': kind,
      'title': title,
      'savedAt': now.toIso8601String(),
      'data': data,
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$key', raw);
    _items[key] = OfflineItem(
      key: key,
      kind: kind,
      title: title,
      savedAt: now,
      data: data,
      bytes: utf8.encode(raw).length,
    );
    notifyListeners();
  }

  Future<void> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$key');
    _items.remove(key);
    notifyListeners();
  }

  static String formatBytes(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / 1024 / 1024).toStringAsFixed(2)} MB';
  }
}
