/// Display formatting, in one place.
///
/// Prices were previously formatted with an inline `'\$${x.toStringAsFixed(2)}'`
/// in two different widgets, so there was nowhere to change the currency or the
/// thousands separator. `intl` is deliberately not a dependency — one currency
/// and one locale don't justify it.
library;

/// `497.99` -> `$497.99`, `1299` -> `$1,299.00`.
///
/// Always two decimal places, because a price reading `$1,299` next to one
/// reading `$497.99` looks like a bug.
String formatUsd(num amount) {
  final negative = amount < 0;
  final cents = (amount.abs() * 100).round();
  final whole = cents ~/ 100;
  final fraction = (cents % 100).toString().padLeft(2, '0');
  return '${negative ? '-' : ''}\$${_groupThousands(whole)}.$fraction';
}

/// The gap between two prices, always signed, for comparison rows:
/// `+$21.01` / `-$4.50`. Returns null when the two are equal, so callers can
/// omit the label entirely rather than printing `+$0.00`.
String? formatUsdDelta(num from, num to) {
  final diff = to - from;
  if (diff.abs() < 0.005) return null;
  return '${diff > 0 ? '+' : '-'}${formatUsd(diff.abs())}';
}

/// A coarse "how long ago", for price observations and search history.
///
/// Intentionally vague past a week: an exact date adds nothing when the point is
/// "this is recent" or "this is stale".
String formatRelative(DateTime when, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).difference(when);
  if (elapsed.isNegative) return 'just now';
  if (elapsed.inMinutes < 1) return 'just now';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}m ago';
  if (elapsed.inHours < 24) return '${elapsed.inHours}h ago';
  if (elapsed.inDays < 7) return '${elapsed.inDays}d ago';
  if (elapsed.inDays < 30) return '${elapsed.inDays ~/ 7}w ago';
  if (elapsed.inDays < 365) return '${elapsed.inDays ~/ 30}mo ago';
  return '${elapsed.inDays ~/ 365}y ago';
}

String _groupThousands(int value) {
  final digits = value.toString();
  if (digits.length <= 3) return digits;
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
