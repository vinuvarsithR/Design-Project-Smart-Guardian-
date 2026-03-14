import 'package:geolocator/geolocator.dart';

/// Single canonical LocationService.
/// Returns null on failure (never throws) so callers can handle gracefully.
class LocationService {
  static Future<bool> ensurePermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  /// Returns null if permission denied or location unavailable.
  static Future<Position?> getCurrentPosition() async {
    try {
      final granted = await ensurePermission();
      if (!granted) return null;
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('[LocationService] Error: $e');
      return null;
    }
  }

  /// Stream continuous location updates (for live tracking).
  static Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // only emit if moved ≥10 metres
      ),
    );
  }
}
