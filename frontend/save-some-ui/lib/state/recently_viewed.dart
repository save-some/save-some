import 'package:flutter/foundation.dart';

import 'package:save_some_ui/models/models.dart';

/// Products this user has opened, most recent first.
///
/// Gives the history tab something concrete to show — with images — instead of a
/// list of bare search strings. In-memory only: it's a browsing convenience, and
/// persisting it would mean either a schema change or local storage, neither of
/// which is warranted yet.
class RecentlyViewed extends ChangeNotifier {
  RecentlyViewed._();

  static final RecentlyViewed instance = RecentlyViewed._();

  static const _limit = 12;

  final List<Product> _products = [];

  List<Product> get products => List.unmodifiable(_products);

  bool get isEmpty => _products.isEmpty;

  /// Moves an already-seen product back to the front rather than duplicating it,
  /// and keeps the newest [_limit].
  void record(Product product) {
    final existing = _products.indexWhere((p) => p.id == product.id);
    if (existing == 0) {
      // Already at the front; re-recording would notify listeners for nothing.
      _products[0] = product;
      return;
    }
    if (existing > 0) _products.removeAt(existing);
    _products.insert(0, product);
    if (_products.length > _limit) _products.removeRange(_limit, _products.length);
    notifyListeners();
  }

  void clear() {
    if (_products.isEmpty) return;
    _products.clear();
    notifyListeners();
  }
}
