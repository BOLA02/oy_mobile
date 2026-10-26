import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the signed-in session across app launches.
abstract class SessionStorage {
  Future<Map<String, String>> read();
  Future<void> write(Map<String, String> values);
  Future<void> clear();
}

class SecureSessionStorage implements SessionStorage {
  const SecureSessionStorage([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;
  static const _keys = ['token', 'role', 'userId', 'name'];

  @override
  Future<Map<String, String>> read() async {
    final out = <String, String>{};
    for (final k in _keys) {
      final v = await _storage.read(key: k);
      if (v != null) out[k] = v;
    }
    return out;
  }

  @override
  Future<void> write(Map<String, String> values) async {
    for (final e in values.entries) {
      await _storage.write(key: e.key, value: e.value);
    }
  }

  @override
  Future<void> clear() async {
    for (final k in _keys) {
      await _storage.delete(key: k);
    }
  }
}
