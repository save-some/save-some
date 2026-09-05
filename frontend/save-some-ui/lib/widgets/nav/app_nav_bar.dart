import 'package:flutter/material.dart';

import 'package:save_some_ui/theme/breakpoints.dart';
import 'package:save_some_ui/theme/tokens.dart';
import 'package:save_some_ui/widgets/common/svg_asset.dart';

/// The five destinations, defined once and shared by the bar and the rail so
/// they can't drift apart.
class _Destination {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;

  const _Destination(this.icon, this.selectedIcon, this.label);
}

const _destinations = <_Destination>[
  _Destination(Icons.list_alt_outlined, Icons.list_alt, 'Products'),
  _Destination(Icons.location_on_outlined, Icons.location_on, 'Maps'),
  // Home's icon is the brand mark, handled separately below.
  _Destination(Icons.shopping_bag_outlined, null, 'Home'),
  _Destination(Icons.folder_outlined, Icons.folder, 'History'),
  _Destination(Icons.settings_outlined, Icons.settings, 'Settings'),
];

/// Index of the Home tab. Referenced by HomeScreen so the app opens here rather
/// than on Products.
const int homeDestinationIndex = 2;

/// Side navigation, for anything wider than a phone.
///
/// A bottom bar on a laptop puts the primary controls as far from the content as
/// they can physically be, and stretches five labels across 1400px.
class AppNavRail extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  /// Shows labels beside the icons instead of beneath them.
  final bool extended;

  const AppNavRail({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.extended = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      extended: extended,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      indicatorColor: scheme.secondaryContainer,
      // With labels always visible the rail reads as a menu rather than a strip
      // of guessable glyphs.
      labelType: extended ? null : NavigationRailLabelType.all,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: const AppSvg('assets/wallet-logo.svg', size: 32),
      ),
      destinations: [
        for (final destination in _destinations)
          NavigationRailDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon ?? destination.icon),
            label: Text(destination.label),
          ),
      ],
    );
  }
}

/// Picks side or bottom navigation from the window size, so screens don't have to.
class AppNavigation extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;

  const AppNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final window = WindowSize.of(context);

    if (!window.usesNavigationRail) {
      return Scaffold(
        body: SafeArea(child: body),
        bottomNavigationBar: AppNavBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            AppNavRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              extended: window.usesExtendedRail,
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// The five-tab bottom bar: Products, Maps, Home, History, Settings.
///
/// Built on M3 [NavigationBar] rather than the M2 BottomNavigationBar it
/// replaces, where `selectedItemColor: Colors.black` sat on
/// `backgroundColor: Colors.black` — so the selected tab was literally
/// invisible. Selected state now comes from the theme's navigationBarTheme,
/// which paints a secondaryContainer pill behind the active icon.
///
/// Home is deliberately the centre tab, carrying the wallet mark, as the design
/// shows.
class AppNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const AppNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  /// Kept for callers that referenced it before the rail existed.
  static const homeIndex = homeDestinationIndex;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: [
        for (var i = 0; i < _destinations.length; i++)
          NavigationDestination(
            // The brand mark, not a Material glyph — it's the design's anchor
            // for the centre tab.
            icon: i == homeDestinationIndex
                ? const AppSvg('assets/wallet-logo.svg', size: 26)
                : Icon(_destinations[i].icon),
            selectedIcon: i == homeDestinationIndex
                ? const AppSvg('assets/wallet-logo.svg', size: 26)
                : Icon(_destinations[i].selectedIcon ?? _destinations[i].icon),
            label: _destinations[i].label,
          ),
      ],
    );
  }
}
