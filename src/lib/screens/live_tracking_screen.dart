import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../widgets/sg_design_system.dart';
import '../providers/theme_provider.dart';

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  GoogleMapController? _mapController;
  String? _selectedUserId;

  // ── Build markers + circles from Firestore docs ────────────────────────────
  _MapData _buildMapData(
      List<QueryDocumentSnapshot> docs, SGTheme t) {
    final Set<Marker>  markers = {};
    final Set<Circle>  circles = {};

    for (final doc in docs) {
      final d    = doc.data() as Map<String, dynamic>;
      final name = (d['name'] ?? 'Unknown') as String;
      final out  = d['outOfZone'] == true;
      final fall = d['fallDetected'] == true;

      // ── Live location marker ─────────────────────────────────────────────
      final locGeo = d['location'];
      if (locGeo != null && locGeo is GeoPoint) {
        final pos = LatLng(locGeo.latitude, locGeo.longitude);

        // Color: danger if fall, warn if out of zone, safe otherwise
        final hue = fall
            ? BitmapDescriptor.hueRose     // bright pink-red for fall
            : out
                ? BitmapDescriptor.hueOrange // orange for out-of-zone
                : BitmapDescriptor.hueAzure; // blue for safe

        markers.add(Marker(
          markerId: MarkerId('loc_${doc.id}'),
          position: pos,
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: InfoWindow(
            title: name,
            snippet: fall
                ? '🚨 Fall detected'
                : out
                    ? '⚠️ Outside safe zone'
                    : '✅ Safe',
          ),
          onTap: () => setState(() => _selectedUserId = doc.id),
        ));
      }

      // ── Geofence circle ──────────────────────────────────────────────────
      final fLat = (d['fenceLat'] as num?)?.toDouble();
      final fLng = (d['fenceLng'] as num?)?.toDouble();
      final fRad = (d['fenceRadius'] as num?)?.toDouble() ?? 100;

      if (fLat != null && fLng != null && fLat != 0) {
        final strokeColor = out ? t.warn : t.safe;
        circles.add(Circle(
          circleId: CircleId('fence_${doc.id}'),
          center: LatLng(fLat, fLng),
          radius: fRad,
          fillColor: strokeColor.withOpacity(0.08),
          strokeColor: strokeColor.withOpacity(0.6),
          strokeWidth: 2,
        ));
      }
    }

    return _MapData(markers: markers, circles: circles);
  }

  void _fitBounds(Set<Marker> markers) {
    if (markers.isEmpty || _mapController == null) return;
    if (markers.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(markers.first.position, 15),
      );
      return;
    }
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final m in markers) {
      if (m.position.latitude  < minLat) minLat = m.position.latitude;
      if (m.position.latitude  > maxLat) maxLat = m.position.latitude;
      if (m.position.longitude < minLng) minLng = m.position.longitude;
      if (m.position.longitude > maxLng) maxLng = m.position.longitude;
    }
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(minLat - 0.005, minLng - 0.005),
        northeast: LatLng(maxLat + 0.005, maxLng + 0.005),
      ),
      60,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t   = SGTheme.of(context);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: t.bg,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('guardianId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snap) {
          final docs  = snap.data?.docs ?? [];
          final data  = _buildMapData(docs, t);
          final hasLoc = data.markers.isNotEmpty;

          // Apply map style when controller is ready
          if (_mapController != null) {
            _mapController!.setMapStyle(t.mapStyle);
          }

          return Stack(
            children: [
              // ── Map ─────────────────────────────────────────────────────
              hasLoc
                  ? GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: data.markers.first.position,
                        zoom: 14,
                      ),
                      markers:  data.markers,
                      circles:  data.circles,
                      mapType:  MapType.normal,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,   // removes the 3-dot / directions button
                      onMapCreated: (ctrl) {
                        _mapController = ctrl;
                        ctrl.setMapStyle(t.mapStyle);
                        Future.delayed(
                          const Duration(milliseconds: 500),
                          () => _fitBounds(data.markers),
                        );
                      },
                    )
                  : _emptyState(t),

              // ── User legend cards (bottom) ────────────────────────────
              if (docs.isNotEmpty)
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  child: _UserLegend(
                    docs: docs,
                    selectedId: _selectedUserId,
                    onTap: (doc) {
                      setState(() => _selectedUserId = doc.id);
                      final d = doc.data() as Map<String, dynamic>;
                      final loc = d['location'];
                      if (loc is GeoPoint && _mapController != null) {
                        _mapController!.animateCamera(
                          CameraUpdate.newLatLngZoom(
                              LatLng(loc.latitude, loc.longitude), 16));
                      }
                    },
                  ),
                ),

              // ── Fit all button ────────────────────────────────────────
              if (hasLoc)
                Positioned(
                  top: 16, right: 16,
                  child: GestureDetector(
                    onTap: () => _fitBounds(data.markers),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: t.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: t.border),
                        boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                        )],
                      ),
                      child: Icon(Icons.fit_screen_outlined,
                          color: t.accent, size: 20),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _emptyState(SGTheme t) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: t.surface,
            shape: BoxShape.circle,
            border: Border.all(color: t.border),
          ),
          child: Icon(Icons.location_off_outlined,
              color: t.textMuted, size: 32),
        ),
        const SizedBox(height: 16),
        Text('No locations yet',
            style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.w700, color: t.textPrimary)),
        const SizedBox(height: 6),
        Text('Ask monitored users to turn on tracking',
            style: TextStyle(fontSize: 13, color: t.textSecondary)),
      ],
    ),
  );
}

// ── Map data container ────────────────────────────────────────────────────────

class _MapData {
  final Set<Marker> markers;
  final Set<Circle> circles;
  const _MapData({required this.markers, required this.circles});
}

// ── Bottom legend of users ─────────────────────────────────────────────────────

class _UserLegend extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final String? selectedId;
  final ValueChanged<QueryDocumentSnapshot> onTap;

  const _UserLegend({
    required this.docs,
    required this.selectedId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = SGTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        border: Border(top: BorderSide(color: t.border)),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.15),
          blurRadius: 12, offset: const Offset(0, -4),
        )],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MONITORED USERS', style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: t.textMuted, letterSpacing: 1.2,
          )),
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final doc  = docs[i];
                final d    = doc.data() as Map<String, dynamic>;
                final name = (d['name'] ?? 'Unknown') as String;
                final out  = d['outOfZone']    == true;
                final fall = d['fallDetected'] == true;
                final hasLoc = d['location'] != null;
                final selected = doc.id == selectedId;

                final statusColor = fall
                    ? t.danger
                    : out
                        ? t.warn
                        : hasLoc ? t.safe : t.textMuted;

                return GestureDetector(
                  onTap: () => onTap(doc),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? t.accent.withOpacity(0.12)
                          : t.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? t.accent : t.border,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(name.split(' ').first,
                              style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700,
                                color: t.textPrimary,
                              )),
                          const SizedBox(height: 2),
                          Text(
                            fall ? 'Fall alert'
                                : out ? 'Out of zone'
                                : hasLoc ? 'Tracking'
                                : 'No signal',
                            style: TextStyle(
                                fontSize: 11, color: statusColor,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
