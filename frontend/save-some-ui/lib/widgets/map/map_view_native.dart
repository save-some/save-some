import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:save_some_ui/models/models.dart';

/// Mapbox-backed map, used on every platform except web.
///
/// Reached through `widgets/map/map_view.dart`, never imported directly, so the
/// web build never sees the Mapbox dependency.
class MapView extends StatefulWidget {
  /// Where to centre the camera. Defaults to the user's stores if any were
  /// passed, so the map opens on something relevant rather than on the whole
  /// country as it used to.
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
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  /// Empty when no token is configured, in which case Mapbox renders a blank
  /// canvas rather than throwing. We surface that as a message instead.
  late final String _token = dotenv.maybeGet('MAPBOX_TOKEN') ?? '';

  @override
  void initState() {
    super.initState();
    if (_token.isNotEmpty) {
      MapboxOptions.setAccessToken(_token);
    }
  }

  double get _lat => widget.centerLat ?? widget.stores.firstOrNull?.lat ?? 40.7439;
  double get _lng => widget.centerLng ?? widget.stores.firstOrNull?.lng ?? -74.0324;

  @override
  Widget build(BuildContext context) {
    if (_token.isEmpty) return const _MissingTokenNotice();

    return MapWidget(
      cameraOptions: CameraOptions(
        center: Point(coordinates: Position(_lng, _lat)),
        zoom: widget.zoom,
        bearing: 0,
        pitch: 0,
      ),
      onMapCreated: (mapboxMap) async {
        mapboxMap.location.updateSettings(
          LocationComponentSettings(
            // A 2D puck, not the glTF duck model this used to point at.
            locationPuck: LocationPuck(locationPuck2D: DefaultLocationPuck2D()),
            enabled: true,
            puckBearingEnabled: true,
          ),
        );
        // Colours are read before the await, since the callback resumes after an
        // async gap where this State may no longer be mounted.
        await _addStoreMarkers(mapboxMap, Theme.of(context).colorScheme);
      },
    );
  }

  Future<void> _addStoreMarkers(MapboxMap map, ColorScheme scheme) async {
    final plottable =
        widget.stores.where((s) => s.lat != null && s.lng != null).toList();
    if (plottable.isEmpty) return;

    final manager = await map.annotations.createCircleAnnotationManager();
    await manager.createMulti([
      for (final store in plottable)
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(store.lng!, store.lat!)),
          circleRadius: 7,
          circleColor: scheme.primary.toARGB32(),
          circleStrokeWidth: 2,
          circleStrokeColor: scheme.onPrimary.toARGB32(),
        ),
    ]);
  }
}

class _MissingTokenNotice extends StatelessWidget {
  const _MissingTokenNotice();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHigh,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 32, color: scheme.onSurfaceVariant),
              const SizedBox(height: 8),
              Text(
                'Add MAPBOX_TOKEN to .env to load the map',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
