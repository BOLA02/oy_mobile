import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/address.dart';
import '../domain/cart.dart';
import '../domain/order.dart';
import '../domain/promo.dart';
import '../domain/restaurant.dart';

class DeliveryQuote {
  const DeliveryQuote({required this.fee, this.distanceKm});

  final double fee;
  final double? distanceKm;
}

/// What the customer is buying and where it goes.
class CheckoutDetails {
  const CheckoutDetails({
    required this.customerName,
    required this.customerPhone,
    required this.address,
    this.notes,
    this.latitude,
    this.longitude,
  });

  final String customerName;
  final String customerPhone;
  final String address;
  final String? notes;
  final double? latitude;
  final double? longitude;
}

class PaymentStart {
  const PaymentStart({required this.order, required this.reference, required this.authorizationUrl});

  final CustomerOrder order;
  final String reference;
  final String authorizationUrl;
}

class CustomerProfile {
  const CustomerProfile({required this.firstName, required this.lastName, required this.email, required this.phone});

  final String firstName;
  final String lastName;
  final String email;
  final String phone;

  String get fullName => '$firstName $lastName'.trim();

  factory CustomerProfile.fromJson(Map<String, dynamic> j) => CustomerProfile(
        firstName: '${j['firstName'] ?? ''}',
        lastName: '${j['lastName'] ?? ''}',
        email: '${j['email'] ?? ''}',
        phone: '${j['phone'] ?? ''}',
      );
}

class CustomerRepository {
  const CustomerRepository(this._api);

  final ApiClient _api;

  List<Map<String, dynamic>> _list(Object? raw) =>
      raw is List ? raw.whereType<Map<String, dynamic>>().toList() : const [];

  // ── Profile ───────────────────────────────────────────────
  Future<CustomerProfile> profile() async {
    final data = ApiClient.unwrap(await _api.get('/customer/auth/me'));
    return CustomerProfile.fromJson(data['user'] as Map<String, dynamic>);
  }

  // ── Promos ────────────────────────────────────────────────
  Future<List<Promo>> promos() async {
    final body = await _api.get('/public/promos/public-feed');
    return _list(body['data']).map(Promo.fromJson).toList();
  }

  // ── Addresses ─────────────────────────────────────────────
  Future<List<SavedAddress>> addresses() async {
    final data = ApiClient.unwrap(await _api.get('/customer/addresses'));
    return _list(data['addresses']).map(SavedAddress.fromJson).toList();
  }

  Future<SavedAddress> addAddress({
    required String label,
    required String address,
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) async {
    final body = await _api.post('/customer/addresses', body: {
      'label': label,
      'address': address,
      'latitude': ?latitude,
      'longitude': ?longitude,
      'isDefault': isDefault,
    });
    return SavedAddress.fromJson(ApiClient.unwrap(body)['address'] as Map<String, dynamic>);
  }

  Future<void> deleteAddress(int id) => _api.delete('/customer/addresses/$id');

  Future<void> makeDefaultAddress(int id) => _api.patch('/customer/addresses/$id', body: {'isDefault': true});

  // ── Favourites ────────────────────────────────────────────
  Future<List<Restaurant>> favorites() async {
    final data = ApiClient.unwrap(await _api.get('/customer/favorites'));
    return _list(data['favorites']).map(Restaurant.fromJson).toList();
  }

  Future<void> addFavorite(int businessId) => _api.put('/customer/favorites/$businessId');

  Future<void> removeFavorite(int businessId) => _api.delete('/customer/favorites/$businessId');

  // ── Checkout ──────────────────────────────────────────────
  Future<DeliveryQuote> quote(int businessId, {double? latitude, double? longitude}) async {
    final data = ApiClient.unwrap(await _api.post('/orders/delivery-quote', body: {
      'businessId': businessId,
      'customerLatitude': ?latitude,
      'customerLongitude': ?longitude,
    }));
    return DeliveryQuote(
      fee: (data['deliveryFee'] as num).toDouble(),
      distanceKm: (data['distanceKm'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> _orderBody(CartState cart, CheckoutDetails d) => {
        'businessId': cart.restaurantId,
        'customerName': d.customerName,
        'customerPhone': d.customerPhone,
        'address': d.address,
        if (d.notes?.trim().isNotEmpty == true) 'notes': d.notes!.trim(),
        'customerLatitude': ?d.latitude,
        'customerLongitude': ?d.longitude,
        'items': [
          for (final l in cart.lines) {'menuItemId': l.item.id, 'quantity': l.quantity},
        ],
      };

  /// Pay on delivery.
  Future<CustomerOrder> placeCashOrder(CartState cart, CheckoutDetails d) async {
    final body = await _api.post('/orders', body: {..._orderBody(cart, d), 'paymentMethod': 'cash'});
    return CustomerOrder.fromJson(ApiClient.unwrap(body)['order'] as Map<String, dynamic>);
  }

  /// Creates the order and a Paystack transaction. The customer pays in a web view.
  Future<PaymentStart> startOnlinePayment(
    CartState cart,
    CheckoutDetails d, {
    required String email,
    required String callbackUrl,
  }) async {
    final body = await _api.post('/orders/initialize-payment', body: {
      ..._orderBody(cart, d),
      'email': email,
      'callbackUrl': callbackUrl,
    });
    final data = ApiClient.unwrap(body);
    final url = data['authorization_url'];
    final reference = data['reference'];
    if (url is! String || reference is! String) {
      throw const ApiException('Could not start the payment. Please try again.');
    }
    return PaymentStart(
      order: CustomerOrder.fromJson(data['order'] as Map<String, dynamic>),
      reference: reference,
      authorizationUrl: url,
    );
  }

  /// Whether Paystack confirms the payment. Safe to call repeatedly.
  Future<bool> verifyPayment(String reference) async {
    try {
      await _api.get('/orders/verify-payment/$reference');
      return true;
    } on ApiException catch (e) {
      // 400 = not paid (yet); anything else is a real problem worth surfacing.
      if (e.statusCode == 400) return false;
      rethrow;
    }
  }

  // ── Orders ────────────────────────────────────────────────
  Future<List<CustomerOrder>> orders() async {
    final data = ApiClient.unwrap(await _api.get('/orders/my'));
    return _list(data['orders']).map(CustomerOrder.fromJson).toList();
  }

  Future<void> cancelOrder(int id) => _api.post('/orders/$id/cancel');

  Future<void> reviewOrder(int id, {required int rating, String? comment}) =>
      _api.post('/orders/$id/review', body: {
        'rating': rating,
        if (comment?.trim().isNotEmpty == true) 'comment': comment!.trim(),
      });

  /// Null while no rider has been assigned.
  Future<RiderLocation?> trackRider(int orderId) async =>
      RiderLocation.fromJson(await _api.get('/orders/$orderId/track-rider'));
}
