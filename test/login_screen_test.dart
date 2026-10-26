import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oyaeat/core/providers.dart';
import 'package:oyaeat/core/storage/session_storage.dart';
import 'package:oyaeat/features/auth/presentation/login_screen.dart';

class _MemoryStorage implements SessionStorage {
  @override
  Future<void> clear() async {}
  @override
  Future<Map<String, String>> read() async => {};
  @override
  Future<void> write(Map<String, String> values) async {}
}

void main() {
  testWidgets('role switch changes the identifier field and validates input', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(_MemoryStorage())],
      child: const MaterialApp(home: LoginScreen()),
    ));

    expect(find.text('Email or phone'), findsOneWidget);
    expect(find.text('New here? Create an account'), findsOneWidget);

    await tester.tap(find.text('Rider'));
    await tester.pump();
    expect(find.text('Email or phone'), findsNothing);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Want to ride with us? Register as a rider'), findsOneWidget);

    // Submitting an empty form shows validation errors and makes no request.
    await tester.tap(find.text('Log in'));
    await tester.pump();
    expect(find.text('Required'), findsNWidgets(2));
  });
}
