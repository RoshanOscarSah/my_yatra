import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/providers/district_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/widgets/common.dart';
import '../recommendations/recommendation_provider.dart';
import 'preferences_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pp = context.watch<ProfileProvider>();
    final p = pp.profile!;
    final recs = context.watch<RecommendationProvider>();
    final dp = context.watch<DistrictProvider>();
    final fb = recs.feedback.entries.where((e) => e.value != 'helpful').toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Card(
          child: Column(children: [
            SwitchListTile(
              key: const Key('gamification-switch'),
              title: const Text('Badges & challenges'),
              subtitle: const Text('Show badges, challenges and their notices'),
              value: p.gamificationOn,
              onChanged: (v) => pp.update({'gamificationOn': v}),
            ),
            ListTile(
              title: const Text('Preferences'),
              subtitle: const Text('Interests, habits, budget, distance, season'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PreferencesScreen())),
            ),
          ]),
        ),
        const SectionTitle('Emergency contact'),
        InfoCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.emergencyContact == null
                ? 'No contact saved. Add one to send quick "I\'m safe" check-ins.'
                : '${p.emergencyContact!.name} · ${p.emergencyContact!.phone}'),
            const SizedBox(height: 4),
            const Text('MyYatra never tracks your location in the background.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _editContact(context, pp),
              child: Text(p.emergencyContact == null ? 'Add contact' : 'Edit contact'),
            ),
          ]),
        ),
        const SectionTitle('Hidden recommendations'),
        if (fb.isEmpty)
          const Text('You have not hidden or reported any district.',
              style: TextStyle(color: AppColors.textSecondary)),
        for (final e in fb)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(dp.byId(e.key)?.name ?? e.key),
            subtitle: Text(e.value == 'reported' ? 'Reported' : 'Not interested'),
            trailing: TextButton(onPressed: () => recs.undo(e.key), child: const Text('Undo')),
          ),
      ]),
    );
  }

  Future<void> _editContact(BuildContext context, ProfileProvider pp) async {
    final c = pp.profile!.emergencyContact;
    final name = TextEditingController(text: c?.name);
    final phone = TextEditingController(text: c?.phone);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emergency contact'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 8),
          TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    if (phone.text.trim().length < 7) {
      if (context.mounted) showSnack(context, 'Enter a valid phone number.');
      return;
    }
    await pp.update({
      'emergencyContact': {'name': name.text.trim(), 'phone': phone.text.trim()}
    });
  }
}
