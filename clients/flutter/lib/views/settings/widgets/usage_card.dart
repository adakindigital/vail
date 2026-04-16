import 'package:flutter/material.dart';
import 'package:vail_app/core/theme/vail_theme.dart';

class UsageCard extends StatelessWidget {
  final double percent;
  final int daysToReset;

  const UsageCard({
    this.percent = 0.84,
    this.daysToReset = 4,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(VailTheme.xl),
      decoration: BoxDecoration(
        color: VailTheme.surfaceContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(VailTheme.radiusLg),
        border: Border.all(color: VailTheme.ghostBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CURRENT USAGE',
                style: VailTheme.micro.copyWith(letterSpacing: 1.5, color: VailTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${(percent * 100).toInt()}% Capacity',
            style: VailTheme.heading.copyWith(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          // Progress Bar
          Stack(
            children: [
              Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(VailTheme.radiusFull),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percent,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: VailTheme.primary,
                    borderRadius: BorderRadius.circular(VailTheme.radiusFull),
                    boxShadow: [
                      BoxShadow(
                        color: VailTheme.primary.withValues(alpha: 0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              style: VailTheme.bodySmall.copyWith(fontSize: 12, color: VailTheme.onSurfaceVariant.withValues(alpha: 0.5)),
              children: [
                const TextSpan(text: 'Your tokens will reset in '),
                TextSpan(
                  text: '$daysToReset days.',
                  style: const TextStyle(color: VailTheme.primary, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
