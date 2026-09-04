import 'package:flutter/material.dart';

import 'package:save_some_ui/models/models.dart';
import 'package:save_some_ui/services/app_services.dart';
import 'package:save_some_ui/theme/tokens.dart';
import 'package:save_some_ui/widgets/cards/product.dart';
import 'package:save_some_ui/widgets/charts/price_sparkline.dart';
import 'package:save_some_ui/widgets/common/primary_button.dart';
import 'package:save_some_ui/widgets/common/product_search_delegate.dart';
import 'package:save_some_ui/widgets/common/search_field.dart';
import 'package:save_some_ui/widgets/common/section_header.dart';
import 'package:save_some_ui/widgets/common/state_views.dart';

/// Product price history and past searches — the design's history frame.
///
/// Doubles as the product detail view: tapping a card anywhere in the app opens
/// this with [initialProduct] set, which is why it takes an optional product
/// rather than always starting from the search field.
class HistoryScreen extends StatefulWidget {
  final String userId;
  final Product? initialProduct;

  const HistoryScreen({
    super.key,
    required this.userId,
    this.initialProduct,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _services = AppServices.instance;

  Product? _product;
  Future<List<ProductPrice>>? _priceHistory;
  late Future<List<SearchHistoryEntry>> _searches;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _searches = _services.users.fetchSearchHistory(widget.userId);
    final initial = widget.initialProduct;
    if (initial != null) _selectProduct(initial);
  }

  void _selectProduct(Product product) {
    setState(() {
      _product = product;
      _priceHistory = _services.products.fetchPriceHistory(product.id);
    });
  }

  Future<void> _refresh() async {
    final searches = _services.users.fetchSearchHistory(widget.userId);
    setState(() => _searches = searches);
    await searches;
  }

  void _openSearch() {
    showSearch(
      context: context,
      delegate: ProductSearchDelegate(
        productsService: _services.products,
        userId: widget.userId,
        onSelect: _selectProduct,
      ),
    ).then((_) {
      // Searching writes to search_history, so the list below is now stale.
      if (mounted) _refresh();
    });
  }

  Future<void> _saveProduct() async {
    final product = _product;
    if (product == null) return;

    setState(() => _saving = true);
    try {
      await _services.users.addToWatchlist(widget.userId, product.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tracking ${product.name}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\'t save that: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pushed as a detail route (has an initial product) vs shown as a tab.
    final isRoute = widget.initialProduct != null;

    final body = RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: AppSpacing.pageAll,
        children: [
          SearchField(hint: 'Search for products', onTap: _openSearch),
          const SizedBox(height: AppSpacing.xl),
          if (_product != null) ...[
            _ProductDetailCard(
              product: _product!,
              priceHistory: _priceHistory,
              saving: _saving,
              onSave: _saveProduct,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          const SectionHeader('Recent searches'),
          FutureBuilder<List<SearchHistoryEntry>>(
            future: _searches,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return AppErrorState(
                  message: 'Couldn\'t load your search history.',
                  error: snapshot.error,
                  onRetry: _refresh,
                );
              }
              if (!snapshot.hasData) return const AppLoading(compact: true);
              if (snapshot.data!.isEmpty) {
                return const AppEmptyState(
                  message: 'Nothing searched yet',
                  icon: Icons.history,
                );
              }
              return Column(
                children: [
                  for (final entry in snapshot.data!)
                    _SearchHistoryRow(entry: entry),
                ],
              );
            },
          ),
        ],
      ),
    );

    if (!isRoute) return body;
    return Scaffold(
      appBar: AppBar(title: Text(_product?.name ?? 'Price history')),
      body: SafeArea(child: body),
    );
  }
}

/// The expanded product card from the design: retailer row, price chart,
/// description, then Options and Save Product.
class _ProductDetailCard extends StatelessWidget {
  final Product product;
  final Future<List<ProductPrice>>? priceHistory;
  final bool saving;
  final VoidCallback onSave;

  const _ProductDetailCard({
    required this.product,
    required this.priceHistory,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.retailerName ?? product.brand ?? 'Product',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (product.price != null)
                  PriceRow(
                    price: product.price!,
                    originalPrice: product.originalPrice,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            FutureBuilder<List<ProductPrice>>(
              future: priceHistory,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return AppErrorState(
                    message: 'Couldn\'t load price history.',
                    error: snapshot.error,
                  );
                }
                if (!snapshot.hasData) return const AppLoading();
                return PriceSparkline(prices: snapshot.data!);
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(product.name, style: theme.textTheme.titleMedium),
            if (product.description != null &&
                product.description!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                product.description!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: AppSpacing.sm,
              children: [
                SecondaryButton(
                  label: 'Options',
                  onPressed: () => _showOptions(context),
                ),
                AccentButton(
                  label: 'Save Product',
                  busy: saving,
                  onPressed: onSave,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Set a price alert'),
              // TODO: needs a target-price input; the watchlist endpoint already
              // accepts target_price.
              onTap: () => Navigator.of(context).pop(),
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('View at retailer'),
              // TODO: retailer_products.product_url isn't returned by the
              // products endpoints yet.
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchHistoryRow extends StatelessWidget {
  final SearchHistoryEntry entry;

  const _SearchHistoryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        child: ListTile(
          leading: Icon(Icons.history, color: scheme.onSurfaceVariant),
          title: Text(entry.query),
          subtitle: Text(_relative(entry.searchedAt)),
        ),
      ),
    );
  }

  /// Coarse relative time. `intl` isn't a dependency and one date format doesn't
  /// justify adding it.
  static String _relative(DateTime when) {
    final elapsed = DateTime.now().difference(when);
    if (elapsed.inMinutes < 1) return 'just now';
    if (elapsed.inMinutes < 60) return '${elapsed.inMinutes}m ago';
    if (elapsed.inHours < 24) return '${elapsed.inHours}h ago';
    return '${elapsed.inDays}d ago';
  }
}
