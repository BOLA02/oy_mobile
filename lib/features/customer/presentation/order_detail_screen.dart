import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/cta_button.dart';
import '../../../shared/widgets/ui.dart';
import '../application/customer_providers.dart';
import '../domain/order.dart';
import 'widgets/order_status.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final int orderId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  Timer? _poll;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Live order: refresh the status and, once a rider is moving, their position.
    _poll = Timer.periodic(const Duration(seconds: 10), (_) {
      final order = ref.read(orderProvider(widget.orderId)).value;
      if (order == null || !order.status.isActive) return;
      ref.invalidate(ordersProvider);
      if (order.status == OrderStatus.outForDelivery) ref.invalidate(riderLocationProvider(widget.orderId));
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _cancel(CustomerOrder order) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text(order.isPaidOnline
            ? 'You already paid online. Our team will process your refund.'
            : "The restaurant hasn't started yet, so you can cancel for free."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep order')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(customerRepositoryProvider).cancelOrder(order.id);
      ref.invalidate(ordersProvider);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review(CustomerOrder order) async {
    final result = await showModalBottomSheet<({int rating, String comment})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ReviewSheet(),
    );
    if (result == null) return;
    try {
      await ref.read(customerRepositoryProvider).reviewOrder(order.id, rating: result.rating, comment: result.comment);
      ref.invalidate(ordersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks for your review!')));
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(orderProvider(widget.orderId));

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/c/orders'),
        title: Text('Order #${widget.orderId}'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(ordersProvider)),
        data: (order) {
          if (order == null) {
            return const EmptyView(icon: Icons.search_off_rounded, title: 'Order not found');
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(ordersProvider);
              await ref.read(ordersProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                _StatusHero(order: order),
                if (order.status == OrderStatus.outForDelivery && order.rider != null) ...[
                  const SizedBox(height: 16),
                  _RiderCard(order: order),
                ],
                if (order.awaitingPayment && order.status == OrderStatus.pending) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: AppColors.warning),
                        SizedBox(width: 10),
                        Expanded(child: Text('We have not received your online payment for this order.', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(order.businessName, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 14),
                      for (final l in order.items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${l.quantity}×', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                              const SizedBox(width: 10),
                              Expanded(child: Text(l.name)),
                              Text(formatNaira(l.total), style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      const Divider(height: 24),
                      _Row('Subtotal', formatNaira(order.subtotal)),
                      if (order.deliveryFee != null) ...[const SizedBox(height: 8), _Row('Delivery fee', formatNaira(order.deliveryFee!))],
                      const Divider(height: 24),
                      _Row('Total', formatNaira(order.total), bold: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Info(icon: Icons.location_on_outlined, label: 'Delivering to', value: order.address ?? '—'),
                      const SizedBox(height: 14),
                      _Info(
                        icon: Icons.payments_outlined,
                        label: 'Payment',
                        value: order.isPaidOnline ? 'Paid online' : (order.paymentMethod == 'cash' ? 'Cash on delivery' : 'Online payment pending'),
                      ),
                      const SizedBox(height: 14),
                      _Info(icon: Icons.schedule_rounded, label: 'Placed', value: DateFormat('EEE d MMM, h:mm a').format(order.createdAt)),
                      if (order.notes?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 14),
                        _Info(icon: Icons.sticky_note_2_outlined, label: 'Your note', value: order.notes!.trim()),
                      ],
                    ],
                  ),
                ),
                if (order.reviewRating != null) ...[
                  const SizedBox(height: 16),
                  SurfaceCard(
                    child: Row(
                      children: [
                        const Text('Your rating', style: TextStyle(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        for (var i = 1; i <= 5; i++)
                          Icon(i <= order.reviewRating! ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.gold, size: 26),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (order.canCancel)
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                    onPressed: _busy ? null : () => _cancel(order),
                    child: const Text('Cancel order'),
                  ),
                if (order.canReview) CtaButton(label: 'Rate this order', onPressed: () => _review(order)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.order});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final cancelled = order.status == OrderStatus.cancelled;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: cancelled ? null : AppColors.brandGradient,
        color: cancelled ? AppColors.dangerSoft : null,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(order.status.label,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: cancelled ? AppColors.danger : Colors.white)),
          const SizedBox(height: 4),
          Text(order.status.description,
              style: TextStyle(color: cancelled ? AppColors.ink : Colors.white.withValues(alpha: 0.85), fontSize: 14)),
          if (!cancelled) ...[
            const SizedBox(height: 22),
            OrderProgress(status: order.status, onDark: true),
          ],
        ],
      ),
    );
  }
}

/// Rider details, the call button and how far away the rider currently is.
class _RiderCard extends ConsumerWidget {
  const _RiderCard({required this.order});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rider = order.rider!;
    final loc = ref.watch(riderLocationProvider(order.id)).value;
    String? distance;
    if (loc != null && order.latitude != null && order.longitude != null) {
      final km = loc.distanceKmTo(order.latitude!, order.longitude!);
      distance = km < 1 ? '${(km * 1000).round()} m away' : '${km.toStringAsFixed(1)} km away';
    }

    return SurfaceCard(
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(radius: 24, backgroundColor: AppColors.primarySoft, child: Icon(Icons.two_wheeler_rounded, color: AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rider.name.isEmpty ? 'Your rider' : rider.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(
                      [rider.vehicle, rider.plate].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                      style: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (rider.phone?.isNotEmpty == true)
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: AppColors.success),
                  onPressed: () => launchUrl(Uri(scheme: 'tel', path: rider.phone)),
                  icon: const Icon(Icons.call_rounded),
                  tooltip: 'Call rider',
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Row(
              children: [
                const Icon(Icons.near_me_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(distance ?? 'Your rider is on the way', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontSize: bold ? 17 : 14);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: bold ? style : const TextStyle(color: AppColors.inkMuted)), Text(value, style: style)],
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.inkMuted, fontSize: 12)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet();

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  int _rating = 0;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('How was your order?', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      iconSize: 40,
                      onPressed: () => setState(() => _rating = i),
                      icon: Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.gold),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _comment,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(hintText: 'Tell others about the food (optional)'),
              ),
              const SizedBox(height: 16),
              CtaButton(
                label: 'Submit review',
                onPressed: _rating == 0 ? null : () => Navigator.pop(context, (rating: _rating, comment: _comment.text)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
