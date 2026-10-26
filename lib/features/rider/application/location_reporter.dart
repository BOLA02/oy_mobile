import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'rider_providers.dart';

/// While the rider is online, sends their GPS position to the backend so
/// customers can track the delivery and dispatch can find nearby riders.
class LocationReporter {
  LocationReporter(this._ref);

  final Ref _ref;
  StreamSubscription<Position>? _sub;

  bool get isRunning => _sub != null;

  /// Returns false when location permission is missing.
  Future<bool> start() async {
    if (isRunning) return true;
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return false;
    }

    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 25),
    ).listen((p) {
      // A failed ping is not worth interrupting the rider; the next one retries.
      _ref.read(riderRepositoryProvider).pingLocation(p.latitude, p.longitude).catchError((_) {});
    });
    return true;
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }
}

final locationReporterProvider = Provider<LocationReporter>((ref) {
  final reporter = LocationReporter(ref);
  ref.onDispose(reporter.stop);
  return reporter;
});
