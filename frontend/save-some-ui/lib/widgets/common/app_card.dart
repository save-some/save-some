import 'package:flutter/material.dart';

import 'package:save_some_ui/theme/tokens.dart';

/// Every card in the app: soft shadow, and a small depress on tap.
///
/// The Figma draws cards flat on the cream page. This is a deliberate departure —
/// flat cards on a warm background read as unclickable, and there was no feedback
/// at all when one was pressed. One shadow token and one animation curve are used
/// everywhere so the whole app moves the same way.
class AppCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Slightly stronger shadow, for a card that is the focus of a screen rather
  /// than one row in a list.
  final bool raised;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.raised = false,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  // Short enough to feel like a response rather than an animation.
  static const _duration = Duration(milliseconds: 120);

  void _setPressed(bool value) {
    if (!mounted || _pressed == value || widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    // Tinted with the scheme's shadow colour rather than pure black, so it sits
    // on the cream page instead of greying it. Dark mode leans on the border
    // instead — a shadow under a dark card is invisible.
    final elevation = widget.raised ? 1.6 : 1.0;
    final shadows = isDark
        ? const <BoxShadow>[]
        : [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: _pressed ? 0.04 : 0.07),
              blurRadius: (widget.raised ? 18 : 12) * elevation,
              offset: Offset(0, (_pressed ? 1 : 3) * elevation),
            ),
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.03),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ];

    return AnimatedScale(
      // Barely perceptible as movement, clearly perceptible as feedback.
      scale: _pressed ? 0.985 : 1,
      duration: _duration,
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: _duration,
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: AppRadius.lgAll,
          boxShadow: shadows,
          border: isDark
              ? Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5))
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: AppRadius.lgAll,
            onTap: widget.onTap,
            // Covers pointer-up, drag-away and cancel, so a card can't be left
            // stuck in the pressed state.
            onTapDown: (_) => _setPressed(true),
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}
