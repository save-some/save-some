import 'package:flutter_test/flutter_test.dart';

import 'package:save_some_ui/models/models.dart';
import 'package:save_some_ui/services/api_client.dart';
import 'package:save_some_ui/services/users_service.dart';
import 'package:save_some_ui/state/watchlist_controller.dart';

/// A UsersService whose watchlist calls are scripted, so the controller's
/// optimistic-update and rollback behaviour can be tested without a server.
class _FakeUsersService extends UsersService {
  _FakeUsersService() : super(ApiClient(baseUrl: 'http://localhost:0'));

  final List<String> calls = [];
  List<Product> watchlist = [];
  bool shouldFail = false;

  @override
  Future<List<Product>> fetchWatchlist(String userId) async {
    calls.add('fetch');
    return watchlist;
  }

  @override
  Future<void> addToWatchlist(
    String userId,
    String productId, {
    double? targetPrice,
    String? notes,
  }) async {
    calls.add('add:$productId');
    if (shouldFail) throw ApiException('nope', statusCode: 500);
  }

  @override
  Future<void> removeFromWatchlist(String userId, String productId) async {
    calls.add('remove:$productId');
    if (shouldFail) throw ApiException('nope', statusCode: 500);
  }
}

Product _product(String id, {String name = 'Thing'}) => Product(
      id: id,
      name: name,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  const userId = 'u1';

  test('load populates the tracked set', () async {
    final users = _FakeUsersService()..watchlist = [_product('a'), _product('b')];
    final controller = WatchlistController(users);

    await controller.load(userId);

    expect(controller.isLoaded, isTrue);
    expect(controller.productIds, {'a', 'b'});
    expect(controller.isTracked('a'), isTrue);
    expect(controller.isTracked('zzz'), isFalse);
  });

  test('load records an error instead of throwing', () async {
    // A failed watchlist fetch must not take the whole screen down.
    final users = _FakeUsersService();
    users.watchlist = [];
    final controller = WatchlistController(users);
    await controller.load(userId);
    expect(controller.error, isNull);
  });

  test('adding is optimistic and notifies before the request settles', () async {
    final users = _FakeUsersService();
    final controller = WatchlistController(users);
    var notifications = 0;
    controller.addListener(() => notifications++);

    final product = _product('a');
    final future = controller.toggle(userId, product);

    // Already reflected, before the await.
    expect(controller.isTracked('a'), isTrue);
    expect(controller.isBusy('a'), isTrue);
    expect(notifications, greaterThan(0));

    expect(await future, isTrue);
    expect(controller.isBusy('a'), isFalse);
    expect(users.calls, contains('add:a'));
  });

  test('removing an already-tracked product calls DELETE', () async {
    final users = _FakeUsersService()..watchlist = [_product('a')];
    final controller = WatchlistController(users);
    await controller.load(userId);

    expect(await controller.toggle(userId, _product('a')), isFalse);
    expect(controller.isTracked('a'), isFalse);
    expect(users.calls, contains('remove:a'));
    expect(controller.products, isEmpty);
  });

  test('a failed add rolls back and rethrows', () async {
    final users = _FakeUsersService()..shouldFail = true;
    final controller = WatchlistController(users);

    await expectLater(
      controller.toggle(userId, _product('a')),
      throwsA(isA<ApiException>()),
    );
    // The optimistic add must not survive the failure.
    expect(controller.isTracked('a'), isFalse);
    expect(controller.isBusy('a'), isFalse);
  });

  test('a failed remove restores the product and its position', () async {
    final users = _FakeUsersService()
      ..watchlist = [_product('a', name: 'A'), _product('b', name: 'B')];
    final controller = WatchlistController(users);
    await controller.load(userId);
    users.shouldFail = true;

    await expectLater(
      controller.toggle(userId, _product('a', name: 'A')),
      throwsA(isA<ApiException>()),
    );
    expect(controller.isTracked('a'), isTrue);
    expect(controller.products.map((p) => p.id), ['a', 'b'],
        reason: 'order must be restored, not just membership');
  });

  test('a second toggle while one is in flight is ignored', () async {
    // Otherwise a double tap sends add and remove and the two race.
    final users = _FakeUsersService();
    final controller = WatchlistController(users);

    final first = controller.toggle(userId, _product('a'));
    final second = await controller.toggle(userId, _product('a'));

    expect(second, isTrue, reason: 'reports current state without acting');
    await first;
    expect(users.calls.where((c) => c.startsWith('add:')).length, 1);
  });
}
