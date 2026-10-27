import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/cta_button.dart';
import '../../../shared/widgets/ui.dart';
import '../application/location_reporter.dart';
import '../application/offers.dart';
import '../application/rider_providers.dart';
import '../domain/rider_dashboard.dart';

class RiderDashboardScreen extends ConsumerStatefulWidget {
  const RiderDashboardScreen({super.key});

  @override
  ConsumerState<RiderDashboardScreen> createState() => _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends ConsumerState<RiderDashboardScreen> {
  Timer? _poll;
  Duration? _pollEvery;
  bool _busy = false;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// Offers arrive instantly over the socket, so polling is only a safety net:
  /// slow while the live connection is up, quicker when it is down.
  void _syncPolling({required bool online, required bool live}) {
    if (!online) {
      _poll?.cancel();
      _poll = null;
      _pollEvery = null;
      return;
    }
    final every = live ? const Duration(seconds: 60) : const Duration(seconds: 15);
    if (_poll != null && _pollEvery == every) return;
    _poll?.cancel();
    _pollEvery = every;
    _poll = Timer.periodic(every, (_) => ref.invalidate(riderDashboardProvider));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(riderDashboardProvider);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleShift() => _run(() async {
        HapticFeedback.mediumImpact();
        final repo = ref.read(riderRepositoryProvider);
        final reporter = ref.read(locationReporterProvider);
        final online = await repo.toggleShift();
        if (online) {
          final ok = await reporter.start();
          if (!ok && mounted) {
            showError(context, 'Turn on location so customers and dispatch can find you.');
          }
        } else {
          await reporter.stop();
        }
      });

  @override
  Widget build(BuildContext context) {
    final dash = ref.watch(riderDashboardProvider);
    final live = ref.watch(liveConnectionProvider).value ?? false;
    _syncPolling(online: dash.value?.isOnline ?? false, live: live);

    return Scaffold(
      body: SafeArea(
        child: dash.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(20),
            children: const [
              Skeleton(height: 140, radius: AppRadius.lg),
              SizedBox(height: 16),
              Skeleton(height: 84, radius: AppRadius.lg),
              SizedBox(height: 16),
              Skeleton(height: 200, radius: AppRadius.lg),
            ],
          ),
          error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(riderDashboardProvider)),
          data: (d) => RefreshIndicator(
            color: AppColors.violet,
            onRefresh: () async {
              ref.invalidate(riderDashboardProvider);
              await ref.read(riderDashboardProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Hi ${d.firstName.isEmpty ? 'rider' : d.firstName} 👋',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineMedium),
                    ),
                    _LiveChip(live: live),
                  ],
                ),
                const SizedBox(height: 14),
                _EarningsHero(earnings: d.todayEarnings, deliveries: d.completedToday),
                const SizedBox(height: 16),
                if (!d.isApproved)
                  const _Banner(
                    icon: Icons.hourglass_top_rounded,
                    text: 'Your account is awaiting verification. You can accept deliveries once approved.',
                  ),
                _ShiftCard(online: d.isOnline, busy: _busy, onToggle: _toggleShift),
                const SizedBox(height: 22),
                Text(d.activeDelivery?.isAccepted == true ? 'Current delivery' : 'Delivery offers',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                if (d.activeDelivery != null)
                  _DeliveryCard(
                    delivery: d.activeDelivery!,
                    busy: _busy,
                    canAccept: d.isApproved && d.isOnline,
                    onAccept: () => _run(() => ref.read(riderRepositoryProvider).accept(d.activeDelivery!.orderId)),
                    onDecline: () => _run(() => ref.read(riderRepositoryProvider).decline(d.activeDelivery!.orderId)),
                    onComplete: () => _run(() => ref.read(riderRepositoryProvider).complete(d.activeDelivery!.orderId)),
                  )
                else
                  SurfaceCard(
                    child: EmptyView(
                      icon: d.isOnline ? Icons.radar_rounded : Icons.power_settings_new_rounded,
                      title: d.isOnline ? 'Looking for deliveries…' : 'You are offline',
                      subtitle: d.isOnline ? 'New offers appear here as soon as a restaurant is ready.' : 'Go online to start receiving offers.',
                    ),
                  ),
                if (d.recentDeliveries.isNotEmpty) ...[
                  const SizedBox(height: 26),
                  Text('Recent deliveries', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  SurfaceCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < d.recentDeliveries.length; i++) ...[
                          if (i > 0) const Divider(indent: 16, endIndent: 16),
                          ListTile(
                            leading: const CircleAvatar(backgroundColor: AppColors.successSoft, child: Icon(Icons.check_rounded, color: AppColors.success)),
                            title: Text(d.recentDeliveries[i].restaurant, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(d.recentDeliveries[i].time),
                            trailing: Text(d.recentDeliveries[i].payout, style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Green "Live" when offers will arrive instantly, grey while reconnecting.
class _LiveChip extends StatelessWidget {
  const _LiveChip({required this.live});

  final bool live;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: live ? AppColors.successSoft : AppColors.violetSoft, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: live ? AppColors.success : AppColors.inkFaint, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(live ? 'Live' : 'Connecting…',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: live ? AppColors.success : AppColors.inkMuted)),
        ],
      ),
    );
  }
}

class _EarningsHero extends StatelessWidget {
  const _EarningsHero({required this.earnings, required this.deliveries});

  final String earnings;
  final int deliveries;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Today's earnings", style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(earnings, style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: Colors.white)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Column(
              children: [
                Text('$deliveries', style: const TextStyle(color: AppColors.mango, fontSize: 24, fontWeight: FontWeight.w800)),
                Text('deliveries', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({required this.online, required this.busy, required this.onToggle});

  final bool online;
  final bool busy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: online ? AppColors.successSoft : AppColors.violetSoft,
            ),
            child: Icon(Icons.two_wheeler_rounded, color: online ? AppColors.success : AppColors.violet),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(online ? "You're online" : "You're offline", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(online ? 'Sharing your location' : 'Go online to receive orders',
                    style: const TextStyle(color: AppColors.inkMuted, fontSize: 13)),
              ],
            ),
          ),
          Switch.adaptive(value: online, activeTrackColor: AppColors.success, onChanged: busy ? null : (_) => onToggle()),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(
        children: [
          Icon(icon, color: AppColors.mangoDeep),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({
    required this.delivery,
    required this.busy,
    required this.canAccept,
    required this.onAccept,
    required this.onDecline,
    required this.onComplete,
  });

  final ActiveDelivery delivery;
  final bool busy;
  final bool canAccept;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final d = delivery;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(
                label: d.isAccepted ? 'In progress' : 'New offer',
                color: d.isAccepted ? AppColors.violet : AppColors.mangoDeep,
                background: d.isAccepted ? AppColors.violetSoft : AppColors.cream,
              ),
              const Spacer(),
              Text(d.payout, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.success)),
            ],
          ),
          const SizedBox(height: 16),
          _Stop(icon: Icons.storefront_rounded, label: 'Pick up', value: d.restaurant),
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Container(width: 2, height: 18, color: AppColors.border),
          ),
          _Stop(icon: Icons.location_on_rounded, label: 'Drop off', value: d.dropoff, sub: d.customer),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppColors.violetSoft, borderRadius: BorderRadius.circular(AppRadius.sm)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.route_rounded, size: 16, color: AppColors.violet),
                const SizedBox(width: 6),
                Text(d.distance, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.violet)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (d.isAccepted)
            CtaButton(label: 'Mark as delivered', loading: busy, onPressed: onComplete)
          else ...[
            CtaButton(label: 'Accept delivery', loading: busy, onPressed: canAccept ? onAccept : null),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: busy ? null : onDecline, child: const Text('Decline')),
            if (!canAccept)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('Go online and get verified to accept offers.', style: TextStyle(color: AppColors.inkMuted, fontSize: 12.5)),
              ),
          ],
        ],
      ),
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({required this.icon, required this.label, required this.value, this.sub});

  final IconData icon;
  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: AppColors.violet),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.inkMuted, fontSize: 12)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              if (sub?.isNotEmpty == true) Text(sub!, style: const TextStyle(color: AppColors.inkMuted, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}
