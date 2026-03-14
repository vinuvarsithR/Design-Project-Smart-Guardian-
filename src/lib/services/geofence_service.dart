import 'dart:math';

class GeofenceService {
  // Haversine formula to calculate distance between 2 points in meters
  static double distanceInMeters(
      double lat1, double lon1, double lat2, double lon2) {

    const earthRadius = 6371000; // meters

    double dLat = _degToRad(lat2 - lat1);
    double dLon = _degToRad(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  static double _degToRad(double deg) {
    return deg * pi / 180;
  }

  static bool isOutsideFence({
    required double userLat,
    required double userLng,
    required double fenceLat,
    required double fenceLng,
    required double radius,
  }) {
    final distance = distanceInMeters(
      userLat,
      userLng,
      fenceLat,
      fenceLng,
    );

    return distance > radius;
  }
}
