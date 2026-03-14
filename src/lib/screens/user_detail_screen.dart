import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../models/person_model.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../widgets/sg_design_system.dart';
import '../providers/theme_provider.dart';
import 'map_screen.dart';

class UserDetailScreen extends StatefulWidget {
  final String personId;
  const UserDetailScreen({super.key, required this.personId});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen>
    with SingleTickerProviderStateMixin {
  final _fs = FirestoreService();
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? SG.danger : SG.navyCard,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _setGeofence() async {
    final pos = await Navigator.push<LatLng>(context,
        MaterialPageRoute(
            builder: (_) =>
                MapScreen(selectMode: true, userId: widget.personId)));
    if (pos is LatLng && mounted) _toast('Geofence updated');
  }

  Future<void> _updateLocation(Person p) async {
    if (p.fenceLat == null) {
      _toast('Set a geofence first', error: true); return;
    }
    final pos = await LocationService.getCurrentPosition();
    if (pos == null) { _toast('Could not get location', error: true); return; }
    await _fs.updateLocationAndCheckGeofence(
        widget.personId, pos.latitude, pos.longitude,
        p.fenceLat!, p.fenceLng!, p.fenceRadius!);
    if (mounted) _toast('Location updated');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(widget.personId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(
            backgroundColor: SGTheme.of(context).bg,
            body: Center(child: CircularProgressIndicator(color: SG.accent)),
          );
        }
        final p    = Person.fromDoc(snap.data!);
        final fall = p.fallDetected == true;

        return Scaffold(
          backgroundColor: SGTheme.of(context).bg,
          body: SafeArea(
            child: Column(children: [
              // ── Header ──────────────────────────────────────────────────
              _Header(
                person: p, fall: fall,
                onBack: () => Navigator.pop(context),
                onAcknowledge: fall
                    ? () async {
                        await _fs.acknowledgeFall(widget.personId);
                        if (mounted) _toast('Fall alert cleared');
                      }
                    : null,
              ),

              // ── Pill tabs ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: SGTheme.of(context).surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: SGTheme.of(context).border),
                  ),
                  child: TabBar(
                    controller: _tab,
                    indicator: BoxDecoration(
                      color: SG.accent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: SG.glowShadow(SG.accent),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: SG.textSecondary,
                    labelStyle: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                    padding: const EdgeInsets.all(3),
                    tabs: const [
                      Tab(text: 'Overview'),
                      Tab(text: 'Location'),
                      Tab(text: 'Alerts'),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              // ── Content ──────────────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _Overview(
                      p: p, fall: fall,
                      onGeofence: _setGeofence,
                      onLocation: () => _updateLocation(p),
                    ),
                    _LocationTab(p: p),
                    _AlertsTab(userId: widget.personId, fs: _fs),
                  ],
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final Person person;
  final bool fall;
  final VoidCallback onBack;
  final VoidCallback? onAcknowledge;

  const _Header({
    required this.person, required this.fall,
    required this.onBack, this.onAcknowledge,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = fall ? SG.danger
        : person.outOfZone == true ? SG.warn : SG.safe;
    final statusLabel = fall ? 'Fall Detected'
        : person.outOfZone == true ? 'Out of Zone' : 'Safe';
    final statusIcon  = fall ? Icons.warning_amber_rounded
        : person.outOfZone == true
            ? Icons.location_off_outlined
            : Icons.check_circle_outline;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      decoration: BoxDecoration(
        color: SGTheme.of(context).card,
        border: Border(
          bottom: BorderSide(color: SGTheme.of(context).border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back + acknowledge row
          Row(children: [
            GestureDetector(
              onTap: onBack,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SGTheme.of(context).surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: SGTheme.of(context).border),
                ),
                child: Icon(Icons.arrow_back_ios_new,
                    size: 14, color: SGTheme.of(context).textSecondary),
              ),
            ),
            const Spacer(),
            if (fall && onAcknowledge != null)
              GestureDetector(
                onTap: onAcknowledge,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: SG.dangerGlow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: SG.danger.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 14, color: SG.danger),
                      SizedBox(width: 6),
                      Text('Acknowledge', style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: SG.danger)),
                    ],
                  ),
                ),
              ),
          ]),

          SizedBox(height: 16),

          // Person info
          Row(children: [
            // Avatar with status ring
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: statusColor, width: 2),
                boxShadow: SG.glowShadow(statusColor),
              ),
              child: Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    person.name[0].toUpperCase(),
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800,
                        color: statusColor),
                  ),
                ),
              ),
            ),
            SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(person.name,
                      style: SG.titleStyle(context).copyWith(fontSize: 18)),
                  SizedBox(height: 3),
                  Text(
                    '${person.age ?? "--"} yrs · ${person.gender ?? "Unknown"}',
                    style: SG.bodyStyle(context),
                  ),
                ],
              ),
            ),

            SGPill(
              label: statusLabel, color: statusColor,
              bg: statusColor.withOpacity(0.12), icon: statusIcon,
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Overview tab ──────────────────────────────────────────────────────────────

class _Overview extends StatelessWidget {
  final Person p;
  final bool fall;
  final VoidCallback onGeofence, onLocation;

  const _Overview({
    required this.p, required this.fall,
    required this.onGeofence, required this.onLocation,
  });

  Color _hrColor(int? v) {
    if (v == null || v == 0) return SG.textMuted;
    if (v < 40 || v > 120)  return SG.danger;
    if (v > 100)             return SG.warn;
    return SG.safe;
  }

  Color _tmpColor(double? v) {
    if (v == null || v == 0) return SG.textMuted;
    if (v < 35 || v > 38.5) return SG.danger;
    if (v > 37.5)            return SG.warn;
    return SG.purple;
  }

  String _hrLabel(int? v) {
    if (v == null || v == 0) return 'No data';
    if (v < 40)  return 'Critical low';
    if (v > 120) return 'Elevated';
    return 'Normal';
  }

  String _tmpLabel(double? v) {
    if (v == null || v == 0) return 'No data';
    if (v < 35)   return 'Hypothermia';
    if (v > 38.5) return 'Fever';
    return 'Normal';
  }

  @override
  Widget build(BuildContext context) {
    final hr  = p.heartRate;
    final tmp = p.temperature;
    final gp  = p.location as GeoPoint?;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
      children: [

        // ── Fall banner ──────────────────────────────────────────────────
        if (fall) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SG.dangerGlow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SG.danger.withOpacity(0.4)),
            ),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded,
                  color: SG.danger, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fall detected',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: SG.danger)),
                    if (p.fallDetectedAt != null)
                      Text(
                        DateFormat('HH:mm, MMM d')
                            .format(p.fallDetectedAt!.toLocal()),
                        style: TextStyle(
                            fontSize: 12, color: SG.danger),
                      ),
                  ],
                ),
              ),
            ]),
          ),
          SizedBox(height: 20),
        ],

        // ── Vitals ───────────────────────────────────────────────────────
        const SGSectionLabel('Vitals'),
        Row(children: [
          Expanded(child: _VitalCard(
            icon: Icons.favorite_outline,
            iconColor: SG.danger,
            label: 'Heart Rate',
            value: (hr != null && hr != 0) ? '$hr' : '--',
            unit: 'bpm',
            status: _hrLabel(hr),
            statusColor: _hrColor(hr),
          )),
          SizedBox(width: 12),
          Expanded(child: _VitalCard(
            icon: Icons.thermostat_outlined,
            iconColor: SG.purple,
            label: 'Temperature',
            value: (tmp != null && tmp != 0)
                ? tmp.toStringAsFixed(1) : '--',
            unit: '°C',
            status: _tmpLabel(tmp),
            statusColor: _tmpColor(tmp),
          )),
        ]),

        SizedBox(height: 24),

        // ── Geofence ─────────────────────────────────────────────────────
        const SGSectionLabel('Safe Zone'),
        _ActionRow(
          icon: Icons.fence_outlined,
          iconColor: p.outOfZone == true ? SG.warn : SG.accent,
          title: p.fenceLat != null
              ? '${p.fenceLat!.toStringAsFixed(4)}, '
                '${p.fenceLng!.toStringAsFixed(4)}'
              : 'No geofence set',
          subtitle: p.fenceLat != null
              ? '${(p.fenceRadius ?? 100).toStringAsFixed(0)} m · '
                '${p.outOfZone == true ? "⚠️ Outside zone" : "✅ Inside zone"}'
              : 'Tap to set safe zone on map',
          onTap: onGeofence,
          trailing: Icon(Icons.arrow_forward_ios,
              size: 13, color: SGTheme.of(context).textMuted),
        ),

        SizedBox(height: 12),

        // ── Location ─────────────────────────────────────────────────────
        const SGSectionLabel('Last Location'),
        _ActionRow(
          icon: Icons.my_location_outlined,
          iconColor: SG.safe,
          title: gp != null
              ? '${gp.latitude.toStringAsFixed(5)}, '
                '${gp.longitude.toStringAsFixed(5)}'
              : 'No location data',
          subtitle: 'Tap to refresh from device GPS',
          onTap: onLocation,
          trailing: Icon(Icons.refresh,
              size: 16, color: SGTheme.of(context).textMuted),
        ),
      ],
    );
  }
}

