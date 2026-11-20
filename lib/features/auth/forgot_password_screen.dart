import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/repositories/auth_repository.dart';
import '../../core/widgets/common.dart';

/// US-1.3. Firebase emails a single-use reset link that expires, which meets
/// the "one-time, expiring" acceptance criteria (design decision).
class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: widget.initialEmail);
  final _key = GlobalKey<FormState>();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  Future<void> _send() async {
    if (!_key.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().sendPasswordReset(_email.text);
      setState(() => _sent = true);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _sent
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.mark_email_read_outlined, size: 48, color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text('Check your email', style: AppTheme.serif(24)),
                    const SizedBox(height: 8),
                    Text(
                      'If ${_email.text.trim()} is registered, we have sent a reset link. '
                      'The link works once and expires after a short time. '
                      'Open it to choose a new password, then sign in.',
                      style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(label: 'Back to sign in', onPressed: () => Navigator.pop(context)),
                  ])
                : Form(
                    key: _key,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text('Forgot your password?', style: AppTheme.serif(24)),
                      const SizedBox(height: 8),
                      const Text('Enter the email you registered with and we will send you a single-use reset link.',
                          style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (v) => AuthRepository.validateEmail(v ?? ''),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: AppColors.danger)),
                      ],
                      const SizedBox(height: 20),
                      PrimaryButton(label: 'Send reset link', loading: _busy, onPressed: _send),
                    ]),
                  ),
          ),
        ),
      ),
    );
  }
}
