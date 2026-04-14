import 'package:flutter/material.dart';
import 'package:vail_app/core/theme/vail_theme.dart';

/// Shows the Vail Pro upgrade paywall.
///
/// Works on both mobile and desktop — renders as a centred dialog card.
/// Replace the [_SubscribeButton] TODO with PayFast integration when ready.
Future<void> showUpgradeSheet(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (_) => const _UpgradeDialog(),
  );
}

// ── Dialog ────────────────────────────────────────────────────────────────────

class _UpgradeDialog extends StatelessWidget {
  const _UpgradeDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 40,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          decoration: BoxDecoration(
            color: VailTheme.surface,
            border: Border.all(color: VailTheme.border),
            borderRadius: BorderRadius.circular(VailTheme.radiusLg),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _UpgradeHeader(),
              const _PlanCard(),
              const _FeatureList(),
              const _UpgradeFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _UpgradeHeader extends StatelessWidget {
  const _UpgradeHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        VailTheme.xl, VailTheme.xl, VailTheme.xl, VailTheme.lg,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: VailTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Pro badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: VailTheme.sm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5C07B).withValues(alpha: 0.1),
                  border: Border.all(
                    color: const Color(0xFFE5C07B).withValues(alpha: 0.5),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'PRO',
                  style: VailTheme.mono.copyWith(
                    color: const Color(0xFFE5C07B),
                    fontSize: 9,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: VailTheme.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: VailTheme.md),
          Text(
            'Upgrade to Vail Pro',
            style: VailTheme.heading.copyWith(fontSize: 22),
          ),
          const SizedBox(height: VailTheme.sm),
          Text(
            'Access advanced models, extended context, and priority routing — '
            'built for complex, real-world work.',
            style: VailTheme.bodySmall.copyWith(
              color: VailTheme.textSecondary,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Plan card ─────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        VailTheme.xl, VailTheme.lg, VailTheme.xl, 0,
      ),
      child: Container(
        padding: const EdgeInsets.all(VailTheme.lg),
        decoration: BoxDecoration(
          color: VailTheme.accentSubtle,
          border: Border.all(color: VailTheme.accent.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(VailTheme.radiusMd),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VAIL PRO',
                    style: VailTheme.mono.copyWith(
                      color: VailTheme.accent,
                      fontSize: 11,
                      letterSpacing: 2.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: VailTheme.xs),
                  Text(
                    'Monthly subscription',
                    style: VailTheme.bodySmall.copyWith(
                      color: VailTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'R149',
                  style: VailTheme.heading.copyWith(
                    color: VailTheme.accent,
                    fontSize: 28,
                    height: 1,
                  ),
                ),
                Text(
                  'per month',
                  style: VailTheme.mono.copyWith(
                    color: VailTheme.textSecondary,
                    fontSize: 9,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Feature list ──────────────────────────────────────────────────────────────

class _FeatureList extends StatelessWidget {
  const _FeatureList();

  static const _features = [
    (
      title: 'VAIL.CORE + VAIL.PRO models',
      detail: 'More capable models with deeper reasoning and extended context.',
      comingSoon: false,
    ),
    (
      title: 'Priority routing',
      detail: 'Your requests skip the queue during peak load.',
      comingSoon: false,
    ),
    (
      title: 'Extended context window',
      detail: 'Maintain longer conversations without losing thread.',
      comingSoon: false,
    ),
    (
      title: 'Advanced multi-step reasoning',
      detail: 'Better performance on complex, multi-part tasks.',
      comingSoon: false,
    ),
    (
      title: 'VAIL.MAX — maximum capability',
      detail: 'Our most powerful model tier. Launching soon for Pro members.',
      comingSoon: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        VailTheme.xl, VailTheme.lg, VailTheme.xl, 0,
      ),
      child: Column(
        children: _features.map((f) => _FeatureRow(f)).toList(),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final ({String title, String detail, bool comingSoon}) feature;

  const _FeatureRow(this.feature);

  @override
  Widget build(BuildContext context) {
    const soonColor = Color(0xFF4A4A4A);
    final isComingSoon = feature.comingSoon;

    return Padding(
      padding: const EdgeInsets.only(bottom: VailTheme.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: isComingSoon ? Colors.transparent : VailTheme.accentSubtle,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isComingSoon
                      ? soonColor
                      : VailTheme.accent.withValues(alpha: 0.4),
                ),
              ),
              child: Icon(
                isComingSoon ? Icons.schedule_rounded : Icons.check_rounded,
                color: isComingSoon ? soonColor : VailTheme.accent,
                size: 10,
              ),
            ),
          ),
          const SizedBox(width: VailTheme.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      feature.title,
                      style: VailTheme.body.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isComingSoon
                            ? VailTheme.textSecondary
                            : VailTheme.textPrimary,
                      ),
                    ),
                    if (isComingSoon) ...[
                      const SizedBox(width: VailTheme.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: VailTheme.xs + 1,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: soonColor),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          'COMING SOON',
                          style: VailTheme.mono.copyWith(
                            color: soonColor,
                            fontSize: 7,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  feature.detail,
                  style: VailTheme.bodySmall.copyWith(
                    color: isComingSoon
                        ? VailTheme.textMuted
                        : VailTheme.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Footer + CTA ──────────────────────────────────────────────────────────────

class _UpgradeFooter extends StatelessWidget {
  const _UpgradeFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(VailTheme.xl),
      child: Column(
        children: [
          // Subscribe CTA
          GestureDetector(
            onTap: () {
              // TODO: initiate PayFast payment flow
              Navigator.of(context).pop();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: VailTheme.md + 2),
              decoration: BoxDecoration(
                color: VailTheme.accent,
                borderRadius: BorderRadius.circular(VailTheme.radiusMd),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    color: VailTheme.onAccent,
                    size: 16,
                  ),
                  const SizedBox(width: VailTheme.sm),
                  Text(
                    'GET PRO  —  R149/MONTH',
                    style: VailTheme.mono.copyWith(
                      color: VailTheme.onAccent,
                      fontSize: 11,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: VailTheme.md),
          // Fine print
          Text(
            'Cancel anytime. Billed monthly. Secured by PayFast.',
            style: VailTheme.mono.copyWith(
              color: VailTheme.textMuted,
              fontSize: 8,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: VailTheme.md),
          // Maybe later
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Text(
              'Maybe later',
              style: VailTheme.bodySmall.copyWith(
                color: VailTheme.textSecondary,
                decoration: TextDecoration.underline,
                decorationColor: VailTheme.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
