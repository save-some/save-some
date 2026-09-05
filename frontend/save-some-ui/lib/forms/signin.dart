import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:save_some_ui/forms/signup.dart';
import 'package:save_some_ui/state/session.dart';
import 'package:save_some_ui/theme/tokens.dart';
import 'package:save_some_ui/widgets/brand/blob_backdrop.dart';
import 'package:save_some_ui/widgets/brand/wordmark.dart';
import 'package:save_some_ui/widgets/common/app_text_field.dart';
import 'package:save_some_ui/widgets/common/primary_button.dart';
import 'package:save_some_ui/widgets/common/svg_asset.dart';

class SignInForm extends StatefulWidget {
  const SignInForm({super.key});

  @override
  State<SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<SignInForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _attempted = false; // only surface validation after a submit attempt
  bool _busy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _email => _emailController.text.trim();
  String get _password => _passwordController.text;

  /// The design labels this field "username", but authentication here is
  /// email-based (magic link or password), so a username would have nowhere to
  /// go. Labelled honestly instead.
  String? get _emailError {
    if (!_attempted || _email.isNotEmpty) return null;
    return 'Enter your email to continue';
  }

  /// Every auth path reports failures the same way; this replaces three
  /// identical `on AuthException catch` blocks.
  Future<void> _run(Future<void> Function() action) async {
    if (!AppSession.instance.supabaseReady) {
      _notify('Sign-in needs SUPABASE_URL and SUPABASE_ANON_KEY in .env.');
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
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

  Future<void> _signInWithPassword() async {
    setState(() => _attempted = true);
    if (_email.isEmpty || _password.isEmpty) return;
    await _run(() async {
      await Supabase.instance.client.auth
          .signInWithPassword(email: _email, password: _password);
      // AuthGate observes the session change and swaps in the app.
    });
  }

  Future<void> _sendMagicLink() async {
    setState(() => _attempted = true);
    if (_email.isEmpty) return;
    await _run(() async {
      await Supabase.instance.client.auth.signInWithOtp(
        email: _email,
        // TODO: register this scheme in ios/Runner/Info.plist and
        // AndroidManifest.xml before shipping — OAuth and magic links can't
        // round-trip back into the app until it exists.
        emailRedirectTo: 'com.yourapp://login-callback',
      );
      _notify('Check your email for a magic link.');
    });
  }

  Future<void> _signInWithProvider(OAuthProvider provider) {
    return _run(() async {
      await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: 'com.yourapp://login-callback',
      );
    });
  }

  /// Enter the app without an account. With Supabase configured this creates an
  /// anonymous session; without it, the seeded development user is used, which
  /// is what makes the app runnable against just the local backend.
  Future<void> _continueWithoutAccount() async {
    // No credentials configured: enter as the seeded development profile.
    // AuthGate watches Session, so it swaps the screen — this used to push a
    // route by hand, which left sign-in underneath it.
    if (!AppSession.instance.supabaseReady) {
      AppSession.instance.signInAsDevUser();
      return;
    }
    await _run(() async {
      final response =
          await Supabase.instance.client.auth.signInAnonymously();
      if (response.user == null) {
        throw Exception('Anonymous sign-in returned no user');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: BlobBackdrop(
        child: SafeArea(
          // Without this the column overflowed on most phone heights, and always
          // once the keyboard appeared.
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xl,
            ),
            child: Center(
              // Keeps the form a readable width on desktop and web, replacing a
              // hand-rolled `width > 500 ? width / 2 : width` breakpoint.
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.xl),
                    const SaveSomeWordmark(),
                    const SizedBox(height: AppSpacing.xl),
                    Text('Log In', style: theme.textTheme.titleMedium),
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
                      hint: 'password',
                      icon: Icons.lock_outline,
                      obscureText: true,
                      isIdentifier: true,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _signInWithPassword(),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    PrimaryButton(
                      label: 'Log In',
                      busy: _busy,
                      onPressed: _signInWithPassword,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: _busy ? null : _sendMagicLink,
                      child: const Text('Email me a magic link instead'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const SignUpForm(),
                                ),
                              ),
                      child: const Text('Or Sign Up'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // The design's log-in frame doesn't show provider sign-in, so
                    // these sit below the primary path rather than competing
                    // with it — but the app already supports Google and GitHub,
                    // so they stay available.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: AppSpacing.md,
                      children: [
                        _ProviderButton(
                          asset: 'assets/google-logo.svg',
                          tooltip: 'Continue with Google',
                          onPressed: _busy
                              ? null
                              : () => _signInWithProvider(OAuthProvider.google),
                        ),
                        _ProviderButton(
                          asset: 'assets/github-logo.svg',
                          tooltip: 'Continue with GitHub',
                          onPressed: _busy
                              ? null
                              : () => _signInWithProvider(OAuthProvider.github),
                        ),
                        // Not wired up on the backend yet, so shown disabled
                        // rather than as buttons that silently do nothing.
                        const _ProviderButton(
                          asset: 'assets/microsoft-logo.svg',
                          tooltip: 'Microsoft — not configured yet',
                          onPressed: null,
                        ),
                        const _ProviderButton(
                          asset: 'assets/apple-173-logo.svg',
                          tooltip: 'Apple — not configured yet',
                          onPressed: null,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    TextButton(
                      onPressed: _busy ? null : _continueWithoutAccount,
                      child: const Text('Continue without an account'),
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

/// A circular provider button holding a brand SVG.
///
/// Replaces `ElevatedButton(style: ButtonStyle(), ...)` — an empty ButtonStyle,
/// which meant Material's default purple tonal fill behind each brand mark.
class _ProviderButton extends StatelessWidget {
  final String asset;
  final String tooltip;
  final VoidCallback? onPressed;

  const _ProviderButton({
    required this.asset,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: onPressed == null ? 0.4 : 1,
        child: Material(
          color: scheme.surface,
          shape: CircleBorder(side: BorderSide(color: scheme.outlineVariant)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: AppSvg(asset, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}
