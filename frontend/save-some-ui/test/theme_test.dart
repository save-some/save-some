import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:save_some_ui/theme/app_theme.dart';
import 'package:save_some_ui/theme/tokens.dart';

void main() {
  group('light theme', () {
    final theme = AppTheme.light;

    test('page background is the design\'s cream, not Material\'s near-white', () {
      // The single most defining colour in the design, and the one thing seeding
      // from Material 3 does not give you.
      expect(theme.scaffoldBackgroundColor, AppColors.canvas);
      expect(theme.scaffoldBackgroundColor, isNot(theme.colorScheme.surface));
    });

    test('scheme carries the exact colours sampled from the Figma', () {
      // Sampled pixel-by-pixel from the design frames. They're pinned over
      // ColorScheme.fromSeed rather than trusted to fall out of it: Flutter's
      // tonal algorithm drifts between versions (3.47 seeds surface #FDF7FF and
      // primary #65558F), and the design should win over the algorithm.
      final scheme = theme.colorScheme;
      expect(scheme.primary, const Color(0xFF6750A4), reason: 'accent / Save Product');
      expect(scheme.surface, const Color(0xFFFEF7FF), reason: 'card fill');
      expect(scheme.surfaceContainerHigh, const Color(0xFFECE6F0),
          reason: 'search field / thumb placeholder');
      expect(scheme.secondaryContainer, const Color(0xFFE8DEF8),
          reason: 'selected chip and nav indicator');
      expect(scheme.primaryContainer, const Color(0xFFEADEFF),
          reason: 'avatar circle');
      expect(scheme.onSurfaceVariant, const Color(0xFF49454F),
          reason: 'secondary text');
    });

    test('primary CTA is the near-black pill, not the seed purple', () {
      final style = theme.filledButtonTheme.style!;
      expect(
        style.backgroundColor?.resolve({}),
        AppColors.ink,
      );
      expect(style.shape?.resolve({}), isA<StadiumBorder>());
    });

    test('filled buttons do not demand infinite width', () {
      // Size.fromHeight sets minimum *width* to infinity, which silently breaks
      // any themed button placed inside a Row — it removed the Options and
      // Save Product buttons from the product card entirely.
      final minimum = theme.filledButtonTheme.style?.minimumSize?.resolve({});
      expect(minimum, isNotNull);
      expect(minimum!.width.isFinite, isTrue,
          reason: 'an infinite minimum width cannot lay out inside a Row');
      expect(minimum.height, 52);
    });

    test('switch reads as the design\'s green when on', () {
      final track = theme.switchTheme.trackColor;
      expect(track?.resolve({WidgetState.selected}), AppColors.success);
      expect(
        track?.resolve(<WidgetState>{}),
        isNot(AppColors.success),
        reason: 'off state must not look enabled',
      );
    });

    test('cards are flat and share one radius', () {
      expect(theme.cardTheme.elevation, 0);
      final shape = theme.cardTheme.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, AppRadius.lgAll);
    });

    test('brand extension is attached', () {
      final brand = theme.extension<AppBrand>();
      expect(brand, isNotNull);
      expect(brand!.blobTaupe, AppColors.blobTaupe);
      expect(brand.blobSand, AppColors.blobSand);
    });
  });

  group('dark theme', () {
    final theme = AppTheme.dark;

    test('is actually dark and keeps a distinct canvas', () {
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, isNot(AppColors.canvas));
      expect(theme.extension<AppBrand>(), isNotNull);
    });

    test('CTA stays legible by inverting ink', () {
      final style = theme.filledButtonTheme.style!;
      final background = style.backgroundColor?.resolve({});
      final foreground = style.foregroundColor?.resolve({});
      expect(background, isNot(foreground));
      // Ink is light in dark mode, so its text must be dark.
      expect(background, AppBrand.dark.ink);
    });
  });

  group('navigation bar', () {
    // Regression guard for the app's most visible bug: the old M2
    // BottomNavigationBar had selectedItemColor: Colors.black on
    // backgroundColor: Colors.black, so the selected tab was invisible.
    for (final (name, theme) in [
      ('light', AppTheme.light),
      ('dark', AppTheme.dark),
    ]) {
      test('$name: selected and unselected are distinguishable', () {
        final navTheme = theme.navigationBarTheme;

        final selectedLabel = navTheme.labelTextStyle
            ?.resolve({WidgetState.selected})?.color;
        final unselectedLabel =
            navTheme.labelTextStyle?.resolve(<WidgetState>{})?.color;
        expect(selectedLabel, isNotNull);
        expect(selectedLabel, isNot(unselectedLabel));

        final selectedIcon =
            navTheme.iconTheme?.resolve({WidgetState.selected})?.color;
        final unselectedIcon =
            navTheme.iconTheme?.resolve(<WidgetState>{})?.color;
        expect(selectedIcon, isNot(unselectedIcon));

        // And the selection indicator must not vanish into the bar.
        expect(navTheme.indicatorColor, isNotNull);
        expect(navTheme.indicatorColor, isNot(navTheme.backgroundColor));
        expect(selectedLabel, isNot(navTheme.backgroundColor));
      });
    }
  });
}
