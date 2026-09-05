import 'package:flutter/material.dart';

import 'package:save_some_ui/models/models.dart';
import 'package:save_some_ui/screens/product_detail.dart';
import 'package:save_some_ui/services/app_services.dart';
import 'package:save_some_ui/theme/tokens.dart';
import 'package:save_some_ui/widgets/cards/product.dart';
import 'package:save_some_ui/widgets/common/chip_group.dart';
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

class _ProductScreenState extends State<ProductScreen> {
  final _services = AppServices.instance;

  late Future<List<Retailer>> _retailers;
  late Future<List<Product>> _browseProducts;

  final Set<String> _selectedRetailerIds = {};

  @override
  void initState() {
    super.initState();
    _retailers = _services.retailers.fetchAll();
    _browseProducts = _services.retailers.fetchProducts();
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
      _browseProducts = _services.retailers.fetchProducts(
        retailerIds:
            _selectedRetailerIds.isEmpty ? null : _selectedRetailerIds,
      );
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _retailers = _services.retailers.fetchAll();
      _browseProducts = _services.retailers.fetchProducts(
        retailerIds:
            _selectedRetailerIds.isEmpty ? null : _selectedRetailerIds,
      );
    });
    await Future.wait([
      _retailers,
      _browseProducts,
      _services.watchlist.load(widget.userId),
    ]);
  }

  void _openSearch() {
    showSearch(
      context: context,
      delegate: ProductSearchDelegate(
        productsService: _services.products,
        userId: widget.userId,
      ),
    );
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
              if (!watchlist.isLoaded) return const AppLoading(compact: true);
              if (watchlist.products.isEmpty) {
                return const AppEmptyState(
                  message: 'Nothing tracked yet',
                  icon: Icons.bookmark_border,
                );
              }
              return Column(
                children: [
                  for (final product in watchlist.products)
                    ProductCard(
                      product: product,
                      onTap: () => _openProduct(product),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            _selectedRetailerIds.isEmpty
                ? 'Browse all retailers'
                : 'Browse ${_selectedRetailerIds.length} selected',
          ),
          FutureBuilder<List<Product>>(
            future: _browseProducts,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return AppErrorState(
                  message: 'Couldn\'t load products.',
                  error: snapshot.error,
                  onRetry: _refresh,
                );
              }
              if (!snapshot.hasData) return const AppLoading();
              if (snapshot.data!.isEmpty) {
                return const AppEmptyState(
                  message: 'No products found',
                  icon: Icons.search_off,
                );
              }
              return Column(
                children: [
                  for (final product in snapshot.data!)
                    ProductCard(
                      product: product,
                      onTap: () => _openProduct(product),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
