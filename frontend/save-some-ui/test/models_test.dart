import 'package:flutter_test/flutter_test.dart';

import 'package:save_some_ui/models/models.dart';

/// The API returns Postgres REAL columns as either int or double depending on the
/// value, and omits embedded collections on some endpoints — both of which used
/// to be easy to get wrong in four separately copy-pasted parse helpers.
void main() {
  group('Product', () {
    test('parses a trending row with a discount', () {
      final product = Product.fromJson({
        'id': 'p1',
        'name': '65" Samsung TV',
        'description': 'Samsung 65" Class 4K UHD Smart LED TV',
        'image_url': null,
        'upc': '887276512341',
        'brand': 'Samsung',
        'created_at': '2026-09-04T15:40:20.713600-04:00',
        'retailer_id': 'r1',
        'retailer_name': 'Walmart',
        'price': 497.99,
        'original_price': 649.99,
      });

      expect(product.retailerName, 'Walmart');
      expect(product.price, 497.99);
      expect(product.isDiscounted, isTrue);
    });

    test('accepts a whole-number price as an int', () {
      // /v1/products/trending returns 199 (not 199.0) for the DeWalt combo, and
      // a plain `as double` cast throws on that.
      final product = Product.fromJson({
        'id': 'p2',
        'name': 'DeWalt Drill Driver Combo',
        'created_at': '2026-09-04T15:40:20Z',
        'price': 199,
        'original_price': 209,
      });

      expect(product.price, 199.0);
      expect(product.originalPrice, 209.0);
      expect(product.isDiscounted, isTrue);
    });

    test('a watchlist row has a target price and no current price', () {
      final product = Product.fromJson({
        'id': 'p3',
        'name': '65" Samsung TV',
        'created_at': '2026-09-04T15:40:20Z',
        'target_price': 450.0,
        'notes': 'Wait for a holiday sale',
        'tracked_at': '2026-09-04T15:40:20Z',
      });

      expect(product.price, isNull);
      expect(product.targetPrice, 450.0);
      expect(product.trackedAt, isNotNull);
      expect(product.isDiscounted, isFalse,
          reason: 'no current price means no discount to show');
    });

    test('is not discounted when the original is not above the price', () {
      final product = Product.fromJson({
        'id': 'p4',
        'name': 'Extra Strength Pain Reliever',
        'created_at': '2026-09-04T15:40:20Z',
        'price': 12.49,
        'original_price': 12.49,
      });
      expect(product.isDiscounted, isFalse);
    });

    test('survives a row with only the required columns', () {
      final product = Product.fromJson({
        'id': 'p5',
        'name': 'iPhone Repair Kit',
        'created_at': '2026-09-04T15:40:20Z',
      });
      expect(product.brand, isNull);
      expect(product.price, isNull);
      expect(product.retailerName, isNull);
    });
  });

  group('User', () {
    test('null interests and retailers become empty lists', () {
      // The profile endpoint leaves both null; they're fetched separately.
      final user = User.fromJson({
        'id': 'u1',
        'display_name': 'John',
        'avatar_url': null,
        'zipcode': '07030',
        'interests': null,
        'retailers': null,
      });

      expect(user.displayName, 'John');
      expect(user.interests, isEmpty);
      expect(user.retailers, isEmpty);
    });

    test('parses embedded collections when present', () {
      final user = User.fromJson({
        'id': 'u1',
        'display_name': 'John',
        'interests': [
          {'id': 'c1', 'name': 'Electronics', 'created_at': '2026-01-01T00:00:00Z'},
        ],
        'retailers': [
          {'id': 'r1', 'name': 'Walmart', 'website': 'https://www.walmart.com',
           'created_at': '2026-01-01T00:00:00Z'},
        ],
      });

      expect(user.interests.single.name, 'Electronics');
      expect(user.retailers.single.website, 'https://www.walmart.com');
    });
  });

  group('Retailer', () {
    test('reads the website column', () {
      // The Pydantic model named this field website_url, which silently dropped
      // it from every response until it was renamed to match the column.
      final retailer = Retailer.fromJson({
        'id': 'r1',
        'name': 'Walmart',
        'website': 'https://www.walmart.com',
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(retailer.website, 'https://www.walmart.com');
    });
  });

  group('Store', () {
    test('parses a nearby-store row including its computed distance', () {
      final store = Store.fromJson({
        'id': 's1',
        'retailer_id': 'r2',
        'name': 'Target Hoboken',
        'address': '614 Clinton St',
        'city': 'Hoboken',
        'state': 'NJ',
        'zipcode': '07030',
        'lat': 40.7439,
        'lng': -74.0324,
        'created_at': '2026-01-01T00:00:00Z',
        // A store at the query point: the haversine guard must yield 0, not an
        // out-of-range error from acos().
        'distance_miles': 0,
      });

      expect(store.locality, 'Hoboken, NJ');
      expect(store.distanceMiles, 0.0);
    });

    test('locality degrades when parts are missing', () {
      final store = Store.fromJson({
        'id': 's2',
        'retailer_id': 'r2',
        'city': 'Hoboken',
        'created_at': '2026-01-01T00:00:00Z',
      });
      expect(store.locality, 'Hoboken');
      expect(store.distanceMiles, isNull);
    });
  });

  group('ProductPrice', () {
    test('parses an observation and defaults in_stock', () {
      final price = ProductPrice.fromJson({
        'price': 497.99,
        'original_price': 649.99,
        'scraped_at': '2026-09-04T15:40:20-04:00',
        'retailer_id': 'r1',
      });

      expect(price.price, 497.99);
      expect(price.inStock, isTrue);
      expect(price.scrapedAt.year, 2026);
    });
  });

  group('SearchHistoryEntry', () {
    test('parses a logged search', () {
      final entry = SearchHistoryEntry.fromJson({
        'id': 'h1',
        'query': 'logitech g705',
        'searched_at': '2026-09-04T13:40:20-04:00',
      });
      expect(entry.query, 'logitech g705');
    });
  });
}
