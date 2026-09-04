import 'package:flutter/foundation.dart';

/// Build-time and platform-dependent configuration.
///
/// Deliberately uses `kIsWeb` / `defaultTargetPlatform` from
/// package:flutter/foundation rather than `Platform` from dart:io — dart:io
/// does not exist on the web, and importing it here made the whole app fail to
/// compile for Chrome.
class Env {
  /// Where the FastAPI backend lives.
  ///
  /// Override with `--dart-define=API_BASE_URL=...` to point at a deployed
  /// instance; the defaults below only make sense for local development.
  static String get apiBaseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;

    // 10.0.2.2 is the Android emulator's alias for the host machine. A physical
    // Android device needs the host's LAN IP instead (e.g. http://192.168.1.x:8000),
    // since 10.0.2.2 only exists inside the emulator's virtual network.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }

    // Web, iOS simulator and desktop all reach the host's loopback directly.
    return 'http://127.0.0.1:8000';
  }

  /// User to act as when Supabase auth isn't configured. Matches the profile
  /// created by backend/seed/local_seed.sql, so a freshly seeded local database
  /// renders a populated home screen with no sign-in step.
  static const devUserId = String.fromEnvironment(
    'DEV_USER_ID',
    defaultValue: '00000000-0000-4000-8000-000000000001',
  );
}
