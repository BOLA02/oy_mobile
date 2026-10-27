import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/session.dart';
import '../data/offer_socket.dart';
import '../domain/delivery_offer.dart';

/// The live socket, only for a signed-in rider. Reconnects automatically and is
/// closed when the rider signs out.
final offerSocketProvider = Provider<OfferSocket?>((ref) {
  final session = ref.watch(sessionControllerProvider).value;
  if (session == null || session.role != AppRole.rider) return null;
  final socket = SocketIoOfferSocket(url: Env.apiBaseUrl, token: session.token)..connect();
  ref.onDispose(socket.dispose);
  return socket;
});

/// Whether the live connection is up (drives the "Live" badge and how often the
/// dashboard falls back to polling).
final liveConnectionProvider = StreamProvider<bool>((ref) async* {
  final socket = ref.watch(offerSocketProvider);
  if (socket == null) {
    yield false;
    return;
  }
  yield socket.isConnected;
  yield* socket.connection;
});

/// Offers waiting for the rider's answer, oldest first. A repeated offer for
/// the same order replaces the earlier one instead of stacking up.
class OffersController extends Notifier<List<DeliveryOffer>> {
  @override
  List<DeliveryOffer> build() {
    final sub = ref.watch(offerSocketProvider)?.offers.listen(add);
    ref.onDispose(() => sub?.cancel());
    return const [];
  }

  void add(DeliveryOffer offer) {
    final i = state.indexWhere((o) => o.orderId == offer.orderId);
    if (i < 0) {
      state = [...state, offer];
    } else {
      final next = [...state];
      next[i] = offer;
      state = next;
    }
  }

  void remove(int orderId) => state = state.where((o) => o.orderId != orderId).toList();
}

final offersProvider = NotifierProvider<OffersController, List<DeliveryOffer>>(OffersController.new);
