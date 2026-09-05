import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:save_some_ui/state/session.dart';
import 'package:save_some_ui/theme/tokens.dart';
import 'package:save_some_ui/widgets/brand/blob_backdrop.dart';
import 'package:save_some_ui/widgets/brand/wordmark.dart';
import 'package:save_some_ui/widgets/common/app_text_field.dart';
import 'package:save_some_ui/widgets/common/primary_button.dart';

class SignUpForm extends StatefulWidget {
  const SignUpForm({super.key});

  @override
  State<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  // Previously all three fields had `controller: null`, so the form collected
  // nothing and could not submit.
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _attempted = false;
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String get _email => _emailController.text.trim();
  String get _password => _passwordController.text;
  String get _confirm => _confirmController.text;

  String? get _emailError {
    if (!_attempted) return null;
    if (_email.isEmpty) return 'Enter your email';
    // Deliberately permissive: the server is the real authority on
    // deliverability, so this only catches obvious typos.
    if (!_email.contains('@') || !_email.contains('.')) {
      return 'That doesn\'t look like an email address';
    }
    return null;
  }

  String? get _passwordError {
    if (!_attempted) return null;
    if (_password.isEmpty) return 'Choose a password';
    // Supabase's own default minimum.
    if (_password.length < 6) return 'Use at least 6 characters';
    return null;
  }

  String? get _confirmError {
    if (!_attempted || _confirm.isEmpty && _password.isEmpty) return null;
    if (_confirm != _password) return 'Passwords don\'t match';
    return null;
  }

  bool get _isValid =>
      _emailError == null &&
      _passwordError == null &&
      _confirmError == null &&
      _email.isNotEmpty &&
      _password.isNotEmpty &&
      _confirm == _password;

  Future<void> _submit() async {
    setState(() => _attempted = true);
    if (!_isValid) return;

    if (!AppSession.instance.supabaseReady) {
      _notify('Sign-up needs SUPABASE_URL and SUPABASE_ANON_KEY in .env.');
      return;
    }

    setState(() => _busy = true);
    try {
      final response = await Supabase.instance.client.auth
          .signUp(email: _email, password: _password);

      if (!mounted) return;
      if (response.session != null) {
        // Email confirmation is off, so we're signed in already — AuthGate
        // takes over from here.
        Navigator.of(context).pop();
      } else {
        _notify('Check your email to confirm your account.');
        Navigator.of(context).pop();
      }
    } on AuthException catch (error) {
      _notify(error.message);
    } catch (error) {
      _notify('Something went wrong: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: BlobBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xl,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.xl),
                    // Casing used to differ from sign-in ('Save\nSome' here,
                    // 'SAVE\nSOME' there); the shared wordmark settles it.
                    const SaveSomeWordmark(),
                    const SizedBox(height: AppSpacing.xl),
                    Text('Sign Up', style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      controller: _emailController,
                      hint: 'email',
                      icon: Icons.person_outline,
                      keyboardType: TextInputType.emailAddress,
                      isIdentifier: true,
                      textInputAction: TextInputAction.next,
                      errorText: _emailError,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _passwordController,
                      hint: 'enter password',
                      icon: Icons.lock_outline,
                      // Passwords were previously rendered in clear text.
                      obscureText: true,
                      isIdentifier: true,
                      textInputAction: TextInputAction.next,
                      errorText: _passwordError,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _confirmController,
                      hint: 'confirm password',
                      icon: Icons.lock_outline,
                      obscureText: true,
                      isIdentifier: true,
                      textInputAction: TextInputAction.done,
                      errorText: _confirmError,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    PrimaryButton(
                      label: 'Sign Up',
                      busy: _busy,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextButton(
                      onPressed:
                          _busy ? null : () => Navigator.of(context).pop(),
                      child: const Text('Back to log in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
