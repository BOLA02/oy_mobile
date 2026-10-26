import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyaeat/core/network/api_client.dart';
import 'package:oyaeat/core/network/api_exception.dart';
import 'package:oyaeat/features/auth/data/auth_repository.dart';
import 'package:oyaeat/features/auth/domain/session.dart';

import 'support/fake_adapter.dart';

ApiClient clientFor(FakeAdapter adapter, {String? token, void Function()? onUnauthorized}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
  return ApiClient(readToken: () => token, onUnauthorized: onUnauthorized ?? () {}, dio: dio);
}

void main() {
  group('ApiClient', () {
    test('unwrap handles both wrapped and top-level payloads', () {
      expect(ApiClient.unwrap({'success': true, 'data': {'a': 1}}), {'a': 1});
      expect(ApiClient.unwrap({'token': 'x', 'dashboard': {}}), {'token': 'x', 'dashboard': {}});
    });

    test('surfaces the server message on failure', () async {
      final api = clientFor(FakeAdapter(409, {'success': false, 'message': 'Email or phone already in use'}));
      await expectLater(
        api.post('/customer/auth/register', body: {}),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'Email or phone already in use')
            .having((e) => e.statusCode, 'status', 409)),
      );
    });

    test('sends the bearer token and signs out on 401', () async {
      var signedOut = false;
      final adapter = FakeAdapter(401, {'message': 'Invalid or expired token'});
      final api = clientFor(adapter, token: 'abc', onUnauthorized: () => signedOut = true);

      await expectLater(api.get('/orders/my'), throwsA(isA<ApiException>()));
      expect(adapter.last!.headers['Authorization'], 'Bearer abc');
      expect(signedOut, isTrue);
    });

    test('a failed login (no token sent) does not trigger sign-out', () async {
      var signedOut = false;
      final api = clientFor(FakeAdapter(401, {'message': 'Invalid credentials'}),
          onUnauthorized: () => signedOut = true);

      await expectLater(api.post('/customer/auth/login', body: {}), throwsA(isA<ApiException>()));
      expect(signedOut, isFalse);
    });
  });

  group('AuthRepository', () {
    test('customer login reads user and token from data', () async {
      final repo = AuthRepository(clientFor(FakeAdapter(200, {
        'success': true,
        'data': {
          'token': 't1',
          'user': {'id': 7, 'firstName': 'Ada', 'lastName': 'Obi', 'role': 'customer'},
        },
      })));
      final s = await repo.loginCustomer(emailOrPhone: 'ada@x.com', password: 'secret');
      expect(s.role, AppRole.customer);
      expect(s.token, 't1');
      expect(s.userId, 7);
      expect(s.name, 'Ada Obi');
    });

    test('rider login reads the top-level token and dashboard.userId', () async {
      final repo = AuthRepository(clientFor(FakeAdapter(200, {
        'message': 'Login successful',
        'token': 'rt',
        'dashboard': {'userId': 12, 'role': 'rider'},
      })));
      final s = await repo.loginRider(email: 'r@x.com', password: 'secret');
      expect(s.role, AppRole.rider);
      expect(s.token, 'rt');
      expect(s.userId, 12);
    });

    test('rider login rejects an unexpected response', () async {
      final repo = AuthRepository(clientFor(FakeAdapter(200, {'message': 'ok'})));
      await expectLater(repo.loginRider(email: 'r@x.com', password: 'p'), throwsA(isA<ApiException>()));
    });
  });

  test('Session round-trips through storage', () {
    const s = Session(token: 't', role: AppRole.rider, userId: 3, name: 'Tunde');
    final back = Session.fromStorage(s.toStorage())!;
    expect((back.token, back.role, back.userId, back.name), ('t', AppRole.rider, 3, 'Tunde'));
    expect(Session.fromStorage({'token': 't'}), isNull);
  });
}
