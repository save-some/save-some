import 'package:flutter/material.dart';

import 'package:save_some_ui/theme/tokens.dart';

/// The design's primary call to action: a near-black stadium pill with a
/// circled-glyph leading icon.
///
/// Replaces the private `_darkBtn` / `_lightBtn` ButtonStyle fields on
/// `_SignInFormState`, which were the closest thing to design tokens the app
/// had — unreachable from any other file, and inconsistent with each other (one
/// had 5px corners, the other square).
class PrimaryButton extends StatelessWidget {
  final String label;

  /// Null disables the button, which is how the theme's disabled colours get
  /// exercised during form validation.
  final VoidCallback? onPressed;

  /// The design pairs each CTA with a small circled glyph.
  final IconData? icon;

  /// Swaps a spinner in for the icon and blocks presses.
  final bool busy;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon = Icons.star_outline,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : (icon == null ? null : Icon(icon, size: 18));

    // Page-level CTA, so it claims the full gutter width. The theme only sets a
    // minimum height, which keeps other themed buttons usable inside a Row.
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: busy ? null : onPressed,
        icon: child,
        label: Text(label),
      ),
    );
  }
}

/// The design's secondary action — an outlined pill sitting on a card, used for
/// "Options" beside "Save Product".
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (icon == null) {
      return OutlinedButton(onPressed: onPressed, child: Text(label));
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

/// A filled accent pill in the scheme's primary colour — the design's
/// "Save Product" button, which is violet rather than near-black to separate it
/// from page-level CTAs.
class AccentButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  const AccentButton({
    super.key,
    required this.label,
    this.onPressed,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      ),
      child: busy
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(label),
    );
  }
}
