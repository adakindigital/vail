import 'package:flutter/material.dart';

/// All brand design tokens live here.
///
/// Widgets reference these constants — never hardcode colours, font sizes,
/// radii, or spacing inline. To retheme the entire app, update this file.
abstract final class VailTheme {
  // ── Colours ───────────────────────────────────────────────────────────────

  /// Page / scaffold background — near-black.
  static const Color background = Color(0xFF080808);

  /// Elevated surface: cards, code blocks, bottom sheet.
  static const Color surface = Color(0xFF111111);

  /// Input fields and secondary surfaces.
  static const Color surfaceInput = Color(0xFF181818);

  /// Strong border: card outlines, separators.
  static const Color border = Color(0xFF202020);

  /// Subtle border: dividers, inset lines.
  static const Color borderSubtle = Color(0xFF161616);

  /// Signature brand green — accent, active states, CTAs.
  static const Color accent = Color(0xFF00E676);

  /// Muted green tint — active chip / pill background.
  static const Color accentSubtle = Color(0xFF00200E);

  /// Text rendered on accent-coloured surfaces.
  static const Color onAccent = Color(0xFF000000);

  static const Color textPrimary = Color(0xFFF0F0F0);
  static const Color textSecondary = Color(0xFF6A6A6A);
  static const Color textMuted = Color(0xFF333333);

  /// User message bubble background (green-tinted dark).
  static const Color userBubble = Color(0xFF182820);
  static const Color onUserBubble = Color(0xFFD0F5E4);

  static const Color error = Color(0xFFFF4D4D);

  // ── Spacing ───────────────────────────────────────────────────────────────

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 40;

  // ── Radius ────────────────────────────────────────────────────────────────

  static const double radiusSm = 6;
  static const double radiusMd = 10;
  static const double radiusLg = 16;

  // ── Typography ────────────────────────────────────────────────────────────
  // Change font family strings here to retheme typography across the whole app.

  static const String _fontBody = 'SF Pro Display'; // system sans fallback
  static const String _fontMono = 'JetBrains Mono'; // system mono fallback

  /// Massive wordmark — empty state / splash screen.
  static const TextStyle wordmark = TextStyle(
    fontFamily: _fontBody,
    fontSize: 52,
    fontWeight: FontWeight.w900,
    letterSpacing: 14,
    color: textPrimary,
    height: 1,
  );

  /// Screen heading ("Settings", "Sessions").
  static const TextStyle heading = TextStyle(
    fontFamily: _fontBody,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    color: textPrimary,
    height: 1.1,
  );

  /// All-caps section label above content groups.
  static const TextStyle sectionLabel = TextStyle(
    fontFamily: _fontMono,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.0,
    color: textSecondary,
  );

  /// Top-bar brand label ("VAIL.CORE").
  static const TextStyle brandLabel = TextStyle(
    fontFamily: _fontMono,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.5,
    color: textPrimary,
  );

  /// Standard body text.
  static const TextStyle body = TextStyle(
    fontFamily: _fontBody,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textPrimary,
    height: 1.55,
  );

  /// Secondary / descriptive text.
  static const TextStyle bodySmall = TextStyle(
    fontFamily: _fontBody,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    height: 1.4,
  );

  /// Tiny mono label — status lines, metadata, nav labels.
  static const TextStyle mono = TextStyle(
    fontFamily: _fontMono,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.5,
    color: textSecondary,
  );

  /// Session list item title.
  static const TextStyle sessionTitle = TextStyle(
    fontFamily: _fontBody,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  // ── Syntax highlight theme ────────────────────────────────────────────────
  //
  // Used by flutter_highlight's HighlightView. The 'root' entry MUST set
  // backgroundColor — HighlightView falls back to pure white otherwise.
  // All other keys map to highlight.js token class names.

  static const Map<String, TextStyle> codeTheme = {
    // Root container — background must match surface so the code block
    // Container provides the actual background, not HighlightView.
    'root': TextStyle(
      color: textPrimary,
      backgroundColor: background,
    ),

    // ── Structural ──────────────────────────────────────────────────────────
    'keyword': TextStyle(color: accent, fontWeight: FontWeight.w600),
    'built_in': TextStyle(color: accent),
    'type': TextStyle(color: Color(0xFFE5C07B)),
    'class': TextStyle(color: Color(0xFFE5C07B), fontWeight: FontWeight.w600),
    'function': TextStyle(color: Color(0xFF61AFEF)),
    'title': TextStyle(color: Color(0xFF61AFEF), fontWeight: FontWeight.w600),

    // ── Values ───────────────────────────────────────────────────────────────
    'string': TextStyle(color: Color(0xFFE5C07B)),
    'number': TextStyle(color: Color(0xFFD19A66)),
    'literal': TextStyle(color: Color(0xFFD19A66)),
    'boolean': TextStyle(color: Color(0xFFD19A66)),
    'regexp': TextStyle(color: Color(0xFFD19A66)),

    // ── Markup / meta ────────────────────────────────────────────────────────
    'tag': TextStyle(color: Color(0xFFE06C75)),
    'attr': TextStyle(color: Color(0xFFE5C07B)),
    'attribute': TextStyle(color: Color(0xFFE5C07B)),
    'name': TextStyle(color: Color(0xFFE06C75)),
    'selector-tag': TextStyle(color: accent),
    'selector-class': TextStyle(color: Color(0xFFE5C07B)),
    'selector-id': TextStyle(color: Color(0xFF61AFEF)),

    // ── Comments & docs ──────────────────────────────────────────────────────
    'comment': TextStyle(
      color: Color(0xFF4A4A4A),
      fontStyle: FontStyle.italic,
    ),
    'quote': TextStyle(
      color: Color(0xFF4A4A4A),
      fontStyle: FontStyle.italic,
    ),
    'doctag': TextStyle(color: Color(0xFF4A4A4A)),

    // ── Variables & params ───────────────────────────────────────────────────
    'variable': TextStyle(color: Color(0xFFE06C75)),
    'template-variable': TextStyle(color: Color(0xFFE06C75)),
    'params': TextStyle(color: textPrimary),

    // ── Operators & punctuation ───────────────────────────────────────────────
    'operator': TextStyle(color: Color(0xFF56B6C2)),
    'symbol': TextStyle(color: Color(0xFF56B6C2)),
    'bullet': TextStyle(color: accent),
    'meta': TextStyle(color: Color(0xFF56B6C2)),
    'meta-keyword': TextStyle(color: accent, fontWeight: FontWeight.w600),

    // ── Emphasis ─────────────────────────────────────────────────────────────
    'emphasis': TextStyle(fontStyle: FontStyle.italic),
    'strong': TextStyle(fontWeight: FontWeight.w700),
    'deletion': TextStyle(color: Color(0xFFE06C75)),
    'addition': TextStyle(color: accent),
    'link': TextStyle(
      color: Color(0xFF61AFEF),
      decoration: TextDecoration.underline,
    ),
  };

  // ── Material ThemeData ────────────────────────────────────────────────────

  /// Builds a [ThemeData] consistent with the Vail brand tokens above.
  /// Called once from [VailApp] — never used directly in widgets.
  static ThemeData materialTheme() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          onPrimary: onAccent,
          secondary: accent,
          onSecondary: onAccent,
          surface: surface,
          onSurface: textPrimary,
          onSurfaceVariant: textSecondary,
          outline: border,
          outlineVariant: borderSubtle,
          error: error,
        ),
        dividerTheme: const DividerThemeData(
          color: border,
          thickness: 1,
          space: 1,
        ),
        iconTheme: const IconThemeData(
          color: textSecondary,
          size: 20,
        ),
      );
}
