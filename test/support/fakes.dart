import 'package:flutter_test/flutter_test.dart';
import 'package:oyaeat/features/customer/data/customer_repository.dart';
import 'package:oyaeat/features/customer/data/restaurant_repository.dart';
import 'package:oyaeat/features/customer/domain/address.dart';
import 'package:oyaeat/features/customer/domain/order.dart';
import 'package:oyaeat/features/customer/domain/promo.dart';
import 'package:oyaeat/features/customer/domain/restaurant.dart';
import 'package:oyaeat/features/rider/data/rider_repository.dart';
import 'package:oyaeat/features/rider/domain/rider_dashboard.dart';

const suya = Restaurant(
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
const mamaPut = Restaurant(id: 2, name: 'Mama Put Kitchen', type: 'Nigerian', city: 'Yaba', state: 'Lagos', rating: 4.1);
const pizza = Restaurant(id: 3, name: 'A Very Long Restaurant Name That Should Truncate Nicely', type: 'Pizza', city: 'Lekki');

class FakeRestaurants extends Fake implements RestaurantRepository {
  @override
  Future<List<Restaurant>> list({String query = '', int page = 1, int limit = 20}) async => [suya, mamaPut, pizza];

  @override
  Future<RestaurantMenu> menu(int restaurantId) async => const RestaurantMenu(restaurant: suya, items: [
        MenuItem(id: 10, name: 'Beef suya', price: 2500, category: 'Grills', description: 'Spicy skewers with onions and yaji pepper.'),
        MenuItem(id: 11, name: 'Chicken suya', price: 3000, category: 'Grills'),
        MenuItem(id: 12, name: 'Zobo', price: 800, category: 'Drinks'),
      ]);
}

CustomerOrder makeOrder(int id, OrderStatus status, {bool withRider = false}) => CustomerOrder(
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

class FakeCustomer extends Fake implements CustomerRepository {
  @override
  Future<List<Promo>> promos() async => const [Promo(id: 1, title: '20% off all grills', description: 'This weekend only', businessId: 1)];
  @override
  Future<List<Restaurant>> favorites() async => [suya];
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
        makeOrder(2, OrderStatus.outForDelivery, withRider: true),
        makeOrder(1, OrderStatus.delivered),
      ];
  @override
  Future<RiderLocation?> trackRider(int orderId) async =>
      const RiderLocation(name: 'Tunde Bello', latitude: 6.5244, longitude: 3.3792);
}

class FakeRider extends Fake implements RiderRepository {
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

