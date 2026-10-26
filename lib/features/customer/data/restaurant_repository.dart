import '../../../core/network/api_client.dart';
import '../domain/restaurant.dart';

class RestaurantRepository {
  const RestaurantRepository(this._api);

  final ApiClient _api;

  Future<List<Restaurant>> list({String query = '', int page = 1, int limit = 20}) async {
    final body = await _api.get('/public/restaurants', query: {
      'page': page,
      'limit': limit,
      if (query.isNotEmpty) 'q': query,
    });
    final list = ApiClient.unwrap(body)['restaurants'];
    if (list is! List) return const [];
    return list.whereType<Map<String, dynamic>>().map(Restaurant.fromJson).toList();
  }

  Future<RestaurantMenu> menu(int restaurantId) async {
    final body = await _api.get('/public/restaurants/$restaurantId/menu');
    final data = ApiClient.unwrap(body);
    final menu = data['menu'];
    return RestaurantMenu(
      restaurant: Restaurant.fromJson(data['restaurant'] as Map<String, dynamic>),
      items: menu is List
          ? menu.whereType<Map<String, dynamic>>().map(MenuItem.fromJson).toList()
          : const [],
    );
  }
}
