import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyaeat/core/network/api_client.dart';
import 'package:oyaeat/core/network/api_exception.dart';
import 'package:oyaeat/features/auth/data/auth_repository.dart';
import 'package:oyaeat/features/auth/domain/session.dart';

import 'support/fake_adapter.dart';
import 'support/routing_adapter.dart';

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

  unifiedLoginTests();

  test('Session round-trips through storage', () {
    const s = Session(token: 't', role: AppRole.rider, userId: 3, name: 'Tunde');
    final back = Session.fromStorage(s.toStorage())!;
    expect((back.token, back.role, back.userId, back.name), ('t', AppRole.rider, 3, 'Tunde'));
    expect(Session.fromStorage({'token': 't'}), isNull);
  });
}

// ── Single login for customers and riders ──────────────────────────────
void unifiedLoginTests() {
  const customerOk = (200, {
    'success': true,
    'data': {
      'token': 'ct',
      'user': {'id': 7, 'firstName': 'Ada', 'lastName': 'Obi', 'role': 'customer'},
    },
  });
  const riderOk = (200, {
    'message': 'Login successful',
    'token': 'rt',
    'dashboard': {'userId': 12, 'role': 'rider'},
  });
  const wrongDetails = (401, {'success': false, 'message': 'Invalid credentials'});
  const notCustomer = (403, {'success': false, 'message': 'Not a customer account'});
  const limited = (429, {'success': false, 'message': 'Too many failed login attempts. Try again in 10 minutes.'});
  const riderRejects = (401, {'message': 'Invalid credentials or not a rider'});

  AuthRepository repoWith(RoutingAdapter a) {
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = a;
    return AuthRepository(ApiClient(readToken: () => null, onUnauthorized: () {}, dio: dio));
  }

  group('unified login', () {
    test('a customer signs in on the first call', () async {
      final a = RoutingAdapter({'/customer/auth/login': customerOk});
      final s = await repoWith(a).login(identifier: 'ada@x.com', password: 'p');
      expect(s.role, AppRole.customer);
      expect(a.calls, ['/customer/auth/login']);
    });

    test('a rider is found when the customer endpoint says "not a customer"', () async {
      final a = RoutingAdapter({'/customer/auth/login': notCustomer, '/auth/rider/login': riderOk});
      final s = await repoWith(a).login(identifier: 'tunde@x.com', password: 'p');
      expect(s.role, AppRole.rider);
      expect(s.userId, 12);
      expect(a.calls, ['/customer/auth/login', '/auth/rider/login']);
    });

    test('a device that last had a rider goes to the rider endpoint first', () async {
      final a = RoutingAdapter({'/auth/rider/login': riderOk, '/customer/auth/login': customerOk});
      final s = await repoWith(a).login(identifier: 'tunde@x.com', password: 'p', preferred: AppRole.rider);
      expect(s.role, AppRole.rider);
      // No wrong-role call, so nothing counts against the customer login rate limit.
      expect(a.calls, ['/auth/rider/login']);
    });

    test('a customer on a rider-preferred device still gets in', () async {
      final a = RoutingAdapter({'/auth/rider/login': riderRejects, '/customer/auth/login': customerOk});
      final s = await repoWith(a).login(identifier: 'ada@x.com', password: 'p', preferred: AppRole.rider);
      expect(s.role, AppRole.customer);
      expect(a.calls, ['/auth/rider/login', '/customer/auth/login']);
    });

    test('wrong details stop at the first call', () async {
      final a = RoutingAdapter({'/customer/auth/login': wrongDetails});
      await expectLater(
        repoWith(a).login(identifier: 'ada@x.com', password: 'bad'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Invalid credentials')),
      );
      expect(a.calls, ['/customer/auth/login']);
    });

    test('a rider with a wrong password sees the rider endpoint\'s answer', () async {
      final a = RoutingAdapter({'/auth/rider/login': (401, {'message': 'Invalid credentials'}), '/customer/auth/login': notCustomer});
      await expectLater(
        repoWith(a).login(identifier: 'tunde@x.com', password: 'bad', preferred: AppRole.rider),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Invalid credentials')),
      );
    });

    test('a rate-limited customer endpoint still lets a rider in', () async {
      final a = RoutingAdapter({'/customer/auth/login': limited, '/auth/rider/login': riderOk});
      final s = await repoWith(a).login(identifier: 'tunde@x.com', password: 'p');
      expect(s.role, AppRole.rider);
    });

    test('a genuinely rate-limited customer keeps the rate-limit message', () async {
      final a = RoutingAdapter({'/customer/auth/login': limited, '/auth/rider/login': riderRejects});
      await expectLater(
        repoWith(a).login(identifier: 'ada@x.com', password: 'p'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 429)),
      );
    });

    test('an owner or admin account gets a pointer to the web dashboard', () async {
      final a = RoutingAdapter({'/customer/auth/login': notCustomer, '/auth/rider/login': riderRejects});
      await expectLater(
        repoWith(a).login(identifier: 'owner@x.com', password: 'p'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('web dashboard'))),
      );
    });

    test('a phone number cannot be a rider login', () async {
      final a = RoutingAdapter({'/customer/auth/login': notCustomer});
      await expectLater(
        repoWith(a).login(identifier: '08031112222', password: 'p'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('email'))),
      );
      expect(a.calls, ['/customer/auth/login']);
    });

    test('no network is reported as such, not as a wrong password', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = _Offline();
      final repo = AuthRepository(ApiClient(readToken: () => null, onUnauthorized: () {}, dio: dio));
      await expectLater(
        repo.login(identifier: 'ada@x.com', password: 'p'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('Cannot reach the server'))),
      );
    });

    test('forgot password posts the email and trims it', () async {
      final adapter = FakeAdapter(200, {'success': true, 'message': 'ok'});
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
      await AuthRepository(ApiClient(readToken: () => null, onUnauthorized: () {}, dio: dio)).forgotPassword('  ada@x.com ');
      expect(adapter.last!.path, '/customer/auth/forgot-password');
      expect((adapter.last!.data as Map)['email'], 'ada@x.com');
    });
  });
}

class _Offline implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) =>
      throw DioException(requestOptions: options, type: DioExceptionType.connectionError);

  @override
  void close({bool force = false}) {}
}
