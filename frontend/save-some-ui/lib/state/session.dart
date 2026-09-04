import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:save_some_ui/config/env.dart';

/// Who is signed in, for the whole app.
///
/// Named AppSession rather than Session because gotrue exports its own
/// Session type via supabase_flutter, and prefixing here beats hiding that
/// import in every consumer.
///
/// One notifier covers both modes, which is the point. Sign-out used to be
/// unreachable in practice: with Supabase unconfigured there was no session to
/// clear, so the account screen could only show a SnackBar and the user stayed
/// logged in. Now every path — Supabase sign-in, anonymous sign-in, the
/// development user, sign-out — goes through here, and AuthGate just listens.
class AppSession extends ChangeNotifier {
  AppSession._();

  static final AppSession instance = AppSession._();

  String? _userId;
  StreamSubscription<AuthState>? _authSubscription;

  /// Null means signed out, and the app shows the sign-in screen.
  String? get userId => _userId;

  bool get isSignedIn => _userId != null;

  /// True when this session is the local development user rather than a real
  /// account, so screens can be honest about what sign-out will do.
  bool get isDevUser => _userId != null && !supabaseReady;

  /// Whether Supabase auth is wired up for this run. The app deliberately works
  /// without it: local UI development only needs the FastAPI backend, and
  /// requiring credentials to render a single frame made the app unbootable.
  bool supabaseReady = false;

  /// Adopts any existing Supabase session and starts following auth changes.
  /// Called once from main() after Supabase.initialize succeeds.
  void bindSupabase() {
    supabaseReady = true;
    final auth = Supabase.instance.client.auth;
    _userId = auth.currentSession?.user.id;

    // Cancelled in dispose — this used to leak and call setState after the
    // listening State was gone.
    _authSubscription = auth.onAuthStateChange.listen((data) {
      final next = data.session?.user.id;
      if (next == _userId) return;
      _userId = next;
      notifyListeners();
    });
  }

  /// Enters the app as the seeded development profile, for runs with no
  /// Supabase credentials.
  void signInAsDevUser() {
    if (_userId == Env.devUserId) return;
    _userId = Env.devUserId;
    notifyListeners();
  }

  /// Clears the session. With Supabase configured this also revokes it server
  /// side; without it, dropping the local id is the whole of signing out.
  Future<void> signOut() async {
    if (supabaseReady) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (error) {
        debugPrint('save-some: Supabase signOut failed ($error) — clearing locally.');
      }
    }
    if (_userId == null) return;
    _userId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
