import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/rider/application/offers.dart';
import '../../features/rider/application/rider_providers.dart';
import '../../features/rider/presentation/offer_sheet.dart';

class CustomerShell extends StatelessWidget {
  const CustomerShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

/// The rider's frame. Besides the tabs, it listens for live delivery requests
/// and puts each one in front of the rider, wherever they are in the app.
class RiderShell extends ConsumerStatefulWidget {
  const RiderShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<RiderShell> createState() => _RiderShellState();
}

class _RiderShellState extends ConsumerState<RiderShell> {
  bool _showing = false;

  /// Shows queued offers one after another until none are left.
  Future<void> _showOffers() async {
    if (_showing) return;
    _showing = true;
    try {
      while (mounted) {
        final queue = ref.read(offersProvider);
        if (queue.isEmpty) break;
        final offer = queue.first;
        signalNewOffer();
        final outcome = await showModalBottomSheet<OfferOutcome>(
          context: context,
          isDismissible: false,
          enableDrag: false,
          isScrollControlled: true,
          builder: (_) => OfferSheet(offer: offer),
        );
        ref.read(offersProvider.notifier).remove(offer.orderId);
        if (!mounted) break;

        if (outcome == OfferOutcome.accepted) {
          // Taking a delivery ends the queue: the rider is busy now.
          for (final o in ref.read(offersProvider)) {
            ref.read(offersProvider.notifier).remove(o.orderId);
          }
          ref.invalidate(riderDashboardProvider);
          widget.navigationShell.goBranch(0);
          _toast('Delivery accepted. Head to the restaurant!');
        } else if (outcome == OfferOutcome.taken) {
          ref.invalidate(riderDashboardProvider);
          _toast('That delivery was taken by another rider.');
        }
      }
    } finally {
      _showing = false;
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    // Watching the socket is what opens the connection while a rider is signed in.
    ref.watch(offerSocketProvider);
    ref.listen(offersProvider, (_, next) {
      if (next.isNotEmpty) _showOffers();
    });

    final shell = widget.navigationShell;
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.two_wheeler_outlined), selectedIcon: Icon(Icons.two_wheeler_rounded), label: 'Deliveries'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet_rounded), label: 'Wallet'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}
