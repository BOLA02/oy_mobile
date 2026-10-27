import 'package:oyaeat/core/storage/session_storage.dart';

/// In-memory stand-in for secure storage. Pass [saved] to start signed in.
class MemoryStorage implements SessionStorage {
  MemoryStorage([Map<String, String>? saved]) : _saved = {...?saved};

  final Map<String, String> _saved;
  String? lastRole;

  @override
  Future<void> clear() async => _saved.clear();

  @override
  Future<Map<String, String>> read() async => {..._saved};

  @override
  Future<void> write(Map<String, String> values) async => _saved.addAll(values);

  @override
  Future<String?> readLastRole() async => lastRole;

  @override
  Future<void> writeLastRole(String role) async => lastRole = role;
}
