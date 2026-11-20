import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/connectivity_provider.dart';
import '../../core/providers/journal_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/offline_banner.dart';
import '../districts/explore_screen.dart';
import '../gamification/stats_provider.dart';
import '../journal/journal_screen.dart';
import '../profile/profile_screen.dart';
import '../recommendations/for_you_screen.dart';
import 'home_screen.dart';

/// Five tabs as in Figma: Home · Explore · For you · Journal · Profile.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  static void goToTab(BuildContext context, int index) =>
      context.findAncestorStateOfType<_HomeShellState>()?.select(index);

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  StreamSubscription<void>? _reconnect;
  StatsProvider? _stats;

  void select(int i) => setState(() => _index = i);

  @override
  void initState() {
    super.initState();
    final conn = context.read<ConnectivityProvider>();
    final journal = context.read<JournalProvider>();
    _reconnect = conn.onReconnect.listen((_) async {
      final n = await journal.flushQueue();
      if (n > 0 && mounted) showSnack(context, 'Back online: $n journal photo(s) uploaded.');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (conn.online) journal.flushQueue();
      _stats = context.read<StatsProvider>()..addListener(_onStats);
    });
  }

  /// Badge notice (US-9.1), hidden when gamification is off (US-9.3).
  void _onStats() {
    final s = _stats;
    if (s == null || !mounted) return;
    final newly = s.takeNewlyUnlocked();
    if (newly.isEmpty || !context.read<ProfileProvider>().gamificationOn) return;
    showSnack(context, '🏅 Badge earned: ${newly.map((b) => b.title).join(', ')}');
  }

  @override
  void dispose() {
    _reconnect?.cancel();
    _stats?.removeListener(_onStats);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const pages = [
      HomeScreen(),
      ExploreScreen(),
      ForYouScreen(),
      JournalScreen(),
      ProfileScreen(),
    ];
    return Scaffold(
      body: Column(children: [
        const OfflineBanner(),
        Expanded(child: IndexedStack(index: _index, children: pages)),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: select,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore_rounded), label: 'Explore'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'For you'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book_rounded), label: 'Journal'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}
