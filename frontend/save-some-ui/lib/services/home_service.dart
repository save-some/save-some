import '../models/models.dart';
import '../models/trending_product.dart';
import 'products_service.dart';
import 'users_service.dart';

/// Everything the Home screen needs, fetched together so the widget
/// deals with one Future instead of three.
class HomeData {
  final User profile;
  final List<Category> interests;
  final List<TrendingProduct> trending;

  HomeData({
    required this.profile,
    required this.interests,
    required this.trending,
  });
}

class HomeService {
  final UsersService _users;
  final ProductsService _products;

  HomeService(this._users, this._products);

  Future<HomeData> load(String userId) async {
    // Start all three requests immediately, then await them — this runs
    // them concurrently rather than one after another. (Future.wait would
    // also work here, but with three different return types it forces
    // casts; this reads cleaner for a fixed, known set of calls.)
    final profileFuture = _users.fetchProfile(userId);
    final interestsFuture = _users.fetchInterests(userId);
    final trendingFuture = _products.fetchTrending();

    final profile = await profileFuture;
    final interests = await interestsFuture;
    final trending = await trendingFuture;

    return HomeData(profile: profile, interests: interests, trending: trending);
  }
}