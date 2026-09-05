import 'package:flutter_test/flutter_test.dart';

import 'package:save_some_ui/util/format.dart';

void main() {
  group('formatUsd', () {
    test('always shows two decimal places', () {
      // A price reading $1,299 beside one reading $497.99 looks like a bug.
      expect(formatUsd(497.99), '\$497.99');
      expect(formatUsd(199), '\$199.00');
      expect(formatUsd(12.5), '\$12.50');
      expect(formatUsd(0), '\$0.00');
    });

    test('groups thousands', () {
      expect(formatUsd(1299), '\$1,299.00');
      expect(formatUsd(12999.5), '\$12,999.50');
      expect(formatUsd(1234567.89), '\$1,234,567.89');
      expect(formatUsd(999), '\$999.00', reason: 'no separator below 1000');
    });

    test('rounds rather than truncating', () {
      // Postgres REAL round-trips produce values like 89.999985.
      expect(formatUsd(89.999985), '\$90.00');
      expect(formatUsd(12.345), '\$12.35');
      expect(formatUsd(12.344), '\$12.34');
    });

    test('handles negatives, sign outside the symbol', () {
      expect(formatUsd(-4.5), '-\$4.50');
    });
  });

  group('formatUsdDelta', () {
    test('signs the difference', () {
      expect(formatUsdDelta(497.99, 537.72), '+\$39.73');
      expect(formatUsdDelta(537.72, 497.99), '-\$39.73');
    });

    test('returns null when the prices match', () {
      // So callers can omit the label rather than printing +$0.00.
      expect(formatUsdDelta(10, 10), isNull);
      // Sub-cent differences are float noise, not a real delta.
      expect(formatUsdDelta(10, 10.001), isNull);
    });
  });

  group('formatRelative', () {
    final now = DateTime(2026, 9, 4, 12, 0);

    test('describes recent times loosely', () {
      expect(formatRelative(now, now: now), 'just now');
      expect(formatRelative(now.subtract(const Duration(minutes: 5)), now: now),
          '5m ago');
      expect(formatRelative(now.subtract(const Duration(hours: 3)), now: now),
          '3h ago');
      expect(formatRelative(now.subtract(const Duration(days: 3)), now: now),
          '3d ago');
    });

    test('coarsens as it gets older', () {
      expect(formatRelative(now.subtract(const Duration(days: 10)), now: now),
          '1w ago');
      expect(formatRelative(now.subtract(const Duration(days: 60)), now: now),
          '2mo ago');
      expect(formatRelative(now.subtract(const Duration(days: 400)), now: now),
          '1y ago');
    });

    test('a future timestamp reads as now, not as negative time', () {
      // Clock skew between the server and the device shouldn't render "-3m ago".
      expect(formatRelative(now.add(const Duration(hours: 2)), now: now),
          'just now');
    });
  });
}
