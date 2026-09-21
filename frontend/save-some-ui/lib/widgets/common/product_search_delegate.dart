import 'dart:async';

import 'package:flutter/material.dart';

import 'package:save_some_ui/models/models.dart';
import 'package:save_some_ui/services/products_service.dart';
import 'package:save_some_ui/state/data_revision.dart';
import 'package:save_some_ui/theme/tokens.dart';
import 'package:save_some_ui/widgets/cards/product.dart';
import 'package:save_some_ui/widgets/common/page_width.dart';
import 'package:save_some_ui/widgets/common/section_header.dart';
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

  /// SearchDelegate renders the query TextField as the AppBar title, so the
  /// app's titleLarge + centerTitle heading style (right for page headings,
  /// wrong for an input) showed the typed query as oversized text floating in
  /// the middle of the bar. The delegate merges this ThemeData over the
  /// ambient theme for its own bar — scope the title back to body text,
  /// leading-aligned.
  @override
  ThemeData appBarTheme(BuildContext context) {
    final base = super.appBarTheme(context);
    final text = base.textTheme;
    return base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(
        centerTitle: false,
        titleTextStyle: text.bodyLarge,
      ),
      // The TextField inherits the title style directly in some paths.
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        hintStyle: text.bodyLarge?.copyWith(
          color: base.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
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
      productsService
          .search(q, userId: log ? userId : null)
          .then(
            (results) {
              _settled = true;
              if (log) DataRevision.instance.bump();
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
      // An open search box with nothing typed is the best slot in the app
      // for "start here": price drops inside the categories this user said
      // they care about, instead of a dead prompt.
      return userId == null ? _prompt : _recommendations();
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
        // The delegate's page is its own Scaffold — cap it like every other
        // screen, or desktop gets cards stretched across 1440px again.
        return PageWidth(
          child: ListView.builder(
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
          ),
        );
      },
    );
  }

  static const _prompt = AppEmptyState(
    message: 'Search for a product',
    icon: Icons.search,
  );

  /// The empty-state body: one FutureBuilder over the interest-ranked drops,
  /// rendered with the same card list as live results so a tap behaves the
  /// same from either state. Failures degrade to the plain prompt rather
  /// than an error page — this is a courtesy list, not the search.
  Widget _recommendations() {
    return FutureBuilder<List<Product>>(
      future: productsService.fetchRecommended(userId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoading();
        }
        final picks = snapshot.data ?? const <Product>[];
        if (snapshot.hasError || picks.isEmpty) return _prompt;
        return PageWidth(
          child: ListView(
            padding: AppSpacing.pageAll,
            children: [
              const SectionHeader('Recommended for you', muted: true),
              for (final p in picks.take(10))
                ProductCard(
                  product: p,
                  onTap: () {
                    close(context, p);
                    onSelect?.call(p);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
