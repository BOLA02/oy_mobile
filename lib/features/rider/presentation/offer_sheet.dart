import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/cta_button.dart';
import '../../../shared/widgets/ui.dart';
import '../application/rider_providers.dart';
import '../domain/delivery_offer.dart';

enum OfferOutcome { accepted, declined, expired, taken }

/// How long a rider has to answer before the offer is put away on this device.
/// (The server keeps the order available to other riders regardless.)
const offerWindow = Duration(seconds: 45);

/// Full-width sheet shown the moment a delivery request arrives.
class OfferSheet extends ConsumerStatefulWidget {
  const OfferSheet({super.key, required this.offer, this.window = offerWindow});

  final DeliveryOffer offer;
  final Duration window;

  @override
  ConsumerState<OfferSheet> createState() => _OfferSheetState();
}

class _OfferSheetState extends ConsumerState<OfferSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(vsync: this, duration: widget.window)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed && !_busy && mounted) Navigator.pop(context, OfferOutcome.expired);
    })
    ..forward();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(riderRepositoryProvider).accept(widget.offer.orderId);
      if (mounted) Navigator.pop(context, OfferOutcome.accepted);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409) {
        // Another rider got there first: say so, then put the sheet away.
        setState(() {
          _error = 'This delivery was just taken by another rider.';
        });
        _clock.stop();
        await Future<void>.delayed(const Duration(milliseconds: 1800));
        if (mounted) Navigator.pop(context, OfferOutcome.taken);
        return;
      }
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  Future<void> _decline() async {
    setState(() => _busy = true);
    try {
      await ref.read(riderRepositoryProvider).decline(widget.offer.orderId);
    } catch (_) {
      // Declining is best-effort: the offer is dismissed either way.
    }
    if (mounted) Navigator.pop(context, OfferOutcome.declined);
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.offer;
    return PopScope(
      canPop: false,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const StatusPill(label: 'New delivery request', color: AppColors.mangoDeep, background: AppColors.cream),
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _clock,
                    builder: (_, _) {
                      final left = (widget.window.inSeconds * (1 - _clock.value)).ceil();
                      return Text('${left}s', style: TextStyle(fontWeight: FontWeight.w800, color: left <= 10 ? AppColors.danger : AppColors.inkMuted));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AnimatedBuilder(
                animation: _clock,
                builder: (_, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 1 - _clock.value,
                    minHeight: 5,
                    color: _clock.value > 0.78 ? AppColors.danger : AppColors.violet,
                    backgroundColor: AppColors.violetSoft,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    const Text('You will earn', style: TextStyle(color: AppColors.inkMuted)),
                    Text(formatNaira(o.payout), style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: AppColors.success, fontSize: 44)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _Stop(icon: Icons.storefront_rounded, label: 'Pick up', value: o.restaurantName, trailing: o.distance.isEmpty ? null : '${o.distance} away'),
              Padding(padding: const EdgeInsets.only(left: 11), child: Container(width: 2, height: 16, color: AppColors.border)),
              _Stop(icon: Icons.location_on_rounded, label: 'Drop off', value: o.dropoffAddress),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
                ),
              ],
              const SizedBox(height: 20),
              CtaButton(label: 'Accept delivery', loading: _busy, onPressed: _accept),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: _busy ? null : _decline, child: const Text('Decline')),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({required this.icon, required this.label, required this.value, this.trailing});

  final IconData icon;
  final String label;
  final String value;
  final String? trailing;

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
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
        ),
        if (trailing != null)
          Text(trailing!, style: const TextStyle(color: AppColors.violet, fontWeight: FontWeight.w700, fontSize: 13)),
      ],
    );
  }
}

/// Short attention cue when an offer arrives: system alert sound and a few buzzes.
Future<void> signalNewOffer() async {
  SystemSound.play(SystemSoundType.alert);
  for (var i = 0; i < 3; i++) {
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 180));
  }
}
