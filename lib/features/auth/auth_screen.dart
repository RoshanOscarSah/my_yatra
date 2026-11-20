import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/repositories/auth_repository.dart';
import '../../core/widgets/common.dart';
import 'forgot_password_screen.dart';
import 'privacy_policy_screen.dart';

/// Figma 02 Sign in / Create account (US-1.1, US-1.2).
class AuthScreen extends StatefulWidget {
  final bool startOnRegister;
  const AuthScreen({super.key, this.startOnRegister = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
      length: 2, vsync: this, initialIndex: widget.startOnRegister ? 1 : 0);

  final _signInKey = GlobalKey<FormState>();
  final _registerKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _regEmail = TextEditingController();
  final _regPassword = TextEditingController();

  bool _obscure = true;
  bool _regObscure = true;
  bool _policy = false;
  bool _policyHighlight = false;
  bool _signInTried = false;
  bool _registerTried = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in [_email, _password, _name, _regEmail, _regPassword]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
      if (e.code == 'email-already-in-use') {
        _email.text = _regEmail.text;
        _tabs.animateTo(0);
      }
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _signIn() {
    // After the first attempt, re-check each field as it is edited so a
    // fixed field loses its error straight away.
    setState(() => _signInTried = true);
    if (!_signInKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    _run(() => auth.signIn(_email.text, _password.text));
  }

  void _register() {
    setState(() => _registerTried = true);
    final valid = _registerKey.currentState!.validate();
    if (!_policy) {
      // US-1.1 / TC-02: block sign-up and highlight the policy link.
      setState(() => _policyHighlight = true);
      return;
    }
    if (!valid) return;
    final auth = context.read<AuthProvider>();
    _run(() => auth.register(_name.text, _regEmail.text, _regPassword.text));
  }

  // Google sign-in is turned off for now. To bring it back, uncomment this
  // method and the "or" divider and button at the end of build().
  // void _google() {
  //   final auth = context.read<AuthProvider>();
  //   _run(auth.signInWithGoogle);
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              Text('Welcome to MyYatra', style: AppTheme.serif(28)),
              const SizedBox(height: 6),
              const Text('Your travel story across Nepal, saved to your own account.',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.all(4),
                child: TabBar(
                  controller: _tabs,
                  onTap: (_) => setState(() => _error = null),
                  indicator: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter'),
                  tabs: const [Tab(text: 'Sign in'), Tab(text: 'Create account')],
                ),
              ),
              const SizedBox(height: 20),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InfoCard(
                    color: const Color(0xFFFDECEA),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: AppColors.danger),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, key: const Key('auth-error'))),
                    ]),
                  ),
                ),
              AnimatedBuilder(
                animation: _tabs,
                builder: (_, _) =>
                    _tabs.index == 0 ? _signInForm() : _registerForm(),
              ),
              // const SizedBox(height: 20),
              // const Row(children: [
              //   Expanded(child: Divider()),
              //   Padding(
              //     padding: EdgeInsets.symmetric(horizontal: 12),
              //     child: Text('or', style: TextStyle(color: AppColors.textSecondary)),
              //   ),
              //   Expanded(child: Divider()),
              // ]),
              // const SizedBox(height: 16),
              // OutlinedButton.icon(
              //   onPressed: _busy ? null : _google,
              //   icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
              //   label: const Text('Continue with Google'),
              // ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _signInForm() {
    return Form(
      key: _signInKey,
      autovalidateMode: _signInTried ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const Key('signin-email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email'),
            validator: (v) => AuthRepository.validateEmail(v ?? ''),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('signin-password'),
            controller: _password,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => _signIn(),
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Show password' : 'Hide password',
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) => (v ?? '').isEmpty ? 'Enter your password.' : null,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ForgotPasswordScreen(initialEmail: _email.text))),
              child: const Text('Forgot password?'),
            ),
          ),
          const Text('You stay signed in on this device until you sign out.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Sign in', loading: _busy, onPressed: _signIn),
        ],
      ),
    );
  }

  Widget _registerForm() {
    return Form(
      key: _registerKey,
      autovalidateMode: _registerTried ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const Key('register-name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Full name'),
            validator: (v) => (v ?? '').trim().length < 2 ? 'Enter your name.' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('register-email'),
            controller: _regEmail,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: (v) => AuthRepository.validateEmail(v ?? ''),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('register-password'),
            controller: _regPassword,
            obscureText: _regObscure,
            decoration: InputDecoration(
              labelText: 'Password',
              helperText: 'At least 8 characters with letters and a number',
              suffixIcon: IconButton(
                tooltip: _regObscure ? 'Show password' : 'Hide password',
                icon: Icon(_regObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _regObscure = !_regObscure),
              ),
            ),
            validator: (v) => AuthRepository.validatePassword(v ?? ''),
          ),
          const SizedBox(height: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _policyHighlight ? const Color(0xFFFDECEA) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _policyHighlight ? AppColors.danger : Colors.transparent),
            ),
            child: Row(
              children: [
                Checkbox(
                  key: const Key('policy-checkbox'),
                  value: _policy,
                  onChanged: (v) => setState(() {
                    _policy = v ?? false;
                    if (_policy) _policyHighlight = false;
                  }),
                ),
                Expanded(
                  child: Wrap(
                    children: [
                      const Text('I have read and accept the '),
                      InkWell(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const PrivacyPolicyScreen())),
                        child: Text(
                          'privacy policy',
                          style: TextStyle(
                            color: _policyHighlight ? AppColors.danger : AppColors.primary,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_policyHighlight)
            const Padding(
              padding: EdgeInsets.only(left: 12, top: 4),
              child: Text('Please accept the privacy policy to create an account.',
                  style: TextStyle(color: AppColors.danger, fontSize: 12)),
            ),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Create account', loading: _busy, onPressed: _register),
        ],
      ),
    );
  }
}
