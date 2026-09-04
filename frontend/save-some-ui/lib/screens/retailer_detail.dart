import 'package:flutter/material.dart';

import 'package:save_some_ui/models/models.dart';
import 'package:save_some_ui/screens/product_detail.dart';
import 'package:save_some_ui/services/app_services.dart';
import 'package:save_some_ui/theme/tokens.dart';
import 'package:save_some_ui/widgets/cards/product.dart';
import 'package:save_some_ui/widgets/cards/store.dart';
import 'package:save_some_ui/widgets/common/avatar_badge.dart';
import 'package:save_some_ui/widgets/common/section_header.dart';
import 'package:save_some_ui/widgets/common/state_views.dart';

/// One retailer: what it stocks, where its nearby stores are, and whether the
/// user follows it.
///
/// Following writes `user_retailers`, which is what scopes the maps screen's chip
/// row — so this is the only place that set could previously be changed at all,
/// and it wasn't reachable.
class RetailerDetailScreen extends StatefulWidget {
  final String userId;
  final String retailerId;
  final String retailerName;

  const RetailerDetailScreen({
    super.key,
    required this.userId,
    required this.retailerId,
    required this.retailerName,
  });

  @override
  State<RetailerDetailScreen> createState() => _RetailerDetailScreenState();
}

class _RetailerDetailScreenState extends State<RetailerDetailScreen> {
  final _services = AppServices.instance;

  late Future<List<Product>> _products;
  late Future<List<Store>> _stores;

  bool? _following;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _products = _services.retailers.fetchProducts(
      retailerIds: {widget.retailerId},
    );
    _stores = _services.retailers.fetchNearbyStores(
      lat: _anchorLat,
      lng: _anchorLng,
      retailerIds: {widget.retailerId},
    );
    _loadFollowing();
  }

  // TODO: share one geo anchor with the maps screen once device location or
  // zipcode geocoding lands; duplicated constants will drift.
  static const _anchorLat = 40.7439;
  static const _anchorLng = -74.0324;

  Future<void> _loadFollowing() async {
    try {
      final followed = await _services.users.fetchRetailers(widget.userId);
      if (!mounted) return;
      setState(() =>
          _following = followed.any((r) => r.id == widget.retailerId));
    } catch (_) {
      // Leave it unknown rather than claiming "not following" — the button shows
      // a neutral state until we actually know.
    }
  }

  Future<void> _toggleFollow() async {
    final wasFollowing = _following ?? false;
    setState(() {
      _busy = true;
      _following = !wasFollowing;
    });
    try {
      if (wasFollowing) {
        await _services.users.unfollowRetailer(widget.userId, widget.retailerId);
      } else {
        await _services.users.followRetailer(widget.userId, widget.retailerId);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _following = wasFollowing);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\'t update that: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
    final theme = Theme.of(context);
    final following = _following ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(widget.retailerName)),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.pageAll,
          children: [
            Row(
              children: [
                AvatarBadge(source: widget.retailerName, size: 56),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Text(
                    widget.retailerName,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _toggleFollow,
                  icon: Icon(
                    following ? Icons.check : Icons.add,
                    size: 18,
                  ),
                  label: Text(following ? 'Following' : 'Follow'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader('Products'),
            FutureBuilder<List<Product>>(
              future: _products,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return AppErrorState(
                    message: 'Couldn\'t load this retailer\'s products.',
                    error: snapshot.error,
                  );
                }
                if (!snapshot.hasData) return const AppLoading();
                if (snapshot.data!.isEmpty) {
                  return const AppEmptyState(
                    message: 'Nothing tracked from this retailer yet',
                    icon: Icons.inventory_2_outlined,
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
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader('Stores near you'),
            FutureBuilder<List<Store>>(
              future: _stores,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const AppLoading(compact: true);
                if (snapshot.data!.isEmpty) {
                  return const AppEmptyState(
                    message: 'No stores within 25 miles',
                    icon: Icons.storefront_outlined,
                  );
                }
                return Column(
                  children: [
                    for (final store in snapshot.data!)
                      StoreCard(store: store, retailerName: widget.retailerName),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
