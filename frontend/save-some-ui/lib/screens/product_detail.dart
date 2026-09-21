import 'package:flutter/material.dart';

import 'package:save_some_ui/models/models.dart';
import 'package:save_some_ui/screens/retailer_detail.dart';
import 'package:save_some_ui/services/app_services.dart';
import 'package:save_some_ui/state/recently_viewed.dart';
import 'package:save_some_ui/theme/tokens.dart';
import 'package:save_some_ui/util/format.dart';
import 'package:save_some_ui/widgets/charts/price_history_chart.dart';
import 'package:save_some_ui/widgets/common/app_card.dart';
import 'package:save_some_ui/widgets/common/offer_list.dart';
import 'package:save_some_ui/widgets/common/product_thumb.dart';
import 'package:save_some_ui/widgets/common/save_button.dart';
import 'package:save_some_ui/widgets/common/page_width.dart';
import 'package:save_some_ui/widgets/common/section_header.dart';
import 'package:save_some_ui/widgets/common/state_views.dart';

/// One product: image, current price, history chart, and the same product at
/// every other retailer.
///
/// Previously this lived inside the history screen, which meant the comparison
/// and the chart were only reachable from one tab. Now any product card anywhere
/// opens this.
class ProductDetailScreen extends StatefulWidget {
  final String userId;
  final Product product;

  const ProductDetailScreen({
    super.key,
    required this.userId,
    required this.product,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _services = AppServices.instance;

  late Future<List<ProductPrice>> _priceHistory;
  late Future<List<ProductOffer>> _offers;

  @override
  void initState() {
    super.initState();
    _load();
    // Feeds the history tab's "recently viewed" list.
    RecentlyViewed.instance.record(widget.product);
  }

  void _load() {
    _priceHistory = _services.products.fetchPriceHistory(widget.product.id);
    _offers = _services.products.fetchOffers(widget.product.id).then((o) {
      _offersCache = o;
      return o;
    });
  }

  /// Latest offers result, so the price chart can label its lines without
  /// awaiting the offers future inside the price FutureBuilder (they load in
  /// parallel). Empty until the first fetch lands; the chart then has one
  /// unnamed line, which beats serialising the two requests.
  List<ProductOffer> _offersCache = const [];

  Future<void> _refresh() async {
    setState(_load);
    await Future.wait([_priceHistory, _offers]);
  }

  void _openRetailer(String retailerId, String retailerName) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RetailerDetailScreen(
          userId: widget.userId,
          retailerId: retailerId,
          retailerName: retailerName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final product = widget.product;

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: PageWidth(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: AppSpacing.pageAll,
              children: [
                AppCard(
                  raised: true,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // The product image the design calls for, at a size
                          // that's worth looking at rather than a list thumbnail.
                          ProductThumb(
                            seed: product.id,
                            productName: product.name,
                            imageUrl: product.imageUrl,
                            size: 96,
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (product.brand != null)
                                  Text(
                                    product.brand!,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                Text(
                                  product.name,
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                if (product.price != null)
                                  _PriceHeadline(product: product),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (product.description != null &&
                          product.description!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          product.description!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: SaveButton(product: product, extended: true),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const SectionHeader('Price history'),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: FutureBuilder<List<ProductPrice>>(
                    future: _priceHistory,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return AppErrorState(
                          message: 'Couldn\'t load price history.',
                          error: snapshot.error,
                          onRetry: _refresh,
                        );
                      }
                      if (!snapshot.hasData) return const AppLoading();
                      // Offers are already loaded alongside (the comparison
                      // below); reused here only to name each retailer's line.
                      return _PriceHistoryBlock(
                        prices: snapshot.data!,
                        offers: _offersCache,
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const SectionHeader('Also available at'),
                FutureBuilder<List<ProductOffer>>(
                  future: _offers,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return AppErrorState(
                        message: 'Couldn\'t load other retailers.',
                        error: snapshot.error,
                        onRetry: _refresh,
                      );
                    }
                    if (!snapshot.hasData) return const AppLoading();
                    return OfferList(
                      offers: snapshot.data!,
                      onSelect: (offer) =>
                          _openRetailer(offer.retailerId, offer.retailerName),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PriceHeadline extends StatelessWidget {
  final Product product;

  const _PriceHeadline({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              formatUsd(product.price!),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (product.isDiscounted) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                formatUsd(product.originalPrice!),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        if (product.isDiscounted)
          Text(
            'down ${formatUsd(product.originalPrice! - product.price!)}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (product.targetPrice != null)
          Text(
            'alerting below ${formatUsd(product.targetPrice!)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// The chart plus the numbers that make it legible — a bare line says nothing
/// about whether now is a good time to buy.
class _PriceHistoryBlock extends StatelessWidget {
  final List<ProductPrice> prices;
  final List<ProductOffer> offers;

  const _PriceHistoryBlock({required this.prices, required this.offers});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (prices.isEmpty) {
      return const AppEmptyState(
        message: 'No price history recorded yet',
        icon: Icons.show_chart,
      );
    }

    // Group by retailer: two chains that both carry this product have their
    // own line. The service already hands history oldest-first, so groups
    // stay chronological by construction. Retailers with no offer row (a
    // price whose offer was removed) still get a line, just unnamed.
    final byRetailer = <String, List<ProductPrice>>{};
    for (final p in prices) {
      byRetailer.putIfAbsent(p.retailerId ?? '?', () => []).add(p);
    }
    final nameFor = {for (final o in offers) o.retailerId: o.retailerName};
    final palette = PriceHistoryChart.paletteFor(scheme);
    final series = <PriceSeries>[];
    var i = 0;
    // Cheapest-current-first so the line you'd act on is the first colour.
    final entries = byRetailer.entries.toList()
      ..sort((a, b) => a.value.last.price.compareTo(b.value.last.price));
    for (final e in entries) {
      series.add(
        PriceSeries(
          label: nameFor[e.key] ?? 'Other',
          color: palette[i % palette.length],
          points: e.value,
        ),
      );
      i++;
    }

    final values = prices.map((p) => p.price).toList()..sort();
    final low = values.first;
    final high = values.last;
    // "now" is the newest observation overall, not one retailer's.
    final newest = prices.reduce(
      (a, b) => a.scrapedAt.isAfter(b.scrapedAt) ? a : b,
    );
    final current = newest.price;

    return Column(
      children: [
        if (series.length > 1) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Across ${series.length} retailers',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        PriceHistoryChart(series: series),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Stat(
              label: 'lowest',
              value: formatUsd(low),
              highlight: current <= low,
            ),
            _Stat(label: 'now', value: formatUsd(current)),
            _Stat(label: 'highest', value: formatUsd(high)),
          ],
        ),
        if (current <= low) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'This is the lowest price we\'ve seen',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _Stat({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: highlight ? scheme.primary : null,
          ),
        ),
      ],
    );
  }
}
