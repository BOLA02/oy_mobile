import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/async_view.dart';
import '../application/customer_providers.dart';

class PaymentArgs {
  const PaymentArgs({required this.authorizationUrl, required this.reference, required this.callbackUrl});

  final String authorizationUrl;
  final String reference;
  final String callbackUrl;
}

/// Shows Paystack's checkout page. Pops `true` once the server confirms the
/// payment, `false` otherwise. The server is always asked: the redirect alone
/// is never trusted as proof of payment.
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.args});

  final PaymentArgs args;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  late final WebViewController _web;
  int _progress = 0;
  bool _verifying = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => mounted ? setState(() => _progress = p) : null,
        onNavigationRequest: (req) {
          if (req.url.startsWith(widget.args.callbackUrl)) {
            _confirm(retries: 4);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onWebResourceError: (e) {
          if (e.isForMainFrame == true && mounted) setState(() => _loadFailed = true);
        },
      ))
      ..loadRequest(Uri.parse(widget.args.authorizationUrl));
  }

  /// Asks the server whether the payment went through. Bank transfers can lag
  /// a few seconds, so it retries a few times before giving up.
  Future<void> _confirm({required int retries}) async {
    if (_verifying) return;
    setState(() => _verifying = true);
    var paid = false;
    try {
      for (var i = 0; i < retries && !paid; i++) {
        paid = await ref.read(customerRepositoryProvider).verifyPayment(widget.args.reference);
        if (!paid && i < retries - 1) await Future<void>.delayed(const Duration(seconds: 3));
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
    if (mounted) Navigator.pop(context, paid);
  }

  Future<void> _leave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave payment?'),
        content: const Text('If you have already paid, we will confirm it now.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
        ],
      ),
    );
    if (leave == true) await _confirm(retries: 1);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_verifying) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Secure payment'),
          leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: _verifying ? null : _leave),
          bottom: _progress < 100 && !_verifying
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(value: _progress / 100, minHeight: 3, color: AppColors.primary, backgroundColor: AppColors.primarySoft),
                )
              : null,
        ),
        body: Stack(
          children: [
            if (_loadFailed)
              ErrorView(
                message: 'Could not load the payment page. Check your connection.',
                onRetry: () {
                  setState(() => _loadFailed = false);
                  _web.loadRequest(Uri.parse(widget.args.authorizationUrl));
                },
              )
            else
              WebViewWidget(controller: _web),
            if (_verifying)
              Container(
                color: Colors.white.withValues(alpha: 0.96),
                alignment: Alignment.center,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 18),
                    Text('Confirming your payment…', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    SizedBox(height: 4),
                    Text("Please don't close the app", style: TextStyle(color: AppColors.inkMuted)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
