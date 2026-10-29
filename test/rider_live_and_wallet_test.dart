import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyaeat/core/network/api_exception.dart';
import 'package:oyaeat/core/providers.dart';
import 'package:oyaeat/core/router/app_router.dart';
import 'package:oyaeat/features/rider/application/offers.dart';
import 'package:oyaeat/features/rider/application/rider_providers.dart';
import 'package:oyaeat/features/rider/domain/delivery_offer.dart';
import 'package:oyaeat/features/rider/domain/wallet.dart';
import 'package:oyaeat/features/rider/presentation/wallet_screen.dart';
import 'package:oyaeat/features/splash/splash_screen.dart';

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

const _riderSession = {'token': 'r', 'role': 'rider', 'userId': '12', 'name': 'Tunde Bello'};

class _Rig {
  _Rig(this.container, this.socket, this.rider);

  final ProviderContainer container;
  final FakeOfferSocket socket;
  final FakeRider rider;
}

Future<_Rig> _launchRider(WidgetTester tester, {FakeOfferSocket? socket}) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final fakeSocket = socket ?? FakeOfferSocket();
  final rider = FakeRider();
  final container = ProviderContainer(overrides: [
    sessionStorageProvider.overrideWithValue(MemoryStorage(_riderSession)),
    riderRepositoryProvider.overrideWithValue(rider),
    offerSocketProvider.overrideWithValue(fakeSocket),
    splashDurationProvider.overrideWithValue(const Duration(milliseconds: 50)),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const _App()));
  // Past the splash, onto the rider's deliveries.
  for (var i = 0; i < 32; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return _Rig(container, fakeSocket, rider);
}

