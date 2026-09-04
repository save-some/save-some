import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:save_some_ui/config/env.dart';
import 'package:save_some_ui/forms/signin.dart';
import 'package:save_some_ui/screens/home.dart';
import 'package:save_some_ui/theme/app_theme.dart';

/// Whether Supabase auth is wired up for this run.
///
/// The app deliberately works without it: local UI development only needs the
/// FastAPI backend, and requiring Supabase credentials to render a single frame
/// made the whole app unbootable without secrets.
bool supabaseReady = false;

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
      supabaseReady = true;
    } catch (error) {
      debugPrint('save-some: Supabase.initialize failed ($error).');
    }
  } else {
    debugPrint(
      'save-some: SUPABASE_URL / SUPABASE_ANON_KEY not set — skipping auth and '
      'signing in as the development user ${Env.devUserId}. '
      'See .env.example to enable real authentication.',
    );
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

/// Routes to the app or the sign-in screen based on Supabase auth state.
///
/// When Supabase isn't configured there is no session to observe, so this goes
/// straight to the app as [Env.devUserId] — the profile that
/// backend/seed/local_seed.sql creates.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _authSubscription;
  String? _userId;

  @override
  void initState() {
    super.initState();

    if (!supabaseReady) {
      _userId = Env.devUserId;
      return;
    }

    final auth = Supabase.instance.client.auth;
    // Start from any existing session, e.g. a returning user.
    _userId = auth.currentSession?.user.id;

    // Previously this subscription was never cancelled, so the callback
    // outlived the State and called setState after dispose.
    _authSubscription = auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      setState(() => _userId = data.session?.user.id);
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = _userId;
    if (userId == null) return const SignInForm();
    return HomeScreen(userId: userId);
  }
}
