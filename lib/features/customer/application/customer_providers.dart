import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/restaurant_repository.dart';
import '../domain/cart.dart';
import '../domain/restaurant.dart';

final restaurantRepositoryProvider =
    Provider<RestaurantRepository>((ref) => RestaurantRepository(ref.watch(apiClientProvider)));

/// The text typed in the home search box. Changing it reloads the list.
class RestaurantQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

final restaurantQueryProvider = NotifierProvider<RestaurantQuery, String>(RestaurantQuery.new);

final restaurantsProvider = FutureProvider<List<Restaurant>>((ref) {
  final query = ref.watch(restaurantQueryProvider).trim();
  return ref.watch(restaurantRepositoryProvider).list(query: query);
});

final restaurantMenuProvider = FutureProvider.family<RestaurantMenu, int>(
  (ref, id) => ref.watch(restaurantRepositoryProvider).menu(id),
);

/// The cart holds items from one restaurant at a time.
class CartController extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  /// Whether adding from [restaurantId] would discard the current cart.
  bool wouldReplace(int restaurantId) =>
      !state.isEmpty && state.restaurantId != restaurantId;

  void add(Restaurant restaurant, MenuItem item) {
    var lines = state.lines;
    if (wouldReplace(restaurant.id)) lines = const [];

    final i = lines.indexWhere((l) => l.item.id == item.id);
    final next = [...lines];
    if (i >= 0) {
      next[i] = CartLine(item: item, quantity: next[i].quantity + 1);
    } else {
      next.add(CartLine(item: item, quantity: 1));
    }
    state = CartState(
      restaurantId: restaurant.id,
      restaurantName: restaurant.name,
      lines: next,
    );
  }

  void increase(int menuItemId) {
    state = CartState(
      restaurantId: state.restaurantId,
      restaurantName: state.restaurantName,
      lines: [
        for (final l in state.lines)
          l.item.id == menuItemId ? CartLine(item: l.item, quantity: l.quantity + 1) : l,
      ],
    );
  }

  void decrease(int menuItemId) {
    final next = <CartLine>[
      for (final l in state.lines)
        if (l.item.id == menuItemId)
          if (l.quantity > 1) CartLine(item: l.item, quantity: l.quantity - 1) else ...[]
        else
          l,
    ];
    state = next.isEmpty
        ? const CartState()
        : CartState(
            restaurantId: state.restaurantId,
            restaurantName: state.restaurantName,
            lines: next,
          );
  }

  void clear() => state = const CartState();
}

final cartProvider = NotifierProvider<CartController, CartState>(CartController.new);
