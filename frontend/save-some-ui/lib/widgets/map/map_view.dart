/// Platform-switched map surface.
///
/// mapbox_maps_flutter has no web implementation, and importing it anywhere in
/// the reachable tree makes the whole app fail to compile for Chrome. This
/// conditional export keeps the Mapbox import behind dart:io so web resolves to
/// a placeholder of the same size instead.
///
/// Callers only ever see [MapView] and never import Mapbox directly.
library;

export 'map_view_stub.dart' if (dart.library.io) 'map_view_native.dart';
