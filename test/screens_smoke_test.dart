import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oyaeat/core/providers.dart';
import 'package:oyaeat/features/auth/presentation/join_screen.dart';
import 'package:oyaeat/features/auth/presentation/login_screen.dart';
import 'package:oyaeat/features/customer/application/customer_providers.dart';
import 'package:oyaeat/features/customer/domain/cart.dart';
import 'package:oyaeat/features/customer/domain/restaurant.dart';
import 'package:oyaeat/features/customer/presentation/account_screens.dart';
import 'package:oyaeat/features/customer/presentation/cart_screen.dart';
import 'package:oyaeat/features/customer/presentation/home_screen.dart';
import 'package:oyaeat/features/customer/presentation/order_detail_screen.dart';
import 'package:oyaeat/features/customer/presentation/orders_screen.dart';
import 'package:oyaeat/features/customer/presentation/restaurant_screen.dart';
import 'package:oyaeat/features/rider/application/rider_providers.dart';
import 'package:oyaeat/features/rider/presentation/rider_dashboard_screen.dart';

import 'support/fakes.dart';
import 'support/fonts.dart';
import 'support/memory_storage.dart';

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
    GoRoute(path: '/rider-register', builder: (_, s) => Scaffold(body: Text('route ${s.uri}'))),
    GoRoute(path: '/signup', builder: (_, s) => Scaffold(body: Text('route ${s.uri}'))),
    GoRoute(path: '/c/restaurant/:id', builder: (_, s) => Scaffold(body: Text('restaurant ${s.pathParameters['id']}'))),
    GoRoute(path: '/c/order/:id', builder: (_, s) => Scaffold(body: Text('order ${s.pathParameters['id']}'))),
  ]);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      sessionStorageProvider.overrideWithValue(MemoryStorage()),
      restaurantRepositoryProvider.overrideWithValue(FakeRestaurants()),
      customerRepositoryProvider.overrideWithValue(FakeCustomer()),
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

void main() {
  setUpAll(loadRoboto);

  group('no layout overflow or exceptions', () {
    testWidgets('login at a small phone width', (tester) async {
      await _pump(tester, const LoginScreen(), size: const Size(320, 568));
      expect(find.text('Log in'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('join screen offers both roles and routes to the right form', (tester) async {
      await _pump(tester, const JoinScreen());
      expect(find.text('Order food'), findsOneWidget);
      expect(find.text('Deliver with us'), findsOneWidget);

      await tester.tap(find.text('Deliver with us'));
      await _settle(tester);
      expect(find.text('route /rider-register'), findsOneWidget);
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
      await _pump(tester, const RestaurantScreen(restaurantId: 1, initial: suya));

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
      await _pump(tester, const RestaurantScreen(restaurantId: 1, initial: suya));

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
      final rider = FakeRider();
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
