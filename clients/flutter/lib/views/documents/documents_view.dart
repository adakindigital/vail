import 'package:flutter/material.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:vail_app/views/documents/documents_view.desktop.dart';
import 'package:vail_app/views/documents/documents_view.mobile.dart';

/// Entry point for the documents feature.
///
/// Thin [ScreenTypeLayout.builder] wrapper — all UI concerns are in:
///   [DocumentsViewMobile]  — lib/views/documents/documents_view.mobile.dart
///   [DocumentsViewDesktop] — lib/views/documents/documents_view.desktop.dart
class DocumentsView extends StatelessWidget {
  const DocumentsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenTypeLayout.builder(
      mobile: (ctx) => const DocumentsViewMobile(),
      desktop: (ctx) => const DocumentsViewDesktop(),
    );
  }
}
