import 'dart:async';

import 'package:flutter/material.dart';

import 'package:save_some_ui/models/models.dart';
import 'package:save_some_ui/services/api_client.dart' show ApiException;
import 'package:save_some_ui/services/app_services.dart';
import 'package:save_some_ui/state/data_revision.dart';
import 'package:save_some_ui/theme/tokens.dart';
import 'package:save_some_ui/widgets/common/app_text_field.dart';
import 'package:save_some_ui/widgets/common/chip_group.dart';
import 'package:save_some_ui/widgets/common/page_width.dart';
import 'package:save_some_ui/widgets/common/primary_button.dart';
import 'package:save_some_ui/widgets/common/state_views.dart';
import 'package:save_some_ui/widgets/map/map_view.dart';

/// Three steps to a usable account: where you shop, which chains, what you care
/// about.
///
/// Fills the gap the home screen used to dead-end into — it had a "finish setting
/// up your account" state with nowhere to go, because the backend modelled
/// onboarding but exposed no endpoint and there was no screen.
class OnboardingScreen extends StatefulWidget {
  final String userId;

  /// Called once the profile is saved, so the caller can refresh.
  final VoidCallback onComplete;

  const OnboardingScreen({
    super.key,
    required this.userId,
    required this.onComplete,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _services = AppServices.instance;
  final _nameController = TextEditingController();
  final _zipController = TextEditingController();
  final _pageController = PageController();

  late Future<_OnboardingOptions> _options;

  final Set<String> _retailerIds = {};
  final Set<String> _interestIds = {};

  int _step = 0;
  bool _attempted = false;
  bool _saving = false;

  static const _steps = 3;

  /// Debounced preview of "what your ZIP means": the backend resolves it and
  /// the nearby stores render on a mini-map as you type, so onboarding shows
  /// its own payoff — and an unpopulated area is visible before you commit
  /// to it rather than discovered as an empty Maps tab later.
  Timer? _zipPreviewTimer;
  _ZipPreview? _zipPreview;

  @override
  void initState() {
    super.initState();
    _options = _loadOptions();
  }

  @override
  void dispose() {
    _zipPreviewTimer?.cancel();
    _nameController.dispose();
    _zipController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<_OnboardingOptions> _loadOptions() async {
    // Independent, so fetched together.
    final retailers = _services.retailers.fetchAll();
    final categories = _services.categories.fetchAll();
    return _OnboardingOptions(
      retailers: await retailers,
      categories: await categories,
    );
  }

  String get _name => _nameController.text.trim();
  String get _zip => _zipController.text.trim();

  String? get _nameError {
    if (!_attempted) return null;
    // profiles.display_name is NOT NULL and the home screen greets by it.
    if (_name.isEmpty) return 'What should we call you?';
    return null;
  }

  /// US ZIPs only, which is what the store data covers.
  String? get _zipError {
    if (!_attempted) return null;
    if (_zip.isEmpty) return 'Enter your ZIP code';
    if (!RegExp(r'^\d{5}$').hasMatch(_zip)) return 'ZIP codes are five digits';
    return null;
  }

  /// Refires the ZIP preview only for the newest typed ZIP; a lookup that
  /// resolves after the user moved on is dropped rather than displayed.
  void _onZipChanged(String value) {
    setState(() {}); // validation + Continue button freshness
    _zipPreviewTimer?.cancel();
    final zip = value.trim();
    if (!RegExp(r'^\d{5}$').hasMatch(zip)) {
      if (mounted) setState(() => _zipPreview = null);
      return;
    }
    _zipPreviewTimer = Timer(const Duration(milliseconds: 450), () async {
      _ZipPreview? next;
      try {
        final info = await _services.retailers.fetchZip(zip);
        final stores = await _services.retailers.fetchNearbyStores(
          lat: info.lat,
          lng: info.lng,
        );
        next = _ZipPreview(
          lat: info.lat,
          lng: info.lng,
          label: info.label ?? info.zip,
          stores: stores,
        );
      } on ApiException {
        next = _ZipPreview(lat: 0, lng: 0, label: zip, stores: const []);
      }
      if (!mounted || _zipController.text.trim() != zip) return;
      setState(() => _zipPreview = next);
    });
  }

  bool get _canAdvance => switch (_step) {
    0 =>
      _nameError == null &&
          _name.isNotEmpty &&
          _zipError == null &&
          _zip.isNotEmpty,
    // Deliberately permissive: picking nothing is a valid answer, and
    // blocking on it would trap someone who just wants in.
    _ => true,
  };

  void _next() {
    setState(() => _attempted = true);
    if (!_canAdvance) return;
    if (_step == _steps - 1) {
      _submit();
      return;
    }
    setState(() {
      _step += 1;
      _attempted = false;
    });
    _pageController.animateToPage(
      _step,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step -= 1);
    _pageController.animateToPage(
      _step,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      await _services.users.completeOnboarding(
        widget.userId,
        displayName: _name,
        zipcode: _zip,
        retailerIds: _retailerIds,
        interestIds: _interestIds,
      );
      if (!mounted) return;
      // The profile, interests and retailer picks just changed for this user;
      // every tab holding user-scoped data must notice, not just the one that
      // owns the completion callback.
      DataRevision.instance.bump();
      widget.onComplete();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Couldn\'t save that: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: _step == 0
            ? null
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back),
        title: Text('Step ${_step + 1} of $_steps'),
      ),
      body: SafeArea(
        // PageWidth keeps the form a readable column on desktop — without it
        // every field and the CTA stretched the whole 1440px window.
        child: PageWidth(
          child: FutureBuilder<_OnboardingOptions>(
            future: _options,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return AppErrorState(
                  message: 'Couldn\'t load the setup options.',
                  error: snapshot.error,
                  onRetry: () => setState(() {
                    _options = _loadOptions();
                  }),
                );
              }
              if (!snapshot.hasData) return const AppLoading();
              final options = snapshot.data!;

              return Column(
                children: [
                  // Progress first, so the flow never feels open-ended.
                  Padding(
                    padding: AppSpacing.pageH,
                    child: LinearProgressIndicator(
                      value: (_step + 1) / _steps,
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      // Driven by the buttons so validation can't be swiped past.
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _Step(
                          title: 'Let\'s start with you',
                          blurb:
                              'A name for your account, and the ZIP code we '
                              'should look for stores and prices around.',
                          child: Column(
                            children: [
                              AppTextField(
                                controller: _nameController,
                                hint: 'your name',
                                icon: Icons.person_outline,
                                textInputAction: TextInputAction.next,
                                errorText: _nameError,
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              AppTextField(
                                controller: _zipController,
                                hint: 'ZIP code',
                                icon: Icons.location_on_outlined,
                                keyboardType: TextInputType.number,
                                isIdentifier: true,
                                textInputAction: TextInputAction.done,
                                errorText: _zipError,
                                onChanged: _onZipChanged,
                                onSubmitted: (_) => _next(),
                              ),
                              if (_zipPreview != null) ...[
                                const SizedBox(height: AppSpacing.lg),
                                ClipRRect(
                                  borderRadius: AppRadius.mdAll,
                                  child: SizedBox(
                                    height: 200,
                                    child: MapView(
                                      centerLat: _zipPreview!.lat,
                                      centerLng: _zipPreview!.lng,
                                      stores: _zipPreview!.stores,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  _zipPreview!.stores.isEmpty
                                      ? 'No stores mapped near '
                                            '${_zipPreview!.label} yet — your ZIP '
                                            'is still saved, and the area can be '
                                            'seeded later.'
                                      : '${_zipPreview!.stores.length} stores '
                                            'near ${_zipPreview!.label}',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        _Step(
                          title: 'Which stores?',
                          blurb:
                              'Pick the ones you actually shop at. You can '
                              'change this any time.',
                          child: FilterChipGroup(
                            options: [
                              for (final r in options.retailers)
                                (id: r.id, label: r.name),
                            ],
                            selectedIds: _retailerIds,
                            onToggle: (id) => setState(() {
                              if (!_retailerIds.remove(id)) {
                                _retailerIds.add(id);
                              }
                            }),
                          ),
                        ),
                        _Step(
                          title: 'What are you after?',
                          blurb:
                              'We\'ll lead with price drops in these '
                              'categories.',
                          child: FilterChipGroup(
                            options: [
                              for (final c in options.categories)
                                (id: c.id, label: c.name),
                            ],
                            selectedIds: _interestIds,
                            onToggle: (id) => setState(() {
                              if (!_interestIds.remove(id)) {
                                _interestIds.add(id);
                              }
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.gutter),
                    child: Column(
                      children: [
                        PrimaryButton(
                          label: _step == _steps - 1 ? 'Finish' : 'Continue',
                          icon: _step == _steps - 1
                              ? Icons.check_circle_outline
                              : Icons.arrow_forward,
                          busy: _saving,
                          onPressed: _next,
                        ),
                        if (_step > 0)
                          Text(
                            _step == 1
                                ? '${_retailerIds.length} selected'
                                : '${_interestIds.length} selected',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String title;
  final String blurb;
  final Widget child;

  const _Step({required this.title, required this.blurb, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: AppSpacing.pageAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(
            blurb,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          child,
        ],
      ),
    );
  }
}

/// One resolved ZIP-typed-into-the-form snapshot: where to point the mini
/// map, what to call the place, and what is actually there.
class _ZipPreview {
  final double lat;
  final double lng;
  final String label;
  final List<Store> stores;

  const _ZipPreview({
    required this.lat,
    required this.lng,
    required this.label,
    required this.stores,
  });
}

class _OnboardingOptions {
  final List<Retailer> retailers;
  final List<Category> categories;

  const _OnboardingOptions({required this.retailers, required this.categories});
}
