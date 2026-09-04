import 'package:flutter/material.dart';

import 'package:save_some_ui/models/models.dart';
import 'package:save_some_ui/services/app_services.dart';
import 'package:save_some_ui/theme/tokens.dart';
import 'package:save_some_ui/widgets/cards/store.dart';
import 'package:save_some_ui/widgets/common/chip_group.dart';
import 'package:save_some_ui/widgets/common/section_header.dart';
import 'package:save_some_ui/widgets/common/state_views.dart';
import 'package:save_some_ui/widgets/map/map_view.dart';

/// Retailer chips, nearby stores, and a map — the design's maps frame.
///
/// Replaces a bare full-bleed MapWidget inside a nested Scaffold whose camera
/// was parked at (-98, 39.5) zoom 2, i.e. the entire continental US.
class MapsScreen extends StatefulWidget {
  final String userId;
  const MapsScreen({super.key, required this.userId});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  final _services = AppServices.instance;

  late Future<_MapsData> _data;
  final Set<String> _selectedRetailerIds = {};

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_MapsData> _load() async {
    // Two retailer lists, deliberately. The chips show the chains this user
    // opted into, but nearby stores can belong to any chain — so names have to
    // be resolved against every retailer, otherwise a Sam's Club store rendered
    // as "Store" because it wasn't in the user's own list.
    final allRetailers = await _services.retailers.fetchAll();
    final userRetailers = await _services.users.fetchRetailers(widget.userId);

    // The profile's zipcode is the geo anchor. Device location would be better
    // but needs a runtime permission prompt, and iOS has no usage description
    // declared yet.
    final stores = await _services.retailers.fetchNearbyStores(
      lat: _anchorLat,
      lng: _anchorLng,
      retailerIds:
          _selectedRetailerIds.isEmpty ? null : _selectedRetailerIds,
    );

    return _MapsData(
      chipRetailers: userRetailers.isEmpty ? allRetailers : userRetailers,
      namesById: {for (final r in allRetailers) r.id: r.name},
      stores: stores,
    );
  }

  // Hoboken NJ — the seeded profile's zipcode, and the area the design's map
  // frame shows. TODO: resolve the user's zipcode to coordinates, or ask for
  // device location, instead of hardcoding a fallback.
  static const _anchorLat = 40.7439;
  static const _anchorLng = -74.0324;

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _data = next);
    await next;
  }

  void _toggleRetailer(String retailerId) {
    setState(() {
      if (!_selectedRetailerIds.remove(retailerId)) {
        _selectedRetailerIds.add(retailerId);
      }
      _data = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_MapsData>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AppErrorState(
            message: 'Couldn\'t load nearby stores.',
            error: snapshot.error,
            onRetry: _refresh,
          );
        }
        if (!snapshot.hasData) return const AppLoading();

        final data = snapshot.data!;
        final names = data.namesById;
        // The design shows a short list above the map rather than every result,
        // so the header says what's actually on screen instead of claiming all
        // 13 are listed.
        const visibleLimit = 4;
        final visible = data.stores.take(visibleLimit).toList();
        final truncated = data.stores.length > visibleLimit;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: AppSpacing.pageAll,
            children: [
              const SectionHeader('Retailers'),
              FilterChipGroup(
                options: [
                  for (final r in data.chipRetailers) (id: r.id, label: r.name),
                ],
                selectedIds: _selectedRetailerIds,
                // Scrolls on one line, running off the right edge as in the
                // design, rather than wrapping.
                scrollable: true,
                onToggle: _toggleRetailer,
              ),
              const SizedBox(height: AppSpacing.xl),
              SectionHeader(
                switch (data.stores.length) {
                  0 => 'Stores nearby',
                  1 => '1 store nearby',
                  final n when truncated => 'Nearest $visibleLimit of $n stores',
                  final n => '$n stores nearby',
                },
              ),
              if (data.stores.isEmpty)
                const AppEmptyState(
                  message: 'No stores within 25 miles',
                  icon: Icons.storefront_outlined,
                )
              else
                for (final store in visible)
                  StoreCard(
                    store: store,
                    retailerName: names[store.retailerId] ?? 'Store',
                  ),
              const SizedBox(height: AppSpacing.lg),
              const SectionHeader('See Stores Nearby'),
              // Fixed height and rounded, as the design shows — not full-bleed.
              // On web this resolves to a placeholder of the same size, since
              // Mapbox has no web implementation.
              ClipRRect(
                borderRadius: AppRadius.mdAll,
                child: SizedBox(
                  height: 320,
                  child: MapView(
                    centerLat: _anchorLat,
                    centerLng: _anchorLng,
                    stores: data.stores,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        );
      },
    );
  }
}

/// Everything the maps screen needs, fetched together so the widget deals with
/// one Future rather than three.
class _MapsData {
  /// Chains this user opted into — what the chip row offers.
  final List<Retailer> chipRetailers;

  /// Every retailer, so a store from any chain can be named.
  final Map<String, String> namesById;

  final List<Store> stores;

  const _MapsData({
    required this.chipRetailers,
    required this.namesById,
    required this.stores,
  });
}
