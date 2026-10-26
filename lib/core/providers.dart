import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/application/session_controller.dart';
import 'network/api_client.dart';
import 'storage/session_storage.dart';

final sessionStorageProvider = Provider<SessionStorage>((ref) => const SecureSessionStorage());

/// One shared HTTP client. It reads the token lazily so a login/logout is
/// picked up immediately, and signs the user out when the server says 401.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    readToken: () => ref.read(sessionControllerProvider).value?.token,
    onUnauthorized: () => ref.read(sessionControllerProvider.notifier).signOut(),
  );
});
