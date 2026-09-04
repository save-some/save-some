import 'package:flutter/material.dart';

import 'package:save_some_ui/widgets/common/svg_asset.dart';

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

  /// Index of the Home tab. Referenced by HomeScreen so the app opens here
  /// rather than on Products.
  static const homeIndex = 2;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.list_alt_outlined),
          selectedIcon: Icon(Icons.list_alt),
          label: 'Products',
        ),
        NavigationDestination(
          icon: Icon(Icons.location_on_outlined),
          selectedIcon: Icon(Icons.location_on),
          label: 'Maps',
        ),
        NavigationDestination(
          // The brand mark, not a Material glyph — it's the design's anchor for
          // the centre tab.
          icon: AppSvg('assets/wallet-logo.svg', size: 26),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.folder_outlined),
          selectedIcon: Icon(Icons.folder),
          label: 'History',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    );
  }
}
