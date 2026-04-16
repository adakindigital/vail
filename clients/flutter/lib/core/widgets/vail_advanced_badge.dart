import 'package:flutter/material.dart';
import 'package:vail_app/core/theme/vail_theme.dart';

/// Polished VAIL ADVANCED AI branded badge.
/// Used in the desktop top bar and empty states.
class VailAdvancedBadge extends StatelessWidget {
  const VailAdvancedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VailTheme.md,
        vertical: VailTheme.xs + 2,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: VailTheme.ghostBorder),
        borderRadius: BorderRadius.circular(VailTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_rounded,
              color: VailTheme.primary, size: 14),
          const SizedBox(width: VailTheme.xs + 2),
          Text(
            'VAIL ADVANCED AI',
            style: VailTheme.mono.copyWith(
              color: VailTheme.primary,
              fontSize: 9,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
