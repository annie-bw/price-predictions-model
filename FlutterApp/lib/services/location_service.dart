import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../utils/geo.dart';

/// A location problem with a short message for the location notice.
class LocationException implements Exception {
  final String message;
  const LocationException(this.message);

  @override
  String toString() => message;
}

/// Gets the phone's position. Permission is asked only when this is called,
/// i.e. when the user taps "Use my location", never at startup.
class LocationService {
  static const turnedOffMessage = 'Location is turned off. Type a market instead.';
  static const deniedMessage = 'Location permission was not given. Type a market instead.';
  static const blockedMessage =
      'Location is blocked for this app. Type a market instead, or allow it in Settings.';
  static const timeoutMessage = 'Couldn’t find your location in time. Type a market instead.';
  static const failedMessage = 'Couldn’t get your location. Type a market instead.';

  const LocationService();

  Future<GeoPoint> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(turnedOffMessage);
    }
    await _ensurePermission();

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return GeoPoint(position.latitude, position.longitude);
    } on TimeoutException {
      throw const LocationException(timeoutMessage);
    } on LocationServiceDisabledException {
      throw const LocationException(turnedOffMessage);
    } on PermissionDeniedException {
      throw const LocationException(deniedMessage);
    } catch (_) {
      throw const LocationException(failedMessage);
    }
  }

  Future<void> _ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(blockedMessage);
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      throw const LocationException(deniedMessage);
    }
  }
}
