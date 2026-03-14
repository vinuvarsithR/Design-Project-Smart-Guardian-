import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/live_tracking_screen.dart';
import 'screens/monitored_user_screen.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';
import 'widgets/sg_design_system.dart';
import 'providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint('Notification init failed: $e');
  }
  runApp(const SmartGuardianApp());
}

// ─────────────────────────────────────────────────────────────────────────────
// Root app — owns ThemeProvider state
// ─────────────────────────────────────────────────────────────────────────────

class SmartGuardianApp extends StatefulWidget {
  const SmartGuardianApp({super.key});
  @override
  State<SmartGuardianApp> createState() => _SmartGuardianAppState();
}

class _SmartGuardianAppState extends State<SmartGuardianApp> {
  final _theme = ThemeProvider();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _theme,
      builder: (context, _) {
        final t = SGTheme(isDark: _theme.isDark);

        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              _theme.isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: t.navBar,
          systemNavigationBarIconBrightness:
              _theme.isDark ? Brightness.light : Brightness.dark,
        ));

        return SGThemeWrapper(
          isDark: _theme.isDark,
          child: MaterialApp(
            title: 'SmartGuardian',
            debugShowCheckedModeBanner: false,
            theme: t.themeData,
            home: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Scaffold(
                    backgroundColor: t.bg,
                    body: Center(
                        child: CircularProgressIndicator(color: t.accent)),
                  );
                }
                if (!snap.hasData) return const LoginScreen();

                return FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .where('monitoredUid', isEqualTo: snap.data!.uid)
                      .limit(1)
                      .get(),
                  builder: (context, roleSnap) {
                    if (roleSnap.connectionState == ConnectionState.waiting) {
                      return Scaffold(
                        backgroundColor: t.bg,
                        body: Center(
                            child:
                                CircularProgressIndicator(color: t.accent)),
                      );
                    }
                    final docs = roleSnap.data?.docs ?? [];
                    if (docs.isNotEmpty) {
                      final d = docs.first.data() as Map<String, dynamic>;
                      return MonitoredUserScreen(
                        userId:   docs.first.id,
                        userName: d['name'] ?? 'You',
                      );
                    }
                    return AppShell(themeProvider: _theme);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Guardian App Shell
// ─────────────────────────────────────────────────────────────────────────────

class AppShell extends StatefulWidget {
  final ThemeProvider themeProvider;
  const AppShell({super.key, required this.themeProvider});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final _fs = FirestoreService();

  @override
  void initState() {
    super.initState();
    _fs.startVitalsWatcher();
  }

  final _screens = const [
    DashboardScreen(),
    LiveTrackingScreen(),
    AlertsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final t = SGTheme.of(context);

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.navBar,
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
              boxShadow: SG.glowShadow(SG.accent),
            ),
            child: const Icon(Icons.shield_outlined,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Text('SmartGuardian',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800,
                  color: t.textPrimary, letterSpacing: -0.3)),
        ]),
        actions: [
          // ── Theme toggle ─────────────────────────────────────────────────
          GestureDetector(
            onTap: widget.themeProvider.toggle,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: t.border),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  widget.themeProvider.isDark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  key: ValueKey(widget.themeProvider.isDark),
                  size: 18,
                  color: t.textSecondary,
                ),
              ),
            ),
          ),
          // ── Sign out ──────────────────────────────────────────────────────
          GestureDetector(
            onTap: () => _confirmSignOut(context),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: t.border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.logout_outlined,
                    size: 14, color: t.textSecondary),
                const SizedBox(width: 6),
                Text('Sign out',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: t.textSecondary)),
              ]),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: t.border),
        ),
      ),
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: StreamBuilder<int>(
        stream: _fs.getUnreadAlertCount(),
        builder: (context, snap) {
          final unread = snap.data ?? 0;
          return Container(
            decoration: BoxDecoration(
              color: t.navBar,
              border: Border(top: BorderSide(color: t.border)),
            ),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              backgroundColor: Colors.transparent,
              elevation: 0,
              indicatorColor: t.accentGlow,
              labelBehavior:
                  NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                NavigationDestination(
                  icon: Icon(Icons.shield_outlined, color: t.textSecondary),
                  selectedIcon: Icon(Icons.shield, color: t.accent),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.map_outlined, color: t.textSecondary),
                  selectedIcon: Icon(Icons.map, color: t.accent),
                  label: 'Live Map',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: unread > 0,
                    label: Text(unread > 9 ? '9+' : '$unread',
                        style: const TextStyle(fontSize: 10)),
                    backgroundColor: SG.danger,
                    child: Icon(Icons.notifications_outlined,
                        color: t.textSecondary),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: unread > 0,
                    label: Text(unread > 9 ? '9+' : '$unread',
                        style: const TextStyle(fontSize: 10)),
                    backgroundColor: SG.danger,
                    child: Icon(Icons.notifications, color: t.accent),
                  ),
                  label: 'Alerts',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext ctx) async {
    final t  = SGTheme.of(ctx);
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: t.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Sign out?',
            style: TextStyle(color: t.textPrimary,
                fontWeight: FontWeight.w700)),
        content: Text('You will need to sign in again.',
            style: TextStyle(color: t.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: t.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: t.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) await FirebaseAuth.instance.signOut();
  }
}
