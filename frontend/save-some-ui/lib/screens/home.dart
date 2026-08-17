import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:save_some_ui/screens/products.dart';
import 'package:save_some_ui/screens/account.dart';
import 'package:save_some_ui/screens/history.dart';
import 'package:save_some_ui/screens/maps.dart';

import 'package:save_some_ui/config/env.dart';
import 'package:save_some_ui/models/models.dart';
import 'package:save_some_ui/widgets/cards/product.dart';
import 'package:save_some_ui/services/api_client.dart';
import 'package:save_some_ui/services/home_service.dart';
import 'package:save_some_ui/services/products_service.dart';
import 'package:save_some_ui/services/users_service.dart';

/// Home tab content: greeting, interest chips, trending products.
///
/// `userId` is a placeholder param until real session/auth state exists
/// — wire it up to wherever the logged-in user's id ends up living once
/// that's built.
class HomeContent extends StatefulWidget {
  final String userId;

  const HomeContent({super.key, required this.userId});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  late final HomeService _homeService;
  late Future<HomeData> _homeData;

  @override
  void initState() {
    super.initState();
    // TODO: this should come from one shared ApiClient (e.g. injected via
    // Provider/Riverpod) instead of every screen constructing its own —
    // fine for now, but worth fixing before more screens need it.
    final client = ApiClient(baseUrl: Env.apiBaseUrl);
    _homeService = HomeService(UsersService(client), ProductsService(client));
    _homeData = _homeService.load(widget.userId);
  }

  Future<void> _refresh() async {
    final next = _homeService.load(widget.userId);
    setState(() => _homeData = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HomeData>(
      future: _homeData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorState(onRetry: _refresh, error: snapshot.error);
        }

        final data = snapshot.data!;
        // No profile row yet (e.g. anonymous/new user who hasn't
        // onboarded) — send them there instead of rendering a broken page.
        if (data.profile == null) {
          return const _NeedsOnboardingState();
        }
        final profile = data.profile!;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              Text(
                'Welcome back,\n${profile.displayName}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              Text(
                'Your Interests',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              _InterestChips(interests: data.interests),
              const SizedBox(height: 24),
              Text(
                'Trending this week',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              ...data.trending.map((p) => ProductCard(product: p)),
            ],
          ),
        );
      },
    );
  }
}

class _InterestChips extends StatelessWidget {
  final List<Category> interests;
  const _InterestChips({required this.interests});

  @override
  Widget build(BuildContext context) {
    if (interests.isEmpty) {
      return Text('No interests set yet', style: TextStyle(color: Colors.grey[500]));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: interests
            .map(
              (c) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(
                  label: Text(c.name),
                  backgroundColor: Colors.grey[100],
                  side: BorderSide(color: Colors.grey[300]!),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}



class _NeedsOnboardingState extends StatelessWidget {
  const _NeedsOnboardingState();

  @override
  Widget build(BuildContext context) {
    // TODO: replace with Navigator.push to your onboarding flow once
    // it exists as a route.
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          "Looks like you haven't finished setting up your account yet.",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  final Object? error;
  const _ErrorState({required this.onRetry, this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40, color: Colors.grey),
          const SizedBox(height: 8),
          const Text('Something went wrong loading your home page.'),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final String userId;
  const HomeScreen({super.key, required this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  void onItemTapped(int idx) {
    if (idx == _selectedIndex) return;
    setState(() => _selectedIndex = idx);
  }

  @override
  Widget build(BuildContext context) {
    // Can't be a static const list anymore since HomeContent now needs
    // widget.userId, which isn't known at compile time.
    final pages = <Widget>[
      ProductScreen(userId: widget.userId),
      const MapsScreen(),
      HomeContent(userId: widget.userId),
      const HistoryScreen(),
      const AccountScreen(),
    ];

    return Scaffold(
      body: SafeArea(child: pages.elementAt(_selectedIndex)),
      bottomNavigationBar: BottomNavigationBar(
        unselectedItemColor: Colors.grey,
        selectedItemColor: Colors.black,
        currentIndex: _selectedIndex,
        backgroundColor: Colors.black,
        onTap: onItemTapped,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.shop), label: 'Products'),
          const BottomNavigationBarItem(icon: Icon(Icons.location_on), label: 'Maps'),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/wallet-logo.svg',
              height: 30,
              width: 30,
              placeholderBuilder: (_) => const SizedBox(
                height: 25,
                width: 25,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ),
            label: 'Home',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'History'),
          const BottomNavigationBarItem(icon: Icon(Icons.account_circle), label: 'Account'),
        ],
      ),
    );
  }
}