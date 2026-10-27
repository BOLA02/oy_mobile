import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/auth_repository.dart';
import '../domain/session.dart';

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository(ref.watch(apiClientProvider)));

/// The signed-in session, or null when signed out. Loading while the saved
/// session is being read at startup.
class SessionController extends AsyncNotifier<Session?> {
  @override
  Future<Session?> build() async {
    final saved = await ref.read(sessionStorageProvider).read();
    return Session.fromStorage(saved);
  }

  Future<void> signIn(Session session) async {
    final storage = ref.read(sessionStorageProvider);
    await storage.write(session.toStorage());
    await storage.writeLastRole(session.role.name);
    state = AsyncData(session);
  }

  Future<void> signOut() async {
    await ref.read(sessionStorageProvider).clear();
    state = const AsyncData(null);
  }
}

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, Session?>(SessionController.new);
