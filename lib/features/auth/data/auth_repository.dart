import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/session.dart';

class AuthRepository {
  const AuthRepository(this._api);

  final ApiClient _api;

  Future<Session> loginCustomer({required String emailOrPhone, required String password}) async {
    final body = await _api.post('/customer/auth/login', body: {
      'emailOrPhone': emailOrPhone,
      'password': password,
    });
    return _customerSession(body);
  }

  Future<Session> registerCustomer({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final body = await _api.post('/customer/auth/register', body: {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'password': password,
    });
    return _customerSession(body);
  }

  /// Rider login replies `{message, token, dashboard}` with no `data` wrapper.
  Future<Session> loginRider({required String email, required String password}) async {
    final body = await _api.post('/auth/rider/login', body: {
      'email': email,
      'password': password,
    });
    final token = body['token'];
    final dashboard = body['dashboard'];
    final userId = dashboard is Map ? dashboard['userId'] : null;
    if (token is! String || userId is! int) {
      throw const ApiException('Unexpected response from the server.');
    }
    return Session(token: token, role: AppRole.rider, userId: userId);
  }

  /// Creates a rider account. The rider cannot work until an admin verifies
  /// the ID document, so this does not sign them in.
  Future<void> registerRider({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String vehicleType,
    String? plateNumber,
    required String password,
    required String idDocumentPath,
  }) async {
    final form = FormData.fromMap({
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'vehicleType': vehicleType,
      if (plateNumber != null && plateNumber.isNotEmpty) 'plateNumber': plateNumber,
      'password': password,
      'idDocument': await MultipartFile.fromFile(idDocumentPath),
    });
    await _api.postForm('/auth/rider/register', form);
  }

  Session _customerSession(Map<String, dynamic> body) {
    final data = ApiClient.unwrap(body);
    final user = data['user'];
    final token = data['token'];
    if (user is! Map || token is! String) {
      throw const ApiException('Unexpected response from the server.');
    }
    final name = [user['firstName'], user['lastName']].whereType<String>().join(' ').trim();
    return Session(
      token: token,
      role: AppRole.customer,
      userId: user['id'] as int,
      name: name.isEmpty ? null : name,
    );
  }
}
