import 'package:flutter/material.dart';

import 'package:save_some_ui/models/models.dart';

/// Web stand-in for [MapView]. mapbox_maps_flutter ships no web
/// implementation, so rather than break the build this occupies exactly the
/// same box and lists what the map would have plotted — which keeps the rest of
/// the maps screen laid out identically to the native build.
///
/// The constructor mirrors map_view_native.dart's; unused parameters are kept so
/// callers don't need to know which platform they're on.
class MapView extends StatelessWidget {
  final double? centerLat;
  final double? centerLng;
  final double zoom;
  final List<Store> stores;

  const MapView({
    super.key,
    this.centerLat,
    this.centerLng,
    this.zoom = 10,
    this.stores = const [],
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final plottable = stores.where((s) => s.lat != null && s.lng != null).length;

    return ColoredBox(
      color: scheme.surfaceContainerHigh,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 36, color: scheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                'Map available on iOS and Android',
                style: text.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(
                plottable == 1
                    ? '1 nearby store would be plotted here'
                    : '$plottable nearby stores would be plotted here',
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
