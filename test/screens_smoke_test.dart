import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oyaeat/core/providers.dart';
import 'package:oyaeat/core/storage/session_storage.dart';
import 'package:oyaeat/features/auth/presentation/login_screen.dart';
import 'package:oyaeat/features/customer/application/customer_providers.dart';
import 'package:oyaeat/features/customer/data/customer_repository.dart';
import 'package:oyaeat/features/customer/data/restaurant_repository.dart';
import 'package:oyaeat/features/customer/domain/address.dart';
import 'package:oyaeat/features/customer/domain/cart.dart';
import 'package:oyaeat/features/customer/domain/order.dart';
import 'package:oyaeat/features/customer/domain/promo.dart';
import 'package:oyaeat/features/customer/domain/restaurant.dart';
import 'package:oyaeat/features/customer/presentation/account_screens.dart';
import 'package:oyaeat/features/customer/presentation/cart_screen.dart';
import 'package:oyaeat/features/customer/presentation/home_screen.dart';
import 'package:oyaeat/features/customer/presentation/order_detail_screen.dart';
import 'package:oyaeat/features/customer/presentation/orders_screen.dart';
import 'package:oyaeat/features/customer/presentation/restaurant_screen.dart';
import 'package:oyaeat/features/rider/application/rider_providers.dart';
import 'package:oyaeat/features/rider/data/rider_repository.dart';
import 'package:oyaeat/features/rider/domain/rider_dashboard.dart';
import 'package:oyaeat/features/rider/presentation/rider_dashboard_screen.dart';

const _suya = Restaurant(
  id: 1,
  name: 'Suya Spot',
  type: 'Grills',
  city: 'Ikeja',
  state: 'Lagos',
  rating: 4.6,
  reviewCount: 12,
  deliveryFee: 1200,
  minimumOrder: 3000,
  openingHour: '09:00',
  closingHour: '22:00',
  description: 'The best suya in town.',
);
const _mamaPut = Restaurant(id: 2, name: 'Mama Put Kitchen', type: 'Nigerian', city: 'Yaba', state: 'Lagos', rating: 4.1);
const _pizza = Restaurant(id: 3, name: 'A Very Long Restaurant Name That Should Truncate Nicely', type: 'Pizza', city: 'Lekki');

class _FakeRestaurants extends Fake implements RestaurantRepository {
  @override
  Future<List<Restaurant>> list({String query = '', int page = 1, int limit = 20}) async => [_suya, _mamaPut, _pizza];

  @override
  Future<RestaurantMenu> menu(int restaurantId) async => const RestaurantMenu(restaurant: _suya, items: [
        MenuItem(id: 10, name: 'Beef suya', price: 2500, category: 'Grills', description: 'Spicy skewers with onions and yaji pepper.'),
        MenuItem(id: 11, name: 'Chicken suya', price: 3000, category: 'Grills'),
        MenuItem(id: 12, name: 'Zobo', price: 800, category: 'Drinks'),
      ]);
}

CustomerOrder _order(int id, OrderStatus status, {bool withRider = false}) => CustomerOrder(
      id: id,
      status: status,
      total: 6500,
      deliveryFee: 1500,
      createdAt: DateTime(2026, 10, 26, 12, 30),
      businessId: 1,
      businessName: 'Suya Spot',
      address: '12 Allen Ave, Ikeja',
      paymentMethod: 'cash',
      paymentStatus: 'pending',
      latitude: 6.5344,
      longitude: 3.3792,
      items: const [OrderLine(name: 'Beef suya', price: 2500, quantity: 2)],
      rider: withRider ? const RiderInfo(name: 'Tunde Bello', phone: '0803', vehicle: 'Motorcycle', plate: 'ABC-123') : null,
    );

