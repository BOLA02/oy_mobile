import 'dart:math' as math;

enum OrderStatus {
  pending('Order placed', 'Waiting for the restaurant to accept'),
  preparing('Preparing', 'The kitchen is cooking your food'),
  ready('Ready for pickup', 'Finding a rider for you'),
  outForDelivery('On the way', 'Your rider is heading to you'),
  delivered('Delivered', 'Enjoy your meal!'),
  cancelled('Cancelled', 'This order was cancelled');

  const OrderStatus(this.label, this.description);

  final String label;
  final String description;

  bool get isActive => this != delivered && this != cancelled;

  /// Position on the progress timeline (0..3 for the four live steps).
  int get step => switch (this) {
        pending => 0,
        preparing => 1,
        ready => 2,
        outForDelivery => 2,
        delivered => 3,
        cancelled => 0,
      };

  static OrderStatus parse(String? raw) => switch (raw) {
        'preparing' => preparing,
        'ready' => ready,
        'out_for_delivery' => outForDelivery,
        'delivered' => delivered,
        'cancelled' => cancelled,
        _ => pending,
      };
}

class OrderLine {
  const OrderLine({required this.name, required this.price, required this.quantity, this.imageUrl});

  final String name;
  final double price;
  final int quantity;
  final String? imageUrl;

  double get total => price * quantity;

  factory OrderLine.fromJson(Map<String, dynamic> j) {
    final menuItem = j['menuItem'];
    return OrderLine(
      name: '${j['name'] ?? ''}',
      price: (j['price'] as num?)?.toDouble() ?? 0,
      quantity: (j['quantity'] as num?)?.toInt() ?? 1,
      imageUrl: menuItem is Map ? menuItem['imageUrl'] as String? : null,
    );
  }
}

class RiderInfo {
  const RiderInfo({required this.name, this.phone, this.vehicle, this.plate});

  final String name;
  final String? phone;
  final String? vehicle;
  final String? plate;

  static RiderInfo? fromJson(Object? j) {
    if (j is! Map<String, dynamic>) return null;
    final profile = j['riderProfile'];
    return RiderInfo(
      name: [j['firstName'], j['lastName']].whereType<String>().join(' ').trim(),
      phone: j['phone'] as String?,
      vehicle: profile is Map ? profile['vehicleType'] as String? : null,
      plate: profile is Map ? profile['plateNumber'] as String? : null,
    );
  }
}

class CustomerOrder {
  const CustomerOrder({
    required this.id,
    required this.status,
    required this.total,
    required this.createdAt,
    required this.businessId,
    required this.businessName,
    required this.items,
    this.deliveryFee,
    this.paymentMethod,
    this.paymentStatus,
    this.address,
    this.notes,
    this.rider,
    this.reviewRating,
    this.latitude,
    this.longitude,
  });

  final int id;
  final OrderStatus status;
  final double total;
  final double? deliveryFee;
  final DateTime createdAt;
  final int businessId;
  final String businessName;
  final List<OrderLine> items;
  final String? paymentMethod;
  final String? paymentStatus;
  final String? address;
  final String? notes;
  final RiderInfo? rider;
  final int? reviewRating;
  final double? latitude;
  final double? longitude;

  double get subtotal => total - (deliveryFee ?? 0);
  bool get canCancel => status == OrderStatus.pending;
  bool get canReview => status == OrderStatus.delivered && reviewRating == null;
  bool get isPaidOnline => paymentMethod == 'paystack' && paymentStatus == 'paid';
  bool get awaitingPayment => paymentMethod == 'paystack' && paymentStatus != 'paid' && status != OrderStatus.cancelled;
  int get itemCount => items.fold(0, (n, l) => n + l.quantity);

  factory CustomerOrder.fromJson(Map<String, dynamic> j) {
    final business = j['business'];
    final review = j['review'];
    final items = j['items'];
    return CustomerOrder(
      id: j['id'] as int,
      status: OrderStatus.parse(j['status'] as String?),
      total: (j['total'] as num?)?.toDouble() ?? 0,
      deliveryFee: (j['deliveryFee'] as num?)?.toDouble(),
      createdAt: DateTime.tryParse('${j['createdAt']}')?.toLocal() ?? DateTime.now(),
      businessId: (j['businessId'] as num?)?.toInt() ?? (business is Map ? (business['id'] as num).toInt() : 0),
      businessName: business is Map ? '${business['name'] ?? ''}' : '',
      items: items is List ? items.whereType<Map<String, dynamic>>().map(OrderLine.fromJson).toList() : const [],
      paymentMethod: j['paymentMethod'] as String?,
      paymentStatus: j['paymentStatus'] as String?,
      address: j['address'] as String?,
      notes: j['notes'] as String?,
      rider: RiderInfo.fromJson(j['rider']),
      reviewRating: review is Map ? (review['rating'] as num?)?.toInt() : null,
      latitude: (j['customerLatitude'] as num?)?.toDouble(),
      longitude: (j['customerLongitude'] as num?)?.toDouble(),
    );
  }
}

/// Where the rider is right now, from `GET /orders/:id/track-rider`.
class RiderLocation {
  const RiderLocation({required this.name, required this.latitude, required this.longitude});

  final String name;
  final double latitude;
  final double longitude;

  /// Null when no rider is assigned yet (the endpoint then returns only a message).
  static RiderLocation? fromJson(Map<String, dynamic> j) {
    final lat = (j['latitude'] as num?)?.toDouble();
    final lng = (j['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return RiderLocation(name: '${j['riderName'] ?? 'Your rider'}', latitude: lat, longitude: lng);
  }

  /// Straight-line distance in km (haversine).
  double distanceKmTo(double lat, double lng) {
    double rad(double d) => d * math.pi / 180;
    final a = math.pow(math.sin(rad(lat - latitude) / 2), 2) +
        math.cos(rad(latitude)) * math.cos(rad(lat)) * math.pow(math.sin(rad(lng - longitude) / 2), 2);
    return 6371 * 2 * math.asin(math.sqrt(a));
  }
}
