import 'package:flutter/material.dart';
import 'package:vail_app/core/theme/vail_theme.dart';

/// Reusable button variants for the Vail design language.
///
/// All variants share the same mono-font label style and border-radius.
/// Disabled state is applied automatically when [onTap] is null.
///
/// Variants:
/// - [VailButton.primary] — accent border, accent text, subtle accent background
/// - [VailButton.ghost]   — muted border, secondary text, transparent background
/// - [VailButton.destructive] — error border, error text
///
/// Usage:
/// ```dart
/// VailButton.primary(label: 'NEW CHAT', onTap: _startNewSession)
/// VailButton.ghost(label: 'CANCEL', onTap: () => Navigator.pop(context))
/// VailButton.destructive(label: 'DELETE', onTap: _deleteSession)
/// ```
class VailButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final _VailButtonVariant _variant;

  const VailButton.primary({
    required this.label,
    required this.onTap,
    this.leadingIcon,
    this.trailingIcon,
    super.key,
  }) : _variant = _VailButtonVariant.primary;

  const VailButton.ghost({
    required this.label,
    required this.onTap,
    this.leadingIcon,
    this.trailingIcon,
    super.key,
  }) : _variant = _VailButtonVariant.ghost;

  const VailButton.destructive({
    required this.label,
    required this.onTap,
    this.leadingIcon,
    this.trailingIcon,
    super.key,
  }) : _variant = _VailButtonVariant.destructive;

  bool get _isEnabled => onTap != null;

  Color get _activeBorderColor => switch (_variant) {
        _VailButtonVariant.primary => VailTheme.accent,
        _VailButtonVariant.ghost => VailTheme.border,
        _VailButtonVariant.destructive => VailTheme.error,
      };

  Color get _activeTextColor => switch (_variant) {
        _VailButtonVariant.primary => VailTheme.accent,
        _VailButtonVariant.ghost => VailTheme.textSecondary,
        _VailButtonVariant.destructive => VailTheme.error,
      };

  Color get _activeBgColor => switch (_variant) {
        _VailButtonVariant.primary => VailTheme.accentSubtle,
        _VailButtonVariant.ghost => Colors.transparent,
        _VailButtonVariant.destructive => const Color(0xFF200808),
      };

  @override
  Widget build(BuildContext context) {
    final textColor = _isEnabled ? _activeTextColor : VailTheme.textMuted;
    final borderColor = _isEnabled ? _activeBorderColor : VailTheme.border;
    final bgColor = _isEnabled ? _activeBgColor : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: VailTheme.lg,
          vertical: VailTheme.sm + 2,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(VailTheme.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, color: textColor, size: 14),
              const SizedBox(width: VailTheme.xs),
            ],
            Text(
              label,
              style: VailTheme.mono.copyWith(
                color: textColor,
                letterSpacing: 1.5,
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: VailTheme.xs),
              Icon(trailingIcon, color: textColor, size: 14),
            ],
          ],
        ),
      ),
    );
  }
}

enum _VailButtonVariant { primary, ghost, destructive }