// ── Location tab ──────────────────────────────────────────────────────────────

class _LocationTab extends StatelessWidget {
  final Person p;
  const _LocationTab({required this.p});

  @override
  Widget build(BuildContext context) {
    final gp = p.location as GeoPoint?;
    if (gp == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SGIconBox(icon: Icons.location_off_outlined,
                color: SGTheme.of(context).textMuted, size: 60),
            SizedBox(height: 16),
            Text('No location yet', style: SG.headingStyle(context)),
            SizedBox(height: 4),
            Text('Update from the Overview tab', style: SG.bodyStyle(context)),
          ],
        ),
      );
    }

    final pos = LatLng(gp.latitude, gp.longitude);
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(0)),
      child: GoogleMap(
        initialCameraPosition:
            CameraPosition(target: pos, zoom: 15),
        mapType: MapType.normal,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        markers: {
          Marker(
            markerId: const MarkerId('user'),
            position: pos,
            infoWindow: InfoWindow(
              title: p.name,
              snippet: p.outOfZone == true ? '⚠️ Out of Zone' : '✅ Safe',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              p.outOfZone == true
                  ? BitmapDescriptor.hueOrange
                  : BitmapDescriptor.hueGreen,
            ),
          ),
        },
        circles: {
          if (p.fenceLat != null)
            Circle(
              circleId: const CircleId('fence'),
              center: LatLng(p.fenceLat!, p.fenceLng!),
              radius: p.fenceRadius ?? 100,
              fillColor: (p.outOfZone == true
                      ? SG.warn
                      : SG.accent)
                  .withOpacity(0.08),
              strokeColor:
                  p.outOfZone == true ? SG.warn : SG.accent,
              strokeWidth: 2,
            ),
        },
      ),
    );
  }
}

