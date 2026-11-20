import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app.dart';
import '../../app/theme.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/repositories/auth_repository.dart';
import '../../core/repositories/user_repository.dart';
import '../../core/widgets/common.dart';
import '../onboarding/preference_widgets.dart';

/// US-1.6: edit profile details or delete the account with all data.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final p = context.read<ProfileProvider>().profile!;
  late final _name = TextEditingController(text: p.name);
  late final _occupation = TextEditingController(text: p.occupation);
  late String? _age = p.ageRange;
  late final Set<String> _companions = p.habits.companions.toSet();
  bool _busy = false;

  static const ages = ['Under 18', '18–20', '21–25', '26–30', '31+'];

  @override
  void dispose() {
    _name.dispose();
    _occupation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2) {
      showSnack(context, 'Enter your name.');
      return;
    }
    setState(() => _busy = true);
    await context.read<ProfileProvider>().update({
      'name': _name.text.trim(),
      'ageRange': _age,
      'occupation': _occupation.text.trim(),
      // Companions feed the profile analysis, so DNA/recommendations refresh.
      'habits': p.habits.copyWith(companions: _companions.toList()).toMap(),
    });
    if (!mounted) return;
    showSnack(context, 'Profile saved.');
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final auth = context.read<AuthProvider>();
    final repo = context.read<UserRepository?>();
    final password = TextEditingController();
    final usesPassword = auth.repo.usesPassword;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account permanently?'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            'This permanently deletes your profile, visits, journal entries, photos, itineraries, '
            'reviews and Journey DNA. Reports you sent stay with the team without your name. It cannot be undone.',
          ),
          if (usesPassword) ...[
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Confirm with your password'),
            ),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      if (usesPassword) await auth.repo.reauthenticate(password.text);
      await repo?.deleteAllData();
      await auth.repo.deleteAuthUser();
      navigatorKey.currentState?.popUntil((r) => r.isFirst);
      messengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Your account and all its data were deleted.')));
    } on AuthException catch (e) {
      if (mounted) showSnack(context, e.message);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not delete the account: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: ages.contains(_age) ? _age : null,
          decoration: const InputDecoration(labelText: 'Age range'),
          items: [for (final a in ages) DropdownMenuItem(value: a, child: Text(a))],
          onChanged: (v) => setState(() => _age = v),
        ),
        const SizedBox(height: 12),
        TextField(controller: _occupation, decoration: const InputDecoration(labelText: 'Occupation')),
        const SizedBox(height: 16),
        const Text('Usual travel companions', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [
          for (final c in HabitsForm.companions.entries)
            FilterChip(
              label: Text(c.value),
              selected: _companions.contains(c.key),
              onSelected: (s) => setState(() => s ? _companions.add(c.key) : _companions.remove(c.key)),
            ),
        ]),
        const SizedBox(height: 8),
        Text('Email: ${p.email}', style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        PrimaryButton(label: 'Save', loading: _busy, onPressed: _save),
        const SizedBox(height: 40),
        const Divider(),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('delete-account'),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
          onPressed: _busy ? null : _delete,
          icon: const Icon(Icons.delete_forever_outlined),
          label: const Text('Delete account'),
        ),
      ]),
    );
  }
}
