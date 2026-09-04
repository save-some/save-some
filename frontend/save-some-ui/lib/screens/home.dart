import 'package:flutter/material.dart';

import 'package:save_some_ui/models/models.dart';
import 'package:save_some_ui/screens/account.dart';
import 'package:save_some_ui/screens/history.dart';
import 'package:save_some_ui/screens/maps.dart';
import 'package:save_some_ui/screens/products.dart';
import 'package:save_some_ui/screens/submit_product.dart';
import 'package:save_some_ui/services/app_services.dart';
import 'package:save_some_ui/services/home_service.dart';
import 'package:save_some_ui/theme/tokens.dart';
import 'package:save_some_ui/widgets/cards/product.dart';
import 'package:save_some_ui/widgets/common/chip_group.dart';
import 'package:save_some_ui/widgets/common/section_header.dart';
import 'package:save_some_ui/widgets/common/state_views.dart';
import 'package:save_some_ui/widgets/nav/app_nav_bar.dart';

/// Home tab content: greeting, interest chips, trending products.
class HomeContent extends StatefulWidget {
  final String userId;

  const HomeContent({super.key, required this.userId});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  late Future<HomeData> _homeData;

  @override
  void initState() {
    super.initState();
    _homeData = AppServices.instance.home.load(widget.userId);
  }

  Future<void> _refresh() async {
    final next = AppServices.instance.home.load(widget.userId);
    setState(() => _homeData = next);
    await next;
  }

  void _openSubmitProduct() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SubmitProductScreen(userId: widget.userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<HomeData>(
      future: _homeData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoading();
        }
        if (snapshot.hasError) {
          return AppErrorState(
            message: 'Couldn\'t load your home page.',
            error: snapshot.error,
            onRetry: _refresh,
          );
        }

        final data = snapshot.data!;
        // No profile row yet (e.g. anonymous/new user who hasn't onboarded) —
        // say so rather than rendering a broken page.
        if (data.profile == null) return const _NeedsOnboardingState();
        final profile = data.profile!;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: AppSpacing.pageAll,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'Welcome back,\n${profile.displayName}',
                      style: theme.textTheme.displaySmall,
                    ),
                  ),
                  IconButton(
                    onPressed: _openSubmitProduct,
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Submit a product',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader('Your Interests', muted: true),
              if (data.interests.isEmpty)
                const AppEmptyState(message: 'No interests set yet')
              else
                ChipRow(labels: [for (final c in data.interests) c.name]),
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader('Trending this week'),
              if (data.trending.isEmpty)
                const AppEmptyState(
                  message: 'No price drops to show yet',
                  icon: Icons.trending_down,
                )
              else
                for (final product in data.trending)
                  ProductCard(
                    product: product,
                    onTap: () => _openHistory(product),
                  ),
            ],
          ),
        );
      },
    );
  }

  void _openHistory(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HistoryScreen(
          userId: widget.userId,
          initialProduct: product,
        ),
      ),
    );
  }
}

class _NeedsOnboardingState extends StatelessWidget {
  const _NeedsOnboardingState();

  @override
  Widget build(BuildContext context) {
    // TODO: replace with a push into the onboarding flow once it exists as a
    // route. The backend models OnboardingRequest but exposes no endpoint yet.
    return const Center(
      child: AppEmptyState(
        message: "Looks like you haven't finished setting up your account yet.",
        icon: Icons.person_outline,
      ),
    );
  }
}

/// The app shell: five tabs behind an M3 navigation bar.
class HomeScreen extends StatefulWidget {
  final String userId;
  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Opens on Home, the centre tab, as the design shows. It used to default to
  /// 0, which is Products.
  int _selectedIndex = AppNavBar.homeIndex;

  void _onDestinationSelected(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack, not `pages.elementAt(index)`: that rebuilt each tab from
      // scratch on every switch, so scroll position and in-flight requests were
      // discarded. The stray "back to sign in" button that used to sit above
      // this is gone — it did nothing when HomeScreen was the root route.
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            ProductScreen(userId: widget.userId),
            MapsScreen(userId: widget.userId),
            HomeContent(userId: widget.userId),
            HistoryScreen(userId: widget.userId),
            AccountScreen(userId: widget.userId),
          ],
        ),
      ),
      bottomNavigationBar: AppNavBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
      ),
    );
  }
}
