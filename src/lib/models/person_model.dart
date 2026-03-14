import 'package:cloud_firestore/cloud_firestore.dart';

class Person {
  final String id;
  final String name;
  final int? age;
  final String? gender;
  final String guardianId; // ✅ ownership field

  // Location stored as GeoPoint in Firestore
  final GeoPoint? location;

  // Geofence
  final double? fenceLat;
  final double? fenceLng;
  final double? fenceRadius;
  final bool? outOfZone;

  // Vitals
  final int? heartRate;
  final double? temperature;

  // Fall detection
  final bool? fallDetected;
  final DateTime? fallDetectedAt;

  Person({
    required this.id,
    required this.name,
    required this.guardianId,
    this.age,
    this.gender,
    this.location,
    this.fenceLat,
    this.fenceLng,
    this.fenceRadius,
    this.outOfZone,
    this.heartRate,
    this.temperature,
    this.fallDetected,
    this.fallDetectedAt,
  });

  factory Person.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Person(
      id: doc.id,
      name: d['name'] ?? 'Unknown',
      guardianId: d['guardianId'] ?? '',
      age: d['age'] as int?,
      gender: d['gender'] as String?,
      location: d['location'] as GeoPoint?,
      fenceLat: (d['fenceLat'] as num?)?.toDouble(),
      fenceLng: (d['fenceLng'] as num?)?.toDouble(),
      fenceRadius: (d['fenceRadius'] as num?)?.toDouble(),
      outOfZone: d['outOfZone'] as bool?,
      heartRate: (d['heartRate'] as num?)?.toInt(),
      temperature: (d['temperature'] as num?)?.toDouble(),
      fallDetected: d['fallDetected'] as bool?,
      fallDetectedAt: (d['fallDetectedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'guardianId': guardianId,
        'age': age,
        'gender': gender,
        'fenceLat': fenceLat,
        'fenceLng': fenceLng,
        'fenceRadius': fenceRadius,
        'outOfZone': outOfZone ?? false,
        'heartRate': heartRate ?? 0,
        'temperature': temperature ?? 0.0,
        'fallDetected': fallDetected ?? false,
        'fallDetectedAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
