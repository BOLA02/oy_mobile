import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyaeat/features/customer/application/customer_providers.dart';
import 'package:oyaeat/features/customer/domain/restaurant.dart';
import 'package:oyaeat/features/rider/domain/rider_dashboard.dart';

const _pizza = Restaurant(id: 1, name: 'Pizza Place');
const _suya = Restaurant(id: 2, name: 'Suya Spot');
const _a = MenuItem(id: 10, name: 'Margherita', price: 3500);
const _b = MenuItem(id: 11, name: 'Pepperoni', price: 4000);
const _c = MenuItem(id: 20, name: 'Beef suya', price: 2500);

void main() {
  group('Restaurant.fromJson', () {
    test('falls back to the first gallery image when there is no thumbnail', () {
      final r = Restaurant.fromJson({
        'id': 1,
        'name': 'X',
        'thumbnailUrl': null,
        'profilePicUrl': null,
        'galleryImages': [
          {'id': 1, 'imageUrl': 'http://img/1.jpg'},
        ],
        'rating': 4.5,
        'reviewCount': 3,
      });
      expect(r.imageUrl, 'http://img/1.jpg');
      expect(r.rating, 4.5);
    });

    test('groups menu items by category', () {
      final m = RestaurantMenu(restaurant: _pizza, items: const [
        MenuItem(id: 1, name: 'a', price: 1, category: 'Mains'),
        MenuItem(id: 2, name: 'b', price: 1, category: 'Drinks'),
        MenuItem(id: 3, name: 'c', price: 1, category: 'Mains'),
        MenuItem(id: 4, name: 'd', price: 1),
      ]);
      expect(m.byCategory.keys, ['Mains', 'Drinks', 'Menu']);
      expect(m.byCategory['Mains']!.length, 2);
    });
  });

  group('Cart', () {
    late ProviderContainer c;
    late CartController cart;

    setUp(() {
      c = ProviderContainer();
      addTearDown(c.dispose);
      cart = c.read(cartProvider.notifier);
    });

    test('adding the same item increments quantity and totals correctly', () {
      cart
        ..add(_pizza, _a)
        ..add(_pizza, _a)
        ..add(_pizza, _b);
      final s = c.read(cartProvider);
      expect(s.itemCount, 3);
      expect(s.subtotal, 3500 * 2 + 4000);
      expect(s.restaurantName, 'Pizza Place');
    });

    test('adding from another restaurant starts a fresh cart', () {
      cart.add(_pizza, _a);
      expect(cart.wouldReplace(_suya.id), isTrue);
      cart.add(_suya, _c);
      final s = c.read(cartProvider);
      expect(s.restaurantId, 2);
      expect(s.lines.single.item.id, 20);
    });

    test('decrease removes the line at zero and empties the cart', () {
      cart
        ..add(_pizza, _a)
        ..add(_pizza, _a);
      cart.decrease(_a.id);
      expect(c.read(cartProvider).itemCount, 1);
      cart.decrease(_a.id);
      expect(c.read(cartProvider).isEmpty, isTrue);
      expect(c.read(cartProvider).restaurantId, isNull);
    });

    test('increase bumps only the chosen line', () {
      cart
        ..add(_pizza, _a)
        ..add(_pizza, _b)
        ..increase(_b.id);
      final lines = c.read(cartProvider).lines;
      expect(lines.firstWhere((l) => l.item.id == _a.id).quantity, 1);
      expect(lines.firstWhere((l) => l.item.id == _b.id).quantity, 2);
    });
  });

  group('Rider dashboard', () {
    test('parses the un-wrapped payload and the ORD- prefixed id', () {
      final d = RiderDashboard.fromJson({
        'isOnline': true,
        'status': 'active',
        'profile': {'firstName': 'Tunde'},
        'stats': {'todayEarnings': '₦2,400', 'completedToday': 2},
        'activeDelivery': {
          'id': 'ORD-42',
          'restaurant': 'Suya Spot',
          'customer': 'Ada',
          'dropoff': '12 Allen Ave',
          'payout': '₦1,200',
          'status': 'ready',
          'distance': '3.2 km',
        },
        'recentDeliveries': [
          {'id': 'ORD-40', 'payout': '₦900', 'restaurant': 'Pizza Place', 'time': '10:30 AM'},
        ],
      });
      expect(d.isApproved, isTrue);
      expect(d.activeDelivery!.orderId, 42);
      expect(d.activeDelivery!.isAccepted, isFalse); // ready = still an offer
      expect(d.recentDeliveries.single.restaurant, 'Pizza Place');
    });

    test('an unapproved rider with no delivery', () {
      final d = RiderDashboard.fromJson({'isOnline': false, 'status': 'pending', 'activeDelivery': null});
      expect(d.isApproved, isFalse);
      expect(d.activeDelivery, isNull);
    });
  });
}
