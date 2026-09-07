import 'package:flutter/material.dart';

import 'package:save_some_ui/models/models.dart';
import 'package:save_some_ui/screens/product_detail.dart';
import 'package:save_some_ui/services/app_services.dart';
import 'package:save_some_ui/state/data_revision.dart';
import 'package:save_some_ui/theme/tokens.dart';
import 'package:save_some_ui/widgets/cards/product_grid.dart';
import 'package:save_some_ui/widgets/common/chip_group.dart';
import 'package:save_some_ui/widgets/common/page_width.dart';
import 'package:save_some_ui/widgets/common/product_search_delegate.dart';
import 'package:save_some_ui/widgets/common/search_field.dart';
import 'package:save_some_ui/widgets/common/section_header.dart';
import 'package:save_some_ui/widgets/common/state_views.dart';

/// Browse and search products, filtered by retailer chips.
class ProductScreen extends StatefulWidget {
  final String userId;
  const ProductScreen({super.key, required this.userId});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> with RevisionAware {
  final _services = AppServices.instance;

  late Future<List<Retailer>> _retailers;

  final Set<String> _selectedRetailerIds = {};

  /// Order-independent selection identity: re-selecting a set already seen
  /// reuses the browse state instead of remounting it (Set.toString is
  /// insertion-ordered, which would churn).
  String get _browseKey => (_selectedRetailerIds.toList()..sort()).join(',');

  @override
  void initState() {
    super.initState();
    _retailers = _services.retailers.fetchAll();
    // "Your Products" reads the shared controller rather than fetching its own
    // copy — otherwise untracking something on another tab left it visible here
    // until a manual refresh, which is the exact disagreement the controller
    // exists to prevent.
    if (!_services.watchlist.isLoaded) {
      _services.watchlist.load(widget.userId);
    }
  }

  void _toggleRetailer(String retailerId) {
    setState(() {
      if (!_selectedRetailerIds.remove(retailerId)) {
        _selectedRetailerIds.add(retailerId);
      }
      // The browse section keys off the selection and reloads itself; no
      // future to reassign here any more.
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _retailers = _services.retailers.fetchAll();
    });
    await Future.wait([_retailers, _services.watchlist.load(widget.userId)]);
  }

  @override
  void onDataRevision() => _refresh();

  void _openSearch() {
    // Tapping a result closes the delegate with that product; open its
    // detail. The returned value used to be dropped — a result tap did
    // nothing beyond dismissing the search.
    showSearch<Product?>(
      context: context,
      delegate: ProductSearchDelegate(
        productsService: _services.products,
        userId: widget.userId,
      ),
    ).then((product) {
      if (product == null || !mounted) return;
      _openProduct(product);
    });
  }

  void _openProduct(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ProductDetailScreen(userId: widget.userId, product: product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: PageWidth(
        wide: true,
        child: ListView(
          padding: AppSpacing.pageAll,
          children: [
            SearchField(hint: 'Search for products', onTap: _openSearch),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader('Retailers'),
            FutureBuilder<List<Retailer>>(
              future: _retailers,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return AppErrorState(
                    message: 'Couldn\'t load retailers.',
                    error: snapshot.error,
                    onRetry: _refresh,
                  );
                }
                if (!snapshot.hasData) return const AppLoading(compact: true);
                if (snapshot.data!.isEmpty) {
                  return const AppEmptyState(message: 'No retailers yet');
                }
                return FilterChipGroup(
                  options: [
                    for (final r in snapshot.data!) (id: r.id, label: r.name),
                  ],
                  selectedIds: _selectedRetailerIds,
                  onToggle: _toggleRetailer,
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader('Your Products'),
            ListenableBuilder(
              listenable: _services.watchlist,
              builder: (context, _) {
                final watchlist = _services.watchlist;
                if (watchlist.error != null) {
                  return AppErrorState(
                    message: 'Couldn\'t load your tracked products.',
                    error: watchlist.error,
                    onRetry: _refresh,
                  );
                }
                if (!watchlist.isLoaded) {
                  return const AppLoading(compact: true);
                }
                if (watchlist.products.isEmpty) {
                  return const AppEmptyState(
                    message: 'Nothing tracked yet',
                    icon: Icons.bookmark_border,
                  );
                }
                return ProductGrid(
                  products: watchlist.products,
                  onTap: _openProduct,
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(
              _selectedRetailerIds.isEmpty
                  ? 'Browse all retailers'
                  : 'Browse ${_selectedRetailerIds.length} selected',
            ),
            // Keyed by the selection so toggling a chip gives it a fresh
            // state rather than appending page one of the new filter onto
            // the old list.
            _Browse(
              // Keyed by the (sorted) selection so toggling a chip rebuilds
              // the browse with a fresh page one, while re-selecting a set
              // already seen keeps the loaded pages.
              key: ValueKey(_browseKey),
              retailerIds: _selectedRetailerIds,
              onOpen: _openProduct,
            ),
          ],
        ),
      ),
    );
  }
}

/// Paginated browse list with an explicit "Show more".
///
/// The whole catalogue used to arrive as one 50-item fetch with no way to see
/// past it; a web visitor could reach the end of the page and find nothing to
/// click. Pages of 24, appended on demand, with the grid filling desktop
/// columns.
class _Browse extends StatefulWidget {
  final Set<String> retailerIds;
  final ValueChanged<Product> onOpen;

  const _Browse({super.key, required this.retailerIds, required this.onOpen});

  @override
  State<_Browse> createState() => _BrowseState();
}

class _BrowseState extends State<_Browse> {
  static const _pageSize = 24;

  final _services = AppServices.instance;
  List<Product> _items = const [];
  bool _loading = true;
  bool _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _fetch(reset: true);
  }

  Future<void> _fetch({required bool reset}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _services.retailers.fetchProducts(
        retailerIds: widget.retailerIds.isEmpty ? null : widget.retailerIds,
        limit: _pageSize,
        offset: reset ? 0 : _items.length,
      );
      if (!mounted) return;
      setState(() {
        _items = reset ? page : [..._items, ...page];
        _hasMore = page.length == _pageSize;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_error != null && _items.isEmpty) {
      return AppErrorState(
        message: 'Couldn\'t load products.',
        error: _error,
        onRetry: () => _fetch(reset: true),
      );
    }
    if (_loading && _items.isEmpty) return const AppLoading();
    if (_items.isEmpty) {
      return const AppEmptyState(
        message: 'No products found',
        icon: Icons.search_off,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProductGrid(products: _items, onTap: widget.onOpen),
        const SizedBox(height: AppSpacing.lg),
        if (_hasMore)
          Center(
            child: TextButton.icon(
              onPressed: _loading ? null : () => _fetch(reset: false),
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more, size: 18),
              label: Text(
                _loading ? 'Loading…' : 'Show more (${_items.length} shown)',
              ),
            ),
          )
        else
          Text(
            '${_items.length} products',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
