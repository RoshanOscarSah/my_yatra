import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../providers/connectivity_provider.dart';

/// Offline banner listing what still works (US-11.2).
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final online = context.watch<ConnectivityProvider>().online;
    if (online) return const SizedBox.shrink();
    return Material(
      color: AppColors.goldSoft,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: const [
            Icon(Icons.cloud_off_rounded, size: 18, color: AppColors.warning),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'You are offline. Saved districts, itineraries, safety tips and '
                'emergency numbers still work. Journal text will sync later.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Use for online-only features (AI recommendations, the map).
class NeedsInternet extends StatelessWidget {
  final String feature;
  final Widget child;
  const NeedsInternet({super.key, required this.feature, required this.child});

  @override
  Widget build(BuildContext context) {
    final online = context.watch<ConnectivityProvider>().online;
    if (online) return child;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.textSecondary),
          const SizedBox(height: 8),
          Text('$feature needs an internet connection.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Open Profile → Downloads to see what you saved for offline use.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary)),
        ]),
      ),
    );
  }
}
