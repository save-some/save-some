import 'package:flutter/material.dart';

import 'package:save_some_ui/models/models.dart';
import 'package:save_some_ui/theme/breakpoints.dart';
import 'package:save_some_ui/widgets/cards/product.dart';

/// Product cards as a responsive column grid.
///
/// A single full-width column of row-cards is a phone layout; on a desktop
/// window it either stretches each card into unreadable slack or (with
/// PageWidth) strands a narrow strip in a sea of background. Both browse
/// screens use this: the window buys more columns, the cards keep the same
/// comfortable measure.
class ProductGrid extends StatelessWidget {
  final List<Product> products;
  final ValueChanged<Product> onTap;

  /// Horizontal gutter between columns.
  static const double gap = 16;

  const ProductGrid({super.key, required this.products, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final columns = WindowSize.of(context).browseColumns;
    if (columns == 1) {
      return Column(
        children: [
          for (final p in products)
            ProductCard(product: p, onTap: () => onTap(p)),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final p in products)
              SizedBox(
                width: itemWidth,
                child: ProductCard(product: p, onTap: () => onTap(p)),
              ),
          ],
        );
      },
    );
  }
}
