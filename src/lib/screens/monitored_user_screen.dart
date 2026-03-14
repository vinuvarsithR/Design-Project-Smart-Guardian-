import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../services/tracking_service.dart';
import '../services/notification_service.dart';
import '../widgets/sg_design_system.dart';

/// Screen shown to the MONITORED PERSON when they log in.
/// Features:
///  1. Live GPS tracking toggle
///  2. Vitals simulator (sliders for HR and temperature)
///  3. Accelerometer-based fall detection (real sensor)
///  4. Manual "Simulate Fall" button for demo
class MonitoredUserScreen extends StatefulWidget {
  final String userId;
  final String userName;
  const MonitoredUserScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<MonitoredUserScreen> createState() => _MonitoredUserScreenState();
}

class _MonitoredUserScreenState extends State<MonitoredUserScreen> {
  // ── Tracking ────────────────────────────────────────────────────────────────
  bool _tracking = false;
  double _fenceLat = 0, _fenceLng = 0, _fenceRadius = 100;
  bool _fenceLoaded = false;

  // ── Vitals ──────────────────────────────────────────────────────────────────
  double _hr   = 75;
  double _temp = 37.0;
  bool _uploading = false;

  // ── Accelerometer fall detection ─────────────────────────────────────────────
  StreamSubscription<AccelerometerEvent>? _accelSub;
  bool _fallCooldown = false; // prevent repeated alerts
  static const double _fallThreshold = 20.0; // m/s² — tune as needed

  @override
  void initState() {
    super.initState();
    _loadFence();
    _startAccelerometer();
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    if (_tracking) TrackingService.stop();
    super.dispose();
  }

