import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../repositories/user_repository.dart';

class PickedPhoto {
  final Uint8List bytes;
  final String ext;
  const PickedPhoto(this.bytes, this.ext);
}

/// Streams users/{uid}/journal (US-7.1 to US-7.3). Text is synced by
/// Firestore's offline queue; photos picked offline wait in a small local
/// upload queue and are uploaded on reconnect (US-11.2).
class JournalProvider extends ChangeNotifier {
  final UserRepository? repo;
  StreamSubscription<List<JournalEntry>>? _sub;
  List<JournalEntry> _entries = [];
  bool _loaded = false;
  int _queued = 0;

  JournalProvider(this.repo) {
    final r = repo;
    if (r == null) {
      _loaded = true;
      return;
    }
    _sub = r.journal().listen((list) {
      _entries = list;
      _loaded = true;
      notifyListeners();
    });
    _countQueue();
  }

  bool get loaded => _loaded;
  List<JournalEntry> get entries => _entries;
  int get queuedPhotos => _queued;
  JournalEntry? byId(String id) => _entries.where((e) => e.id == id).firstOrNull;
  List<JournalEntry> forDistrict(String id) =>
      _entries.where((e) => e.districtId == id).toList();

  String newId() => repo?.newJournalId() ?? DateTime.now().millisecondsSinceEpoch.toString();

  String get _queueKey => 'photoQueue:${repo?.uid}';

  Future<void> _countQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _queued = (prefs.getStringList(_queueKey) ?? []).length;
      notifyListeners();
    } catch (_) {}
  }

  /// Saves an entry. New photos are uploaded now when online, otherwise
  /// queued and the entry is marked as a draft until they are uploaded.
  Future<void> save(
    JournalEntry entry, {
    List<PickedPhoto> newPhotos = const [],
    List<String> removedPaths = const [],
    required bool online,
  }) async {
    final r = repo;
    if (r == null) return;
    for (final p in removedPaths) {
      await r.deletePhoto(p);
    }
    final urls = [...entry.photoUrls];
    final paths = [...entry.photoPaths];
    final queued = <PickedPhoto>[];
    for (final p in newPhotos) {
      if (!online) {
        queued.add(p);
        continue;
      }
      try {
        final (url, path) = await r.uploadPhoto(entry.id, p.bytes, p.ext);
        urls.add(url);
        paths.add(path);
      } catch (_) {
        queued.add(p);
      }
    }
    final saved = JournalEntry(
      id: entry.id,
      districtId: entry.districtId,
      startDate: entry.startDate,
      endDate: entry.endDate,
      activities: entry.activities,
      story: entry.story,
      photoUrls: urls,
      photoPaths: paths,
      draft: queued.isNotEmpty,
    );
    await r.saveJournal(saved);
    if (queued.isNotEmpty) await _enqueue(entry.id, queued);
  }

  Future<void> _enqueue(String entryId, List<PickedPhoto> photos) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_queueKey) ?? [];
    for (final p in photos) {
      list.add(jsonEncode(
          {'entryId': entryId, 'ext': p.ext, 'data': base64Encode(p.bytes)}));
    }
    await prefs.setStringList(_queueKey, list);
    _queued = list.length;
    notifyListeners();
  }

  /// Uploads queued photos (called when the connection returns).
  Future<int> flushQueue() async {
    final r = repo;
    if (r == null) return 0;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_queueKey) ?? [];
    if (list.isEmpty) return 0;
    final remaining = <String>[];
    var uploaded = 0;
    for (final raw in list) {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final entry = byId(m['entryId'] as String);
      if (entry == null) continue;
      try {
        final (url, path) = await r.uploadPhoto(
            entry.id, base64Decode(m['data'] as String), m['ext'] as String);
        final updated = JournalEntry(
          id: entry.id,
          districtId: entry.districtId,
          startDate: entry.startDate,
          endDate: entry.endDate,
          activities: entry.activities,
          story: entry.story,
          photoUrls: [...entry.photoUrls, url],
          photoPaths: [...entry.photoPaths, path],
          draft: false,
        );
        _entries = [for (final e in _entries) e.id == entry.id ? updated : e];
        await r.saveJournal(updated);
        uploaded++;
      } catch (_) {
        remaining.add(raw);
      }
    }
    await prefs.setStringList(_queueKey, remaining);
    _queued = remaining.length;
    notifyListeners();
    return uploaded;
  }

  Future<void> delete(JournalEntry e) async {
    _entries = _entries.where((x) => x.id != e.id).toList();
    notifyListeners();
    await repo?.deleteJournal(e);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
