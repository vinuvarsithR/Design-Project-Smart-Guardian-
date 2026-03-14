import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

/// Runs on the MONITORED PERSON's phone.
/// Continuously streams GPS → Firestore every [intervalSeconds] seconds.
/// Firestore's geofence check in FirestoreService triggers alerts on the
/// guardian's side automatically via stream listeners.
class TrackingService {
  TrackingService._();

  static StreamSubscription<Position>? _sub;
  static bool get isRunning => _sub != null;

  // ── Start tracking ──────────────────────────────────────────────────────────
  static Future<String?> start({
    required String userId,
    required double fenceLat,
    required double fenceLng,
    required double fenceRadius,
    int intervalSeconds = 10,
  }) async {
    if (_sub != null) return null; // already running

    // Check / request permission
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      return 'Location permission permanently denied. '
          'Enable it in device settings.';
    }
    if (perm == LocationPermission.denied) {
      return 'Location permission denied.';
    }

    final settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // metres — only update if moved 5 m
    );

    _sub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((pos) async {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'location': GeoPoint(pos.latitude, pos.longitude),
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Geofence check (simple Haversine — same logic as FirestoreService)
      final dist = Geolocator.distanceBetween(
          pos.latitude, pos.longitude, fenceLat, fenceLng);
      final outside = dist > fenceRadius;

      // Only write if state changed (prevents hammering Firestore)
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final wasOutside = snap.data()?['outOfZone'] == true;

      if (outside != wasOutside) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'outOfZone': outside});

        if (outside) {
          // Create geofence alert
          final name = snap.data()?['name'] ?? 'User';
          final guardianId = snap.data()?['guardianId'] ?? '';
          await FirebaseFirestore.instance.collection('alerts').add({
            'guardianId': guardianId,
            'userId': userId,
            'userName': name,
            'type': 'geofence',
            'severity': 'high',
            'message': '$name has left the safe zone',
            'isRead': false,
            'isResolved': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
    });

    return null; // null = success
  }

  // ── Stop tracking ───────────────────────────────────────────────────────────
  static Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }
}