  // ── Load geofence from Firestore ─────────────────────────────────────────────
  Future<void> _loadFence() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();
    if (doc.exists) {
      final d = doc.data()!;
      setState(() {
        _fenceLat    = (d['fenceLat']    as num?)?.toDouble() ?? 0;
        _fenceLng    = (d['fenceLng']    as num?)?.toDouble() ?? 0;
        _fenceRadius = (d['fenceRadius'] as num?)?.toDouble() ?? 100;
        _fenceLoaded = _fenceLat != 0 && _fenceLng != 0;
      });
    }
  }

  // ── Accelerometer ─────────────────────────────────────────────────────────────
  void _startAccelerometer() {
    _accelSub = accelerometerEventStream().listen((event) {
      final magnitude = sqrt(
          event.x * event.x + event.y * event.y + event.z * event.z);
      if (magnitude > _fallThreshold && !_fallCooldown) {
        _triggerFall(source: 'Accelerometer detected a sudden impact');
      }
    });
  }

  // ── Trigger fall ──────────────────────────────────────────────────────────────
  Future<void> _triggerFall({String source = 'Fall simulated'}) async {
    if (_fallCooldown) return;
    setState(() => _fallCooldown = true);

    // Write to Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .update({
      'fallDetected':   true,
      'fallDetectedAt': FieldValue.serverTimestamp(),
    });

    // Create alert
    await _createAlert(
      type: 'fall',
      severity: 'high',
      message: '${widget.userName}: $source',
    );

    // Local notification on this device
    await NotificationService.notifyFall(widget.userName);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('⚠️ Fall alert sent to guardian'),
        backgroundColor: SG.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }

    // Cool down 30 seconds to prevent repeated alerts
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) setState(() => _fallCooldown = false);
    });
  }

  // ── Upload vitals ─────────────────────────────────────────────────────────────
  Future<void> _uploadVitals() async {
    setState(() => _uploading = true);
    final hr   = _hr.round();
    final temp = double.parse(_temp.toStringAsFixed(1));

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .update({
      'heartRate':   hr,
      'temperature': temp,
    });

    // Heart rate alert
    if (hr < 40 || hr > 120) {
      await _createAlert(
        type: 'heart_rate',
        severity: 'high',
        message: '${widget.userName}\'s heart rate is $hr bpm '
            '(${hr < 40 ? "dangerously low" : "dangerously high"})',
      );
      await NotificationService.notifyHeartRate(widget.userName, hr);
    } else if (hr > 100) {
      await _createAlert(
        type: 'heart_rate',
        severity: 'medium',
        message: '${widget.userName}\'s heart rate is elevated at $hr bpm',
      );
    }

    // Temperature alert
    if (temp < 35 || temp > 38.5) {
      await _createAlert(
        type: 'temperature',
        severity: 'high',
        message: '${widget.userName}\'s temperature is ${temp.toStringAsFixed(1)}°C '
            '(${temp < 35 ? "hypothermia risk" : "fever"})',
      );
      await NotificationService.notifyTemperature(widget.userName, temp);
    }

    if (mounted) {
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Vitals uploaded to guardian'),
        backgroundColor: SG.navyCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  // ── Create Firestore alert ────────────────────────────────────────────────────
  Future<void> _createAlert({
    required String type,
    required String severity,
    required String message,
  }) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();
    final guardianId = doc.data()?['guardianId'] ?? '';

    // Dedup: don't create same alert type if one is already open
    final existing = await FirebaseFirestore.instance
        .collection('alerts')
        .where('userId',     isEqualTo: widget.userId)
        .where('type',       isEqualTo: type)
        .where('isResolved', isEqualTo: false)
        .get();
    if (existing.docs.isNotEmpty) return;

    await FirebaseFirestore.instance.collection('alerts').add({
      'guardianId': guardianId,
      'userId':     widget.userId,
      'userName':   widget.userName,
      'type':       type,
      'severity':   severity,
      'message':    message,
      'isRead':     false,
      'isResolved': false,
      'createdAt':  FieldValue.serverTimestamp(),
    });
  }

  // ── Toggle tracking ───────────────────────────────────────────────────────────
  Future<void> _toggleTracking() async {
    if (_tracking) {
      await TrackingService.stop();
      setState(() => _tracking = false);
    } else {
      if (!_fenceLoaded) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text(
              'No geofence set. Ask your guardian to set one first.'),
          backgroundColor: SG.warn,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
        return;
      }
      final err = await TrackingService.start(
        userId:      widget.userId,
        fenceLat:    _fenceLat,
        fenceLng:    _fenceLng,
        fenceRadius: _fenceRadius,
      );
      if (err != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err),
          backgroundColor: SG.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
        return;
      }
      setState(() => _tracking = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hrColor = _hr < 40 || _hr > 120
        ? SG.danger
        : _hr > 100
            ? SG.warn
            : SG.safe;
    final tmpColor = _temp < 35 || _temp > 38.5
        ? SG.danger
        : _temp > 37.5
            ? SG.warn
            : SG.purple;

    return Scaffold(
      backgroundColor: SG.navy,
      appBar: AppBar(
        backgroundColor: SG.navyCard,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.shield_outlined,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('SmartGuardian',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800,
                      color: SG.textPrimary)),
              Text('Monitored: ${widget.userName}',
                  style: const TextStyle(
                      fontSize: 11, color: SG.textSecondary)),
            ],
          ),
        ]),
        actions: [
          GestureDetector(
            onTap: () async => await FirebaseAuth.instance.signOut(),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: SG.navySurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SG.navyBorder),
              ),
              child: const Text('Sign out',
                  style: TextStyle(fontSize: 12, color: SG.textSecondary)),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: SG.navyBorder),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        children: [

          // ── Tracking toggle ────────────────────────────────────────────────
          SGCard(
            borderColor: _tracking
                ? SG.safe.withOpacity(0.4)
                : SG.navyBorder,
            child: Row(children: [
              SGIconBox(
                icon: _tracking
                    ? Icons.location_on
                    : Icons.location_off_outlined,
                color: _tracking ? SG.safe : SG.textMuted,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tracking ? 'Tracking active' : 'Tracking off',
                      style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: _tracking ? SG.safe : SG.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _tracking
                          ? 'Your location is being sent to your guardian'
                          : _fenceLoaded
                              ? 'Tap to start sending your location'
                              : 'Waiting for guardian to set geofence…',
                      style: SG.body.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _tracking,
                onChanged: (_) => _toggleTracking(),
                activeColor: SG.safe,
                activeTrackColor: SG.safeGlow,
              ),
            ]),
          ),

          const SizedBox(height: 24),

          // ── Vitals simulator ───────────────────────────────────────────────
          const SGSectionLabel('Vitals Simulator'),

          SGCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Heart rate
                Row(children: [
                  SGIconBox(icon: Icons.favorite_outline,
                      color: hrColor, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text('Heart Rate',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600,
                                  color: SG.textPrimary)),
                          const Spacer(),
                          Text('${_hr.round()} bpm',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w800,
                                  color: hrColor)),
                        ]),
                        Slider(
                          value: _hr,
                          min: 20, max: 160,
                          divisions: 140,
                          activeColor: hrColor,
                          inactiveColor: hrColor.withOpacity(0.15),
                          onChanged: (v) => setState(() => _hr = v),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('20', style: SG.caption),
                            _hrZone(_hr.round()),
                            Text('160', style: SG.caption),
                          ],
                        ),
                      ],
                    ),
                  ),
                ]),

                Divider(color: SG.navyBorder, height: 24),

                // Temperature
                Row(children: [
                  SGIconBox(icon: Icons.thermostat_outlined,
                      color: tmpColor, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Text('Temperature',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600,
                                  color: SG.textPrimary)),
                          const Spacer(),
                          Text('${_temp.toStringAsFixed(1)}°C',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w800,
                                  color: tmpColor)),
                        ]),
                        Slider(
                          value: _temp,
                          min: 33.0, max: 41.0,
                          divisions: 80,
                          activeColor: tmpColor,
                          inactiveColor: tmpColor.withOpacity(0.15),
                          onChanged: (v) =>
                              setState(() => _temp = v),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('33°C', style: SG.caption),
                            _tempZone(_temp),
                            Text('41°C', style: SG.caption),
                          ],
                        ),
                      ],
                    ),
                  ),
                ]),

                const SizedBox(height: 16),

                // Upload button
                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SG.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _uploading
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.upload_outlined, size: 18),
                    label: Text(
                        _uploading ? 'Uploading…' : 'Send vitals to guardian',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    onPressed: _uploading ? null : _uploadVitals,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Fall detection ──────────────────────────────────────────────────
          const SGSectionLabel('Fall Detection'),

          SGCard(
            borderColor: SG.danger.withOpacity(0.25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  SGIconBox(icon: Icons.sensors, color: SG.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Accelerometer active',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600,
                                color: SG.textPrimary)),
                        Text(
                          'Auto-detects falls via phone sensor '
                          '(threshold: ${_fallThreshold.toStringAsFixed(0)} m/s²)',
                          style: SG.body.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 10, height: 10,
                    decoration: const BoxDecoration(
                        color: SG.safe, shape: BoxShape.circle),
                  ),
                ]),

                const SizedBox(height: 16),

                // Manual simulate button (for demo)
                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SG.dangerGlow,
                      foregroundColor: SG.danger,
                      elevation: 0,
                      side: BorderSide(color: SG.danger.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(
                      _fallCooldown
                          ? Icons.hourglass_bottom
                          : Icons.warning_amber_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _fallCooldown
                          ? 'Alert sent — cooldown active'
                          : 'Simulate fall (demo)',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    onPressed: _fallCooldown
                        ? null
                        : () => _triggerFall(source: 'Manual fall simulation'),
                  ),
                ),

                if (_fallCooldown) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Alert sent. Another can be triggered in 30 seconds.',
                    style: TextStyle(fontSize: 11, color: SG.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Status card ─────────────────────────────────────────────────────
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(widget.userId)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox();
              final d = snap.data!.data() as Map<String, dynamic>? ?? {};
              final out  = d['outOfZone']    == true;
              final fall = d['fallDetected'] == true;
              return SGCard(
                borderColor: fall
                    ? SG.danger.withOpacity(0.4)
                    : out
                        ? SG.warn.withOpacity(0.3)
                        : SG.safe.withOpacity(0.2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SGSectionLabel('Current Status'),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatusDot(
                            label: 'Location',
                            ok: !out,
                            okLabel: 'In zone',
                            badLabel: 'Out of zone'),
                        _StatusDot(
                            label: 'Fall',
                            ok: !fall,
                            okLabel: 'None',
                            badLabel: 'Detected'),
                        _StatusDot(
                            label: 'HR',
                            ok: d['heartRate'] == null ||
                                (d['heartRate'] as num) >= 40 &&
                                    (d['heartRate'] as num) <= 120,
                            okLabel: 'Normal',
                            badLabel: 'Abnormal'),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _hrZone(int hr) {
    String label; Color color;
    if (hr < 40)       { label = 'Critical';  color = SG.danger; }
    else if (hr < 60)  { label = 'Low';        color = SG.warn; }
    else if (hr <= 100){ label = 'Normal';     color = SG.safe; }
    else if (hr <= 120){ label = 'Elevated';   color = SG.warn; }
    else               { label = 'Dangerous';  color = SG.danger; }
    return SGPill(label: label, color: color, bg: color.withOpacity(0.12));
  }

  Widget _tempZone(double t) {
    String label; Color color;
    if (t < 35)       { label = 'Hypothermia'; color = SG.accent; }
    else if (t < 36.1){ label = 'Low';          color = SG.warn; }
    else if (t <= 37.5){ label = 'Normal';      color = SG.purple; }
    else if (t <= 38.5){ label = 'Elevated';    color = SG.warn; }
    else               { label = 'Fever';       color = SG.danger; }
    return SGPill(label: label, color: color, bg: color.withOpacity(0.12));
  }
}

class _StatusDot extends StatelessWidget {
  final String label, okLabel, badLabel;
  final bool ok;
  const _StatusDot({
    required this.label, required this.ok,
    required this.okLabel, required this.badLabel,
  });

  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (ok ? SG.safe : SG.danger).withOpacity(0.12),
            border: Border.all(
                color: (ok ? SG.safe : SG.danger).withOpacity(0.4)),
          ),
          child: Icon(
            ok ? Icons.check : Icons.close,
            size: 18, color: ok ? SG.safe : SG.danger,
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: SG.caption),
        Text(ok ? okLabel : badLabel,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: ok ? SG.safe : SG.danger)),
      ]);
}
