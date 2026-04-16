import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:vail_app/core/theme/vail_theme.dart';

/// A reusable glassmorphic container with backdrop blur and border.
/// 
/// Used for cards, headers, and sheets in the Forest Sanctuary design system.
class VailGlass extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color? color;
  final BorderRadius? borderRadius;
  final Border? border;
  final EdgeInsetsGeometry? padding;
  final List<BoxShadow>? boxShadow;

  const VailGlass({
    required this.child,
    this.blur = 20,
    this.opacity = 0.8,
    this.color,
    this.borderRadius,
    this.border,
    this.padding,
    this.boxShadow,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(VailTheme.radiusMd),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (color ?? VailTheme.surfaceContainerLow).withValues(alpha: opacity),
            borderRadius: borderRadius ?? BorderRadius.circular(VailTheme.radiusMd),
            border: border ?? Border.all(color: VailTheme.ghostBorder),
            boxShadow: boxShadow,
          ),
          child: child,
        ),
      ),
    );
  }
}
