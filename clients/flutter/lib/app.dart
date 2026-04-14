import 'package:flutter/material.dart';
import 'package:vail_app/core/theme/vail_theme.dart';
import 'package:vail_app/views/shell/app_shell.dart';

class VailApp extends StatelessWidget {
  const VailApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vail',
      debugShowCheckedModeBanner: false,
      theme: VailTheme.materialTheme(),
      home: const AppShell(),
    );
  }
}
