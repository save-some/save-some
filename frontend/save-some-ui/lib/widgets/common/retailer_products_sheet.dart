import 'package:flutter/material.dart';

import 'package:save_some_ui/models/models.dart';
import 'package:save_some_ui/screens/product_detail.dart';
import 'package:save_some_ui/services/app_services.dart';
import 'package:save_some_ui/theme/tokens.dart';
import 'package:save_some_ui/widgets/cards/product.dart';
import 'package:save_some_ui/widgets/common/avatar_badge.dart';
import 'package:save_some_ui/widgets/common/state_views.dart';

/// What a retailer carries, in a sheet.
///
/// The small popup the maps screen needs: seeing a chain's products shouldn't
/// mean losing the map. Deliberately capped and scrollable rather than a full
/// screen — the full list is a tap further, on the retailer's own page.
class RetailerProductsSheet extends StatefulWidget {
  final String userId;
  final String retailerId;
  final String retailerName;

  /// Opens the retailer's full page. The sheet only shows the first few.
  final VoidCallback onOpenRetailer;

  const RetailerProductsSheet({
    super.key,
    required this.userId,
    required this.retailerId,
    required this.retailerName,
    required this.onOpenRetailer,
  });

  @override
  State<RetailerProductsSheet> createState() => _RetailerProductsSheetState();
}

class _RetailerProductsSheetState extends State<RetailerProductsSheet> {
  late Future<List<Product>> _products;

  @override
  void initState() {
    super.initState();
    _products = AppServices.instance.retailers
        .fetchProducts(retailerIds: {widget.retailerId}, limit: 8);
  }

  void _openProduct(Product product) {
    // Close the sheet first, so back from the detail returns to the map.
    Navigator.of(context).pop();
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

    return SafeArea(
      child: ConstrainedBox(
        // Leaves the map visible behind the sheet.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Padding(
          padding: AppSpacing.pageH,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AvatarBadge(source: widget.retailerName, size: 36),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      widget.retailerName,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onOpenRetailer,
                    child: const Text('See all'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Flexible(
                child: FutureBuilder<List<Product>>(
                  future: _products,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return AppErrorState(
                        message: 'Couldn\'t load these products.',
                        error: snapshot.error,
                      );
                    }
                    if (!snapshot.hasData) return const AppLoading();
                    if (snapshot.data!.isEmpty) {
                      return const AppEmptyState(
                        message: 'Nothing tracked from here yet',
                        icon: Icons.inventory_2_outlined,
                      );
                    }
                    return ListView(
                      shrinkWrap: true,
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
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}
