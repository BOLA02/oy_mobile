import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/ui.dart';
import '../application/customer_providers.dart';
import '../domain/order.dart';
import 'widgets/order_status.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  bool _showActive = true;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // Keep live orders fresh without the customer having to pull to refresh.
    _poll = Timer.periodic(const Duration(seconds: 20), (_) {
      final orders = ref.read(ordersProvider).value;
      if (orders != null && orders.any((o) => o.status.isActive)) ref.invalidate(ordersProvider);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My orders')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: AppColors.violetSoft, borderRadius: BorderRadius.circular(30)),
              child: Row(
                children: [
                  _Tab(label: 'Active', selected: _showActive, onTap: () => setState(() => _showActive = true)),
                  _Tab(label: 'Past', selected: !_showActive, onTap: () => setState(() => _showActive = false)),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.violet,
              onRefresh: () async {
                ref.invalidate(ordersProvider);
                await ref.read(ordersProvider.future);
              },
              child: orders.when(
                loading: () => ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: const [_OrderSkeleton(), SizedBox(height: 14), _OrderSkeleton(), SizedBox(height: 14), _OrderSkeleton()],
                ),
                error: (e, _) => ListView(children: [SizedBox(height: 300, child: ErrorView(message: '$e', onRetry: () => ref.invalidate(ordersProvider)))]),
                data: (all) {
                  final list = all.where((o) => o.status.isActive == _showActive).toList();
                  if (list.isEmpty) {
                    return ListView(
                      children: [
                        SizedBox(
                          height: 380,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              EmptyView(
                                icon: _showActive ? Icons.receipt_long_outlined : Icons.history_rounded,
                                title: _showActive ? 'No active orders' : 'No past orders yet',
                                subtitle: _showActive ? 'Hungry? Your next order will show up here.' : 'Delivered and cancelled orders appear here.',
                              ),
                              if (_showActive)
                                FilledButton(
                                  style: FilledButton.styleFrom(minimumSize: const Size(200, 46)),
                                  onPressed: () => context.go('/c/home'),
                                  child: const Text('Browse restaurants'),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (_, i) => _OrderCard(order: list[i]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
            boxShadow: selected ? AppShadows.card : null,
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700, color: selected ? AppColors.violet : AppColors.inkMuted)),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final names = order.items.map((l) => '${l.quantity}× ${l.name}').toList();
    final summary = names.length <= 2 ? names.join(', ') : '${names.take(2).join(', ')} +${names.length - 2} more';

    return SurfaceCard(
      onTap: () => context.push('/c/order/${order.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(backgroundColor: AppColors.violetSoft, child: Icon(Icons.storefront_rounded, color: AppColors.violet)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.businessName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                    Text('#${order.id} · ${DateFormat('d MMM, h:mm a').format(order.createdAt)}',
                        style: const TextStyle(color: AppColors.inkMuted, fontSize: 12.5)),
                  ],
                ),
              ),
              OrderStatusPill(status: order.status),
            ],
          ),
          const SizedBox(height: 12),
          Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.inkMuted, height: 1.35)),
          if (order.status.isActive) ...[
            const SizedBox(height: 14),
            OrderProgress(status: order.status),
          ],
          const Divider(height: 28),
          Row(
            children: [
              Text(formatNaira(order.total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(width: 8),
              if (order.awaitingPayment && order.status == OrderStatus.pending)
                const StatusPill(label: 'Awaiting payment', color: AppColors.mangoDeep, background: AppColors.cream),
              const Spacer(),
              Text(order.status.isActive ? 'Track order' : 'View details',
                  style: const TextStyle(color: AppColors.violet, fontWeight: FontWeight.w700)),
              const Icon(Icons.chevron_right_rounded, color: AppColors.violet),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderSkeleton extends StatelessWidget {
  const _OrderSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Skeleton(width: 40, height: 40, radius: 20), SizedBox(width: 12), Skeleton(width: 140, height: 15)]),
          SizedBox(height: 14),
          Skeleton(height: 12),
          SizedBox(height: 6),
          Skeleton(width: 180, height: 12),
          SizedBox(height: 18),
          Skeleton(width: 90, height: 16),
        ],
      ),
    );
  }
}
