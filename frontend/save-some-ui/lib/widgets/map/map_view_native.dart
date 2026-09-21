import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'package:save_some_ui/models/models.dart';
import 'package:save_some_ui/widgets/common/retailer_logo.dart';

/// Mapbox-backed map, used on every platform except web.
///
/// Reached through `widgets/map/map_view.dart`, never imported directly, so the
/// web build never sees the Mapbox dependency.
///
/// Stores render as circular retailer-logo pins (a white badge holding each
/// chain's mark), not the generic coloured dots they used to be: on a map whose
/// whole point is "which chain is where", a purple pin tells you nothing and a
/// logo tells you everything. A store whose chain has no bundled mark falls
/// back to a coloured circle so it still shows up.
class MapView extends StatefulWidget {
  /// Where to centre the camera. Defaults to the user's stores if any were
  /// passed, so the map opens on something relevant rather than on the whole
  /// country as it used to.
  final double? centerLat;
  final double? centerLng;
  final double zoom;
  final List<Store> stores;

  /// retailerId -> retailer name, used to pick each pin's logo. Falls back to
  /// a circle for ids not present here or with no bundled mark.
  final Map<String, String> retailerNames;

  const MapView({
    super.key,
    this.centerLat,
    this.centerLng,
    this.zoom = 10,
    this.stores = const [],
    this.retailerNames = const {},
  });

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  /// Empty when no token is configured, in which case Mapbox renders a blank
  /// canvas rather than throwing. We surface that as a message instead.
  late final String _token = dotenv.maybeGet('MAPBOX_TOKEN') ?? '';

  // Kept across rebuilds so a data refresh can move the existing pins rather
  // than being unable to — onMapCreated fires once per platform view and this
  // widget is reused in place when the Maps screen refetches, so a refresh that
  // only rebuilt the widget used to leave the canvas on the OLD stores while
  // the list above showed the new ones.
  MapboxMap? _map;
  PointAnnotationManager? _pointManager;
  CircleAnnotationManager? _circleManager;

  /// The badge PNGs are identical for every store of a chain and don't change
  /// between runs, so decode each asset once for the whole app.
  static final Map<String, Uint8List> _pngByAsset = {};

  /// Guards against two overlapping async redraws leaving a half-torn-down
  /// annotation set; a request mid-flight re-runs once the current one ends.
  bool _syncing = false;
  bool _again = false;

  // Badge art is 128px; ~0.34 lands a pin at a readable ~44px that still
  // doesn't hide the road beneath it.
  static const double _pinScale = 0.34;

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
    if (widget.stores != oldWidget.stores ||
        widget.retailerNames != oldWidget.retailerNames) {
      _syncMarkers();
    }
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
    // The platform view owns the managers; dropping the references is all the
    // Dart side can (and needs to) do.
    _map = null;
    _pointManager = null;
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
        // Colours read before the await: the callback resumes after an async
        // gap where this State may no longer be mounted.
        await _syncMarkers(Theme.of(context).colorScheme);
      },
    );
  }

  Future<Uint8List?> _pngFor(String? retailerName) async {
    final asset = retailerName == null
        ? null
        : RetailerLogo.pngAssetFor(retailerName);
    if (asset == null) return null;
    final cached = _pngByAsset[asset];
    if (cached != null) return cached;
    try {
      final data = await rootBundle.load(asset);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      _pngByAsset[asset] = bytes;
      return bytes;
    } catch (_) {
      // A missing/misconfigured asset shouldn't blank the map — the caller
      // falls back to a circle pin.
      return null;
    }
  }

  /// Redraws both annotation layers from the current [widget.stores]: logo
  /// pins where the chain has a mark, coloured circles everywhere else.
  Future<void> _syncMarkers([ColorScheme? scheme]) async {
    final map = _map;
    if (map == null) return;
    if (_syncing) {
      _again = true;
      return;
    }
    _syncing = true;
    final colors = scheme ?? (mounted ? Theme.of(context).colorScheme : null);
    try {
      final plottable = widget.stores
          .where((s) => s.lat != null && s.lng != null)
          .toList();

      final pins = <PointAnnotationOptions>[];
      final circles = <CircleAnnotationOptions>[];
      for (final store in plottable) {
        final name = widget.retailerNames[store.retailerId];
        final png = await _pngFor(name);
        final point = Point(coordinates: Position(store.lng!, store.lat!));
        if (png != null) {
          pins.add(
            PointAnnotationOptions(
              geometry: point,
              image: png,
              iconSize: _pinScale,
              iconAnchor: IconAnchor.CENTER,
            ),
          );
        } else if (colors != null) {
          circles.add(
            CircleAnnotationOptions(
              geometry: point,
              circleRadius: 7,
              circleColor: colors.primary.toARGB32(),
              circleStrokeWidth: 2,
              circleStrokeColor: colors.onPrimary.toARGB32(),
            ),
          );
        }
      }

      final pointManager = _pointManager ??= await map.annotations
          .createPointAnnotationManager();
      await pointManager.deleteAll();
      if (pins.isNotEmpty) await pointManager.createMulti(pins);

      if (circles.isNotEmpty && colors != null) {
        final circleManager = _circleManager ??= await map.annotations
            .createCircleAnnotationManager();
        await circleManager.deleteAll();
        await circleManager.createMulti(circles);
      } else {
        await _circleManager?.deleteAll();
      }
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
