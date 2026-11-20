import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/models.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/widgets/common.dart';
import '../onboarding/preference_widgets.dart';

/// US-2.5: edit interests and travel settings, reusing the onboarding widgets.
/// Nothing is saved until "Save"; leaving keeps the previous values.
class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});
  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  late final p = context.read<ProfileProvider>().profile!;
  late Set<Experience> _interests = p.interests.toSet();
  late TravelHabits _habits = p.habits;
  late PlanningPrefs _planning = p.planning;
  bool _busy = false;

  Future<void> _save() async {
    if (_interests.isEmpty) {
      showSnack(context, 'Choose at least one interest.');
      return;
    }
    setState(() => _busy = true);
    await context.read<ProfileProvider>().update({
      'interests': _interests.map((e) => e.name).toList(),
      'habits': _habits.toMap(),
      'planning': _planning.toMap(),
    });
    if (!mounted) return;
    showSnack(context, 'Preferences saved. Journey DNA and recommendations were recalculated.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preferences')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const SectionTitle('Interests'),
        InterestsPicker(value: _interests, onChanged: (v) => setState(() => _interests = v)),
        const SectionTitle('Travel habits'),
        HabitsForm(value: _habits, onChanged: (v) => setState(() => _habits = v)),
        const SectionTitle('Planning'),
        PlanningForm(value: _planning, onChanged: (v) => setState(() => _planning = v)),
        const SizedBox(height: 24),
        PrimaryButton(label: 'Save preferences', loading: _busy, onPressed: _save),
      ]),
    );
  }
}
