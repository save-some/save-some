import 'package:flutter/widgets.dart';

/// App-wide "some user-scoped data changed" signal.
///
/// Every tab is mounted at once inside an IndexedStack and fetches exactly
/// once at startup, so a mutation performed in one tab (finishing onboarding,
/// following a retailer, running a search) left the other tabs serving their
/// pre-mutation data indefinitely — Maps kept showing "0 stores" minutes after
/// onboarding had saved a ZIP, which read as the feature being broken.
///
/// Screens that show user-scoped data mix in [RevisionAware] and reload when
/// [value] changes; code that MUTATES such data calls `bump()` after the
/// request succeeds. One counter, no event bus, no per-screen wiring tables.
class DataRevision extends ChangeNotifier {
  DataRevision._();

  static final DataRevision instance = DataRevision._();

  int _value = 0;
  int get value => _value;

  void bump() {
    _value += 1;
    notifyListeners();
  }
}

/// Reload hook for any [State] that caches a Future fetched from the backend.
///
/// [onDataRevision] fires only when the revision actually advanced — the
/// common no-op case is free. Listeners are added in initState and dropped in
/// dispose, mirroring the ChangeNotifier lifecycle the repo already uses for
/// WatchlistController.
mixin RevisionAware<T extends StatefulWidget> on State<T> {
  int _seenRevision = 0;

  /// The revision the current data was loaded under.
  int get currentRevision => _seenRevision;

  @override
  void initState() {
    super.initState();
    _seenRevision = DataRevision.instance.value;
    DataRevision.instance.addListener(_maybeReload);
  }

  void _maybeReload() {
    if (!mounted || DataRevision.instance.value == _seenRevision) return;
    _seenRevision = DataRevision.instance.value;
    onDataRevision();
  }

  /// Called after [currentRevision] has been advanced; refetch whatever this
  /// screen shows.
  void onDataRevision();

  @override
  void dispose() {
    DataRevision.instance.removeListener(_maybeReload);
    super.dispose();
  }
}
