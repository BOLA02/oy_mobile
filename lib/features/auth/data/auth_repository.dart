import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/session.dart';

class AuthRepository {
  const AuthRepository(this._api);

  final ApiClient _api;

  /// One sign-in for everyone. The backend has a separate endpoint per role, so
  /// this tries the likely one first and falls back when the response says the
  /// account is of another type (403) or the attempt was rate-limited (429).
  ///
  /// [preferred] is the role that last signed in on this device; trying it
  /// first keeps riders from piling up "wrong role" failures on the customer
  /// endpoint, which the server counts against its login rate limit.
  Future<Session> login({
    required String identifier,
    required String password,
    AppRole? preferred,
  }) async {
    final id = identifier.trim();
    final isEmail = id.contains('@');
    // Riders can only sign in with an email (that is what their endpoint takes).
    final riderFirst = preferred == AppRole.rider && isEmail;

    Future<Session> asCustomer() => loginCustomer(emailOrPhone: id, password: password);
    Future<Session> asRider() => loginRider(email: id, password: password);

    if (riderFirst) {
      ApiException riderError;
      try {
        return await asRider();
      } on ApiException catch (e) {
        if (e.statusCode != 401 && e.statusCode != 429) rethrow;
        riderError = e;
      }
      try {
        return await asCustomer();
      } on ApiException catch (e) {
        // 401 = no such customer, 403 = some other account type: either way the
        // rider endpoint's answer is the useful one.
        if (e.statusCode == 401 || e.statusCode == 403) throw riderError;
        rethrow;
      }
    }

    ApiException customerError;
    try {
      return await asCustomer();
    } on ApiException catch (e) {
      if (e.statusCode != 403 && e.statusCode != 429) rethrow; // wrong details, or no network
      customerError = e;
    }

    if (!isEmail) {
      throw customerError.statusCode == 403
          ? const ApiException('Riders sign in with their email address.')
          : customerError;
    }
    try {
      return await asRider();
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        throw customerError.statusCode == 429
            ? customerError
            : const ApiException(
                'Invalid credentials. Restaurant owners and admins sign in on the web dashboard.',
                statusCode: 401,
              );
      }
      rethrow;
    }
  }

  /// Sends a password-reset link by email. The server always answers the same
  /// way, so this never reveals whether the address is registered.
  Future<void> forgotPassword(String email) =>
      _api.post('/customer/auth/forgot-password', body: {'email': email.trim()});

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
