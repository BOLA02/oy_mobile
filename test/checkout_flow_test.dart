import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oyaeat/features/customer/application/customer_providers.dart';
import 'package:oyaeat/features/customer/data/customer_repository.dart';
import 'package:oyaeat/features/customer/domain/address.dart';
import 'package:oyaeat/features/customer/domain/cart.dart';
import 'package:oyaeat/features/customer/domain/order.dart';
import 'package:oyaeat/features/customer/domain/restaurant.dart';
import 'package:oyaeat/features/customer/presentation/checkout_screen.dart';

class _FakeRepo extends Fake implements CustomerRepository {
  CartState? orderedCart;
  CheckoutDetails? orderedDetails;
  final quotes = <({double? lat, double? lng})>[];

  @override
  Future<CustomerProfile> profile() async =>
      const CustomerProfile(firstName: 'Ada', lastName: 'Obi', email: 'ada@x.com', phone: '08012345678');

  @override
  Future<List<SavedAddress>> addresses() async => const [
        SavedAddress(id: 1, label: 'Home', address: '12 Allen Ave, Ikeja', latitude: 6.6, longitude: 3.35, isDefault: true),
      ];

  @override
  Future<DeliveryQuote> quote(int businessId, {double? latitude, double? longitude}) async {
    quotes.add((lat: latitude, lng: longitude));
    return const DeliveryQuote(fee: 1500, distanceKm: 4.2);
  }

  @override
  Future<CustomerOrder> placeCashOrder(CartState cart, CheckoutDetails d) async {
    orderedCart = cart;
    orderedDetails = d;
    return CustomerOrder(
      id: 77,
      status: OrderStatus.pending,
      total: 6500,
      createdAt: DateTime(2026, 10, 26),
      businessId: 4,
      businessName: 'Suya Spot',
      items: const [],
    );
  }

  @override
  Future<List<CustomerOrder>> orders() async => const [];
}

class _SeededCart extends CartController {
  @override
  CartState build() => const CartState(
        restaurantId: 4,
        restaurantName: 'Suya Spot',
        lines: [CartLine(item: MenuItem(id: 20, name: 'Beef suya', price: 2500), quantity: 2)],
      );
}

void main() {
  testWidgets('shows the quoted fee and total, then places a cash order', (tester) async {
    final repo = _FakeRepo();
    final router = GoRouter(
      initialLocation: '/c/checkout',
      routes: [
        GoRoute(path: '/c/home', builder: (_, _) => const Scaffold(body: Text('home'))),
        GoRoute(path: '/c/checkout', builder: (_, _) => const CheckoutScreen()),
        GoRoute(path: '/c/order-placed/:id', builder: (_, s) => Scaffold(body: Text('placed ${s.pathParameters['id']}'))),
      ],
    );

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        customerRepositoryProvider.overrideWithValue(repo),
        cartProvider.overrideWith(_SeededCart.new),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    // Let the address, profile and quote futures resolve (shimmers never "settle").
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Default address is selected and the fee was quoted using its pin.
    expect(find.text('12 Allen Ave, Ikeja'), findsOneWidget);
    expect(repo.quotes.last, (lat: 6.6, lng: 3.35));
    // The profile prefilled the contact fields.
    expect(find.widgetWithText(TextFormField, 'Ada Obi'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '08012345678'), findsOneWidget);
    // 2 x ₦2,500 + ₦1,500 delivery.
    expect(find.textContaining('₦5,000'), findsWidgets);
    expect(find.textContaining('₦1,500'), findsOneWidget);
    expect(find.textContaining('₦6,500'), findsWidgets);

    // Switch to cash and place the order.
    await tester.tap(find.text('Cash on delivery'));
    await tester.pump();
    expect(find.text('Place order · ₦6,500'), findsOneWidget);
    await tester.tap(find.text('Place order · ₦6,500'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(repo.orderedDetails!.address, '12 Allen Ave, Ikeja');
    expect(repo.orderedDetails!.customerPhone, '08012345678');
    expect(repo.orderedDetails!.latitude, 6.6);
    expect(repo.orderedCart!.itemCount, 2);
    expect(find.text('placed 77'), findsOneWidget);
  });
}
