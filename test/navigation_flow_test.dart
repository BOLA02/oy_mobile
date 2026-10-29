import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:oyaeat/core/providers.dart';
import 'package:oyaeat/core/router/app_router.dart';
import 'package:oyaeat/features/customer/application/customer_providers.dart';
import 'package:oyaeat/features/rider/application/offers.dart';
import 'package:oyaeat/features/splash/splash_screen.dart';
import 'package:oyaeat/features/rider/application/rider_providers.dart';

import 'support/fakes.dart';
import 'support/fonts.dart';
import 'support/memory_storage.dart';

class _App extends ConsumerWidget {
  const _App();

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        routerConfig: ref.watch(routerProvider),
        theme: ThemeData(fontFamily: 'Roboto', useMaterial3: true),
      );
}

const _customerSession = {'token': 't', 'role': 'customer', 'userId': '7', 'name': 'Ada Obi'};
const _riderSession = {'token': 'r', 'role': 'rider', 'userId': '12', 'name': 'Tunde Bello'};

Future<ProviderContainer> _launch(WidgetTester tester, {Map<String, String>? saved, List<Override> extra = const [], bool realSplash = false}) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(overrides: [
    sessionStorageProvider.overrideWithValue(MemoryStorage(saved)),
    restaurantRepositoryProvider.overrideWithValue(FakeRestaurants()),
    customerRepositoryProvider.overrideWithValue(FakeCustomer()),
    riderRepositoryProvider.overrideWithValue(FakeRider()),
    // Tests that are not about the splash should not sit through it.
    if (!realSplash) splashDurationProvider.overrideWithValue(const Duration(milliseconds: 50)),
    // Never open a real socket from a test.
    offerSocketProvider.overrideWithValue(FakeOfferSocket()),
    ...extra,
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const _App()));
  return container;
}

Future<void> _wait(WidgetTester tester, Duration total) async {
  for (var t = Duration.zero; t < total; t += const Duration(milliseconds: 100)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(loadRoboto);

  testWidgets('signed out: the splash plays, then the login appears', (tester) async {
    await _launch(tester, realSplash: true);
    await _wait(tester, const Duration(milliseconds: 500));

    // Splash: the saved session is already read, but the animation still holds the screen.
    expect(find.byKey(const ValueKey('splash')), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);

    // Still there well into the animation...
    await _wait(tester, const Duration(seconds: 3));
    expect(find.byKey(const ValueKey('splash')), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);

    // ...and gone once its time is up.
    await _wait(tester, const Duration(seconds: 1));
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byKey(const ValueKey('splash')), findsNothing);
  });

  testWidgets('a saved rider session skips login and lands on deliveries', (tester) async {
    await _launch(tester, saved: _riderSession);
    await _wait(tester, const Duration(seconds: 3));
    expect(find.text('Welcome back'), findsNothing);
    expect(find.text('Delivery offers'), findsOneWidget);
  });

  testWidgets('a saved customer session lands on Home, not on the rider side', (tester) async {
    await _launch(tester, saved: _customerSession);
    await _wait(tester, const Duration(seconds: 3));
    expect(find.text('Hi, Ada 👋'), findsOneWidget);
  });

  testWidgets('Track my order opens the order with a working Back button', (tester) async {
    final container = await _launch(tester, saved: _customerSession);
    await _wait(tester, const Duration(seconds: 3));
    final router = container.read(routerProvider);

    // What checkout does after placing an order.
    router.go('/c/home');
    router.push('/c/order-placed/2');
    await _wait(tester, const Duration(seconds: 1));
    expect(find.text('Order placed!'), findsOneWidget);

    await tester.tap(find.text('Track my order'));
    await _wait(tester, const Duration(seconds: 1));
    expect(find.text('Order #2'), findsOneWidget);

    // The bug: there used to be no way back from here.
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await _wait(tester, const Duration(seconds: 1));
    expect(find.text('Hi, Ada 👋'), findsOneWidget);
  });

  testWidgets('Back on an order opened as the first page falls back to Orders', (tester) async {
    final container = await _launch(tester, saved: _customerSession);
    await _wait(tester, const Duration(seconds: 3));

    // `go` replaces the stack, so there is nothing to pop to.
    container.read(routerProvider).go('/c/order/2');
    await _wait(tester, const Duration(seconds: 1));
    expect(find.text('Order #2'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await _wait(tester, const Duration(seconds: 1));
    expect(find.text('My orders'), findsOneWidget);
  });
}
