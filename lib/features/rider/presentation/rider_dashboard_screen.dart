import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/cta_button.dart';
import '../application/location_reporter.dart';
import '../application/rider_providers.dart';
import '../domain/rider_dashboard.dart';

class RiderDashboardScreen extends ConsumerStatefulWidget {
  const RiderDashboardScreen({super.key});

  @override
  ConsumerState<RiderDashboardScreen> createState() => _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends ConsumerState<RiderDashboardScreen> {
  Timer? _poll;
  bool _busy = false;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// Until live push is wired up, an online rider refreshes periodically to
  /// pick up new delivery offers.
  void _syncPolling(bool online) {
    if (online && _poll == null) {
      _poll = Timer.periodic(const Duration(seconds: 15), (_) => ref.invalidate(riderDashboardProvider));
    } else if (!online) {
      _poll?.cancel();
      _poll = null;
    }
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
    _syncPolling(dash.value?.isOnline ?? false);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: dash.whenView(
        onRetry: () => ref.invalidate(riderDashboardProvider),
        data: (d) => RefreshIndicator(
          onRefresh: () async => ref.refresh(riderDashboardProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Hi ${d.firstName.isEmpty ? 'rider' : d.firstName}',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              if (!d.isApproved)
                const _Banner(
                  icon: Icons.hourglass_top_rounded,
                  text: 'Your account is awaiting verification. You can accept deliveries once approved.',
                ),
              Card(
                child: SwitchListTile(
                  title: Text(d.isOnline ? 'You are online' : 'You are offline',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(d.isOnline ? 'Waiting for delivery offers' : 'Go online to receive orders'),
                  value: d.isOnline,
                  onChanged: _busy ? null : (_) => _toggleShift(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _Stat(label: 'Today', value: d.todayEarnings)),
                  const SizedBox(width: 12),
                  Expanded(child: _Stat(label: 'Deliveries', value: '${d.completedToday}')),
                ],
              ),
              const SizedBox(height: 20),
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
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: EmptyView(
                      icon: Icons.two_wheeler,
                      title: 'No delivery right now',
                      subtitle: 'New offers appear here when you are online.',
                    ),
                  ),
                ),
              if (d.recentDeliveries.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Recent deliveries', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                for (final r in d.recentDeliveries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(r.restaurant),
                    subtitle: Text(r.time),
                    trailing: Text(r.payout, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
              ],
            ],
          ),
        ),
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(icon, color: AppColors.mangoDeep),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.inkMuted)),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(d.isAccepted ? 'Current delivery' : 'New delivery offer',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                Text(d.payout,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.success)),
              ],
            ),
            const SizedBox(height: 12),
            _Row(icon: Icons.storefront_outlined, label: 'Pick up', value: d.restaurant),
            _Row(icon: Icons.person_outline, label: 'Customer', value: d.customer),
            _Row(icon: Icons.location_on_outlined, label: 'Drop off', value: d.dropoff),
            _Row(icon: Icons.route_outlined, label: 'Distance', value: d.distance),
            const SizedBox(height: 16),
            if (d.isAccepted)
              CtaButton(label: 'Mark as delivered', loading: busy, onPressed: onComplete)
            else ...[
              CtaButton(label: 'Accept', loading: busy, onPressed: canAccept ? onAccept : null),
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), shape: const StadiumBorder()),
                onPressed: busy ? null : onDecline,
                child: const Text('Decline'),
              ),
              if (!canAccept)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Go online and get verified to accept offers.',
                      style: TextStyle(color: AppColors.inkMuted, fontSize: 12)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.violet),
          const SizedBox(width: 10),
          SizedBox(width: 70, child: Text(label, style: const TextStyle(color: AppColors.inkMuted))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
