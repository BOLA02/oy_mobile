import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyaeat/core/network/api_client.dart';
import 'package:oyaeat/core/network/api_exception.dart';
import 'package:oyaeat/features/customer/data/customer_repository.dart';
import 'package:oyaeat/features/customer/domain/cart.dart';
import 'package:oyaeat/features/customer/domain/order.dart';
import 'package:oyaeat/features/customer/domain/promo.dart';
import 'package:oyaeat/features/customer/domain/restaurant.dart';

import 'support/fake_adapter.dart';

CustomerRepository repoFor(FakeAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
  return CustomerRepository(ApiClient(readToken: () => 't', onUnauthorized: () {}, dio: dio));
}

const _cart = CartState(
  restaurantId: 4,
  restaurantName: 'Suya Spot',
  lines: [CartLine(item: MenuItem(id: 20, name: 'Beef suya', price: 2500), quantity: 2)],
);

const _details = CheckoutDetails(
  customerName: 'Ada Obi',
  customerPhone: '08012345678',
  address: '12 Allen Ave, Ikeja',
  notes: '  extra pepper  ',
  latitude: 6.6,
  longitude: 3.35,
);

Map<String, dynamic> orderJson({String status = 'pending', String payment = 'cash', String paymentStatus = 'pending'}) => {
      'id': 42,
      'status': status,
      'total': 6500,
      'deliveryFee': 1500,
      'createdAt': '2026-10-26T10:00:00.000Z',
      'businessId': 4,
      'business': {'id': 4, 'name': 'Suya Spot'},
      'paymentMethod': payment,
      'paymentStatus': paymentStatus,
      'address': '12 Allen Ave',
      'customerLatitude': 6.6,
      'customerLongitude': 3.35,
      'items': [
        {'name': 'Beef suya', 'price': 2500, 'quantity': 2, 'menuItem': {'imageUrl': 'http://img/x.jpg'}},
      ],
      'rider': {
        'firstName': 'Tunde',
        'lastName': 'Bello',
        'phone': '0803',
        'riderProfile': {'vehicleType': 'Motorcycle', 'plateNumber': 'ABC-123'},
      },
      'review': null,
    };

