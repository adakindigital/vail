import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class VailTheme {
  // Colors
  static const Color background = Color(0xFF051C10);
  static const Color primary = Color(0xFF21C45D);
  static const Color onPrimary = Color(0xFF051C10);
  static const Color primaryContainer = Color(0x1A21C45D);
  static const Color surfaceContainerLow = Color(0xFF0A2918);
  static const Color surfaceContainer = Color(0xFF0E331F);
  static const Color surfaceContainerHigh = Color(0xFF164028);
  static const Color surfaceContainerHighest = Color(0xFF1E4D34);
  static const Color ghostBorder = Color(0x0DFFFFFF);
  static const Color onSurface = Color(0xFFF1F5F9);
  static const Color onSurfaceVariant = Color(0xFFCBD5E1);
  static const Color textMuted = Color(0xFF4A6355);
  static const Color error = Color(0xFFFFB4AB);

  // Aliases for compatibility
  static const Color accent = primary;
  static const Color accentSubtle = primaryContainer;
  static const Color onAccent = onPrimary;
  static const Color border = ghostBorder;
  static const Color borderSubtle = ghostBorder;
  static const Color textPrimary = onSurface;
  static const Color textSecondary = onSurfaceVariant;
  static const Color surface = surfaceContainer;
  static const Color surfaceInput = surfaceContainerLow;

  // Spacing
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 40;

  // Radius
  static const double radiusSm = 12.0;
  static const double radiusMd = 16.0;
  static const double radiusLg = 24.0;
  static const double radiusXl = 32.0;
  static const double radiusFull = 9999.0;

  // Shadows
  static List<BoxShadow> primaryGlow = [
    BoxShadow(color: primary.withValues(alpha: 0.4), blurRadius: 20),
  ];

  static List<BoxShadow> aiCardGlow = [
    BoxShadow(color: primary.withValues(alpha: 0.15), blurRadius: 15),
  ];

  // Typography
  static TextStyle get display => GoogleFonts.manrope(fontSize: 30, fontWeight: FontWeight.w900, color: onSurface);
  static TextStyle get heading => GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: onSurface);
  static TextStyle get subheading => GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w600, color: onSurface);
  static TextStyle get body => GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w400, color: onSurface);
  static TextStyle get bodySmall => GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w400, color: onSurfaceVariant);
  static TextStyle get label => GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w600, color: onSurface);
  static TextStyle get caption => GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w700, color: onSurfaceVariant, letterSpacing: 1.2);
  static TextStyle get micro => GoogleFonts.manrope(fontSize: 9, fontWeight: FontWeight.w700, color: textMuted, letterSpacing: 1.5);

  // Typography Aliases
  static TextStyle get mono => micro;
  static TextStyle get sectionLabel => caption;
  static TextStyle get brandLabel => label;
  static TextStyle get sessionTitle => label.copyWith(fontSize: 14, fontWeight: FontWeight.w600);
  static TextStyle get inlineCode => GoogleFonts.jetBrainsMono(fontSize: 13, color: primary, backgroundColor: primaryContainer);

  static const Map<String, TextStyle> codeTheme = {
    'root': TextStyle(color: Color(0xFFF1F5F9), backgroundColor: Color(0xFF031109)),
    'keyword': TextStyle(color: Color(0xFF21C45D), fontWeight: FontWeight.w600),
    'string': TextStyle(color: Color(0xFFE5C07B)),
    'comment': TextStyle(color: Color(0xFF4A6355), fontStyle: FontStyle.italic),
  };

  static ThemeData materialTheme() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(primary: primary, onPrimary: onPrimary, surface: surfaceContainer, onSurface: onSurface),
      );
}
