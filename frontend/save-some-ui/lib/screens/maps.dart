import 'package:flutter/material.dart';

import 'package:save_some_ui/models/models.dart';
import 'package:save_some_ui/screens/retailer_detail.dart';
import 'package:save_some_ui/services/app_services.dart';
import 'package:save_some_ui/theme/tokens.dart';
import 'package:save_some_ui/widgets/common/app_card.dart';
import 'package:save_some_ui/widgets/common/avatar_badge.dart';
import 'package:save_some_ui/widgets/common/retailer_products_sheet.dart';
import 'package:save_some_ui/widgets/common/section_header.dart';
import 'package:save_some_ui/widgets/common/state_views.dart';
import 'package:save_some_ui/widgets/map/map_view.dart';

/// Which retailers are near you, and what they carry.
///
/// Grouped by retailer rather than listed as a flat run of stores: the question
/// this page answers is "which chains can I actually get to", and a list of 140
/// undifferentiated store rows answered nothing. Tapping a retailer opens its
/// products in a sheet, without leaving the map.
class MapsScreen extends StatefulWidget {
  final String userId;
  const MapsScreen({super.key, required this.userId});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  final _services = AppServices.instance;

  late Future<_MapsData> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_MapsData> _load() async {
    // Started together rather than awaited in sequence: none of the three depends
    // on another, and running them serially cost three round-trips of latency
    // before the tab could render anything.
    final retailersFuture = _services.retailers.fetchAll();
    final followedFuture = _services.users.fetchRetailers(widget.userId);
    // The profile's zipcode is the geo anchor. Server-side geocoding would be
    // better than a lookup table, but the zipcode is what we reliably have.
    final zipcodeFuture = _services.users.fetchZipcode(widget.userId);

    final allRetailers = await retailersFuture;
    final followed = await followedFuture;
    final zipcode = await zipcodeFuture;

    // This one genuinely depends on the zipcode, so it stays sequential.
    final anchor = _anchorFor(zipcode);
    final stores = await _services.retailers.fetchNearbyStores(
      lat: anchor.$1,
      lng: anchor.$2,
      radiusMiles: 25,
    );

    return _MapsData(
      retailers: allRetailers,
      followedIds: followed.map((r) => r.id).toSet(),
      stores: stores,
      anchorLat: anchor.$1,
      anchorLng: anchor.$2,
      zipcode: zipcode,
    );
  }