class _FakeCustomer extends Fake implements CustomerRepository {
  @override
  Future<List<Promo>> promos() async => const [Promo(id: 1, title: '20% off all grills', description: 'This weekend only', businessId: 1)];
  @override
  Future<List<Restaurant>> favorites() async => [_suya];
  @override
  Future<void> addFavorite(int businessId) async {}
  @override
  Future<void> removeFavorite(int businessId) async {}
  @override
  Future<CustomerProfile> profile() async =>
      const CustomerProfile(firstName: 'Ada', lastName: 'Obi', email: 'ada@x.com', phone: '08012345678');
  @override
  Future<List<SavedAddress>> addresses() async => const [
        SavedAddress(id: 1, label: 'Home', address: '12 Allen Ave, Ikeja', latitude: 6.6, longitude: 3.35, isDefault: true),
        SavedAddress(id: 2, label: 'Work', address: 'Plot 4, Admiralty Way, Lekki Phase 1'),
      ];
  @override
  Future<List<CustomerOrder>> orders() async => [
        _order(2, OrderStatus.outForDelivery, withRider: true),
        _order(1, OrderStatus.delivered),
      ];
  @override
  Future<RiderLocation?> trackRider(int orderId) async =>
      const RiderLocation(name: 'Tunde Bello', latitude: 6.5244, longitude: 3.3792);
}

class _FakeRider extends Fake implements RiderRepository {
  final accepted = <int>[];

  @override
  Future<RiderDashboard> dashboard() async => const RiderDashboard(
        firstName: 'Tunde',
        isOnline: true,
        isApproved: true,
        todayEarnings: '₦4,800',
        completedToday: 3,
        activeDelivery: ActiveDelivery(
          orderId: 42,
          restaurant: 'Suya Spot',
          customer: 'Ada Obi',
          dropoff: '12 Allen Ave, Ikeja',
          payout: '₦1,200',
          status: 'ready',
          distance: '3.2 km',
        ),
        recentDeliveries: [RecentDelivery(restaurant: 'Mama Put Kitchen', payout: '₦900', time: '10:30 AM')],
      );

  @override
  Future<void> accept(int orderId) async => accepted.add(orderId);
}

class _MemoryStorage implements SessionStorage {
  @override
  Future<void> clear() async {}
  @override
  Future<Map<String, String>> read() async => {};
  @override
  Future<void> write(Map<String, String> values) async {}
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(390, 844),
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => screen),
    GoRoute(path: '/c/:rest', builder: (_, s) => Scaffold(body: Text('route ${s.uri}'))),
    GoRoute(path: '/c/restaurant/:id', builder: (_, s) => Scaffold(body: Text('restaurant ${s.pathParameters['id']}'))),
    GoRoute(path: '/c/order/:id', builder: (_, s) => Scaffold(body: Text('order ${s.pathParameters['id']}'))),
  ]);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      sessionStorageProvider.overrideWithValue(_MemoryStorage()),
      restaurantRepositoryProvider.overrideWithValue(_FakeRestaurants()),
      customerRepositoryProvider.overrideWithValue(_FakeCustomer()),
      ...overrides,
    ],
    child: MaterialApp.router(
      routerConfig: router,
      // Roboto instead of the test font, so text is measured like on a phone.
      theme: ThemeData(fontFamily: 'Roboto', useMaterial3: true),
    ),
  ));
  await _settle(tester);
}

