import 'package:flutter/material.dart';

import 'package:save_some_ui/models/models.dart';
import 'package:save_some_ui/screens/product_detail.dart';
import 'package:save_some_ui/services/app_services.dart';
import 'package:save_some_ui/state/recently_viewed.dart';
import 'package:save_some_ui/theme/tokens.dart';
import 'package:save_some_ui/util/format.dart';
import 'package:save_some_ui/widgets/cards/product.dart';
import 'package:save_some_ui/widgets/common/app_card.dart';
import 'package:save_some_ui/widgets/common/product_search_delegate.dart';
import 'package:save_some_ui/widgets/common/product_thumb.dart';
import 'package:save_some_ui/widgets/common/search_field.dart';
import 'package:save_some_ui/widgets/common/section_header.dart';
import 'package:save_some_ui/widgets/common/state_views.dart';

/// What this user has been looking at: products they've opened, products they're
/// tracking, and the searches that got them there.
///
/// Previously this tab showed only a list of bare search strings unless a product
/// had been passed in, so it read as empty. Now it leads with products — each with
/// its image — which is what the design shows.
class HistoryScreen extends StatefulWidget {
  final String userId;

  const HistoryScreen({super.key, required this.userId});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _services = AppServices.instance;

  late Future<List<SearchHistoryEntry>> _searches;

  @override
  void initState() {
    super.initState();
    _searches = _services.users.fetchSearchHistory(widget.userId);
  }

  Future<void> _refresh() async {
    final searches = _services.users.fetchSearchHistory(widget.userId);
    setState(() => _searches = searches);
    await Future.wait([
      searches,
      _services.watchlist.load(widget.userId),
    ]);
  }

  void _openSearch({String? initialQuery}) {
    showSearch(
      context: context,
      query: initialQuery ?? '',
      delegate: ProductSearchDelegate(
        productsService: _services.products,
        userId: widget.userId,
        onSelect: _openProduct,
      ),
    ).then((_) {
      // Submitting a search writes to search_history, so the list below is stale.
      if (mounted) _refresh();
    });
  }

  void _openProduct(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailScreen(
          userId: widget.userId,
          product: product,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: AppSpacing.pageAll,
        children: [
          SearchField(
            hint: 'Search for products',
            onTap: () => _openSearch(),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Recently viewed, with images — the products this tab is about.
          ListenableBuilder(
            listenable: RecentlyViewed.instance,
            builder: (context, _) {
              final recent = RecentlyViewed.instance.products;
              if (recent.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader('Recently viewed'),
                  _RecentStrip(products: recent, onSelect: _openProduct),
                  const SizedBox(height: AppSpacing.xl),
                ],
              );
            },
          ),

          // Tracked products, so this tab is useful on a first visit too.
          ListenableBuilder(
            listenable: _services.watchlist,
            builder: (context, _) {
              final tracked = _services.watchlist.products;
              if (tracked.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader('Tracking'),
                  for (final product in tracked)
                    ProductCard(
                      product: product,
                      onTap: () => _openProduct(product),
                    ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              );
            },
          ),

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
                    _SearchHistoryRow(
                      entry: entry,
                      // Tapping a past search re-runs it, which is the only
                      // reason to show it.
                      onTap: () => _openSearch(initialQuery: entry.query),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

/// A horizontal strip of image-led product tiles. Horizontal because recency is
/// browsable rather than something to read top to bottom, and it keeps the
/// searches below on screen.
class _RecentStrip extends StatelessWidget {
  final List<Product> products;
  final void Function(Product) onSelect;

  const _RecentStrip({required this.products, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final product = products[i];
          return SizedBox(
            width: 132,
            child: AppCard(
              onTap: () => onSelect(product),
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: ProductThumb(
                      seed: product.id,
                      productName: product.name,
                      imageUrl: product.imageUrl,
                      size: 84,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  if (product.price != null)
                    Text(
                      formatUsd(product.price!),
                      style: theme.textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SearchHistoryRow extends StatelessWidget {
  final SearchHistoryEntry entry;
  final VoidCallback? onTap;

  const _SearchHistoryRow({required this.entry, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(Icons.history, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(entry.query, style: theme.textTheme.bodyLarge),
            ),
            Text(
              formatRelative(entry.searchedAt),
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.north_west, size: 16, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
