/// An order currently offered to, or claimed by, the rider. The backend sends
/// display-ready strings (`id: "ORD-12"`, `payout: "₦1,200"`), so they are kept
/// as strings and only the numeric id is parsed.
class ActiveDelivery {
  const ActiveDelivery({
    required this.orderId,
    required this.restaurant,
    required this.customer,
    required this.dropoff,
    required this.payout,
    required this.status,
    required this.distance,
  });

  final int orderId;
  final String restaurant;
  final String customer;
  final String dropoff;
  final String payout;
  final String status;
  final String distance;

  /// A `ready` order is only an offer; once accepted it is `out_for_delivery`.
  bool get isAccepted => status == 'out_for_delivery';

  static int? parseOrderId(Object? raw) {
    if (raw is int) return raw;
    return int.tryParse('$raw'.replaceAll(RegExp(r'[^0-9]'), ''));
  }

  static ActiveDelivery? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final id = parseOrderId(json['id']);
    if (id == null) return null;
    return ActiveDelivery(
      orderId: id,
      restaurant: '${json['restaurant'] ?? ''}',
      customer: '${json['customer'] ?? ''}',
      dropoff: '${json['dropoff'] ?? ''}',
      payout: '${json['payout'] ?? ''}',
      status: '${json['status'] ?? ''}',
      distance: '${json['distance'] ?? ''}',
    );
  }
}

class RecentDelivery {
  const RecentDelivery({required this.restaurant, required this.payout, required this.time});

  final String restaurant;
  final String payout;
  final String time;

  factory RecentDelivery.fromJson(Map<String, dynamic> j) => RecentDelivery(
        restaurant: '${j['restaurant'] ?? ''}',
        payout: '${j['payout'] ?? ''}',
        time: '${j['time'] ?? ''}',
      );
}

class RiderDashboard {
  const RiderDashboard({
    required this.firstName,
    required this.isOnline,
    required this.isApproved,
    required this.todayEarnings,
    required this.completedToday,
    required this.activeDelivery,
    required this.recentDeliveries,
  });

  final String firstName;
  final bool isOnline;

  /// False until an admin verifies the rider; riders cannot accept orders before.
  final bool isApproved;
  final String todayEarnings;
  final int completedToday;
  final ActiveDelivery? activeDelivery;
  final List<RecentDelivery> recentDeliveries;

  /// The dashboard is returned without a `data` wrapper.
  factory RiderDashboard.fromJson(Map<String, dynamic> j) {
    final profile = (j['profile'] as Map<String, dynamic>?) ?? const {};
    final stats = (j['stats'] as Map<String, dynamic>?) ?? const {};
    final recent = j['recentDeliveries'];
    return RiderDashboard(
      firstName: '${profile['firstName'] ?? ''}',
      isOnline: j['isOnline'] == true,
      isApproved: j['status'] == 'active',
      todayEarnings: '${stats['todayEarnings'] ?? '₦0'}',
      completedToday: (stats['completedToday'] as num?)?.toInt() ?? 0,
      activeDelivery: ActiveDelivery.fromJson(j['activeDelivery']),
      recentDeliveries: recent is List
          ? recent.whereType<Map<String, dynamic>>().map(RecentDelivery.fromJson).toList()
          : const [],
    );
  }
}
