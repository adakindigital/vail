import 'package:flutter/material.dart';
import 'package:vail_app/core/theme/vail_theme.dart';
import 'package:vail_app/data/models/api/chat/ui_component.dart';

/// Renders dynamic UI components emitted by the model.
///
/// Supported field types: text, textarea, dropdown.
/// When the user taps an action, [onAction] is called with the button payload
/// and a map of all collected form values keyed by [UIField.key].
class DynamicComponentRenderer extends StatefulWidget {
  final UIComponent component;
  final void Function(String payload, Map<String, String> formData)? onAction;

  /// When true, the form renders in its submitted state immediately — driven
  /// from [ConversationMessage.formSubmitted] so the state survives rebuilds.
  final bool isSubmitted;

  const DynamicComponentRenderer({
    required this.component,
    this.onAction,
    this.isSubmitted = false,
    super.key,
  });

  @override
  State<DynamicComponentRenderer> createState() =>
      _DynamicComponentRendererState();
}

class _DynamicComponentRendererState extends State<DynamicComponentRenderer> {
  // Controllers are created lazily so the widget is safe even when the
  // parent rebuilds with a new UIComponent mid-stream (different field keys).
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _selections = {};
  bool _submitted = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Returns (or lazily creates) the controller for a text/textarea field.
  TextEditingController _controllerFor(String key) =>
      _controllers.putIfAbsent(key, () => TextEditingController());

  /// Returns the current selection for a dropdown, defaulting to the first option.
  String _selectionFor(UIField field) =>
      _selections[field.key] ??
      (field.options.isNotEmpty ? field.options.first : '');

  Map<String, String> get _formData {
    final data = <String, String>{};
    for (final field in widget.component.inputFields) {
      if (field.fieldType == 'dropdown') {
        data[field.key] = _selectionFor(field);
      } else {
        data[field.key] = _controllers[field.key]?.text ?? '';
      }
    }
    return data;
  }

  void _handleAction(UIAction action) {
    setState(() => _submitted = true);
    widget.onAction?.call(action.payload, _formData);
  }

