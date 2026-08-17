import 'package:flutter/material.dart';

import 'package:save_some_ui/config/env.dart';
import 'package:save_some_ui/models/models.dart';
import 'package:save_some_ui/services/api_client.dart';
import 'package:save_some_ui/services/products_service.dart';
import 'package:save_some_ui/services/retailers_service.dart';
import 'package:save_some_ui/services/users_service.dart';
import 'package:save_some_ui/widgets/cards/product.dart';
import 'package:save_some_ui/widgets/common/product_search_delegate.dart';

class ProductScreen extends StatefulWidget {
  final String userId;
  const ProductScreen({super.key, required this.userId});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  late final RetailersService _retailersService;
  late final ProductsService _productsService;
  late final UsersService _usersService;

  late Future<List<Retailer>> _retailers;
  late Future<List<Product>> _watchlist;
  late Future<List<Product>> _browseProducts;

  final Set<String> _selectedRetailerIds = {};

  @override
  void initState() {
    super.initState();
    // TODO: same as home.dart — this should come from one shared
    // ApiClient injected higher up, not constructed per screen.
    final client = ApiClient(baseUrl: Env.apiBaseUrl);
    _retailersService = RetailersService(client);
    _productsService = ProductsService(client);
    _usersService = UsersService(client);

    _retailers = _retailersService.fetchAll();
    _watchlist = _usersService.fetchWatchlist(widget.userId);
    _browseProducts = _retailersService.fetchProducts();
  }

  void _toggleRetailer(String retailerId) {
    setState(() {
      if (_selectedRetailerIds.contains(retailerId)) {
        _selectedRetailerIds.remove(retailerId);
      } else {
        _selectedRetailerIds.add(retailerId);
      }
      _browseProducts = _retailersService.fetchProducts(
        retailerIds: _selectedRetailerIds.isEmpty ? null : _selectedRetailerIds,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          _SearchBar(productsService: _productsService),
          const SizedBox(height: 24),
          Text(
            'Retailers',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Retailer>>(
            future: _retailers,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 32,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }
              if (snapshot.data!.isEmpty) {
                return Text('No retailers yet', style: TextStyle(color: Colors.grey[500]));
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: snapshot.data!.map((r) {
                  final selected = _selectedRetailerIds.contains(r.id);
                  return FilterChip(
                    label: Text(r.name),
                    selected: selected,
                    onSelected: (_) => _toggleRetailer(r.id),
                    backgroundColor: Colors.grey[100],
                    selectedColor: Colors.deepPurple[100],
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Your Products',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Product>>(
            future: _watchlist,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.isEmpty) {
                return Text('Nothing tracked yet', style: TextStyle(color: Colors.grey[500]));
              }
              return Column(
                children: snapshot.data!
                    .map((w) => ProductCard(product: w))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          FutureBuilder<List<Product>>(
            future: _browseProducts,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text('Couldn\'t load products: ${snapshot.error}');
              }
              if (snapshot.data!.isEmpty) {
                return Text('No products found', style: TextStyle(color: Colors.grey[500]));
              }
              return Column(
                children: snapshot.data!
                    .map((p) => ProductCard(product: p))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Tappable bar that looks like a search field but opens the full-screen
/// search modal (showSearch) rather than being a real inline TextField —
/// keeps typing/debounce/results entirely inside ProductSearchDelegate.
class _SearchBar extends StatelessWidget {
  final ProductsService productsService;
  const _SearchBar({required this.productsService});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey[100],
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showSearch(
          context: context,
          delegate: ProductSearchDelegate(productsService: productsService),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.menu, color: Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Search for products', style: TextStyle(color: Colors.grey[600])),
              ),
              const Icon(Icons.search, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}