  /// Zipcode to coordinates.
  ///
  /// A small table rather than a geocoding call: the store data currently covers
  /// the New York metro, so anything else has nothing to show anyway.
  /// TODO: resolve properly (Zippopotam works keyless and sends CORS) once store
  /// coverage extends past one metro.
  static (double, double) _anchorFor(String? zipcode) {
    const known = <String, (double, double)>{
      '07030': (40.7439, -74.0324), // Hoboken NJ
      '10001': (40.7484, -73.9967), // Manhattan
      '11201': (40.6940, -73.9903), // Brooklyn
      '11530': (40.7268, -73.6343), // Garden City NY
    };
    return known[zipcode] ?? const (40.7439, -74.0324);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _data = next);
    await next;
  }

  void _showProducts(Retailer retailer) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => RetailerProductsSheet(
        userId: widget.userId,
        retailerId: retailer.id,
        retailerName: retailer.name,
        onOpenRetailer: () {
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => RetailerDetailScreen(
                userId: widget.userId,
                retailerId: retailer.id,
                retailerName: retailer.name,
              ),
            ),
          );
        },
      ),
    );
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
        final grouped = data.groupedByRetailer();

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: AppSpacing.pageAll,
            children: [
              SectionHeader(
                data.zipcode == null
                    ? 'Near you'
                    : 'Near ${data.zipcode}',
                trailing: Text(
                  '${data.stores.length} stores',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              if (grouped.isEmpty)
                const AppEmptyState(
                  message: 'No stores within 25 miles.\n'
                      'Run seed/import_osm_stores.py to load your area.',
                  icon: Icons.storefront_outlined,
                )
              else
                _RetailerGrid(
                  groups: grouped,
                  followedIds: data.followedIds,
                  onSelect: (group) => _showProducts(group.retailer),
                ),

              const SizedBox(height: AppSpacing.xl),
              const SectionHeader('See Stores Nearby'),
              ClipRRect(
                borderRadius: AppRadius.mdAll,
                child: SizedBox(
                  height: 300,
                  child: MapView(
                    centerLat: data.anchorLat,
                    centerLng: data.anchorLng,
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

/// Retailers as a grid of logo tiles with store counts — scannable in a way a
/// long list of individual stores isn't.
class _RetailerGrid extends StatelessWidget {
  final List<_RetailerStores> groups;
  final Set<String> followedIds;

  /// Tapping a retailer opens its products in a sheet — the one behaviour,
  /// rather than tap-to-expand plus long-press-for-products, which gave the same
  /// tile two meanings and made neither discoverable.
  final void Function(_RetailerStores) onSelect;

  const _RetailerGrid({
    required this.groups,
    required this.followedIds,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final group in groups)
          _RetailerTile(
            group: group,
            followed: followedIds.contains(group.retailer.id),
            onTap: () => onSelect(group),
          ),
      ],
    );
  }
}

class _RetailerTile extends StatelessWidget {
  final _RetailerStores group;
  final bool followed;
  final VoidCallback onTap;

  const _RetailerTile({
    required this.group,
    required this.followed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final nearest = group.stores.isEmpty ? null : group.stores.first.distanceMiles;

    return SizedBox(
      width: 104,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.md,
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AvatarBadge(source: group.retailer.name, size: 40),
                if (followed)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check_circle,
                          size: 14, color: scheme.primary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              group.retailer.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              nearest == null
                  ? '${group.stores.length} stores'
                  : '${nearest.toStringAsFixed(1)} mi',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Everything the maps screen needs, fetched together so the widget deals with
/// one Future rather than four.
class _MapsData {
  final List<Retailer> retailers;
  final Set<String> followedIds;
  final List<Store> stores;
  final double anchorLat;
  final double anchorLng;
  final String? zipcode;

  const _MapsData({
    required this.retailers,
    required this.followedIds,
    required this.stores,
    required this.anchorLat,
    required this.anchorLng,
    this.zipcode,
  });

  /// Retailers that actually have a store nearby, most-followed first then
  /// nearest. Retailers with no local stores are omitted rather than shown as
  /// empty — Amazon has no storefronts and a "0 stores" tile is just noise.
  List<_RetailerStores> groupedByRetailer() {
    final byId = {for (final r in retailers) r.id: r};
    final buckets = <String, List<Store>>{};
    for (final store in stores) {
      buckets.putIfAbsent(store.retailerId, () => []).add(store);
    }

    final groups = <_RetailerStores>[];
    for (final entry in buckets.entries) {
      final retailer = byId[entry.key];
      if (retailer == null) continue;
      // The endpoint returns nearest-first overall; keep that within each group.
      groups.add(_RetailerStores(retailer: retailer, stores: entry.value));
    }

    groups.sort((a, b) {
      final aFollowed = followedIds.contains(a.retailer.id) ? 0 : 1;
      final bFollowed = followedIds.contains(b.retailer.id) ? 0 : 1;
      if (aFollowed != bFollowed) return aFollowed - bFollowed;
      final aNear = a.stores.first.distanceMiles ?? double.maxFinite;
      final bNear = b.stores.first.distanceMiles ?? double.maxFinite;
      return aNear.compareTo(bNear);
    });
    return groups;
  }
}

class _RetailerStores {
  final Retailer retailer;
  final List<Store> stores;

  const _RetailerStores({required this.retailer, required this.stores});
}