Future<void> _loadRoboto() async {
  final loader = FontLoader('Roboto');
  for (final f in ['Regular', 'Medium', 'Bold', 'Black']) {
    final bytes = await File('test/fonts/Roboto-$f.ttf').readAsBytes();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

void main() {
  setUpAll(_loadRoboto);

  group('no layout overflow or exceptions', () {
    testWidgets('login at a small phone width', (tester) async {
      await _pump(tester, const LoginScreen(), size: const Size(320, 568));
      expect(find.text('Log in'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('home lists restaurants, filters by cuisine and opens one', (tester) async {
      await _pump(tester, const HomeScreen());

      expect(find.text('Suya Spot'), findsWidgets);
      expect(find.text('Mama Put Kitchen'), findsWidgets);
      expect(find.text('20% off all grills'), findsOneWidget);

      // Cuisine chips come from the restaurants' types and really filter.
      await tester.tap(find.text('Nigerian').first);
      await _settle(tester);
      expect(find.text('Mama Put Kitchen'), findsWidgets);
      expect(find.text('Suya Spot'), findsNothing);

      await tester.tap(find.text('Mama Put Kitchen').first);
      await _settle(tester);
      expect(find.text('restaurant 2'), findsOneWidget);
    });

    testWidgets('restaurant menu: sections, add to cart, cart bar', (tester) async {
      await _pump(tester, const RestaurantScreen(restaurantId: 1, initial: _suya));

      expect(find.text('Beef suya'), findsOneWidget);
      expect(find.textContaining('View cart'), findsNothing);

      // The category chip scrolls the Drinks section into view.
      await tester.tap(find.text('Drinks').first);
      await _settle(tester);
      expect(find.text('Zobo'), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 2000));
      await _settle(tester);

      // The "+" on a menu tile adds one item and shows the floating cart bar.
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await _settle(tester);
      expect(find.text('View cart · 1 item · ₦2,500'), findsOneWidget);
    });

    testWidgets('add via the sheet, then View cart opens the cart (first tap)', (tester) async {
      await _pump(tester, const RestaurantScreen(restaurantId: 1, initial: _suya));

      // Tap the dish to open the sheet, add two, confirm.
      await tester.tap(find.text('Beef suya'));
      await _settle(tester);
      expect(find.textContaining('Add to cart'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add_rounded).last); // stepper +
      await _settle(tester);
      await tester.tap(find.textContaining('Add to cart'));
      await _settle(tester);
      expect(find.textContaining('Add to cart'), findsNothing);

      expect(find.text('View cart · 2 items · ₦5,000'), findsOneWidget);
      await tester.tap(find.text('View cart · 2 items · ₦5,000'));
      await _settle(tester);
      expect(find.text('route /c/cart'), findsOneWidget);
    });

    testWidgets('cart shows the minimum-order warning and blocks checkout', (tester) async {
      await _pump(tester, const CartScreen(), overrides: [cartProvider.overrideWith(_LowCart.new)]);
      expect(find.textContaining('minimum order'), findsOneWidget);
      final checkout = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Checkout · ₦2,000'));
      expect(checkout.onPressed, isNull);
    });

    testWidgets('orders: active tab, then past tab', (tester) async {
      await _pump(tester, const OrdersScreen());
      expect(find.text('#2 · 26 Oct, 12:30 PM'), findsOneWidget);
      expect(find.text('#1 · 26 Oct, 12:30 PM'), findsNothing);

      await tester.tap(find.text('Past'));
      await _settle(tester);
      expect(find.text('#1 · 26 Oct, 12:30 PM'), findsOneWidget);
    });

    testWidgets('order detail shows the rider and how far away they are', (tester) async {
      await _pump(tester, const OrderDetailScreen(orderId: 2));
      expect(find.text('On the way'), findsWidgets);
      expect(find.text('Tunde Bello'), findsOneWidget);
      expect(find.text('Motorcycle · ABC-123'), findsOneWidget);
      // Rider at 6.5244, customer at 6.5344: about 1.1 km.
      expect(find.textMatching(RegExp(r'^1\.\d km away$')), findsOneWidget);
    });

    testWidgets('delivered order offers a review and no cancel', (tester) async {
      await _pump(tester, const OrderDetailScreen(orderId: 1));
      expect(find.text('Rate this order'), findsOneWidget);
      expect(find.text('Cancel order'), findsNothing);
    });

    testWidgets('addresses and favourites screens', (tester) async {
      await _pump(tester, const AddressesScreen());
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);
      expect(find.text('Plot 4, Admiralty Way, Lekki Phase 1'), findsOneWidget);

      await _pump(tester, const FavoritesScreen());
      expect(find.text('Suya Spot'), findsOneWidget);
    });

    testWidgets('rider dashboard: offer, accept', (tester) async {
      final rider = _FakeRider();
      await _pump(tester, const RiderDashboardScreen(), overrides: [riderRepositoryProvider.overrideWithValue(rider)]);

      expect(find.text('₦4,800'), findsOneWidget);
      expect(find.text('New offer'), findsOneWidget);
      expect(find.text('₦1,200'), findsOneWidget);

      await tester.tap(find.text('Accept delivery'));
      await _settle(tester);
      expect(rider.accepted, [42]);
    });
  });
}

class _LowCart extends CartController {
  @override
  CartState build() => const CartState(
        restaurantId: 1,
        restaurantName: 'Suya Spot',
        minimumOrder: 3000,
        lines: [CartLine(item: MenuItem(id: 10, name: 'Beef suya', price: 1000), quantity: 2)],
      );
}

extension on CommonFinders {
  Finder textMatching(RegExp re) => byWidgetPredicate((w) => w is Text && w.data != null && re.hasMatch(w.data!));
}
