import 'package:flutter/material.dart';
import 'package:vail_app/core/theme/vail_theme.dart';

/// Small error banner that appears at the top of the chat or document stack.
/// Used when a non-fatal (turn-level) error occurs.
class VailErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;

  const VailErrorBanner({
    required this.message,
    this.onDismiss,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: VailTheme.lg,
        vertical: VailTheme.sm,
      ),
      color: VailTheme.error.withValues(alpha: 0.12),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: VailTheme.error, size: 16),
          const SizedBox(width: VailTheme.sm),
          Expanded(
            child: Text(
              message,
              style: VailTheme.bodySmall.copyWith(color: VailTheme.error),
            ),
          ),
          if (onDismiss != null)
            GestureDetector(
              onTap: onDismiss,
              child: const Icon(Icons.close_rounded,
                  color: VailTheme.error, size: 16),
            ),
        ],
      ),
    );
  }
}
