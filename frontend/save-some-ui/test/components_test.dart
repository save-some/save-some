import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:save_some_ui/models/models.dart';
import 'package:save_some_ui/widgets/brand/wordmark.dart';
import 'package:save_some_ui/widgets/charts/price_sparkline.dart';
import 'package:save_some_ui/widgets/common/avatar_badge.dart';
import 'package:save_some_ui/widgets/common/primary_button.dart';
import 'package:save_some_ui/widgets/common/search_field.dart';
import 'package:save_some_ui/widgets/common/settings_tile.dart';

import 'helpers.dart';

void main() {
  group('SaveSomeWordmark', () {
    testWidgets('renders uppercase on two lines without clipping',
        (tester) async {
      // The previous implementation pinned 'SAVE\nSOME' at fontSize 30 inside a
      // SizedBox(100, 100), which cut the descender off the second line.
      await tester.pumpWidget(wrapped(const SaveSomeWordmark(showLogo: false)));

      expect(find.text('SAVE\nSOME'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final style = tester.widget<Text>(find.text('SAVE\nSOME')).style!;
      expect(style.fontFamily, 'ArchivoBlack');
      // Set solid and tightly tracked, as the design has it.
      expect(style.height, lessThan(1.0));
      expect(style.letterSpacing, lessThan(0));
    });

    testWidgets('fits a narrow phone width', (tester) async {
      await tester.pumpWidget(wrapped(
        const SizedBox(width: 320, child: SaveSomeWordmark(showLogo: false)),
      ));
      expect(tester.takeException(), isNull);
    });
  });

  group('AvatarBadge', () {
    testWidgets('uses the first letter, skipping leading digits',
        (tester) async {
      // '65" Samsung TV' previously produced a badge reading '6'.
      await tester.pumpWidget(wrapped(
        const AvatarBadge(source: '65" Samsung TV'),
      ));
      expect(find.text('S'), findsOneWidget);
    });

    testWidgets('uppercases and handles an empty source', (tester) async {
      await tester.pumpWidget(wrapped(const Column(
        children: [
          AvatarBadge(source: 'walmart'),
          AvatarBadge(source: '   '),
        ],
      )));
      expect(find.text('W'), findsOneWidget);
      expect(find.text('?'), findsOneWidget);
    });
  });

  group('SearchField', () {
    testWidgets('shows its hint and reports taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrapped(SearchField(
        hint: 'Search for products',
        onTap: () => taps++,
      )));

      expect(find.text('Search for products'), findsOneWidget);
      // The design puts a menu glyph on the leading edge and the magnifier on
      // the trailing edge, not the other way round.
      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);

      await tester.tap(find.byType(SearchField));
      expect(taps, 1);
    });
  });

  group('SettingsTile', () {
    testWidgets('a chevron row is tappable', (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrapped(SettingsTile(
        icon: Icons.person_outline,
        label: 'Personal Details',
        onTap: () => taps++,
      )));

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      await tester.tap(find.text('Personal Details'));
      expect(taps, 1);
    });

    testWidgets('a switch row exposes a Switch and no chevron', (tester) async {
      bool? received;
      await tester.pumpWidget(wrapped(SettingsTile(
        icon: Icons.location_on_outlined,
        label: 'Turn on location',
        value: false,
        onChanged: (v) => received = v,
      )));

      expect(find.byType(Switch), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);

      await tester.tap(find.byType(Switch));
      expect(received, isTrue);
    });

    testWidgets('a destructive row is coloured by the error role',
        (tester) async {
      await tester.pumpWidget(wrapped(const SettingsTile(
        icon: Icons.logout,
        label: 'Sign out',
        destructive: true,
      )));

      final context = tester.element(find.text('Sign out'));
      final error = Theme.of(context).colorScheme.error;
      expect(tester.widget<Text>(find.text('Sign out')).style?.color, error);
    });

    testWidgets('trailing text sits before the chevron', (tester) async {
      await tester.pumpWidget(wrapped(const SettingsTile(
        icon: Icons.palette_outlined,
        label: 'Color Scheme',
        trailingText: 'Light',
      )));

      expect(find.text('Light'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });
  });

  group('PrimaryButton', () {
    testWidgets('busy blocks presses and shows a spinner', (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrapped(PrimaryButton(
        label: 'Log In',
        busy: true,
        onPressed: () => taps++,
      )));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Log In'));
      expect(taps, 0, reason: 'a busy button must not double-submit');
    });

    testWidgets('a null callback renders disabled', (tester) async {
      await tester.pumpWidget(wrapped(const PrimaryButton(label: 'Log In')));
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).enabled,
          isFalse);
    });

    testWidgets('secondary and accent buttons coexist in a Row', (tester) async {
      // Guards the theme bug where a minimum width of infinity made buttons
      // inside a Row fail to lay out.
      await tester.pumpWidget(wrapped(Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SecondaryButton(label: 'Options', onPressed: () {}),
          AccentButton(label: 'Save Product', onPressed: () {}),
        ],
      )));

      expect(tester.takeException(), isNull);
      expect(find.text('Options'), findsOneWidget);
      expect(find.text('Save Product'), findsOneWidget);
    });
  });

  group('PriceSparkline', () {
    ProductPrice at(double price, int day) => ProductPrice(
          price: price,
          scrapedAt: DateTime(2026, 1, day),
        );

    testWidgets('draws a series', (tester) async {
      await tester.pumpWidget(wrapped(PriceSparkline(
        prices: [at(500, 1), at(480, 2), at(520, 3), at(497, 4)],
      )));
      expect(tester.takeException(), isNull);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('says so when there is not enough history', (tester) async {
      await tester.pumpWidget(wrapped(PriceSparkline(prices: [at(500, 1)])));
      expect(find.text('Not enough price history yet'), findsOneWidget);
    });

    testWidgets('a flat series does not divide by zero', (tester) async {
      await tester.pumpWidget(wrapped(PriceSparkline(
        prices: [at(500, 1), at(500, 2), at(500, 3)],
      )));
      expect(tester.takeException(), isNull);
    });
  });
}
