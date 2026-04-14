import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Forest Sanctuary design system tokens.
///
/// All widgets reference these constants — never hardcode colours, font sizes,
/// radii, or spacing inline. To retheme the whole app, update this file only.
///
/// Design language: "Digital Greenhouse" — deep botanical dark palette,
/// vibrant emerald accent, Manrope typeface, ambient glow, no 1px divider lines.
abstract final class VailTheme {
  // ── Colours ───────────────────────────────────────────────────────────────

  /// Deepest background — forest base. Never use pure black.
  static const Color background = Color(0xFF051C10);

  /// Surface — same as background; cards sit above via surface container steps.
  static const Color surface = Color(0xFF051C10);

  /// Surface container low — first elevation step above background.
  static const Color surfaceContainerLow = Color(0xFF0A2918);

  /// Surface container — card backgrounds, list item areas.
  static const Color surfaceContainer = Color(0xFF0E331F);

  /// Surface container high — interactive cards, elevated panels.
  static const Color surfaceContainerHigh = Color(0xFF164028);

  /// Surface container highest — highest elevation within a surface.
  static const Color surfaceContainerHighest = Color(0xFF1F4D32);

  /// Surface bright — header highlights, hover glows.
  static const Color surfaceBright = Color(0xFF1A3528);

  /// Signature brand green — CTAs, active states, AI avatar, glow source.
  static const Color primary = Color(0xFF21C45D);

  /// Text / icon rendered on primary-coloured surfaces.
  static const Color onPrimary = Color(0xFF051C10);

  /// Low-opacity primary fill — chip backgrounds, subtle highlights.
  static const Color primaryContainer = Color(0x1A21C45D); // primary/10

  /// Ghost border — only use when visual separation is required without a line.
  /// Equivalent to white/5 — catches light on container edges.
  static const Color ghostBorder = Color(0x0DFFFFFF); // white/5

  /// Outline — semi-transparent primary for card borders on AI messages.
  static const Color outline = Color(0x4D21C45D); // primary/30

  // Text colours
  static const Color onSurface = Color(0xFFF1F5F9);
  static const Color onSurfaceVariant = Color(0xFFCBD5E1);
  static const Color textMuted = Color(0xFF4A6355); // emerald-900/60 equivalent

  // Semantic
  static const Color error = Color(0xFFFFB4AB);

  // ── Spacing ───────────────────────────────────────────────────────────────

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 40;

  // ── Radius ────────────────────────────────────────────────────────────────
  // Forest Sanctuary: every interactive element has at least 1rem radius.

  static const double radiusSm = 12.0;  // 0.75rem — chips, tags, small badges
  static const double radiusMd = 16.0;  // 1rem    — default card/container
  static const double radiusLg = 24.0;  // 1.5rem  — message bubbles
  static const double radiusXl = 32.0;  // 2rem    — sheets, modals
  static const double radiusFull = 9999.0; // pill — inputs, CTAs

  // ── Shadows / Glows ───────────────────────────────────────────────────────

  /// Primary action glow — used on send button, upgrade CTA.
  static List<BoxShadow> primaryGlow = [
    BoxShadow(
      color: primary.withValues(alpha: 0.4),
      blurRadius: 20,
      spreadRadius: 0,
    ),
  ];

  /// AI message card glow — subtle ambient green haze.
  static List<BoxShadow> aiCardGlow = [
    BoxShadow(
      color: primary.withValues(alpha: 0.15),
      blurRadius: 15,
      spreadRadius: 0,
    ),
  ];

  // ── Typography — Manrope ─────────────────────────────────────────────────

  /// Display / hero — 30px bold, for splash and wordmarks.
  static TextStyle get display => GoogleFonts.manrope(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: onSurface,
        height: 1.1,
      );

  /// Screen heading — 20px bold.
  static TextStyle get heading => GoogleFonts.manrope(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: onSurface,
        height: 1.2,
      );

  /// Sub-heading — 18px semibold.
  static TextStyle get subheading => GoogleFonts.manrope(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: onSurface,
        height: 1.3,
      );

  /// Body — 16px regular. Readable against dark surfaces.
  static TextStyle get body => GoogleFonts.manrope(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: onSurface,
        height: 1.55,
      );

