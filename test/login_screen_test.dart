import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oyaeat/core/providers.dart';
import 'package:oyaeat/features/auth/presentation/login_screen.dart';

import 'support/fonts.dart';
import 'support/memory_storage.dart';

void main() {
  setUpAll(loadRoboto);

  testWidgets('one login form: no role switch, validates, and links to sign-up', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/join', builder: (_, _) => const Scaffold(body: Text('join page'))),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(MemoryStorage())],
      child: MaterialApp.router(routerConfig: router, theme: ThemeData(fontFamily: 'Roboto')),
    ));
    await tester.pump();

    // No Customer/Rider toggle any more.
    expect(find.text('Customer'), findsNothing);
    expect(find.text('Rider'), findsNothing);
    expect(find.text('Email or phone'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);

    // Submitting an empty form shows validation errors and makes no request.
    await tester.tap(find.text('Log in'));
    await tester.pump();
    expect(find.text('Required'), findsNWidgets(2));

    await tester.ensureVisible(find.text('Create an account'));
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    expect(find.text('join page'), findsOneWidget);
  });
}
