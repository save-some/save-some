import 'package:flutter/material.dart';

import 'package:save_some_ui/theme/tokens.dart';

/// One row of the design's account screen: leading glyph, label, and either a
/// chevron or a switch.
///
/// Each row is its own card on a cream page rather than a divided list, which is
/// what the design shows.
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;

  /// Tapping the row. Ignored when [value] is non-null, since a switch row is
  /// toggled by its switch.
  final VoidCallback? onTap;

  /// Non-null turns the row into a switch row.
  final bool? value;
  final ValueChanged<bool>? onChanged;

  /// Optional right-aligned text before the chevron, e.g. the current theme mode.
  final String? trailingText;

  /// Renders the label and glyph in the error colour, for destructive rows such
  /// as sign out.
  final bool destructive;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.value,
    this.onChanged,
    this.trailingText,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = destructive ? scheme.error : scheme.onSurface;
    final isSwitch = value != null;

    final Widget trailing;
    if (isSwitch) {
      trailing = Switch(value: value!, onChanged: onChanged);
    } else if (trailingText != null) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            trailingText!,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
      );
    } else {
      trailing = Icon(Icons.chevron_right, color: scheme.onSurfaceVariant);
    }

    return Card(
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        // A switch row is driven by its switch, so the row itself isn't tappable.
        onTap: isSwitch ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: Row(
            children: [
              Icon(icon, size: 26, color: color),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(color: color),
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
