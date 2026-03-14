import 'package:flutter/material.dart';
import '../providers/theme_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SmartGuardian Design System
// Status/brand colors are constant. Background/text/border colors come
// from SGTheme.of(context) so they respond to dark/light mode.
// ─────────────────────────────────────────────────────────────────────────────

class SG {
  // ── Brand (constant — same in both modes) ──────────────────────────────────
  static const accent      = Color(0xFF3B82F6);
  static const accentGlow  = Color(0x263B82F6);

  // ── Status (constant) ──────────────────────────────────────────────────────
  static const safe        = Color(0xFF10B981);
  static const safeGlow    = Color(0x1A10B981);
  static const warn        = Color(0xFFF59E0B);
  static const warnGlow    = Color(0x1AF59E0B);
  static const danger      = Color(0xFFEF4444);
  static const dangerGlow  = Color(0x1AEF4444);
  static const purple      = Color(0xFF8B5CF6);
  static const purpleGlow  = Color(0x1A8B5CF6);

  // ── Dark-mode fallback colors (used in const constructors / static styles) ─
  // For runtime-resolved colors use SGTheme.of(context) instead.
  static const navy        = Color(0xFF0A0F1E);
  static const navyCard    = Color(0xFF111827);
  static const navyBorder  = Color(0xFF1F2937);
  static const navySurface = Color(0xFF162032);
  static const textPrimary   = Color(0xFFF9FAFB);
  static const textSecondary = Color(0xFF9CA3AF);
  static const textMuted     = Color(0xFF4B5563);

  // ── Typography — resolved at runtime via SGTheme ───────────────────────────
  // Use sgDisplay(context) etc. for theme-aware text styles.
  static TextStyle display(BuildContext ctx) {
    final t = SGTheme.of(ctx);
    return TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
        color: t.textPrimary, letterSpacing: -0.8);
  }
  static TextStyle titleStyle(BuildContext ctx) {
    final t = SGTheme.of(ctx);
    return TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
        color: t.textPrimary, letterSpacing: -0.4);
  }
  static TextStyle headingStyle(BuildContext ctx) {
    final t = SGTheme.of(ctx);
    return TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
        color: t.textPrimary);
  }
  static TextStyle bodyStyle(BuildContext ctx) {
    final t = SGTheme.of(ctx);
    return TextStyle(fontSize: 14, color: t.textSecondary);
  }
  static TextStyle captionStyle(BuildContext ctx) {
    final t = SGTheme.of(ctx);
    return TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
        color: t.textMuted, letterSpacing: 1.1);
  }

  // ── Legacy static getters (dark-mode only, for const contexts) ────────────
  static TextStyle get displayStatic => const TextStyle(
      fontSize: 28, fontWeight: FontWeight.w800,
      color: textPrimary, letterSpacing: -0.8);
  static TextStyle get title  => const TextStyle(
      fontSize: 20, fontWeight: FontWeight.w700,
      color: textPrimary, letterSpacing: -0.4);
  static TextStyle get heading => const TextStyle(
      fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary);
  static TextStyle get body   =>
      const TextStyle(fontSize: 14, color: textSecondary);
  static TextStyle get caption => const TextStyle(
      fontSize: 11, fontWeight: FontWeight.w600,
      color: textMuted, letterSpacing: 1.1);

  // ── Shadows ────────────────────────────────────────────────────────────────
  static List<BoxShadow> cardShadow(BuildContext ctx) {
    final isDark = SGTheme.of(ctx).isDark;
    return [BoxShadow(
      color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
      blurRadius: 16, offset: const Offset(0, 4),
    )];
  }

  // Keep old static version for places that can't take context
  static final List<BoxShadow> cardShadowDark = [
    BoxShadow(color: Colors.black.withOpacity(0.3),
        blurRadius: 16, offset: const Offset(0, 4)),
  ];

  static List<BoxShadow> glowShadow(Color color) => [
    BoxShadow(color: color.withOpacity(0.35),
        blurRadius: 20, spreadRadius: -4, offset: const Offset(0, 6)),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Theme-aware Reusable Widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Card that adapts to dark/light theme
class SGCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? color;

  const SGCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.borderColor,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = SGTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: color ?? t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? t.border),
        boxShadow: SG.cardShadow(context),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          splashColor: SG.accent.withOpacity(0.08),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Pill badge — status colors constant, no theme needed
class SGPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  final IconData? icon;
  final double fontSize;

  const SGPill({
    super.key,
    required this.label,
    required this.color,
    required this.bg,
    this.icon,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
        ],
        Text(label,
            style: TextStyle(
                fontSize: fontSize, fontWeight: FontWeight.w700,
                color: color, letterSpacing: 0.2)),
      ]),
    );
  }
}

/// Icon box — status colors constant
class SGIconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const SGIconBox({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Icon(icon, color: color, size: size * 0.48),
    );
  }
}

/// Section label — theme-aware text color
class SGSectionLabel extends StatelessWidget {
  final String text;
  const SGSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = SGTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text.toUpperCase(),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: t.textMuted, letterSpacing: 1.1)),
    );
  }
}
