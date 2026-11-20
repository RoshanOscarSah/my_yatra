import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Online / offline state for the offline banner (US-11.2).
class ConnectivityProvider extends ChangeNotifier {
  final Connectivity _c = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _online = true;
  final _reconnect = StreamController<void>.broadcast();

  ConnectivityProvider() {
    _c.checkConnectivity().then(_set).catchError((_) {});
    _sub = _c.onConnectivityChanged.listen(_set, onError: (_) {});
  }

  void _set(List<ConnectivityResult> r) {
    final online = r.any((x) => x != ConnectivityResult.none);
    if (online == _online) return;
    _online = online;
    if (online) _reconnect.add(null);
    notifyListeners();
  }

  bool get online => _online;

  /// Fires each time the device comes back online.
  Stream<void> get onReconnect => _reconnect.stream;

  @override
  void dispose() {
    _sub?.cancel();
    _reconnect.close();
    super.dispose();
  }
}
