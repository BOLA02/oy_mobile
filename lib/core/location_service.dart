import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'network/api_exception.dart';

class DeviceLocation {
  const DeviceLocation({required this.latitude, required this.longitude, this.address});

  final double latitude;
  final double longitude;

  /// A readable address from the phone's geocoder; null when it is unavailable.
  final String? address;
}

/// Reads the phone's position once, asking for permission if needed.
/// Throws an [ApiException] with a message fit to show the user.
Future<DeviceLocation> currentDeviceLocation() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const ApiException('Location is turned off. Turn it on and try again.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied) {
    throw const ApiException('Location permission was denied.');
  }
  if (permission == LocationPermission.deniedForever) {
    throw const ApiException('Location permission is blocked. Allow it in the app settings.');
  }

  final pos = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
  );

  String? address;
  try {
    final marks = await Geocoding().placemarkFromCoordinates(pos.latitude, pos.longitude);
    if (marks.isNotEmpty) {
      final m = marks.first;
      address = [m.street, m.subLocality, m.locality, m.administrativeArea]
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .join(', ');
      if (address.isEmpty) address = null;
    }
  } catch (_) {
    // Reverse geocoding is a convenience; the coordinates are what matter.
  }
  return DeviceLocation(latitude: pos.latitude, longitude: pos.longitude, address: address);
}
