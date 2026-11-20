import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app.dart';
import '../../app/theme.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/widgets/common.dart';
import 'privacy_policy_screen.dart';

/// Shown to users who signed in with Google and have no profile yet, so the
/// privacy policy is still accepted before any data is stored (US-1.1).
class PolicyAcceptScreen extends StatefulWidget {
  const PolicyAcceptScreen({super.key});

  @override
  State<PolicyAcceptScreen> createState() => _PolicyAcceptScreenState();
}

class _PolicyAcceptScreenState extends State<PolicyAcceptScreen> {
  bool _accepted = false;
  bool _highlight = false;
  bool _busy = false;

  Future<void> _continue() async {
    if (!_accepted) {
      setState(() => _highlight = true);
      return;
    }
    setState(() => _busy = true);
    final auth = context.read<AuthProvider>();
    final u = auth.user!;
    await auth.repo.createProfile(
        u.uid, u.displayName ?? u.email?.split('@').first ?? 'Traveller', u.email ?? '');
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(padding: const EdgeInsets.all(24), children: [
              Text('One last step', style: AppTheme.serif(28)),
              const SizedBox(height: 8),
              const Text('Please read and accept how MyYatra handles your data.',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              for (final s in PrivacyPolicyScreen.sections.take(4)) ...[
                Text(s.$1, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(s.$2, style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 12),
              ],
              CheckboxListTile(
                value: _accepted,
                onChanged: (v) => setState(() {
                  _accepted = v ?? false;
                  _highlight = false;
                }),
                controlAffinity: ListTileControlAffinity.leading,
                tileColor: _highlight ? const Color(0xFFFDECEA) : null,
                title: const Text('I accept the privacy policy'),
              ),
              const SizedBox(height: 16),
              PrimaryButton(label: 'Continue', loading: _busy, onPressed: _continue),
              TextButton(
                onPressed: () => signOutEverywhere(context.read<AuthProvider>()),
                child: const Text('Cancel and sign out'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
