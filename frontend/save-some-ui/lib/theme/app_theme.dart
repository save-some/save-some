import 'package:flutter/material.dart';

import 'tokens.dart';

/// The app's themes.
///
/// Before this existed, MaterialApp was constructed with only `title` and
/// `home`, so every screen restyled Material's defaults at the call site and
/// the app rendered as stock Material 3. Component sub-themes are configured
/// here precisely so screens can stop passing `backgroundColor:`,
/// `selectedColor:`, `elevation:` and friends to individual widgets.
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final generated = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    );
    // The design only specifies a light scheme, so only light pins its sampled
    // roles; dark stays fully derived from the same seed.
    final scheme = isLight
        ? generated.copyWith(
            primary: AppColors.seed,
            surface: AppColors.surface,
            surfaceContainerHigh: AppColors.surfaceContainerHigh,
            secondaryContainer: AppColors.secondaryContainer,
            primaryContainer: AppColors.primaryContainer,
            onSurfaceVariant: AppColors.onSurfaceVariant,
          )
        : generated;
    final brand = isLight ? AppBrand.light : AppBrand.dark;

    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final textTheme = _textTheme(base.textTheme, scheme);

    return base.copyWith(
      extensions: [brand],
      textTheme: textTheme,

      // The design's defining move: cards sit on a warm cream page rather than
      // white-on-white. M3's default scaffold colour is near-white, which is
      // why this has to be overridden explicitly while the card colour below
      // can just take scheme.surface.
      scaffoldBackgroundColor: brand.canvas,
      canvasColor: brand.canvas,

      appBarTheme: AppBarTheme(
        backgroundColor: brand.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),

      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ),

      // Primary calls to action are near-black stadium pills.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand.ink,
          foregroundColor: isLight ? Colors.white : AppColors.ink,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
          // Height only. Size.fromHeight would set minimum *width* to infinity,
          // which silently breaks any button placed inside a Row — PrimaryButton
          // asks for full width itself instead.
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // Secondary actions (the design's "Options" button) read as an outlined
      // pill on the card surface.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
          minimumSize: const Size(64, 44),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.onSurface),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: scheme.surface,
        selectedColor: scheme.secondaryContainer,
        surfaceTintColor: Colors.transparent,
        side: BorderSide(color: scheme.outlineVariant),
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelLarge,
        secondaryLabelStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        showCheckmark: false,
        elevation: 0,
        pressElevation: 0,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? brand.canvas : scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        border: _inputBorder(brand.blobTaupe),
        enabledBorder: _inputBorder(brand.blobTaupe),
        focusedBorder: _inputBorder(scheme.primary, width: 2),
        errorBorder: _inputBorder(scheme.error),
        focusedErrorBorder: _inputBorder(scheme.error, width: 2),
      ),

      // M3 NavigationBar, not the M2 BottomNavigationBar this replaced — where
      // selectedItemColor and backgroundColor were both Colors.black, making the
      // selected tab invisible.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: brand.canvas,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.secondaryContainer,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? scheme.onSecondaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),

      // The design uses the iOS green for "on", not M3's purple.
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? brand.success
              : scheme.surfaceContainerHighest,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? brand.success
              : scheme.outlineVariant,
        ),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: brand.ink,
        contentTextStyle: TextStyle(
          color: isLight ? Colors.white : AppColors.ink,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: AppRadius.smAll,
      borderSide: BorderSide(color: color, width: width),
    );
  }

  /// Display styles use the bundled Archivo Black; everything else stays on the
  /// platform font. The wordmark in the design is tightly tracked and set solid,
  /// hence the negative letterSpacing and sub-1 line height.
  static TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
    const display = 'ArchivoBlack';
    return base
        .copyWith(
          displayLarge: base.displayLarge?.copyWith(
            fontFamily: display,
            fontWeight: FontWeight.w900,
            letterSpacing: -2,
            height: 0.92,
          ),
          displayMedium: base.displayMedium?.copyWith(
            fontFamily: display,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.5,
            height: 0.94,
          ),
          displaySmall: base.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            height: 1.15,
          ),
          headlineSmall: base.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  }
}
