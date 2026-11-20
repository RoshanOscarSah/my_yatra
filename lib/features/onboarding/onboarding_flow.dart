import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app.dart';
import '../../app/theme.dart';
import '../../core/models/models.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/visit_provider.dart';
import '../../core/widgets/common.dart';
import 'preference_widgets.dart';

/// Interests (01/04) → Habits (02/04) → Planning (03/04) → Visited districts (04/04).
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});
  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  int _step = 0;
  bool _showErrors = false;
  bool _busy = false;
  Set<Experience> _interests = {};
  TravelHabits _habits = const TravelHabits();
  PlanningPrefs _planning = const PlanningPrefs();
  Set<String> _visited = {};
  bool _initialised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    final p = context.read<ProfileProvider>().profile;
    if (p != null) {
      _interests = p.interests.toSet();
      _habits = p.habits;
      _planning = p.planning;
    }
    _initialised = true;
  }

  Future<void> _next() async {
    final profile = context.read<ProfileProvider>();
    if (_step == 0) {
      if (_interests.isEmpty) {
        showSnack(context, 'Please choose at least one kind of place you enjoy.');
        return;
      }
      await profile.saveInterests(_interests);
    } else if (_step == 1) {
      if (!_habits.isComplete) {
        // The missing answer may be below the fold, so say so as well.
        setState(() => _showErrors = true);
        showSnack(context, 'Please answer every question. Scroll down to see what is missing.');
        return;
      }
      await profile.saveHabits(_habits);
    } else if (_step == 2) {
      if (!_planning.isComplete) {
        // The missing answer may be below the fold, so say so as well.
        setState(() => _showErrors = true);
        showSnack(context, 'Please answer every question. Scroll down to see what is missing.');
        return;
      }
      await profile.savePlanning(_planning);
    } else {
      await _finish();
      return;
    }
    setState(() {
      _step++;
      _showErrors = false;
    });
  }

  Future<void> _finish({bool skipVisits = false}) async {
    setState(() => _busy = true);
    if (!skipVisits) {
      await context.read<VisitProvider>().addVisits(_visited);
    }
    if (!mounted) return;
    await context.read<ProfileProvider>().update({'onboardingComplete': true});
    if (mounted) setState(() => _busy = false);
  }

  void _skip() {
    // Interests are required for Journey DNA, so Skip is offered from
    // step 02 onwards; skipped answers can be filled in later in Preferences.
    if (_step == 3) {
      _finish(skipVisits: true);
    } else {
      setState(() => _step++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      'What kind of places do you enjoy?',
      'How do you like to travel?',
      'Plan your trips',
      'Where have you been already?',
    ];
    final subtitles = [
      'Pick as many as you like. This starts your Journey DNA.',
      'This helps suggestions match how you actually travel.',
      'These become your default recommendation filters.',
      'Tick the districts you have visited. You can skip this and add visits later.',
    ];
    final stepLabel = '0${_step + 1}/04';

    Widget body = switch (_step) {
      0 => InterestsPicker(value: _interests, onChanged: (v) => setState(() => _interests = v)),
      1 => HabitsForm(value: _habits, showErrors: _showErrors, onChanged: (v) => setState(() => _habits = v)),
      2 => PlanningForm(value: _planning, showErrors: _showErrors, onChanged: (v) => setState(() => _planning = v)),
      _ => VisitedDistrictPicker(value: _visited, onChanged: (v) => setState(() => _visited = v)),
    };

    return Scaffold(
      appBar: AppBar(
        leading: _step > 0
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _step--))
            : IconButton(
                tooltip: 'Sign out',
                icon: const Icon(Icons.logout),
                onPressed: () => signOutEverywhere(context.read<AuthProvider>())),
        title: Text('Step $stepLabel', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        actions: [
          if (_step > 0)
            TextButton(onPressed: _busy ? null : _skip, child: const Text('Skip')),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(children: [
            LinearProgressIndicator(
              value: (_step + 1) / 4,
              color: AppColors.primary,
              backgroundColor: AppColors.primarySoft,
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.all(20), children: [
                Text(titles[_step], style: AppTheme.serif(26)),
                const SizedBox(height: 6),
                Text(subtitles[_step], style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                body,
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: PrimaryButton(
                key: const Key('onboarding-continue'),
                label: _step == 3 ? 'Finish setup' : 'Continue',
                loading: _busy,
                onPressed: _next,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
