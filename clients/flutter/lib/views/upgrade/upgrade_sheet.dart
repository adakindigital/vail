import 'package:flutter/material.dart';
import 'package:vail_app/core/theme/vail_theme.dart';

/// Vail upgrade paywall — shown when a user selects a Pro/Max tier
/// or taps the Upgrade Plan button in the sidebar.
///
/// [onProActivated] is called immediately when the user taps the upgrade
/// button. The caller is responsible for persisting the pro state and
/// rebuilding affected views.
///
// TODO(prod): remove [onProActivated] bypass — replace with PayFast payment
//             confirmation callback. Pro flag must be set server-side after
//             successful payment, not client-side.
Future<void> showUpgradeSheet(
  BuildContext context, {
  VoidCallback? onProActivated,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    builder: (_) => _UpgradeDialog(onProActivated: onProActivated),
  );
}

// ── Dialog ────────────────────────────────────────────────────────────────────

class _UpgradeDialog extends StatelessWidget {
  // TODO(prod): remove — dev-only bypass (see showUpgradeSheet comment)
  final VoidCallback? onProActivated;

  const _UpgradeDialog({this.onProActivated});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.of(context).size.height - 80,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: VailTheme.surfaceContainer,
            borderRadius: BorderRadius.circular(VailTheme.radiusXl),
            border: Border.all(color: VailTheme.ghostBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 40,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(VailTheme.radiusXl),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _UpgradeHeader(),
                  const _PlanCard(),
                  const _FeatureList(),
                  _UpgradeFooter(onProActivated: onProActivated),
                ],
              ),
            ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        VailTheme.xl, VailTheme.xl, VailTheme.xl, VailTheme.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: VailTheme.sm,
                  vertical: VailTheme.xs,
                ),
                decoration: BoxDecoration(
                  color: VailTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(VailTheme.radiusSm),
                  border: Border.all(
                    color: VailTheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'PRO',
                  style: VailTheme.caption.copyWith(
                    color: VailTheme.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(VailTheme.xs + 2),
                  decoration: const BoxDecoration(
                    color: VailTheme.ghostBorder,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: VailTheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: VailTheme.md),
          Text('Upgrade to Vail Pro', style: VailTheme.heading),
          const SizedBox(height: VailTheme.sm),
          Text(
            'Access advanced models, extended context, and priority routing — built for complex, real-world work.',
            style: VailTheme.bodySmall.copyWith(
              color: VailTheme.onSurfaceVariant,
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
      padding: const EdgeInsets.fromLTRB(VailTheme.xl, 0, VailTheme.xl, 0),
      child: Container(
        padding: const EdgeInsets.all(VailTheme.lg),
        decoration: BoxDecoration(
          color: VailTheme.primaryContainer,
          borderRadius: BorderRadius.circular(VailTheme.radiusMd),
          border: Border.all(
            color: VailTheme.primary.withValues(alpha: 0.25),
          ),
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
                    style: VailTheme.caption.copyWith(
                      color: VailTheme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: VailTheme.xs),
                  Text(
                    'Monthly subscription',
                    style: VailTheme.bodySmall.copyWith(
                      color: VailTheme.onSurfaceVariant,
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
                  style: VailTheme.display.copyWith(
                    color: VailTheme.primary,
                    fontSize: 28,
                    height: 1,
                  ),
                ),
                Text(
                  'per month',
                  style: VailTheme.caption.copyWith(
                    color: VailTheme.onSurfaceVariant,
                    fontSize: 9,
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
      title: 'Vail Core + Pro models',
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
      title: 'Vail Max — maximum capability',
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
    const soonColor = Color(0xFF4A6355);
    final isComingSoon = feature.comingSoon;

    return Padding(
      padding: const EdgeInsets.only(bottom: VailTheme.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: isComingSoon
                    ? Colors.transparent
                    : VailTheme.primaryContainer,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isComingSoon
                      ? soonColor
                      : VailTheme.primary.withValues(alpha: 0.4),
                ),
              ),
              child: Icon(
                isComingSoon ? Icons.schedule_rounded : Icons.check_rounded,
                color: isComingSoon ? soonColor : VailTheme.primary,
                size: 11,
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
                    Expanded(
                      child: Text(
                        feature.title,
                        style: VailTheme.label.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: isComingSoon
                              ? VailTheme.onSurfaceVariant
                              : VailTheme.onSurface,
                        ),
                      ),
                    ),
                    if (isComingSoon)
                      Container(
                        margin: const EdgeInsets.only(left: VailTheme.sm),
                        padding: const EdgeInsets.symmetric(
                          horizontal: VailTheme.xs + 1,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: soonColor),
                          borderRadius:
                              BorderRadius.circular(VailTheme.radiusSm),
                        ),
                        child: Text(
                          'SOON',
                          style: VailTheme.caption.copyWith(
                            color: soonColor,
                            fontSize: 7,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  feature.detail,
                  style: VailTheme.bodySmall.copyWith(
                    color: isComingSoon
                        ? VailTheme.textMuted
                        : VailTheme.onSurfaceVariant,
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
  // TODO(prod): remove — dev-only bypass (see showUpgradeSheet comment)
  final VoidCallback? onProActivated;

  const _UpgradeFooter({this.onProActivated});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(VailTheme.xl),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              // TODO(prod): replace with PayFast payment confirmation.
              //             For now this immediately grants pro access — dev bypass only.
              onProActivated?.call();
              Navigator.of(context).pop();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: VailTheme.md + 2),
              decoration: BoxDecoration(
                color: VailTheme.primary,
                borderRadius: BorderRadius.circular(VailTheme.radiusFull),
                boxShadow: VailTheme.primaryGlow,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    color: VailTheme.onPrimary,
                    size: 18,
                  ),
                  const SizedBox(width: VailTheme.sm),
                  Text(
                    'Get Pro  —  R149/month',
                    style: VailTheme.label.copyWith(
                      color: VailTheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: VailTheme.md),
          Text(
            'Cancel anytime. Billed monthly. Secured by PayFast.',
            style: VailTheme.caption.copyWith(
              color: VailTheme.textMuted,
              fontSize: 9,
            ),
          ),
          const SizedBox(height: VailTheme.md),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Text(
              'Maybe later',
              style: VailTheme.bodySmall.copyWith(
                color: VailTheme.onSurfaceVariant,
                decoration: TextDecoration.underline,
                decorationColor: VailTheme.ghostBorder,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
