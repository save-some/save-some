import 'package:flutter/material.dart';
// gotrue exports its own User; ours is the profile row from our API, so hide
// theirs rather than prefixing every use of ours.
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import 'package:save_some_ui/main.dart' show supabaseReady, themeModeNotifier;
import 'package:save_some_ui/models/models.dart';
import 'package:save_some_ui/screens/submit_product.dart';
import 'package:save_some_ui/services/app_services.dart';
import 'package:save_some_ui/theme/tokens.dart';
import 'package:save_some_ui/widgets/common/settings_tile.dart';
import 'package:save_some_ui/widgets/common/state_views.dart';

/// Account and settings — the design's account frame.
class AccountScreen extends StatefulWidget {
  final String userId;
  const AccountScreen({super.key, required this.userId});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late Future<User?> _profile;

  // Local-only for now: neither toggle has anything behind it yet, so they're
  // honest about their state but don't claim to have taken effect.
  bool _locationEnabled = false;
  bool _biometricsEnabled = false;

  @override
  void initState() {
    super.initState();
    _profile = AppServices.instance.users.fetchProfile(widget.userId);
  }

  Future<void> _refresh() async {
    final next = AppServices.instance.users.fetchProfile(widget.userId);
    setState(() => _profile = next);
    await next;
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You\'ll need to sign in again to see your products.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (!supabaseReady) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not signed in — running as the dev user.')),
      );
      return;
    }
    // AuthGate observes the cleared session and returns to sign-in.
    await Supabase.instance.client.auth.signOut();
  }

  Future<void> _pickThemeMode() async {
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: RadioGroup<ThemeMode>(
          groupValue: themeModeNotifier.value,
          onChanged: (value) => Navigator.of(context).pop(value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final mode in ThemeMode.values)
                RadioListTile<ThemeMode>(
                  value: mode,
                  title: Text(_themeLabel(mode)),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) themeModeNotifier.value = selected;
  }

  static String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'Match device',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<User?>(
        future: _profile,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return AppErrorState(
              message: 'Couldn\'t load your account.',
              error: snapshot.error,
              onRetry: _refresh,
            );
          }
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoading();
          }
          final profile = snapshot.data;

          return ListView(
            padding: AppSpacing.pageAll,
            children: [
              _ProfileHeader(profile: profile),
              const SizedBox(height: AppSpacing.xl),
              SettingsTile(
                icon: Icons.person_outline,
                label: 'Personal Details',
                // TODO: no profile-update endpoint exists yet.
                onTap: () => _notImplemented('Personal details'),
              ),
              const SizedBox(height: AppSpacing.sm),
              SettingsTile(
                icon: Icons.location_on_outlined,
                label: 'Turn on location',
                value: _locationEnabled,
                onChanged: (value) {
                  setState(() => _locationEnabled = value);
                  // TODO: request the OS permission and feed real coordinates
                  // into the maps screen. iOS also needs
                  // NSLocationWhenInUseUsageDescription in Info.plist first.
                  _notImplemented('Location');
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: themeModeNotifier,
                builder: (context, mode, _) => SettingsTile(
                  icon: Icons.palette_outlined,
                  label: 'Color Scheme',
                  trailingText: _themeLabel(mode),
                  onTap: _pickThemeMode,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SettingsTile(
                icon: Icons.lock_outline,
                label: 'Change password',
                onTap: () => _notImplemented('Password change'),
              ),
              const SizedBox(height: AppSpacing.sm),
              SettingsTile(
                icon: Icons.face_outlined,
                label: 'Sign in with Face ID',
                value: _biometricsEnabled,
                onChanged: (value) {
                  setState(() => _biometricsEnabled = value);
                  _notImplemented('Biometric sign-in');
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              SettingsTile(
                icon: Icons.add_circle_outline,
                label: 'Submit a Product',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SubmitProductScreen(userId: widget.userId),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SettingsTile(
                icon: Icons.logout,
                label: 'Sign out',
                destructive: true,
                onTap: _signOut,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          );
        },
      ),
    );
  }

  void _notImplemented(String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what isn\'t wired up yet.')),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final User? profile;

  const _ProfileHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: [
        Container(
          height: 88,
          width: 88,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.person,
            size: 48,
            color: scheme.onPrimaryContainer,
          ),
        ),
        if (profile != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(profile!.displayName, style: theme.textTheme.titleLarge),
          if (profile!.zipcode != null)
            Text(
              profile!.zipcode!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
        ],
      ],
    );
  }
}