  /// Body small — 14px regular.
  static TextStyle get bodySmall => GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: onSurfaceVariant,
        height: 1.4,
      );

  /// Label — 12px semibold. Section headers, metadata.
  static TextStyle get label => GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: onSurface,
        height: 1.2,
      );

  /// Caption — 10px bold uppercase. Nav labels, status tags.
  static TextStyle get caption => GoogleFonts.manrope(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: onSurfaceVariant,
        height: 1.0,
      );

  /// Micro — 9px bold uppercase. Extreme-density labels.
  static TextStyle get micro => GoogleFonts.manrope(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: textMuted,
        height: 1.0,
      );

  // Keep mono for code blocks — Manrope is not a monospace font.
  static const String _fontMono = 'monospace';

  /// Inline code text.
  static TextStyle get inlineCode => const TextStyle(
        fontFamily: _fontMono,
        fontSize: 13,
        color: primary,
        backgroundColor: primaryContainer,
      );

  // ── Backward-compat aliases ───────────────────────────────────────────────
  // Old token names → Forest Sanctuary equivalents.
  // Existing files compile unchanged; update call sites progressively.

  static const Color accent = primary;
  static const Color accentSubtle = primaryContainer;
  static const Color onAccent = onPrimary;
  static const Color border = ghostBorder;
  static const Color borderSubtle = ghostBorder;
  static const Color textPrimary = onSurface;
  static const Color textSecondary = onSurfaceVariant;
  static const Color userBubble = surfaceContainerHigh;
  static const Color onUserBubble = onSurface;
  static const Color surfaceInput = surfaceContainerLow;

  static TextStyle get mono => caption;
  static TextStyle get sectionLabel => caption;
  static TextStyle get wordmark => display;
  static TextStyle get brandLabel => label;
  static TextStyle get sessionTitle => label.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      );

  // ── Syntax highlight theme ────────────────────────────────────────────────

  static const Map<String, TextStyle> codeTheme = {
    'root': TextStyle(
      color: Color(0xFFF1F5F9),
      backgroundColor: Color(0xFF031109), // surfaceContainerLowest
    ),
    'keyword': TextStyle(color: Color(0xFF21C45D), fontWeight: FontWeight.w600),
    'built_in': TextStyle(color: Color(0xFF21C45D)),
    'type': TextStyle(color: Color(0xFFE5C07B)),
    'class': TextStyle(color: Color(0xFFE5C07B), fontWeight: FontWeight.w600),
    'function': TextStyle(color: Color(0xFF61AFEF)),
    'title': TextStyle(color: Color(0xFF61AFEF), fontWeight: FontWeight.w600),
    'string': TextStyle(color: Color(0xFFE5C07B)),
    'number': TextStyle(color: Color(0xFFD19A66)),
    'literal': TextStyle(color: Color(0xFFD19A66)),
    'boolean': TextStyle(color: Color(0xFFD19A66)),
    'regexp': TextStyle(color: Color(0xFFD19A66)),
    'tag': TextStyle(color: Color(0xFFE06C75)),
    'attr': TextStyle(color: Color(0xFFE5C07B)),
    'attribute': TextStyle(color: Color(0xFFE5C07B)),
    'name': TextStyle(color: Color(0xFFE06C75)),
    'selector-tag': TextStyle(color: Color(0xFF21C45D)),
    'selector-class': TextStyle(color: Color(0xFFE5C07B)),
    'selector-id': TextStyle(color: Color(0xFF61AFEF)),
    'comment': TextStyle(color: Color(0xFF4A6355), fontStyle: FontStyle.italic),
    'quote': TextStyle(color: Color(0xFF4A6355), fontStyle: FontStyle.italic),
    'doctag': TextStyle(color: Color(0xFF4A6355)),
    'variable': TextStyle(color: Color(0xFFE06C75)),
    'template-variable': TextStyle(color: Color(0xFFE06C75)),
    'params': TextStyle(color: Color(0xFFF1F5F9)),
    'operator': TextStyle(color: Color(0xFF56B6C2)),
    'symbol': TextStyle(color: Color(0xFF56B6C2)),
    'bullet': TextStyle(color: Color(0xFF21C45D)),
    'meta': TextStyle(color: Color(0xFF56B6C2)),
    'meta-keyword': TextStyle(color: Color(0xFF21C45D), fontWeight: FontWeight.w600),
    'emphasis': TextStyle(fontStyle: FontStyle.italic),
    'strong': TextStyle(fontWeight: FontWeight.w700),
    'deletion': TextStyle(color: Color(0xFFE06C75)),
    'addition': TextStyle(color: Color(0xFF21C45D)),
    'link': TextStyle(
      color: Color(0xFF61AFEF),
      decoration: TextDecoration.underline,
    ),
  };

  // ── Material ThemeData ────────────────────────────────────────────────────

  static ThemeData materialTheme() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          onPrimary: onPrimary,
          secondary: primary,
          onSecondary: onPrimary,
          surface: surfaceContainer,
          onSurface: onSurface,
          onSurfaceVariant: onSurfaceVariant,
          outline: ghostBorder,
          outlineVariant: ghostBorder,
          error: error,
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0x0DFFFFFF),
          thickness: 1,
          space: 1,
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFFCBD5E1),
          size: 20,
        ),
        textTheme: GoogleFonts.manropeTextTheme(
          ThemeData.dark().textTheme,
        ),
      );
}
