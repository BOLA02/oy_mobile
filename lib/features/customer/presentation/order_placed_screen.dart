import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/cta_button.dart';
import '../application/customer_providers.dart';

class OrderPlacedScreen extends ConsumerWidget {
  const OrderPlacedScreen({super.key, required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderProvider(orderId)).value;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/c/home');
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(color: AppColors.successSoft, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, size: 70, color: AppColors.success),
                )
                    .animate()
                    .scale(duration: 500.ms, curve: Curves.elasticOut)
                    .fadeIn(duration: 200.ms),
                const SizedBox(height: 28),
                Text('Order placed!', style: Theme.of(context).textTheme.headlineMedium)
                    .animate()
                    .fadeIn(delay: 250.ms)
                    .slideY(begin: 0.3, end: 0),
                const SizedBox(height: 8),
                Text(
                  order == null
                      ? 'Order #$orderId is on its way to the kitchen.'
                      : '${order.businessName} has received your order #$orderId.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.inkMuted, fontSize: 15, height: 1.4),
                ).animate().fadeIn(delay: 350.ms),
                if (order != null) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(color: AppColors.violetSoft, borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: Text(
                      '${order.itemCount} item${order.itemCount == 1 ? '' : 's'} · ${formatNaira(order.total)} · ${order.isPaidOnline ? 'Paid' : 'Pay on delivery'}',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.violet),
                    ),
                  ).animate().fadeIn(delay: 450.ms),
                ],
                const Spacer(),
                CtaButton(label: 'Track my order', onPressed: () => context.go('/c/order/$orderId')),
                const SizedBox(height: 10),
                TextButton(onPressed: () => context.go('/c/home'), child: const Text('Back to home')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
