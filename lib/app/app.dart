import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/providers/auth_provider.dart';
import '../core/providers/district_provider.dart';
import '../core/providers/itinerary_provider.dart';
import '../core/providers/journal_provider.dart';
import '../core/providers/profile_provider.dart';
import '../core/providers/visit_provider.dart';
import '../core/repositories/district_repository.dart';
import '../core/repositories/user_repository.dart';
import '../features/auth/policy_accept_screen.dart';
import '../features/auth/welcome_screen.dart';
import '../features/dna/dna_provider.dart';
import '../features/gamification/stats_provider.dart';
import '../features/home/home_shell.dart';
import '../features/onboarding/onboarding_flow.dart';
import '../features/recommendations/recommendation_provider.dart';
import 'env.dart';
import 'theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();

class MyYatraApp extends StatelessWidget {
  const MyYatraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyYatra',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      builder: (context, child) {
        final uid = context.watch<AuthProvider>().uid;
        return UserScope(
          key: ValueKey(uid),
          uid: uid,
          // Tapping outside a text field closes the keyboard. iOS has no
          // "done" key on multi-line fields, so without this the keyboard
          // can cover the Save button.
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: IdleTimeout(child: child ?? const SizedBox()),
          ),
        );
      },
      home: const AuthGate(),
    );
  }
}

/// Providers for the signed-in user. Rebuilt from scratch when the user
/// changes, so no data leaks between accounts on a shared device.
class UserScope extends StatelessWidget {
  final String? uid;
  final Widget child;
  const UserScope({super.key, required this.uid, required this.child});

  @override
  Widget build(BuildContext context) {
    final repo = uid == null ? null : UserRepository(uid!);
    return MultiProvider(
      providers: [
        Provider<UserRepository?>.value(value: repo),
        Provider<DistrictRepository>(create: (_) => DistrictRepository()),
        ChangeNotifierProvider(create: (_) => ProfileProvider(repo)),
        ChangeNotifierProvider(
            create: (_) => DistrictProvider(listen: uid != null)),
        ChangeNotifierProvider(create: (_) => VisitProvider(repo)),
        ChangeNotifierProvider(create: (_) => JournalProvider(repo)),
        ChangeNotifierProvider(create: (_) => ItineraryProvider(repo)),
        ChangeNotifierProxyProvider3<ProfileProvider, VisitProvider,
            DistrictProvider, DnaProvider>(
          create: (_) => DnaProvider(repo),
          update: (_, p, v, d, dna) => dna!..update(p, v, d),
        ),
        ChangeNotifierProxyProvider4<DistrictProvider, VisitProvider,
            ProfileProvider, DnaProvider, RecommendationProvider>(
          create: (_) => RecommendationProvider(repo),
          update: (_, d, v, p, dna, r) => r!..update(d, v, p, dna),
        ),
        ChangeNotifierProxyProvider3<DistrictProvider, VisitProvider,
            JournalProvider, StatsProvider>(
          create: (_) => StatsProvider(),
          update: (_, d, v, j, s) => s!..update(d, v, j),
        ),
      ],
      child: child,
    );
  }
}

/// Signs the user out after [Env.idleTimeout] without interaction (US-1.4).
class IdleTimeout extends StatefulWidget {
  final Widget child;
  const IdleTimeout({super.key, required this.child});

  @override
  State<IdleTimeout> createState() => _IdleTimeoutState();
}

class _IdleTimeoutState extends State<IdleTimeout> {
  Timer? _timer;

  void _reset() {
    _timer?.cancel();
    final auth = context.read<AuthProvider>();
    if (!auth.signedIn) return;
    _timer = Timer(Env.idleTimeout, () async {
      if (!auth.signedIn) return;
      await signOutEverywhere(auth);
      messengerKey.currentState?.showSnackBar(SnackBar(
          content: Text('Signed out after ${Env.idleTimeout.inMinutes} '
              'minutes without activity.')));
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reset());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _reset(),
      child: widget.child,
    );
  }
}

/// Sign out and drop every pushed route, so Back cannot reopen protected
/// pages (US-1.4).
Future<void> signOutEverywhere(AuthProvider auth) async {
  navigatorKey.currentState?.popUntil((r) => r.isFirst);
  await auth.signOut();
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.ready) return const _Splash();
    if (!auth.signedIn) return const WelcomeScreen();
    final profile = context.watch<ProfileProvider>();
    if (!profile.loaded) return const _Splash();
    final p = profile.profile;
    if (p == null) return const PolicyAcceptScreen();
    if (!p.onboardingComplete) return const OnboardingFlow();
    return const HomeShell();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('MyYatra', style: AppTheme.serif(32, color: AppColors.primary)),
          const SizedBox(height: 16),
          const CircularProgressIndicator(),
        ]),
      ),
    );
  }
}
