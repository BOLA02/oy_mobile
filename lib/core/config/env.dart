/// Build-time configuration. Override with
/// `--dart-define=API_BASE_URL=https://api.example.com`.
class Env {
  const Env._();

  /// 10.0.2.2 is the Android emulator's alias for the host machine.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000',
  );
}
