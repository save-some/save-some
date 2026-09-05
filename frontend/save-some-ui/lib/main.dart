import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:save_some_ui/config/env.dart';
import 'package:save_some_ui/forms/signin.dart';
import 'package:save_some_ui/screens/home.dart';
import 'package:save_some_ui/state/session.dart';
import 'package:save_some_ui/theme/app_theme.dart';

/// Drives light/dark. The account screen's "Color Scheme" row writes to this.
///
/// Defaults to light rather than system: the design specifies a light scheme
/// only, and following the OS preference meant the app looked nothing like it on
/// any device set to dark. Users can still pick either, or match their device.
final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env is declared as a bundled asset, but may legitimately be empty.
  try {
    await dotenv.load(fileName: '.env');
  } catch (error) {
    debugPrint('save-some: no .env bundled ($error) — continuing without it.');
  }

  final url = dotenv.maybeGet('SUPABASE_URL') ?? '';
  final anonKey = dotenv.maybeGet('SUPABASE_ANON_KEY') ?? '';

  if (url.isNotEmpty && anonKey.isNotEmpty) {
    try {
      await Supabase.initialize(url: url, anonKey: anonKey);
      AppSession.instance.bindSupabase();
    } catch (error) {
      debugPrint('save-some: Supabase.initialize failed ($error).');
    }
  }

  if (!AppSession.instance.supabaseReady) {
    debugPrint(
      'save-some: SUPABASE_URL / SUPABASE_ANON_KEY not set — skipping auth and '
      'signing in as the development user ${Env.devUserId}. '
      'See .env.example to enable real authentication.',
    );
    AppSession.instance.signInAsDevUser();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Save Some',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: const AuthGate(),
        );
      },
    );
  }
}

/// Shows the app or the sign-in screen, following [Session].
///
/// Deliberately thin: all the auth state lives in Session so that signing out
/// works identically whether Supabase is configured or the app is running as the
/// local development user.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSession.instance,
      builder: (context, _) {
        final userId = AppSession.instance.userId;
        if (userId == null) return const SignInForm();
        // Keyed by user so switching accounts rebuilds the tree rather than
        // leaving one user's fetched data on screen.
        return HomeScreen(key: ValueKey(userId), userId: userId);
      },
    );
  }
}
