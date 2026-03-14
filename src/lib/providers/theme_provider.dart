import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ThemeProvider — app-wide dark/light toggle
// Usage:
//   ThemeProvider.of(context).isDark
//   ThemeProvider.of(context).toggle()
// ─────────────────────────────────────────────────────────────────────────────

class ThemeProvider extends ChangeNotifier {
  late bool _isDark;
  ThemeProvider({bool initialDark = true}) { _isDark = initialDark; }
  bool get isDark => _isDark;

  void toggle() {
    _isDark = !_isDark;
    notifyListeners();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SGTheme — resolves colors based on current mode
// Replace hardcoded SG.navy etc. with SGTheme.of(context).bg etc.
// ─────────────────────────────────────────────────────────────────────────────

class SGTheme {
  final bool isDark;
  const SGTheme({required this.isDark});

  static SGTheme of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<_SGThemeInherited>()
        ?.theme;
    return provider ?? const SGTheme(isDark: true);
  }

  // ── Backgrounds ────────────────────────────────────────────────────────────
  Color get bg        => isDark ? const Color(0xFF0A0F1E) : const Color(0xFFF0F4FF);
  Color get card      => isDark ? const Color(0xFF111827) : Colors.white;
  Color get surface   => isDark ? const Color(0xFF162032) : const Color(0xFFE8EEF8);
  Color get border    => isDark ? const Color(0xFF1F2937) : const Color(0xFFD1DCF0);

  // ── Brand ──────────────────────────────────────────────────────────────────
  Color get accent    => const Color(0xFF3B82F6);
  Color get accentGlow=> const Color(0x263B82F6);

  // ── Status ─────────────────────────────────────────────────────────────────
  Color get safe      => const Color(0xFF10B981);
  Color get safeGlow  => const Color(0x1A10B981);
  Color get warn      => const Color(0xFFF59E0B);
  Color get warnGlow  => const Color(0x1AF59E0B);
  Color get danger    => const Color(0xFFEF4444);
  Color get dangerGlow=> const Color(0x1AEF4444);
  Color get purple    => const Color(0xFF8B5CF6);

  // ── Text ───────────────────────────────────────────────────────────────────
  Color get textPrimary   => isDark ? const Color(0xFFF9FAFB) : const Color(0xFF0F172A);
  Color get textSecondary => isDark ? const Color(0xFF9CA3AF) : const Color(0xFF475569);
  Color get textMuted     => isDark ? const Color(0xFF4B5563) : const Color(0xFF94A3B8);

  // ── App bar / nav bar ──────────────────────────────────────────────────────
  Color get navBar    => isDark ? const Color(0xFF111827) : Colors.white;

  // ── Google Maps style string ───────────────────────────────────────────────
  String get mapStyle => isDark ? _darkMapStyle : _lightMapStyle;

  // ── MaterialApp ThemeData ─────────────────────────────────────────────────
  ThemeData get themeData => ThemeData(
    useMaterial3: true,
    brightness: isDark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: bg,
    colorScheme: ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: accent,
      onPrimary: Colors.white,
      secondary: accent,
      onSecondary: Colors.white,
      surface: card,
      onSurface: textPrimary,
      background: bg,
      onBackground: textPrimary,
      error: danger,
      onError: Colors.white,
    ),
  );
}

// ─── Inherited widget wrapper ─────────────────────────────────────────────────

class _SGThemeInherited extends InheritedWidget {
  final SGTheme theme;
  const _SGThemeInherited({required this.theme, required super.child});

  @override
  bool updateShouldNotify(_SGThemeInherited old) => theme.isDark != old.theme.isDark;
}

class SGThemeWrapper extends StatelessWidget {
  final bool isDark;
  final Widget child;
  const SGThemeWrapper({super.key, required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) => _SGThemeInherited(
    theme: SGTheme(isDark: isDark),
    child: child,
  );
}

// ─── Map styles ───────────────────────────────────────────────────────────────

const String _darkMapStyle = '''[
  {"elementType":"geometry","stylers":[{"color":"#0a0f1e"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#6b7280"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#0a0f1e"}]},
  {"featureType":"administrative","elementType":"geometry.stroke","stylers":[{"color":"#1f2937"}]},
  {"featureType":"administrative.land_parcel","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#1f2937"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#111827"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#4b5563"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#162032"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#050a14"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#1f2937"}]}
]''';

const String _lightMapStyle = '''[
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]}
]''';
