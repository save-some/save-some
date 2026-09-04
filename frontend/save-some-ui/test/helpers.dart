import 'package:flutter/material.dart';

import 'package:save_some_ui/theme/app_theme.dart';

/// Wraps [child] in the real app theme, so tests exercise the same styling the
/// app ships rather than Material's defaults.
Widget wrapped(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light,
    home: Scaffold(body: child),
  );
}
