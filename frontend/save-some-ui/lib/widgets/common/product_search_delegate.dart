import 'dart:async';
import 'package:flutter/material.dart';
import 'package:save_some_ui/models/models.dart';
import 'package:save_some_ui/services/products_service.dart';
import 'package:save_some_ui/widgets/cards/product.dart';

/// Full-screen search UI, pushed on top of the current page by
/// showSearch(). Gives back/X-to-close for free — no custom overlay
/// needed. Debounces keystrokes so rapid typing doesn't fire a request
/// per character.
class ProductSearchDelegate extends SearchDelegate<void> {
  final ProductsService productsService;

  ProductSearchDelegate({required this.productsService});

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

  @override
  Widget buildResults(BuildContext context) => _resultsList(query);

  @override
  Widget buildSuggestions(BuildContext context) => _resultsList(query);

  /// Cancels any pending debounce timer and starts a new one. Rapid
  /// keystrokes keep resetting the timer, so only the last keystroke in
  /// a burst actually triggers a network call, ~300ms after typing stops.
  Future<List<Product>> _debouncedSearch(String q) {
    if (_pendingQuery == q && _pendingSearch != null) {
      return _pendingSearch!;
    }
    _debounce?.cancel();
    final completer = Completer<List<Product>>();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      productsService.search(q).then(completer.complete, onError: completer.completeError);
    });
    _pendingQuery = q;
    _pendingSearch = completer.future;
    return completer.future;
  }

  Widget _resultsList(String q) {
    final trimmed = q.trim();
    if (trimmed.isEmpty) {
      return const Center(child: Text('Search for a product'));
    }

    return FutureBuilder<List<Product>>(
      future: _debouncedSearch(trimmed),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Search failed: ${snapshot.error}'));
        }
        final results = snapshot.data ?? [];
        if (results.isEmpty) {
          return const Center(child: Text('No products found'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: results.length,
          itemBuilder: (context, i) => ProductCard(product: results[i]),
        );
      },
    );
  }
}