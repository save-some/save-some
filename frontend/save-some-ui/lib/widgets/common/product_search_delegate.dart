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
  bool _closed = false;

  /// Stops the pending debounce. Both exits below funnel through this, because
  /// otherwise a timer armed by the last keystroke fires after the search UI is
  /// gone and issues a request whose result nobody wants.
  ///
  /// Idempotent: nothing calls SearchDelegate.dispose for a delegate created
  /// inline at a showSearch call site, so close() has to do the teardown too.
  void _cancelPending() {
    _closed = true;
    _debounce?.cancel();
    _debounce = null;
  }

  @override
  void dispose() {
    _cancelPending();
    super.dispose();
  }

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

  @override
  void close(BuildContext context, Product? result) {
    _cancelPending();
    super.close(context, result);
  }

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
    // Reuse only while the *same* query is still resolving. This used to hold on
    // to the completed future for the rest of the session, so re-running a search
    // replayed the first result set even if prices had moved since.
    final pending = _pendingSearch;
    if (_pendingQuery == q && pending != null && !_settled) {
      return pending;
    }

    _debounce?.cancel();
    final completer = Completer<List<Product>>();
    _pendingQuery = q;
    _pendingSearch = completer.future;
    _settled = false;

    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (_closed) return;
      productsService.search(q, userId: log ? userId : null).then(
        (results) {
          _settled = true;
          if (!completer.isCompleted) completer.complete(results);
        },
        onError: (Object error, StackTrace stack) {
          _settled = true;
          if (!completer.isCompleted) completer.completeError(error, stack);
        },
      );
    });
    return completer.future;
  }

  /// True once the current query's request has returned, which is what makes the
  /// cache above a de-duplicator rather than a permanent memo.
  bool _settled = false;

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
