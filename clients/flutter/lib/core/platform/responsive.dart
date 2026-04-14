import 'package:flutter/widgets.dart';
import 'package:responsive_builder/responsive_builder.dart';

/// Vail responsive layout utilities.
///
/// Wraps [responsive_builder] so the rest of the codebase never imports
/// it directly. To change breakpoints or swap the library, update this file.
///
/// Usage — in build methods:
/// ```dart
/// if (Responsive.isDesktop(context)) { ... }
/// ```
///
/// Usage — as a layout switcher:
/// ```dart
/// ScreenTypeLayout.builder(
///   mobile:  (_) => const MyViewMobile(),
///   desktop: (_) => const MyViewDesktop(),
/// )
/// ```
abstract final class Responsive {
  /// Returns true when the current screen width is in the desktop range.
  /// Uses [responsive_builder]'s breakpoints (>= 950px by default).
  static bool isDesktop(BuildContext context) {
    return getDeviceType(MediaQuery.sizeOf(context)) == DeviceScreenType.desktop;
  }

  /// Returns true when rendering on a mobile-sized screen.
  static bool isMobile(BuildContext context) {
    return getDeviceType(MediaQuery.sizeOf(context)) == DeviceScreenType.mobile;
  }
}
