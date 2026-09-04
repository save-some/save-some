import 'package:flutter/foundation.dart';

import 'package:save_some_ui/models/models.dart';
import 'package:save_some_ui/services/users_service.dart';

/// The set of products this user is tracking.
///
/// Held centrally so a save on one screen shows up on every other without a
/// refetch — the products list, the trending list and the detail view all render
/// the same product and previously had no way to agree about it.
///
/// Writes are optimistic and roll back on failure: tapping a bookmark should feel
/// instant, and a failed request is rare enough to be worth an undo rather than a
/// spinner on every tap.
class WatchlistController extends ChangeNotifier {
  final UsersService _users;

  WatchlistController(this._users);

  final Set<String> _productIds = {};
  final Set<String> _inFlight = {};
  List<Product> _products = const [];
  bool _loaded = false;
  Object? _error;

  /// Product ids currently tracked.
  Set<String> get productIds => Set.unmodifiable(_productIds);

  /// Full rows, for the "Your Products" list. Only as fresh as the last [load].
  List<Product> get products => List.unmodifiable(_products);

  bool get isLoaded => _loaded;
  Object? get error => _error;

  bool isTracked(String productId) => _productIds.contains(productId);

  /// True while a toggle for this product is still in flight, so the UI can
  /// disable the control without blocking the rest of the list.
  bool isBusy(String productId) => _inFlight.contains(productId);

  Future<void> load(String userId) async {
    try {
      final rows = await _users.fetchWatchlist(userId);
      _products = rows;
      _productIds
        ..clear()
        ..addAll(rows.map((p) => p.id));
      _error = null;
    } catch (error) {
      _error = error;
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  /// Adds or removes, depending on current state. Returns true if the product is
  /// tracked afterwards, so callers can phrase their confirmation correctly.
  ///
  /// Throws on failure *after* restoring the previous state, letting the caller
  /// surface the error while the UI stays truthful.
  Future<bool> toggle(
    String userId,
    Product product, {
    double? targetPrice,
  }) async {
    final id = product.id;
    if (_inFlight.contains(id)) return isTracked(id);

    final wasTracked = _productIds.contains(id);
    final previousProducts = List<Product>.from(_products);

    // Optimistic.
    _inFlight.add(id);
    if (wasTracked) {
      _productIds.remove(id);
      _products = _products.where((p) => p.id != id).toList();
    } else {
      _productIds.add(id);
      _products = [product, ..._products];
    }
    notifyListeners();

    try {
      if (wasTracked) {
        await _users.removeFromWatchlist(userId, id);
      } else {
        await _users.addToWatchlist(userId, id, targetPrice: targetPrice);
      }
      return !wasTracked;
    } catch (error) {
      // Roll back to exactly what was there before.
      if (wasTracked) {
        _productIds.add(id);
      } else {
        _productIds.remove(id);
      }
      _products = previousProducts;
      rethrow;
    } finally {
      _inFlight.remove(id);
      notifyListeners();
    }
  }

  /// Updates the alert threshold on an already-tracked product. The endpoint
  /// upserts, so this is the same call as adding.
  Future<void> setTargetPrice(
    String userId,
    Product product,
    double? targetPrice,
  ) async {
    await _users.addToWatchlist(userId, product.id, targetPrice: targetPrice);
    _productIds.add(product.id);
    notifyListeners();
  }
}
