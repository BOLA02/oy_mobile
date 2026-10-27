/// A delivery request pushed to the rider over the socket
/// (`NEW_DELIVERY_REQUEST`). The server does not expire offers: the first rider
/// to accept wins and everyone else gets "no longer available".
class DeliveryOffer {
  const DeliveryOffer({
    required this.orderId,
    required this.restaurantName,
    required this.payout,
    required this.distance,
    required this.dropoffAddress,
    required this.receivedAt,
  });

  final int orderId;
  final String restaurantName;

  /// What the rider earns for this trip, in naira.
  final double payout;

  /// Already formatted by the server, e.g. `"1.4 km"` (distance to the restaurant).
  final String distance;
  final String dropoffAddress;
  final DateTime receivedAt;

  /// Returns null for a malformed event rather than throwing inside a socket callback.
  static DeliveryOffer? fromJson(Object? json, {DateTime? now}) {
    if (json is! Map) return null;
    final id = json['orderId'];
    final orderId = id is num ? id.toInt() : int.tryParse('$id');
    if (orderId == null) return null;
    final payoutRaw = json['payout'];
    final payout = payoutRaw is num ? payoutRaw.toDouble() : double.tryParse('${payoutRaw ?? ''}'.replaceAll(RegExp(r'[^0-9.]'), ''));
    return DeliveryOffer(
      orderId: orderId,
      restaurantName: '${json['restaurantName'] ?? 'Restaurant'}',
      payout: payout ?? 0,
      distance: '${json['distance'] ?? ''}',
      dropoffAddress: '${json['dropoffAddress'] ?? 'Customer address'}',
      receivedAt: now ?? DateTime.now(),
    );
  }
}
