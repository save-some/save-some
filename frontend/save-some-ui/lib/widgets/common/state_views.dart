import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:save_some_ui/theme/tokens.dart';

/// Loading, empty and error views, shared across every screen that fetches.
///
/// These were previously a private `_ErrorState` in home.dart plus assorted
/// inline `Text('No retailers yet', style: TextStyle(color: Colors.grey[500]))`
/// literals in products.dart — so the same states looked different depending on
/// which screen you were on.

/// Centred spinner. [compact] suits an inline slot such as a chip row that hasn't
/// loaded yet, where a full-height spinner would shove the page around.
class AppLoading extends StatelessWidget {
  final bool compact;

  const AppLoading({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return const SizedBox(
        height: 36,
        child: Center(
          child: SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

/// "Nothing here yet" — a statement of fact, not a failure.
class AppEmptyState extends StatelessWidget {
  final String message;
  final IconData? icon;

  const AppEmptyState({super.key, required this.message, this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 28, color: scheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Something broke, with a way back. [error] is shown only in debug builds —
/// users get the message, developers get the exception.
class AppErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final Object? error;

  const AppErrorState({
    super.key,
    this.message = 'Something went wrong.',
    this.onRetry,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 32, color: scheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (error != null && kDebugMode) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$error',
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: 160,
              child: FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ),
          ],
        ],
      ),
    );
  }
}
