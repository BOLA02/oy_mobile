import '../../../core/network/api_client.dart';
import '../domain/rider_dashboard.dart';

class RiderRepository {
  const RiderRepository(this._api);

  final ApiClient _api;

  Future<RiderDashboard> dashboard() async =>
      RiderDashboard.fromJson(await _api.get('/rider/dashboard'));

  /// Flips the shift and returns whether the rider is now online.
  Future<bool> toggleShift() async {
    final body = await _api.post('/rider/shift/toggle');
    return body['status'] == 'online';
  }

  Future<void> pingLocation(double latitude, double longitude) =>
      _api.put('/rider/location/ping', body: {'latitude': latitude, 'longitude': longitude});

  Future<void> accept(int orderId) => _api.put('/rider/orders/$orderId/accept');

  Future<void> decline(int orderId) => _api.post('/rider/orders/$orderId/decline');

  Future<void> complete(int orderId) => _api.put('/rider/orders/$orderId/complete');
}