void main() {
  group('Checkout requests', () {
    test('a cash order sends items, coordinates and trims the note', () async {
      final adapter = FakeAdapter(201, {'success': true, 'data': {'order': orderJson()}});
      final order = await repoFor(adapter).placeCashOrder(_cart, _details);

      final body = adapter.last!.data as Map<String, dynamic>;
      expect(adapter.last!.path, '/orders');
      expect(body['paymentMethod'], 'cash');
      expect(body['businessId'], 4);
      expect(body['notes'], 'extra pepper');
      expect(body['customerLatitude'], 6.6);
      expect(body['items'], [
        {'menuItemId': 20, 'quantity': 2},
      ]);
      // The client never sends prices; the server computes the total.
      expect(body.containsKey('total'), isFalse);
      expect(order.id, 42);
    });

    test('an address without a pin omits coordinates entirely', () async {
      final adapter = FakeAdapter(200, {'success': true, 'data': {'deliveryFee': 1500, 'distanceKm': null}});
      final q = await repoFor(adapter).quote(4);

      final body = adapter.last!.data as Map<String, dynamic>;
      expect(body.containsKey('customerLatitude'), isFalse);
      expect(q.fee, 1500);
      expect(q.distanceKm, isNull);
    });

    test('online payment returns the Paystack url and reference', () async {
      final adapter = FakeAdapter(200, {
        'success': true,
        'data': {
          'order': orderJson(payment: 'paystack'),
          'reference': 'order_42_1',
          'authorization_url': 'https://checkout.paystack.com/abc',
        },
      });
      final start = await repoFor(adapter).startOnlinePayment(_cart, _details, email: 'a@x.com', callbackUrl: 'https://cb');

      final body = adapter.last!.data as Map<String, dynamic>;
      expect(body['email'], 'a@x.com');
      expect(body['callbackUrl'], 'https://cb');
      expect(start.reference, 'order_42_1');
      expect(start.authorizationUrl, 'https://checkout.paystack.com/abc');
    });

    test('an online payment response without a url is rejected', () async {
      final adapter = FakeAdapter(200, {'success': true, 'data': {'order': orderJson(), 'reference': 'r'}});
      await expectLater(
        repoFor(adapter).startOnlinePayment(_cart, _details, email: 'a@x.com', callbackUrl: 'https://cb'),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('verifyPayment', () {
    test('true when the server confirms', () async {
      expect(await repoFor(FakeAdapter(200, {'success': true, 'data': {}})).verifyPayment('r'), isTrue);
    });

    test('false while the payment is not completed (HTTP 400)', () async {
      final adapter = FakeAdapter(400, {'success': false, 'message': 'Payment not completed yet (abandoned)'});
      expect(await repoFor(adapter).verifyPayment('r'), isFalse);
    });

    test('a server or network failure is surfaced, not treated as unpaid', () async {
      final adapter = FakeAdapter(502, {'success': false, 'message': "We couldn't reach Paystack"});
      await expectLater(repoFor(adapter).verifyPayment('r'), throwsA(isA<ApiException>()));
    });
  });

  group('Orders', () {
    test('parses an order with its rider, items and totals', () {
      final o = CustomerOrder.fromJson(orderJson(status: 'out_for_delivery', payment: 'paystack', paymentStatus: 'paid'));
      expect(o.status, OrderStatus.outForDelivery);
      expect(o.status.isActive, isTrue);
      expect(o.subtotal, 5000);
      expect(o.itemCount, 2);
      expect(o.items.single.imageUrl, 'http://img/x.jpg');
      expect(o.rider!.name, 'Tunde Bello');
      expect(o.rider!.plate, 'ABC-123');
      expect(o.isPaidOnline, isTrue);
      expect(o.canCancel, isFalse);
    });

    test('only pending orders can be cancelled and only delivered ones reviewed', () {
      expect(CustomerOrder.fromJson(orderJson()).canCancel, isTrue);
      expect(CustomerOrder.fromJson(orderJson(status: 'delivered')).canReview, isTrue);
      expect(CustomerOrder.fromJson(orderJson(status: 'cancelled')).status.isActive, isFalse);
    });

    test('an unpaid online order is flagged as awaiting payment', () {
      final o = CustomerOrder.fromJson(orderJson(payment: 'paystack'));
      expect(o.awaitingPayment, isTrue);
    });

    test('progress steps map the backend statuses', () {
      expect(OrderStatus.parse('pending').step, 0);
      expect(OrderStatus.parse('preparing').step, 1);
      expect(OrderStatus.parse('ready').step, 2);
      expect(OrderStatus.parse('out_for_delivery').step, 2);
      expect(OrderStatus.parse('delivered').step, 3);
      expect(OrderStatus.parse('???'), OrderStatus.pending);
    });
  });

  group('Rider tracking', () {
    test('no rider yet: the endpoint returns only a message', () {
      expect(RiderLocation.fromJson({'message': 'No active rider assigned yet or tracking is offline.'}), isNull);
    });

    test('distance between rider and customer', () {
      final loc = RiderLocation.fromJson({'riderName': 'Tunde', 'latitude': 6.5244, 'longitude': 3.3792})!;
      // Roughly 1.1 km north of the rider.
      final km = loc.distanceKmTo(6.5344, 3.3792);
      expect(km, closeTo(1.11, 0.05));
      expect(loc.distanceKmTo(6.5244, 3.3792), closeTo(0, 0.001));
    });
  });

  group('Promos', () {
    test('uses bgGradient as an image only when it is a url', () {
      expect(Promo.fromJson({'id': 1, 'title': 'A', 'bgGradient': 'https://img/p.jpg'}).imageUrl, 'https://img/p.jpg');
      expect(Promo.fromJson({'id': 2, 'title': 'B', 'bgGradient': 'from-violet-600 to-purple-700'}).imageUrl, isNull);
    });
  });

  group('Cart minimum order', () {
    test('shortfall is how much more is needed to reach the minimum', () {
      const cart = CartState(
        minimumOrder: 6000,
        lines: [CartLine(item: MenuItem(id: 1, name: 'x', price: 2500), quantity: 2)],
      );
      expect(cart.shortfall, 1000);
      expect(cart.copyWithLines([const CartLine(item: MenuItem(id: 1, name: 'x', price: 2500), quantity: 3)]).shortfall, 0);
    });
  });
}
