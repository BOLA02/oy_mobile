import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/customer_repository.dart';
import '../data/restaurant_repository.dart';
import '../domain/address.dart';
import '../domain/cart.dart';
import '../domain/order.dart';
import '../domain/promo.dart';
import '../domain/restaurant.dart';

final restaurantRepositoryProvider =
    Provider<RestaurantRepository>((ref) => RestaurantRepository(ref.watch(apiClientProvider)));

final customerRepositoryProvider =
    Provider<CustomerRepository>((ref) => CustomerRepository(ref.watch(apiClientProvider)));

// ── Browsing ─────────────────────────────────────────────────

/// The text typed in the home search box. Changing it reloads the list.
class RestaurantQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}

final restaurantQueryProvider = NotifierProvider<RestaurantQuery, String>(RestaurantQuery.new);

/// The cuisine chip currently selected on the home screen (null = all).
class SelectedCuisine extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? value) => state = value;
}

final selectedCuisineProvider = NotifierProvider<SelectedCuisine, String?>(SelectedCuisine.new);

final restaurantsProvider = FutureProvider<List<Restaurant>>((ref) {
  final query = ref.watch(restaurantQueryProvider).trim();
  return ref.watch(restaurantRepositoryProvider).list(query: query, limit: 50);
});

final restaurantMenuProvider = FutureProvider.family<RestaurantMenu, int>(
  (ref, id) => ref.watch(restaurantRepositoryProvider).menu(id),
);

final promosProvider = FutureProvider<List<Promo>>((ref) => ref.watch(customerRepositoryProvider).promos());

final profileProvider =
    FutureProvider<CustomerProfile>((ref) => ref.watch(customerRepositoryProvider).profile());

// ── Favourites ───────────────────────────────────────────────

/// Ids of favourite restaurants. Toggling updates the UI immediately and rolls
/// back if the server rejects it.
class FavoritesController extends AsyncNotifier<Set<int>> {
  @override
  Future<Set<int>> build() async {
    final list = await ref.watch(customerRepositoryProvider).favorites();
    return {for (final r in list) r.id};
  }

  Future<void> toggle(int businessId) async {
    final current = state.value ?? <int>{};
    final adding = !current.contains(businessId);
    state = AsyncData(adding ? {...current, businessId} : ({...current}..remove(businessId)));
    try {
      final repo = ref.read(customerRepositoryProvider);
      adding ? await repo.addFavorite(businessId) : await repo.removeFavorite(businessId);
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }
}

final favoritesProvider = AsyncNotifierProvider<FavoritesController, Set<int>>(FavoritesController.new);

final favoriteRestaurantsProvider = FutureProvider.autoDispose<List<Restaurant>>((ref) {
  ref.watch(favoritesProvider); // refresh when a favourite is toggled
  return ref.watch(customerRepositoryProvider).favorites();
});

// ── Addresses ────────────────────────────────────────────────

final addressesProvider = FutureProvider.autoDispose<List<SavedAddress>>(
  (ref) => ref.watch(customerRepositoryProvider).addresses(),
);

// ── Orders ───────────────────────────────────────────────────

final ordersProvider = FutureProvider.autoDispose<List<CustomerOrder>>(
  (ref) => ref.watch(customerRepositoryProvider).orders(),
);

/// A single order picked out of the orders list.
final orderProvider = Provider.autoDispose.family<AsyncValue<CustomerOrder?>, int>((ref, id) {
  return ref.watch(ordersProvider).whenData((list) => list.where((o) => o.id == id).firstOrNull);
});

final riderLocationProvider = FutureProvider.autoDispose.family<RiderLocation?, int>(
  (ref, orderId) => ref.watch(customerRepositoryProvider).trackRider(orderId),
);

// ── Checkout ─────────────────────────────────────────────────

typedef QuoteKey = ({int businessId, double? latitude, double? longitude});

final deliveryQuoteProvider = FutureProvider.autoDispose.family<DeliveryQuote, QuoteKey>(
  (ref, k) => ref.watch(customerRepositoryProvider).quote(k.businessId, latitude: k.latitude, longitude: k.longitude),
);

/// The cart holds items from one restaurant at a time.
class CartController extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  /// Whether adding from [restaurantId] would discard the current cart.
  bool wouldReplace(int restaurantId) => !state.isEmpty && state.restaurantId != restaurantId;

  int quantityOf(int menuItemId) =>
      state.lines.where((l) => l.item.id == menuItemId).fold(0, (n, l) => n + l.quantity);

  void add(Restaurant restaurant, MenuItem item, {int quantity = 1}) {
    var lines = state.lines;
    if (wouldReplace(restaurant.id)) lines = const [];

    final i = lines.indexWhere((l) => l.item.id == item.id);
    final next = [...lines];
    if (i >= 0) {
      next[i] = CartLine(item: item, quantity: next[i].quantity + quantity);
    } else {
      next.add(CartLine(item: item, quantity: quantity));
    }
    state = CartState(
      restaurantId: restaurant.id,
      restaurantName: restaurant.name,
      deliveryFee: restaurant.deliveryFee,
      minimumOrder: restaurant.minimumOrder,
      lines: next,
    );
  }

  void increase(int menuItemId) {
    state = state.copyWithLines([
      for (final l in state.lines)
        l.item.id == menuItemId ? CartLine(item: l.item, quantity: l.quantity + 1) : l,
    ]);
  }

  void decrease(int menuItemId) {
    final next = <CartLine>[
      for (final l in state.lines)
        if (l.item.id == menuItemId)
          if (l.quantity > 1) CartLine(item: l.item, quantity: l.quantity - 1) else ...[]
        else
          l,
    ];
    state = next.isEmpty ? const CartState() : state.copyWithLines(next);
  }

  void remove(int menuItemId) {
    final next = state.lines.where((l) => l.item.id != menuItemId).toList();
    state = next.isEmpty ? const CartState() : state.copyWithLines(next);
  }

  /// Puts a previously removed line back (undo).
  void restore(CartLine line) {
    if (state.lines.any((l) => l.item.id == line.item.id)) return;
    state = state.copyWithLines([...state.lines, line]);
  }

  void clear() => state = const CartState();
}

final cartProvider = NotifierProvider<CartController, CartState>(CartController.new);
