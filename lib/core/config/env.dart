/// Build-time configuration. Override with
/// `--dart-define=API_BASE_URL=https://api.example.com`.
class Env {
  const Env._();

  /// 10.0.2.2 is the Android emulator's alias for the host machine.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000',
  );

  /// Paystack redirects here when a payment finishes. The payment web view
  /// intercepts the redirect, so the host never has to exist (`.invalid` is
  /// reserved and can never resolve).
  static const paymentCallbackUrl = 'https://oyaeat-app.invalid/paystack/callback';
}