Future<void> _wait(WidgetTester tester, [Duration total = const Duration(milliseconds: 600)]) async {
  for (var t = Duration.zero; t < total; t += const Duration(milliseconds: 100)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(loadRoboto);

  group('DeliveryOffer.fromJson', () {
    test('reads the server payload', () {
      final o = DeliveryOffer.fromJson({
        'orderId': 42,
        'restaurantName': 'Suya Spot',
        'payout': 1200,
        'distance': '1.4 km',
        'dropoffAddress': '12 Allen Ave',
      })!;
      expect((o.orderId, o.restaurantName, o.payout, o.distance, o.dropoffAddress), (42, 'Suya Spot', 1200.0, '1.4 km', '12 Allen Ave'));
    });

    test('tolerates strings and missing fields', () {
      final o = DeliveryOffer.fromJson({'orderId': '7', 'payout': '₦1,350'})!;
      expect(o.orderId, 7);
      expect(o.payout, 1350);
      expect(o.restaurantName, 'Restaurant');
    });

    test('a malformed event is ignored instead of crashing the socket callback', () {
      expect(DeliveryOffer.fromJson(null), isNull);
      expect(DeliveryOffer.fromJson('nope'), isNull);
      expect(DeliveryOffer.fromJson({'restaurantName': 'x'}), isNull);
    });
  });

  group('offers queue', () {
    test('socket events land in the queue, and a repeat replaces the earlier one', () async {
      final socket = FakeOfferSocket();
      final container = ProviderContainer(overrides: [offerSocketProvider.overrideWithValue(socket)]);
      addTearDown(container.dispose);
      container.listen(offersProvider, (_, _) {});

      socket.emitOffer(offer(1));
      socket.emitOffer(offer(2));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(offersProvider).map((o) => o.orderId), [1, 2]);

      socket.emitOffer(offer(1, payout: 1500));
      await Future<void>.delayed(Duration.zero);
      final queue = container.read(offersProvider);
      expect(queue.map((o) => o.orderId), [1, 2]);
      expect(queue.first.payout, 1500);

      container.read(offersProvider.notifier).remove(1);
      expect(container.read(offersProvider).map((o) => o.orderId), [2]);
    });

    test('no socket for a signed-out user means no offers and not live', () async {
      final container = ProviderContainer(overrides: [offerSocketProvider.overrideWithValue(null)]);
      addTearDown(container.dispose);
      expect(container.read(offersProvider), isEmpty);
      container.listen(liveConnectionProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(container.read(liveConnectionProvider).value, isFalse);
    });
  });

  group('live offer on screen', () {
    testWidgets('an offer pops up; accepting claims it and returns to deliveries', (tester) async {
      final rig = await _launchRider(tester);
      expect(find.text('Live'), findsOneWidget);

      rig.socket.emitOffer(offer(55, restaurant: 'Mama Put Kitchen', payout: 1350));
      await _wait(tester);

      expect(find.text('New delivery request'), findsOneWidget);
      expect(find.text('₦1,350'), findsOneWidget);
      expect(find.text('Mama Put Kitchen'), findsOneWidget);
      expect(find.text('1.4 km away'), findsOneWidget);

      await tester.tap(find.text('Accept delivery').last);
      await _wait(tester, const Duration(seconds: 1));

      expect(rig.rider.accepted, [55]);
      expect(find.text('New delivery request'), findsNothing);
      expect(find.text('Delivery accepted. Head to the restaurant!'), findsOneWidget);
      expect(rig.container.read(offersProvider), isEmpty);
    });

    testWidgets('declining tells the server and clears the offer', (tester) async {
      final rig = await _launchRider(tester);
      rig.socket.emitOffer(offer(56));
      await _wait(tester);

      await tester.tap(find.text('Decline').last);
      await _wait(tester, const Duration(seconds: 1));

      expect(rig.rider.declined, [56]);
      expect(rig.rider.accepted, isEmpty);
      expect(find.text('New delivery request'), findsNothing);
    });

    testWidgets('another rider got there first: say so, then close', (tester) async {
      final rig = await _launchRider(tester);
      rig.rider.acceptError = const ApiException('This order is no longer available.', statusCode: 409);
      rig.socket.emitOffer(offer(57));
      await _wait(tester);

      await tester.tap(find.text('Accept delivery').last);
      await _wait(tester);
      expect(find.text('This delivery was just taken by another rider.'), findsOneWidget);

      await _wait(tester, const Duration(seconds: 2));
      expect(find.text('New delivery request'), findsNothing);
      expect(find.text('That delivery was taken by another rider.'), findsOneWidget);
    });

    testWidgets('any other accept error stays on screen so the rider can retry', (tester) async {
      final rig = await _launchRider(tester);
      rig.rider.acceptError = const ApiException('You must go online before accepting orders.', statusCode: 400);
      rig.socket.emitOffer(offer(58));
      await _wait(tester);

      await tester.tap(find.text('Accept delivery').last);
      await _wait(tester);
      expect(find.text('You must go online before accepting orders.'), findsOneWidget);
      expect(find.text('New delivery request'), findsOneWidget);

      rig.rider.acceptError = null;
      await tester.tap(find.text('Accept delivery').last);
      await _wait(tester, const Duration(seconds: 1));
      expect(rig.rider.accepted, [58]);
    });

    testWidgets('two offers are shown one after the other', (tester) async {
      final rig = await _launchRider(tester);
      rig.socket.emitOffer(offer(60, restaurant: 'First Kitchen'));
      rig.socket.emitOffer(offer(61, restaurant: 'Second Kitchen'));
      await _wait(tester);
      expect(find.text('First Kitchen'), findsOneWidget);
      expect(find.text('Second Kitchen'), findsNothing);

      await tester.tap(find.text('Decline').last);
      await _wait(tester, const Duration(seconds: 1));
      expect(find.text('Second Kitchen'), findsOneWidget);
      expect(rig.rider.declined, [60]);
    });

    testWidgets('an unanswered offer is put away after the countdown', (tester) async {
      final rig = await _launchRider(tester);
      rig.socket.emitOffer(offer(62));
      await _wait(tester);
      expect(find.text('New delivery request'), findsOneWidget);

      await tester.pump(const Duration(seconds: 46));
      await _wait(tester);
      expect(find.text('New delivery request'), findsNothing);
      // Expiry is local only: nothing was declined on the server.
      expect(rig.rider.declined, isEmpty);
    });

    testWidgets('the Live badge follows the connection', (tester) async {
      final rig = await _launchRider(tester);
      expect(find.text('Live'), findsOneWidget);

      rig.socket.setConnected(false);
      await _wait(tester);
      expect(find.text('Connecting…'), findsOneWidget);
      expect(find.text('Live'), findsNothing);

      rig.socket.setConnected(true);
      await _wait(tester);
      expect(find.text('Live'), findsOneWidget);
    });

    testWidgets('offers keep arriving while the rider is on another tab', (tester) async {
      final rig = await _launchRider(tester);
      await tester.tap(find.text('Wallet'));
      await _wait(tester);
      expect(find.text('Available balance'), findsOneWidget);

      rig.socket.emitOffer(offer(63));
      await _wait(tester);
      expect(find.text('New delivery request'), findsOneWidget);
    });
  });

  // ── Wallet ──────────────────────────────────────────────────────────
  final now = DateTime(2026, 10, 28, 14, 0); // a Wednesday; the week began Sunday 25th

  WalletTx tx(String id, double amount, DateTime at, {TxType type = TxType.credit, TxStatus status = TxStatus.completed, String description = 'Delivery earnings'}) =>
      WalletTx(id: id, amount: amount, type: type, status: status, description: description, createdAt: at);

  WalletSummary summary({double balance = 6000, double pending = 0, bool bank = true, bool verified = true, String account = 'GTBank - 0123456789 (Tunde Bello)', List<WalletTx>? txs}) =>
      WalletSummary(
        balance: balance,
        pendingPayouts: pending,
        hasBankDetails: bank && verified,
        bankVerified: verified,
        linkedBankAccount: account,
        transactions: txs ??
            [
              tx('a', 1200, DateTime(2026, 10, 28, 10)),
              tx('b', 900, DateTime(2026, 10, 28, 9)),
              tx('c', 1500, DateTime(2026, 10, 27, 18)),
              tx('d', 700, DateTime(2026, 10, 25, 12)), // Sunday: start of this week
              tx('e', 2000, DateTime(2026, 10, 20, 12)), // last week
              tx('f', 3000, DateTime(2026, 10, 26, 8), type: TxType.debit, status: TxStatus.pending, description: 'Manual Withdrawal Request'),
              tx('g', 999, DateTime(2026, 10, 28, 8), status: TxStatus.failed),
            ],
      );

  group('WalletSummary maths', () {
    test('today, this week (from Sunday) and the last seven days', () {
      final w = summary();
      expect(w.today(now), 2100); // 1,200 + 900; the failed credit does not count
      expect(w.thisWeek(now), 4300); // + 1,500 + 700, not the debit, not last week
      final days = w.lastSevenDays(now);
      expect(days.length, 7);
      expect(days.last.day, DateTime(2026, 10, 28));
      expect(days.last.amount, 2100);
      expect(days.map((d) => d.amount).reduce((a, b) => a + b), 4300);
    });

    test('Sunday: the week has only just begun', () {
      final w = summary(txs: [tx('x', 500, DateTime(2026, 10, 25, 9)), tx('y', 800, DateTime(2026, 10, 24, 9))]);
      expect(w.thisWeek(DateTime(2026, 10, 25, 15)), 500);
    });

    test('withdraw rules and the reason shown when blocked', () {
      expect(summary().canWithdraw, isTrue);
      expect(summary().withdrawBlockedReason, isNull);
      expect(summary(balance: 0).withdrawBlockedReason, 'Nothing to withdraw yet.');
      expect(summary(account: 'Not setup yet. Please email support.', bank: false, verified: false).withdrawBlockedReason, contains('emailing support'));
      expect(summary(verified: false).withdrawBlockedReason, contains('verification'));
    });

    test('parses the server payload', () {
      final w = WalletSummary.fromJson({
        'wallet': {
          'balance': 5200.5,
          'pendingPayouts': 3000,
          'transactions': [
            {'id': 'u1', 'amount': 1200, 'type': 'credit', 'status': 'completed', 'description': 'Delivery', 'createdAt': '2026-10-28T10:00:00.000Z', 'orderId': 4},
            {'id': 'u2', 'amount': 3000, 'type': 'debit', 'status': 'pending', 'description': 'Withdrawal', 'createdAt': '2026-10-27T10:00:00.000Z'},
          ],
        },
        'hasBankDetails': true,
        'bankVerified': true,
        'linkedBankAccount': 'GTBank - 0123456789 (Tunde Bello)',
      });
      expect(w.balance, 5200.5);
      expect(w.pendingPayouts, 3000);
      expect(w.transactions.map((t) => (t.type, t.status)), [(TxType.credit, TxStatus.completed), (TxType.debit, TxStatus.pending)]);
      expect(w.transactions.first.orderId, 4);
      expect(w.canWithdraw, isTrue);
    });
  });

  group('wallet screen', () {
    Future<FakeRider> pumpWallet(WidgetTester tester, WalletSummary w) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final rider = FakeRider()..walletResult = w;
      await tester.pumpWidget(ProviderScope(
        overrides: [riderRepositoryProvider.overrideWithValue(rider)],
        child: MaterialApp(theme: ThemeData(fontFamily: 'Roboto', useMaterial3: true), home: WalletScreen(now: now)),
      ));
      await _wait(tester, const Duration(seconds: 1));
      return rider;
    }

    testWidgets('shows balance, earnings, bank and transactions', (tester) async {
      await pumpWallet(tester, summary(pending: 3000));
      expect(find.text('₦6,000'), findsOneWidget); // balance
      expect(find.text('₦2,100'), findsWidgets); // today
      expect(find.text('₦4,300'), findsWidgets); // this week
      expect(find.text('₦3,000 on its way to your bank'), findsOneWidget);
      expect(find.text('GTBank - 0123456789 (Tunde Bello)'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Last 7 days'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Manual Withdrawal Request'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Manual Withdrawal Request'), findsOneWidget);
      expect(find.text('−₦3,000'), findsOneWidget);
      expect(find.text('Pending'), findsWidgets);
    });

    testWidgets('withdrawing sends the amount and confirms', (tester) async {
      final rider = await pumpWallet(tester, summary());
      await tester.tap(find.text('Withdraw'));
      await _wait(tester);
      expect(find.text('Withdraw to your bank'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '5,500');
      await tester.tap(find.text('Request payout'));
      await _wait(tester, const Duration(seconds: 1));

      expect(rider.payouts, [5500]);
      expect(find.text('Withdrawal requested'), findsOneWidget);
    });

    testWidgets('"Withdraw all" fills the whole balance', (tester) async {
      final rider = await pumpWallet(tester, summary(balance: 7250));
      await tester.tap(find.text('Withdraw'));
      await _wait(tester);
      await tester.tap(find.text('Withdraw all'));
      await tester.pump();
      await tester.tap(find.text('Request payout'));
      await _wait(tester, const Duration(seconds: 1));
      expect(rider.payouts, [7250]);
    });

    testWidgets('more than the balance is stopped before it reaches the server', (tester) async {
      final rider = await pumpWallet(tester, summary(balance: 6000));
      await tester.tap(find.text('Withdraw'));
      await _wait(tester);
      await tester.enterText(find.byType(TextField), '9000');
      await tester.tap(find.text('Request payout'));
      await _wait(tester);

      expect(find.textContaining('more than your available balance'), findsOneWidget);
      expect(rider.payouts, isEmpty);
    });

    testWidgets("the server's reason (e.g. the minimum balance) is shown as it is", (tester) async {
      final rider = await pumpWallet(tester, summary(balance: 3000));
      rider.payoutError = const ApiException('Your balance must be at least ₦5,000 to request a payout.', statusCode: 400);
      await tester.tap(find.text('Withdraw'));
      await _wait(tester);
      await tester.enterText(find.byType(TextField), '3000');
      await tester.tap(find.text('Request payout'));
      await _wait(tester);

      expect(find.text('Your balance must be at least ₦5,000 to request a payout.'), findsOneWidget);
      expect(find.text('Withdraw to your bank'), findsOneWidget); // still open to adjust
    });

    testWidgets('no verified bank account: withdraw is off and says why', (tester) async {
      await pumpWallet(tester, summary(account: 'Not setup yet. Please email support.', bank: false, verified: false));
      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Withdraw'));
      expect(button.onPressed, isNull);
      expect(find.text('Add a bank account by emailing support.'), findsOneWidget);
      expect(find.text('Contact support to add your bank account'), findsOneWidget);
    });

    testWidgets('an empty wallet shows an empty state, not a blank screen', (tester) async {
      await pumpWallet(tester, summary(balance: 0, txs: const []));
      await tester.scrollUntilVisible(find.text('No transactions yet'), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('No transactions yet'), findsOneWidget);
      expect(find.text('Nothing to withdraw yet.'), findsOneWidget);
    });
  });
}
