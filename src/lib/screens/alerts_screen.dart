import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../widgets/sg_design_system.dart';
import '../providers/theme_provider.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with SingleTickerProviderStateMixin {
  final _fs = FirestoreService();
  late TabController _tab;

  @override
  void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SGTheme.of(context).bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Alerts', style: SG.display(context)),
                      SizedBox(height: 4),
                      Text('Health & safety notifications', style: SG.bodyStyle(context)),
                    ],
                  ),
                ),
                // Unread badge + mark all read
                StreamBuilder<int>(
                  stream: _fs.getUnreadAlertCount(),
                  builder: (context, snap) {
                    final count = snap.data ?? 0;
                    return GestureDetector(
                      onTap: () async {
                        await _fs.markAllAlertsRead();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('All marked as read'),
                            backgroundColor: SG.navyCard,
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ));
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: SGTheme.of(context).surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: SGTheme.of(context).border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (count > 0) ...[
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                    color: SG.accent, shape: BoxShape.circle),
                              ),
                              SizedBox(width: 6),
                            ],
                            Text(
                              count > 0 ? '$count unread' : 'All read',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                  color: SGTheme.of(context).textSecondary),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ]),
            ),

            // ── Pill tab bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
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
                  tabs: const [Tab(text: 'Active'), Tab(text: 'All')],
                ),
              ),
            ),

            SizedBox(height: 16),

            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _List(fs: _fs, unresolvedOnly: true),
                  _List(fs: _fs, unresolvedOnly: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _List extends StatelessWidget {
  final FirestoreService fs;
  final bool unresolvedOnly;
  const _List({required this.fs, required this.unresolvedOnly});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: fs.getAlertsStream(unresolvedOnly: unresolvedOnly),
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
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: SG.safeGlow, shape: BoxShape.circle,
                    border: Border.all(color: SG.safe.withOpacity(0.3)),
                  ),
                  child: Icon(Icons.check_circle_outline,
                      size: 32, color: SG.safe),
                ),
                SizedBox(height: 16),
                Text(unresolvedOnly ? 'No active alerts' : 'No alerts yet',
                    style: SG.headingStyle(context)),
                SizedBox(height: 4),
                Text('Everything looks good', style: SG.bodyStyle(context)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final d  = docs[i].data() as Map<String, dynamic>;
            final id = docs[i].id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AlertTile(data: d, alertId: id, fs: fs),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _AlertTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final String alertId;
  final FirestoreService fs;
  const _AlertTile({required this.data, required this.alertId, required this.fs});

  @override
  Widget build(BuildContext context) {
    final type       = data['type']     ?? '';
    final severity   = data['severity'] ?? 'low';
    final message    = data['message']  ?? '';
    final userName   = data['userName'] ?? '';
    final isRead     = data['isRead']     == true;
    final isResolved = data['isResolved'] == true;
    final ts         = data['createdAt'] as Timestamp?;

    // Type config
    IconData icon; Color color; Color bg; String label;
    switch (type) {
      case 'fall':
        icon = Icons.warning_amber_rounded; color = SG.danger;
        bg = SG.dangerGlow; label = 'Fall';
        break;
      case 'geofence':
        icon = Icons.location_off_outlined; color = SG.warn;
        bg = SG.warnGlow; label = 'Geofence';
        break;
      case 'heart_rate':
        icon = Icons.favorite_outline; color = const Color(0xFFF43F5E);
        bg = const Color(0x1AF43F5E); label = 'Heart Rate';
        break;
      case 'temperature':
        icon = Icons.thermostat_outlined; color = SG.purple;
        bg = SG.purpleGlow; label = 'Temperature';
        break;
      default:
        icon = Icons.notifications_outlined; color = SG.accent;
        bg = SG.accentGlow; label = 'Alert';
    }

    if (isResolved) { color = SG.textMuted; bg = SG.navySurface; }

    final time = ts != null
        ? DateFormat('MMM d, HH:mm').format(ts.toDate().toLocal())
        : '';

    return Dismissible(
      key: Key(alertId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: SG.safe.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: SG.safe.withOpacity(0.3)),
        ),
        child: Icon(Icons.check, color: SG.safe),
      ),
      confirmDismiss: (_) async {
        await fs.resolveAlert(alertId);
        return false;
      },
      child: SGCard(
        borderColor: isResolved
            ? SG.navyBorder
            : color.withOpacity(0.3),
        onTap: isRead ? null : () => fs.markAlertRead(alertId),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon box
            SGIconBox(icon: icon, color: color),
            SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    // Unread dot
                    if (!isRead && !isResolved)
                      Container(
                        width: 6, height: 6,
                        margin: const EdgeInsets.only(right: 6, top: 2),
                        decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle),
                      ),
                    Expanded(
                      child: Text(
                        '$label · $userName',
                        style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: isResolved
                              ? SG.textMuted
                              : SG.textPrimary,
                        ),
                      ),
                    ),
                    SGPill(
                      label: isResolved ? 'Resolved'
                          : severity[0].toUpperCase() +
                              severity.substring(1),
                      color: isResolved ? SG.textMuted : color,
                      bg: isResolved ? SG.navySurface : bg,
                    ),
                  ]),
                  SizedBox(height: 5),
                  Text(message,
                      style: TextStyle(
                          fontSize: 13,
                          color: isResolved
                              ? SG.textMuted
                              : SG.textSecondary)),
                  SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.access_time,
                        size: 11, color: SGTheme.of(context).textMuted),
                    SizedBox(width: 4),
                    Text(time,
                        style: TextStyle(
                            fontSize: 11, color: SGTheme.of(context).textMuted)),
                    const Spacer(),
                    if (!isResolved)
                      GestureDetector(
                        onTap: () => fs.resolveAlert(alertId),
                        child: Text('Resolve ✓',
                            style: TextStyle(
                                fontSize: 12,
                                color: SG.safe,
                                fontWeight: FontWeight.w700)),
                      ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
