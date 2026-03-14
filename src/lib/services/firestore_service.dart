import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';
import '../models/person_model.dart';
import 'geofence_service.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  String? get _guardianId => FirebaseAuth.instance.currentUser?.uid;

  // ── Single user stream ────────────────────────────────────────────────────
  Stream<DocumentSnapshot> getUserStream(String id) =>
      _db.collection('users').doc(id).snapshots();

  // ── All users for this guardian ───────────────────────────────────────────
  Stream<QuerySnapshot> getUsersStream() {
    final uid = _guardianId;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('users')
        .where('guardianId', isEqualTo: uid)
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  // ── Add user (simple) ─────────────────────────────────────────────────────
  Future<void> addUser(Person p) async {
    final uid = _guardianId;
    if (uid == null) return;
    await _db.collection('users').add({
      'guardianId':  uid,
      'name':        p.name,
      'age':         p.age,
      'gender':      p.gender,
      'fenceLat':    p.fenceLat,
      'fenceLng':    p.fenceLng,
      'fenceRadius': p.fenceRadius,
      'outOfZone':   false,
      'createdAt':   FieldValue.serverTimestamp(),
    });
  }

  // ── Add user from multi-step form ─────────────────────────────────────────
  Future<void> addUserFromFields({
    required String name,
    required int age,
    required String gender,
    required String dementiaStage,
    required List<String> conditions,
    required List<String> medications,
    required List<String> allergies,
    required String bloodType,
    required String ecName,
    required String ecPhone,
    required String ecRelation,
    required String doctorName,
    required String doctorPhone,
    required String doctorHospital,
  }) async {
    final uid = _guardianId;
    if (uid == null) return;
    await _db.collection('users').add({
      'guardianId':     uid,
      'name':           name,
      'age':            age,
      'gender':         gender,
      'dementiaStage':  dementiaStage,
      'conditions':     conditions,
      'medications':    medications,
      'allergies':      allergies,
      'bloodType':      bloodType,
      'ecName':         ecName,
      'ecPhone':        ecPhone,
      'ecRelation':     ecRelation,
      'doctorName':     doctorName,
      'doctorPhone':    doctorPhone,
      'doctorHospital': doctorHospital,
      'fenceLat':       0.0,
      'fenceLng':       0.0,
      'fenceRadius':    100.0,
      'outOfZone':      false,
      'fallDetected':   false,
      'heartRate':      0,
      'temperature':    0.0,
      'createdAt':      FieldValue.serverTimestamp(),
    });
  }

  // ── Delete user ───────────────────────────────────────────────────────────
  Future<void> deleteUser(String id) async =>
      _db.collection('users').doc(id).delete();

  // ── Location ──────────────────────────────────────────────────────────────
  Future<void> updateUserLocation(String id, double lat, double lng) async {
    await _db.collection('users').doc(id).update({
      'location': GeoPoint(lat, lng),
    });
  }

  Future<void> setGeofence(
      String id, double lat, double lng, double radius) async {
    await _db.collection('users').doc(id).update({
      'fenceLat':    lat,
      'fenceLng':    lng,
      'fenceRadius': radius,
    });
  }

  Future<void> updateLocationAndCheckGeofence(
    String id,
    double userLat,
    double userLng,
    double fenceLat,
    double fenceLng,
    double fenceRadius,
  ) async {
    final isOut = GeofenceService.isOutsideFence(
      userLat:  userLat,
      userLng:  userLng,
      fenceLat: fenceLat,
      fenceLng: fenceLng,
      radius:   fenceRadius,
    );
    await _db.collection('users').doc(id).update({
      'location':  GeoPoint(userLat, userLng),
      'outOfZone': isOut,
    });
  }

  // ── Fall ──────────────────────────────────────────────────────────────────
  Future<void> acknowledgeFall(String userId) async {
    await _db.collection('users').doc(userId).update({'fallDetected': false});
  }

  // ── Alerts ────────────────────────────────────────────────────────────────
  Stream<QuerySnapshot> getAlertsStream({bool unresolvedOnly = false}) {
    final uid = _guardianId;
    if (uid == null) return const Stream.empty();
    if (unresolvedOnly) {
      return _db
          .collection('alerts')
          .where('guardianId', isEqualTo: uid)
          .where('isResolved', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .snapshots();
    }
    return _db
        .collection('alerts')
        .where('guardianId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getUserAlertsStream(String userId) {
    return _db
        .collection('alerts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<int> getUnreadAlertCount() {
    final uid = _guardianId;
    if (uid == null) return Stream.value(0);
    return _db
        .collection('alerts')
        .where('guardianId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  Future<void> markAlertRead(String alertId) async {
    await _db.collection('alerts').doc(alertId).update({'isRead': true});
  }

  Future<void> resolveAlert(String alertId) async {
    await _db.collection('alerts').doc(alertId).update({
      'isResolved': true,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAllAlertsRead() async {
    final uid = _guardianId;
    if (uid == null) return;
    final batch = _db.batch();
    final snap = await _db
        .collection('alerts')
        .where('guardianId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .get();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // ── Vitals watcher ────────────────────────────────────────────────────────
  void startVitalsWatcher() {
    final uid = _guardianId;
    if (uid == null) return;
    _db
        .collection('users')
        .where('guardianId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          final d    = change.doc.data() as Map<String, dynamic>;
          final id   = change.doc.id;
          final name = (d['name'] ?? 'User') as String;
          final hr   = (d['heartRate']   as num?)?.toInt();
          final temp = (d['temperature'] as num?)?.toDouble();
          final fall = d['fallDetected'] == true;

          if (fall) {
            _createAlertIfNone(id, name, uid, 'fall', 'high',
                '$name may have fallen — check immediately');
          }
          if (hr != null && (hr < 40 || hr > 120)) {
            _createAlertIfNone(id, name, uid, 'heart_rate', 'high',
                '$name\'s heart rate is $hr bpm '
                '(${hr < 40 ? "dangerously low" : "dangerously high"})');
          }
          if (temp != null && (temp < 35.0 || temp > 38.5)) {
            _createAlertIfNone(id, name, uid, 'temperature', 'high',
                '$name\'s temperature is ${temp.toStringAsFixed(1)}°C '
                '(${temp < 35.0 ? "hypothermia risk" : "fever"})');
          }
        }
      }
    });
  }

  Future<void> _createAlertIfNone(
      String userId, String userName, String guardianId,
      String type, String severity, String message) async {
    final existing = await _db
        .collection('alerts')
        .where('userId',     isEqualTo: userId)
        .where('type',       isEqualTo: type)
        .where('isResolved', isEqualTo: false)
        .get();
    if (existing.docs.isNotEmpty) return;

    // Write alert to Firestore
    await _db.collection('alerts').add({
      'guardianId': guardianId,
      'userId':     userId,
      'userName':   userName,
      'type':       type,
      'severity':   severity,
      'message':    message,
      'isRead':     false,
      'isResolved': false,
      'createdAt':  FieldValue.serverTimestamp(),
    });

    // Fire local notification on the guardian's device immediately
    final title = _alertTitle(type, userName);
    await NotificationService.showLocal(title, message);
  }

  String _alertTitle(String type, String name) {
    switch (type) {
      case 'fall':        return '🚨 Fall Detected — $name';
      case 'heart_rate':  return '❤️ Heart Rate Alert — $name';
      case 'temperature': return '🌡️ Temperature Alert — $name';
      case 'geofence':    return '📍 Geofence Alert — $name';
      default:            return '⚠️ Alert — $name';
    }
  }
}
