import 'package:flutter/material.dart';
import 'package:vail_app/core/theme/vail_theme.dart';

/// Terminal-style modal dialog consistent with the Vail design language.
///
/// Use [showVailDialog] to display it. The dialog returns the [value] of the
/// tapped [VailDialogAction], or null if the user dismisses without acting.
///
/// Example — external link confirmation:
/// ```dart
/// final confirmed = await showVailDialog<bool>(
///   context: context,
///   title: 'EXTERNAL LINK',
///   body: Text('You are about to leave Vail.'),
///   actions: [
///     const VailDialogAction(label: 'CANCEL', value: false),
///     const VailDialogAction(label: 'PROCEED', value: true, isPrimary: true),
///   ],
/// );
/// if (confirmed == true) launchUrl(uri);
/// ```
class VailDialog<T> extends StatelessWidget {
  final String title;
  final Widget body;
  final List<VailDialogAction<T>> actions;

  const VailDialog({
    required this.title,
    required this.body,
    required this.actions,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: VailTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VailTheme.radiusMd),
        side: const BorderSide(color: VailTheme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DialogHeader(title: title),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              VailTheme.lg, VailTheme.lg, VailTheme.lg, VailTheme.md,
            ),
            child: body,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              VailTheme.lg, 0, VailTheme.lg, VailTheme.lg,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (int i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: VailTheme.sm),
                  _DialogActionButton<T>(action: actions[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _DialogHeader extends StatelessWidget {
  final String title;

  const _DialogHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VailTheme.lg,
        vertical: VailTheme.md,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: VailTheme.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: VailTheme.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: VailTheme.sm),
          Text(
            title,
            style: VailTheme.mono.copyWith(
              color: VailTheme.textPrimary,
              fontSize: 11,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────

class _DialogActionButton<T> extends StatelessWidget {
  final VailDialogAction<T> action;

  const _DialogActionButton({required this.action});

  Color get _borderColor {
    if (action.isDestructive) return VailTheme.error;
    if (action.isPrimary) return VailTheme.accent;
    return VailTheme.border;
  }

  Color get _textColor {
    if (action.isDestructive) return VailTheme.error;
    if (action.isPrimary) return VailTheme.accent;
    return VailTheme.textSecondary;
  }

  Color get _bgColor {
    if (action.isPrimary) return VailTheme.accentSubtle;
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(action.value),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: VailTheme.lg,
          vertical: VailTheme.sm,
        ),
        decoration: BoxDecoration(
          color: _bgColor,
          border: Border.all(color: _borderColor),
          borderRadius: BorderRadius.circular(VailTheme.radiusSm),
        ),
        child: Text(
          action.label,
          style: VailTheme.mono.copyWith(
            color: _textColor,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

// ── Action descriptor ─────────────────────────────────────────────────────────

/// Describes a single button in a [VailDialog].
class VailDialogAction<T> {
  final String label;
  final T value;

  /// Renders with accent colour and background — use for the confirm action.
  final bool isPrimary;

  /// Renders with error colour — use for delete/destructive actions.
  final bool isDestructive;

  const VailDialogAction({
    required this.label,
    required this.value,
    this.isPrimary = false,
    this.isDestructive = false,
  });
}

// ── Helper ────────────────────────────────────────────────────────────────────

/// Shows a [VailDialog] and returns the tapped action value, or null on dismiss.
Future<T?> showVailDialog<T>({
  required BuildContext context,
  required String title,
  required Widget body,
  required List<VailDialogAction<T>> actions,
}) {
  return showDialog<T>(
    context: context,
    builder: (_) => VailDialog<T>(
      title: title,
      body: body,
      actions: actions,
    ),
  );
}
