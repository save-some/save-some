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

  /// Kept across rebuilds so a data refresh can move the existing pins rather
  /// than being unable to — `onMapCreated` fires exactly once per platform
  /// view, and this widget is reused in place when the Maps screen refetches,
  /// so a refresh that only rebuilt the widget used to leave the canvas
  /// showing the OLD stores while the list above showed the new ones.
  MapboxMap? _map;
  CircleAnnotationManager? _circleManager;

  /// Guards against two overlapping async redraws leaving a half-torn-down
  /// annotation set; a request arriving mid-flight sets the flag so the
  /// in-flight one re-runs when it finishes.
  bool _syncing = false;
  bool _again = false;

  @override
  void initState() {
    super.initState();
    if (_token.isNotEmpty) {
      MapboxOptions.setAccessToken(_token);
    }
  }

  @override
  void didUpdateWidget(MapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_map == null) return;
    if (widget.stores != oldWidget.stores) _syncMarkers();
    if (widget.centerLat != oldWidget.centerLat ||
        widget.centerLng != oldWidget.centerLng) {
      _map!.setCamera(
        CameraOptions(
          center: Point(coordinates: Position(_lng, _lat)),
          zoom: widget.zoom,
        ),
      );
    }
  }

  @override
  void dispose() {
    // The platform view owns the manager; dropping the references is all the
    // Dart side can (and needs to) do.
    _map = null;
    _circleManager = null;
    super.dispose();
  }

  double get _lat =>
      widget.centerLat ?? widget.stores.firstOrNull?.lat ?? 40.7439;
  double get _lng =>
      widget.centerLng ?? widget.stores.firstOrNull?.lng ?? -74.0324;

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
        _map = mapboxMap;
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
        await _syncMarkers(Theme.of(context).colorScheme);
      },
    );
  }

  /// Clears and redraws the store circles from the current [widget.stores].
  Future<void> _syncMarkers([ColorScheme? scheme]) async {
    final map = _map;
    if (map == null) return;
    if (_syncing) {
      _again = true;
      return;
    }
    _syncing = true;
    try {
      final colors = scheme ?? Theme.of(context).colorScheme;
      final plottable = widget.stores
          .where((s) => s.lat != null && s.lng != null)
          .toList();
      var manager = _circleManager;
      if (plottable.isEmpty) {
        await manager?.deleteAll();
        return;
      }
      manager ??= await map.annotations.createCircleAnnotationManager();
      _circleManager = manager;
      await manager.deleteAll();
      await manager.createMulti([
        for (final store in plottable)
          CircleAnnotationOptions(
            geometry: Point(coordinates: Position(store.lng!, store.lat!)),
            circleRadius: 7,
            circleColor: colors.primary.toARGB32(),
            circleStrokeWidth: 2,
            circleStrokeColor: colors.onPrimary.toARGB32(),
          ),
      ]);
    } finally {
      _syncing = false;
      if (_again) {
        _again = false;
        _syncMarkers();
      }
    }
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
              Icon(
                Icons.map_outlined,
                size: 32,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                'Add MAPBOX_TOKEN to .env to load the map',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
