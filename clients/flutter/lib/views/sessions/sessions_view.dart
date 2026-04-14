import 'package:flutter/material.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:vail_app/views/sessions/sessions_view.desktop.dart';
import 'package:vail_app/views/sessions/sessions_view.mobile.dart';

/// Entry point for the sessions (history) feature.
///
/// Thin [ScreenTypeLayout.builder] wrapper — all UI concerns are in:
///   [SessionsViewMobile]  — lib/views/sessions/sessions_view.mobile.dart
///   [SessionsViewDesktop] — lib/views/sessions/sessions_view.desktop.dart
class SessionsView extends StatelessWidget {
  final void Function(int) onSwitchTab;

  const SessionsView({required this.onSwitchTab, super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenTypeLayout.builder(
      mobile: (ctx) => SessionsViewMobile(onSwitchTab: onSwitchTab),
      desktop: (ctx) => SessionsViewDesktop(onSwitchTab: onSwitchTab),
    );
  }
}
