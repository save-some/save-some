import 'package:flutter_test/flutter_test.dart';

import 'package:save_some_ui/models/models.dart';

ProductOffer _offer(String retailer, double? price, {double? original}) =>
    ProductOffer(
      retailerId: 'r-$retailer',
      retailerName: retailer,
      retailerProductId: 'rp-$retailer',
      price: price,
      originalPrice: original,
    );

void main() {
  group('ProductOffer parsing', () {
    test('parses a priced offer', () {
      final offer = ProductOffer.fromJson({
        'retailer_id': '11111111-1111-4111-8111-000000000001',
        'retailer_name': 'Walmart',
        'website': 'https://www.walmart.com',
        'retailer_product_id': '44444444-4444-4444-8444-000000000001',
        'product_url': 'https://www.walmart.com/ip/x/1',
        'price': 497.99,
        'original_price': 649.99,
        'in_stock': true,
        'scraped_at': '2026-09-04T15:40:20-04:00',
      });

      expect(offer.retailerName, 'Walmart');
      expect(offer.isDiscounted, isTrue);
      expect(offer.scrapedAt, isNotNull);
    });

    test('tolerates a retailer that stocks the product with no price yet', () {
      final offer = ProductOffer.fromJson({
        'retailer_id': 'r1',
        'retailer_name': "Sam's Club",
        'retailer_product_id': 'rp1',
      });
      expect(offer.price, isNull);
      expect(offer.isDiscounted, isFalse);
      expect(offer.inStock, isNull);
    });

    test('accepts an int price', () {
      final offer = ProductOffer.fromJson({
        'retailer_id': 'r1',
        'retailer_name': 'Home Depot',
        'retailer_product_id': 'rp1',
        'price': 199,
      });
      expect(offer.price, 199.0);
    });
  });

  group('offer list summary', () {
    test('cheapest skips unpriced retailers', () {
      final offers = [
        _offer('Sears', null),
        _offer('Walmart', 497.99),
        _offer("Sam's Club", 537.72),
      ];
      expect(offers.cheapest?.retailerName, 'Walmart');
      expect(offers.priced.length, 2);
    });

    test('spread is the gap between cheapest and dearest', () {
      final offers = [_offer('Walmart', 497.99), _offer("Sam's", 537.72)];
      expect(offers.spread, closeTo(39.73, 0.001));
    });

    test('no spread with fewer than two prices', () {
      // "Compare" needs two things to compare; one price is not a saving.
      expect([_offer('Walmart', 497.99)].spread, isNull);
      expect([_offer('Walmart', 497.99), _offer('X', null)].spread, isNull);
      expect(<ProductOffer>[].spread, isNull);
      expect(<ProductOffer>[].cheapest, isNull);
    });

    test('spread ignores list order', () {
      final ascending = [_offer('a', 10), _offer('b', 25), _offer('c', 40)];
      final descending = [_offer('c', 40), _offer('b', 25), _offer('a', 10)];
      expect(ascending.spread, descending.spread);
      expect(ascending.spread, 30);
    });
  });
}
