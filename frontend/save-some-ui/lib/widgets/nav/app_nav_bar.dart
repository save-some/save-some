import 'package:flutter/material.dart';

import 'package:save_some_ui/theme/breakpoints.dart';
import 'package:save_some_ui/theme/tokens.dart';
import 'package:save_some_ui/widgets/brand/canvas_backdrop.dart';
import 'package:save_some_ui/widgets/common/svg_asset.dart';
import 'package:save_some_ui/main.dart' show themeModeNotifier;

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

/// Side navigation, for anything wider than a phone: the ink sidebar.
///
/// A bottom bar on a laptop puts the primary controls as far from the content
/// as they can physically be — but the default transparent rail with pale
/// indicator pills read as unfinished on desktop: no anchor, no branding, no
/// edge. This is the design system's own signature instead — the near-black
/// ink the primary pills use, pulled onto the left as a solid column, brand
/// mark at the head, white pill behind the active destination, and the
/// light/dark toggle pinned at the foot so the sidebar does quiet double duty
/// as the app's chrome.
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

  static const _ink = AppColors.ink;
  static const _onInk = Colors.white;
  static const _onInkMuted = Color(0xB3FFFFFF); // white 70%

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: _ink,
        // A hairline rather than a shadow: the ink edge is already a strong
        // line, and elevation on a fixed panel just muddies the canvas.
        border: Border(
          right: BorderSide(color: _onInk.withValues(alpha: 0.08)),
        ),
      ),
      child: Theme(
        // NavigationRail takes its label styles from the ambient theme, so
        // the sidebar's palette is scoped here rather than leaking app-wide.
        data: theme.copyWith(
          navigationRailTheme: theme.navigationRailTheme.copyWith(
            backgroundColor: _ink,
            selectedIconTheme: const IconThemeData(color: _onInk),
            unselectedIconTheme: const IconThemeData(color: _onInkMuted),
            selectedLabelTextStyle: theme.textTheme.labelLarge?.copyWith(
              color: _onInk,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelTextStyle: theme.textTheme.labelLarge?.copyWith(
              color: _onInkMuted,
            ),
          ),
        ),
        child: NavigationRail(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          extended: extended,
          minExtendedWidth: 184,
          groupAlignment: -0.92,
          // Warm white on ink, not the lavender pill — on the dark column the
          // brand purple loses contrast against the canvas next to it.
          indicatorColor: _onInk.withValues(alpha: 0.14),
          labelType: extended ? null : NavigationRailLabelType.all,
          leading: Padding(
            padding: EdgeInsets.fromLTRB(
              extended ? 20 : 0,
              22,
              extended ? 20 : 0,
              26,
            ),
            child: extended
                ? Row(
                    children: const [
                      AppSvg('assets/wallet-logo.svg', size: 26),
                      SizedBox(width: 10),
                      Text(
                        'SAVE SOME',
                        style: TextStyle(
                          color: _onInk,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ],
                  )
                : const AppSvg('assets/wallet-logo.svg', size: 28),
          ),
          // The rail lays trailing out below the destinations in a column of
          // unbounded height, so Expanded/Align-to-bottom would assert; a
          // hairline then the toggle reads as a deliberate footer instead.
          trailing: Padding(
            padding: const EdgeInsets.only(top: 28, bottom: 18),
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 1,
                  color: _onInk.withValues(alpha: 0.15),
                ),
                const SizedBox(height: 10),
                ListenableBuilder(
                  listenable: themeModeNotifier,
                  builder: (context, _) => IconButton(
                    tooltip: themeModeNotifier.value == ThemeMode.dark
                        ? 'Switch to light'
                        : 'Switch to dark',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      themeModeNotifier.value == ThemeMode.dark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                      size: 20,
                      color: _onInkMuted,
                    ),
                    onPressed: () => themeModeNotifier.value =
                        themeModeNotifier.value == ThemeMode.dark
                        ? ThemeMode.light
                        : ThemeMode.dark,
                  ),
                ),
              ],
            ),
          ),
          destinations: [
            for (final destination in _destinations)
              NavigationRailDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(
                  destination.selectedIcon ?? destination.icon,
                ),
                label: Text(destination.label),
              ),
          ],
        ),
      ),
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
      return CanvasBackdrop(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(child: body),
          bottomNavigationBar: AppNavBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
          ),
        ),
      );
    }

    return CanvasBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
