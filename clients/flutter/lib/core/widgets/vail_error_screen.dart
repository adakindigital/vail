import 'package:flutter/material.dart';
import 'package:vail_app/core/theme/vail_theme.dart';
import 'package:vail_app/core/widgets/vail_button.dart';

class VailErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const VailErrorScreen({required this.message, required this.onRetry, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VailTheme.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(VailTheme.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(color: VailTheme.error.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.signal_wifi_off_rounded, color: VailTheme.error, size: 32),
              ),
              const SizedBox(height: VailTheme.xl),
              Text('SIGNAL INTERRUPTED', style: VailTheme.heading.copyWith(color: VailTheme.error)),
              const SizedBox(height: VailTheme.md),
              Text(message, textAlign: TextAlign.center, style: VailTheme.bodySmall),
              const SizedBox(height: VailTheme.xxl),
              VailButton.primary(label: 'RETRY CONNECTION', onTap: onRetry),
            ],
          ),
        ),
      ),
    );
  }
}
