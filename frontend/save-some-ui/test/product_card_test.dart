import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:save_some_ui/models/models.dart';
import 'package:save_some_ui/widgets/cards/product.dart';

import 'helpers.dart';

/// ProductCard's contract is that one widget serves four call sites by keying
/// its layout off which optional fields are populated. Each branch is covered
/// here because all four are load-bearing.
void main() {
  Product product({
    String name = '65" Samsung TV',
    String? brand,
    String? retailerName,
    double? price,
    double? originalPrice,
    double? targetPrice,
  }) {
    return Product(
      id: 'p1',
      name: name,
      brand: brand,
      retailerName: retailerName,
      price: price,
      originalPrice: originalPrice,
      targetPrice: targetPrice,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  testWidgets('with a retailer, the retailer leads and the product follows',
      (tester) async {
    await tester.pumpWidget(wrapped(ProductCard(
      product: product(retailerName: 'Walmart', price: 497.99),
    )));

    final headline = tester.widget<Text>(find.text('Walmart'));
    final subtitle = tester.widget<Text>(find.text('65" Samsung TV'));
    expect(headline.style?.fontWeight, FontWeight.w600);
    // Subtitle is deliberately quieter than the headline.
    expect(subtitle.style?.color, isNot(headline.style?.color));
  });

  testWidgets('without a retailer, the product leads and the brand follows',
      (tester) async {
    await tester.pumpWidget(wrapped(ProductCard(
      product: product(brand: 'Samsung'),
    )));

    expect(find.text('65" Samsung TV'), findsOneWidget);
    expect(find.text('Samsung'), findsOneWidget);
  });

  testWidgets('a discount strikes through the original price', (tester) async {
    await tester.pumpWidget(wrapped(ProductCard(
      product: product(
        retailerName: 'Walmart',
        price: 497.99,
        originalPrice: 649.99,
      ),
    )));

    expect(find.text('\$497.99'), findsOneWidget);
    final original = tester.widget<Text>(find.text('\$649.99'));
    expect(original.style?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('an original price at or below the current one is not a discount',
      (tester) async {
    await tester.pumpWidget(wrapped(ProductCard(
      product: product(
        retailerName: 'Walmart',
        price: 497.99,
        originalPrice: 497.99,
      ),
    )));

    expect(find.text('\$497.99'), findsOneWidget);
    // Only the current price renders — no struck-through duplicate.
    expect(find.textContaining('\$'), findsOneWidget);
  });

  testWidgets('a watchlist item with no price shows its alert threshold',
      (tester) async {
    await tester.pumpWidget(wrapped(ProductCard(
      product: product(targetPrice: 450),
    )));

    expect(find.text('alert \$450.00'), findsOneWidget);
  });

  testWidgets('a tracked product shows both its price and its alert',
      (tester) async {
    // Previously the alert replaced the price, which is why watchlist rows
    // looked priceless.
    await tester.pumpWidget(wrapped(ProductCard(
      product: product(price: 497.99, targetPrice: 450),
    )));

    expect(find.text('\$497.99'), findsOneWidget);
    expect(find.text('alert \$450.00'), findsOneWidget);
  });

  testWidgets('a discount also shows what you save', (tester) async {
    await tester.pumpWidget(wrapped(ProductCard(
      product: product(price: 497.99, originalPrice: 649.99),
    )));
    expect(find.text('save \$152.00'), findsOneWidget);
  });

  testWidgets('thousands are grouped', (tester) async {
    await tester.pumpWidget(wrapped(ProductCard(
      product: product(price: 1299),
    )));
    expect(find.text('\$1,299.00'), findsOneWidget);
  });

  testWidgets('tapping reports the selection', (tester) async {
    var taps = 0;
    await tester.pumpWidget(wrapped(ProductCard(
      product: product(retailerName: 'Walmart'),
      onTap: () => taps++,
    )));

    await tester.tap(find.byType(ProductCard));
    expect(taps, 1);
  });

  testWidgets('long names truncate instead of overflowing', (tester) async {
    await tester.pumpWidget(wrapped(SizedBox(
      width: 300,
      child: ProductCard(
        product: product(
          retailerName: 'Amazon',
          name: 'Logitech G705 Wireless Gaming Mouse, Customizable LIGHTSYNC '
              'RGB Lighting, Lightspeed Wireless, Bluetooth Connectivity',
        ),
      ),
    )));

    // No RenderFlex overflow, and the subtitle is clipped rather than wrapped.
    expect(tester.takeException(), isNull);
    final subtitle = tester.widget<Text>(find.textContaining('Logitech G705'));
    expect(subtitle.maxLines, 1);
    expect(subtitle.overflow, TextOverflow.ellipsis);
  });
}
