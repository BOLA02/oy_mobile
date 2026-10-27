import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../domain/delivery_offer.dart';

/// A live feed of delivery offers. Abstract so screens and tests do not depend
/// on a real socket.
abstract class OfferSocket {
  Stream<DeliveryOffer> get offers;

  /// Emits whenever the connection goes up or down.
  Stream<bool> get connection;

  bool get isConnected;

  void connect();
  void dispose();
}

/// Socket.IO connection to the OyaEat backend. The server puts each rider in a
/// private room (`rider_<id>`) based on the JWT sent as `auth.token`, and emits
/// `NEW_DELIVERY_REQUEST` there when a restaurant marks an order ready.
class SocketIoOfferSocket implements OfferSocket {
  SocketIoOfferSocket({required String url, required String token})
      : _socket = io.io(
          url,
          io.OptionBuilder()
              .setTransports(['websocket'])
              .setAuth({'token': token})
              .disableAutoConnect()
              .enableReconnection()
              .setReconnectionDelay(1000)
              .setReconnectionDelayMax(10000)
              .enableForceNew()
              .build(),
        ) {
    _socket
      ..onConnect((_) => _connection.add(true))
      ..onDisconnect((_) => _connection.add(false))
      // Also fires for a rejected token; the REST 401 handling signs the user out.
      ..onConnectError((_) => _connection.add(false))
      ..on('NEW_DELIVERY_REQUEST', (data) {
        final offer = DeliveryOffer.fromJson(data);
        if (offer != null) _offers.add(offer);
      });
  }

  final io.Socket _socket;
  final _offers = StreamController<DeliveryOffer>.broadcast();
  final _connection = StreamController<bool>.broadcast();

  @override
  Stream<DeliveryOffer> get offers => _offers.stream;

  @override
  Stream<bool> get connection => _connection.stream;

  @override
  bool get isConnected => _socket.connected;

  @override
  void connect() => _socket.connect();

  @override
  void dispose() {
    _socket.dispose();
    _offers.close();
    _connection.close();
  }
}