  @override
  Widget build(BuildContext context) {
    final component = widget.component;

    if (component.type == 'status') {
      return Padding(
        padding: const EdgeInsets.only(top: VailTheme.md),
        child: Row(
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(VailTheme.primary),
              ),
            ),
            const SizedBox(width: VailTheme.sm),
            Text(
              component.description ?? 'Processing...',
              style: VailTheme.caption.copyWith(
                color: VailTheme.textMuted,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    if (_submitted || widget.isSubmitted) {
      return _SubmittedBanner(
        actionLabel: component.actions
            .firstWhere(
              (a) => a.isPrimary,
              orElse: () =>
                  component.actions.isNotEmpty ? component.actions.first : const UIAction(label: '', payload: ''),
            )
            .label,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: VailTheme.md),
      child: Container(
        padding: const EdgeInsets.all(VailTheme.md),
        decoration: BoxDecoration(
          color: VailTheme.primaryContainer.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(VailTheme.radiusMd),
          border: Border.all(
            color: VailTheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (component.title != null) ...[
              Text(
                component.title!.toUpperCase(),
                style: VailTheme.micro.copyWith(
                  color: VailTheme.primary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: VailTheme.xs),
            ],
            if (component.description != null) ...[
              Text(
                component.description!,
                style: VailTheme.bodySmall.copyWith(height: 1.5),
              ),
              const SizedBox(height: VailTheme.md),
            ],
            if (component.inputFields.isNotEmpty) ...[
              ...component.inputFields.map((field) => Padding(
                    padding: const EdgeInsets.only(bottom: VailTheme.md),
                    child: _buildField(field),
                  )),
            ],
            if (component.actions.isNotEmpty)
              Wrap(
                spacing: VailTheme.sm,
                runSpacing: VailTheme.sm,
                children: component.actions
                    .map((a) => _ActionButton(
                          action: a,
                          onTap: () => _handleAction(a),
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(UIField field) {
    return switch (field.fieldType) {
      'dropdown' => _DropdownField(
          field: field,
          selected: _selectionFor(field),
          onChanged: (v) => setState(() => _selections[field.key] = v),
        ),
      'textarea' => _TextField(
          field: field,
          controller: _controllerFor(field.key),
          maxLines: 3,
        ),
      _ => _TextField(
          field: field,
          controller: _controllerFor(field.key),
          maxLines: 1,
        ),
    };
  }
}

// ── Submitted state ────────────────────────────────────────────────────────

class _SubmittedBanner extends StatelessWidget {
  final String actionLabel;
  const _SubmittedBanner({required this.actionLabel});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: VailTheme.md),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 13,
              color: VailTheme.primary,
            ),
            const SizedBox(width: VailTheme.xs),
            Text(
              actionLabel.isNotEmpty ? actionLabel : 'Submitted',
              style: VailTheme.caption.copyWith(
                color: VailTheme.textMuted,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
}

// ── Field widgets ──────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: VailTheme.xs),
        child: Text(
          label,
          style: VailTheme.label.copyWith(
            color: VailTheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      );
}

final _inputBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(VailTheme.radiusSm),
  borderSide: const BorderSide(color: VailTheme.ghostBorder),
);

final _focusedBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(VailTheme.radiusSm),
  borderSide: BorderSide(color: VailTheme.primary.withValues(alpha: 0.5)),
);

class _TextField extends StatelessWidget {
  final UIField field;
  final TextEditingController controller;
  final int maxLines;

  const _TextField({
    required this.field,
    required this.controller,
    required this.maxLines,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(field.label),
          TextField(
            controller: controller,
            maxLines: maxLines,
            style: VailTheme.body,
            decoration: InputDecoration(
              hintText: field.placeholder,
              hintStyle: VailTheme.body.copyWith(color: VailTheme.textMuted),
              filled: true,
              fillColor: VailTheme.surfaceContainerLow,
              border: _inputBorder,
              enabledBorder: _inputBorder,
              focusedBorder: _focusedBorder,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: VailTheme.md,
                vertical: VailTheme.sm + 2,
              ),
              isDense: true,
            ),
          ),
        ],
      );
}

class _DropdownField extends StatelessWidget {
  final UIField field;
  final String selected;
  final ValueChanged<String> onChanged;

  const _DropdownField({
    required this.field,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(field.label),
          GestureDetector(
            onTap: () => _openPicker(context),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: VailTheme.md,
                vertical: VailTheme.sm + 2,
              ),
              decoration: BoxDecoration(
                color: VailTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(VailTheme.radiusSm),
                border: Border.all(color: VailTheme.ghostBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selected.isNotEmpty ? selected : 'Select…',
                      style: VailTheme.body,
                    ),
                  ),
                  const Icon(
                    Icons.expand_more_rounded,
                    size: 16,
                    color: VailTheme.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ],
      );

  void _openPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: VailTheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(VailTheme.radiusMd),
        ),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                VailTheme.lg, VailTheme.lg, VailTheme.lg, VailTheme.sm,
              ),
              child: Text(
                field.label.toUpperCase(),
                style: VailTheme.micro.copyWith(letterSpacing: 1.5),
              ),
            ),
            const Divider(height: 1, color: VailTheme.ghostBorder),
            ...field.options.map(
              (opt) => ListTile(
                dense: true,
                title: Text(opt, style: VailTheme.body),
                trailing: selected == opt
                    ? const Icon(Icons.check_rounded,
                        size: 16, color: VailTheme.primary)
                    : null,
                onTap: () {
                  onChanged(opt);
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: VailTheme.sm),
          ],
        ),
      ),
    );
  }
}

// ── Action button ──────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final UIAction action;
  final VoidCallback onTap;

  const _ActionButton({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: VailTheme.md,
            vertical: VailTheme.sm,
          ),
          decoration: BoxDecoration(
            color: action.isPrimary ? VailTheme.primary : Colors.transparent,
            border: Border.all(
              color: VailTheme.primary.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(VailTheme.radiusSm),
          ),
          child: Text(
            action.label,
            style: VailTheme.label.copyWith(
              color:
                  action.isPrimary ? VailTheme.onPrimary : VailTheme.primary,
              fontSize: 11,
            ),
          ),
        ),
      );
}
