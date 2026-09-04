import 'json.dart';

// ---- Store ----
// GET /v1/retailers/locations?lat=&lng=&radius_miles=
//
// A physical location. `distanceMiles` isn't a column — the nearby-stores
// query computes it per request, so it's only present on that endpoint.

class Store {
  final String id;
  final String retailerId;
  final String? name;
  final String? address;
  final String? city;
  final String? state;
  final String? zipcode;
  final double? lat;
  final double? lng;
  final DateTime createdAt;
  final double? distanceMiles;

  Store({
    required this.id,
    required this.retailerId,
    this.name,
    this.address,
    this.city,
    this.state,
    this.zipcode,
    this.lat,
    this.lng,
    required this.createdAt,
    this.distanceMiles,
  });

  /// "Hoboken, NJ" — falls back through the parts that are present.
  String get locality =>
      [city, state].where((p) => p != null && p.isNotEmpty).join(', ');

  factory Store.fromJson(Map<String, dynamic> json) => Store(
        id: json['id'] as String,
        retailerId: json['retailer_id'] as String,
        name: json['name'] as String?,
        address: json['address'] as String?,
        city: json['city'] as String?,
        state: json['state'] as String?,
        zipcode: json['zipcode'] as String?,
        lat: parseDoubleOrNull(json['lat']),
        lng: parseDoubleOrNull(json['lng']),
        createdAt: parseDate(json['created_at']),
        distanceMiles: parseDoubleOrNull(json['distance_miles']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'retailer_id': retailerId,
        'name': name,
        'address': address,
        'city': city,
        'state': state,
        'zipcode': zipcode,
        'lat': lat,
        'lng': lng,
        'created_at': createdAt.toIso8601String(),
        'distance_miles': distanceMiles,
      };
}
