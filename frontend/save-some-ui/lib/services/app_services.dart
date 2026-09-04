import 'package:save_some_ui/config/env.dart';
import 'package:save_some_ui/state/watchlist_controller.dart';

import 'api_client.dart';
import 'home_service.dart';
import 'products_service.dart';
import 'retailers_service.dart';
import 'users_service.dart';

/// One shared set of services over one shared [ApiClient].
///
/// Resolves the TODO that sat in home.dart and products.dart: each screen used
/// to build its own ApiClient in initState, so a five-tab app opened five HTTP
/// clients and there was no single place to configure headers, auth or timeouts.
///
/// A plain lazy singleton rather than a DI package — the app has one backend and
/// no need to swap implementations at runtime. If that changes, this is the one
/// seam to replace.
class AppServices {
  static final AppServices instance = AppServices._();

  AppServices._();

  late final ApiClient client = ApiClient(baseUrl: Env.apiBaseUrl);

  late final UsersService users = UsersService(client);
  late final ProductsService products = ProductsService(client);
  late final RetailersService retailers = RetailersService(client);
  late final HomeService home = HomeService(users, products);

  /// Shared so a save on one screen is reflected on every other.
  late final WatchlistController watchlist = WatchlistController(users);
}
