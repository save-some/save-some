import 'package:save_some_ui/models/models.dart';
import 'products_service.dart';
import 'users_service.dart';

/// Everything the Home screen needs, fetched together so the widget
/// deals with one Future instead of three.
class HomeData {
  final User? profile; // null = no profile row yet (e.g. hasn't onboarded)
  final List<Category> interests;
  final List<Product> trending;

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
    final profileFuture = _users.fetchProfile(userId);
    final interestsFuture = _users.fetchInterests(userId);
    final trendingFuture = _products.fetchTrending();

    final profile = await profileFuture;
    final interests = await interestsFuture;
    final trending = await trendingFuture;

    return HomeData(profile: profile, interests: interests, trending: trending);
  }
}