// ── Alerts tab ────────────────────────────────────────────────────────────────

class _AlertsTab extends StatelessWidget {
  final String userId;
  final FirestoreService fs;
  const _AlertsTab({required this.userId, required this.fs});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: fs.getUserAlertsStream(userId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(color: SG.accent));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SGIconBox(icon: Icons.check_circle_outline,
                    color: SG.safe, size: 60),
                SizedBox(height: 16),
                Text('No alerts for ${userId.substring(0, 4)}…',
                    style: SG.headingStyle(context)),
                SizedBox(height: 4),
                Text('No health events recorded', style: SG.bodyStyle(context)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d          = docs[i].data() as Map<String, dynamic>;
            final id         = docs[i].id;
            final isResolved = d['isResolved'] == true;
            final sev        = d['severity'] ?? 'low';
            final msg        = d['message']  ?? '';
            final ts         = d['createdAt'] as Timestamp?;
            final color      = sev == 'high'
                ? SG.danger
                : sev == 'medium' ? SG.warn : SG.accent;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SGCard(
                padding: const EdgeInsets.all(14),
                borderColor: isResolved
                    ? SG.navyBorder
                    : color.withOpacity(0.3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 8, height: 8,
                      margin: const EdgeInsets.only(top: 5, right: 10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isResolved ? SG.textMuted : color,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(msg,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: isResolved
                                      ? SG.textMuted
                                      : SG.textPrimary,
                                  fontWeight: FontWeight.w500)),
                          if (ts != null) ...[
                            SizedBox(height: 4),
                            Text(
                              DateFormat('MMM d, HH:mm')
                                  .format(ts.toDate().toLocal()),
                              style: TextStyle(
                                  fontSize: 11, color: SGTheme.of(context).textMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    GestureDetector(
                      onTap: isResolved ? null : () => fs.resolveAlert(id),
                      child: isResolved
                          ? Icon(Icons.check_circle,
                              size: 16, color: SG.safe)
                          : Text('Resolve',
                              style: TextStyle(
                                  fontSize: 12, color: SG.safe,
                                  fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _VitalCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor, statusColor;
  final String label, value, unit, status;

  const _VitalCard({
    required this.icon, required this.iconColor, required this.label,
    required this.value, required this.unit, required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) => SGCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              SGIconBox(icon: icon, color: iconColor, size: 32),
              SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12, color: SGTheme.of(context).textSecondary)),
              ),
            ]),
            SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w800,
                        color: SGTheme.of(context).textPrimary, letterSpacing: -1)),
                SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(unit,
                      style: TextStyle(
                          fontSize: 12, color: SGTheme.of(context).textMuted)),
                ),
              ],
            ),
            SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Text(status,
                  style: TextStyle(
                      fontSize: 11, color: statusColor,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final VoidCallback onTap;
  final Widget trailing;

  const _ActionRow({
    required this.icon, required this.iconColor, required this.title,
    required this.subtitle, required this.onTap, required this.trailing,
  });

  @override
  Widget build(BuildContext context) => SGCard(
        onTap: onTap,
        child: Row(children: [
          SGIconBox(icon: icon, color: iconColor),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: SGTheme.of(context).textPrimary)),
                SizedBox(height: 3),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12, color: SGTheme.of(context).textSecondary)),
              ],
            ),
          ),
          trailing,
        ]),
      );
}
