import 'package:flutter/material.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:vail_app/views/settings/settings_view.desktop.dart';
import 'package:vail_app/views/settings/settings_view.mobile.dart';

/// Entry point for the settings feature.
///
/// Thin [ScreenTypeLayout.builder] wrapper — all UI concerns are in:
///   [SettingsViewMobile]  — lib/views/settings/settings_view.mobile.dart
///   [SettingsViewDesktop] — lib/views/settings/settings_view.desktop.dart
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenTypeLayout.builder(
      mobile: (ctx) => const SettingsViewMobile(),
      desktop: (ctx) => const SettingsViewDesktop(),
    );
  }
}
