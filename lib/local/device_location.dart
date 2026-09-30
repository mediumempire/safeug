import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// A location failure that can be shown directly beside a landmark fallback.
class DeviceLocationException implements Exception {
  const DeviceLocationException(this.message);
  final String message;

  @override
  String toString() => message;
}

class DeviceLocation {
  /// Requests one foreground fix without requiring manually entered coordinates.
  static Future<Position> currentPosition({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      return await _locate(timeout).timeout(timeout);
    } on DeviceLocationException {
      rethrow;
    } on TimeoutException {
      throw const DeviceLocationException(
        'Location timed out. Move to an open area and retry, or enter an area or landmark.',
      );
    } on LocationServiceDisabledException {
      throw const DeviceLocationException(
        'Location services are off. Enable device location and retry, or enter an area or landmark.',
      );
    } on PermissionDeniedException {
      throw const DeviceLocationException(
        'Location permission was denied. Allow location in your device or browser settings, or enter an area or landmark.',
      );
    } catch (_) {
      throw const DeviceLocationException(
        'Current location is unavailable. Check device location and site permissions, then retry or enter an area or landmark. Browser location needs HTTPS or localhost.',
      );
    }
  }

  static Future<Position> _locate(Duration timeout) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const DeviceLocationException(
        'Location services are off. Enable device location and retry, or enter an area or landmark.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const DeviceLocationException(
        'Location is blocked. Allow SafeUG location access in your device or browser settings, or enter an area or landmark.',
      );
    }
    if (permission == LocationPermission.denied) {
      throw const DeviceLocationException(
        'Location permission was denied. Retry and allow location, or enter an area or landmark.',
      );
    }
    return Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: timeout,
      ),
    );
  }
}
