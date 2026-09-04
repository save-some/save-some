import 'dart:async';

import 'package:flutter/material.dart';

import 'package:save_some_ui/models/models.dart';
import 'package:save_some_ui/services/products_service.dart';
import 'package:save_some_ui/theme/tokens.dart';
import 'package:save_some_ui/widgets/cards/product.dart';
import 'package:save_some_ui/widgets/common/state_views.dart';

/// Full-screen search UI, pushed on top of the current page by
/// showSearch(). Gives back/X-to-close for free — no custom overlay
/// needed. Debounces keystrokes so rapid typing doesn't fire a request
/// per character.
class ProductSearchDelegate extends SearchDelegate<Product?> {
  final ProductsService productsService;

  /// Passing this records the search server-side, which is what fills the
  /// history screen's recent-searches list.
  final String? userId;

  /// Called when a result is tapped, so the caller decides where to navigate.
  final ValueChanged<Product>? onSelect;

  ProductSearchDelegate({
    required this.productsService,
    this.userId,
    this.onSelect,
  });

  Timer? _debounce;
  String? _pendingQuery;
  Future<List<Product>>? _pendingSearch;

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  // Submitted (the user pressed enter) — this one is worth remembering.
  @override
  Widget buildResults(BuildContext context) => _resultsList(query, log: true);

  // Still typing. Passing userId here would record every intermediate query, so
  // searching for "logitech" filled the history screen with "l", "lo", "log"…
  @override
  Widget buildSuggestions(BuildContext context) => _resultsList(query);

  /// Cancels any pending debounce timer and starts a new one. Rapid
  /// keystrokes keep resetting the timer, so only the last keystroke in
  /// a burst actually triggers a network call, ~300ms after typing stops.
  Future<List<Product>> _debouncedSearch(String q, {required bool log}) {
    if (_pendingQuery == q && _pendingSearch != null) {
      return _pendingSearch!;
    }
    _debounce?.cancel();
    final completer = Completer<List<Product>>();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      productsService
          .search(q, userId: log ? userId : null)
          .then(completer.complete, onError: completer.completeError);
    });
    _pendingQuery = q;
    _pendingSearch = completer.future;
    return completer.future;
  }

  Widget _resultsList(String q, {bool log = false}) {
    final trimmed = q.trim();
    if (trimmed.isEmpty) {
      return const AppEmptyState(
        message: 'Search for a product',
        icon: Icons.search,
      );
    }

    return FutureBuilder<List<Product>>(
      future: _debouncedSearch(trimmed, log: log),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoading();
        }
        if (snapshot.hasError) {
          return AppErrorState(
            message: 'Search failed.',
            error: snapshot.error,
          );
        }
        final results = snapshot.data ?? [];
        if (results.isEmpty) {
          return const AppEmptyState(
            message: 'No products found',
            icon: Icons.search_off,
          );
        }
        return ListView.builder(
          padding: AppSpacing.pageAll,
          itemCount: results.length,
          itemBuilder: (context, i) => ProductCard(
            product: results[i],
            onTap: () {
              final selected = results[i];
              close(context, selected);
              onSelect?.call(selected);
            },
          ),
        );
      },
    );
  }
}
