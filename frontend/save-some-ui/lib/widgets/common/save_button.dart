import 'package:flutter/material.dart';

import 'package:save_some_ui/models/models.dart';
import 'package:save_some_ui/services/app_services.dart';
import 'package:save_some_ui/state/session.dart';

/// Track / untrack a product.
///
/// Reads and writes the shared [WatchlistController], so every card showing the
/// same product updates together. Until now the watchlist could only be read —
/// the POST and DELETE routes existed but nothing in the UI called them.
class SaveButton extends StatelessWidget {
  final Product product;

  /// Larger, labelled variant for a detail view rather than a list row.
  final bool extended;

  const SaveButton({super.key, required this.product, this.extended = false});

  Future<void> _toggle(BuildContext context) async {
    final userId = AppSession.instance.userId;
    if (userId == null) return;

    final watchlist = AppServices.instance.watchlist;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final nowTracked = await watchlist.toggle(userId, product);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            nowTracked
                ? 'Tracking ${product.name}'
                : 'Stopped tracking ${product.name}',
          ),
          // Undo is the whole point of a two-way control being one tap.
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => watchlist.toggle(userId, product),
          ),
        ),
      );
    } catch (error) {
      // The controller has already rolled the optimistic change back.
      messenger.showSnackBar(
        SnackBar(content: Text('Couldn\'t update your watchlist: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final watchlist = AppServices.instance.watchlist;
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: watchlist,
      builder: (context, _) {
        final tracked = watchlist.isTracked(product.id);
        final busy = watchlist.isBusy(product.id);
        final icon = tracked ? Icons.bookmark : Icons.bookmark_border;
        final colour = tracked ? scheme.primary : scheme.onSurfaceVariant;

        if (extended) {
          return OutlinedButton.icon(
            onPressed: busy ? null : () => _toggle(context),
            icon: Icon(icon, size: 18, color: colour),
            label: Text(tracked ? 'Tracking' : 'Track price'),
          );
        }

        return IconButton(
          onPressed: busy ? null : () => _toggle(context),
          icon: Icon(icon, color: colour),
          iconSize: 20,
          visualDensity: VisualDensity.compact,
          tooltip: tracked ? 'Stop tracking' : 'Track this product',
        );
      },
    );
  }
}
