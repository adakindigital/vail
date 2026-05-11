/// An input field definition inside a dynamic UI form.
///
/// Each field maps to a native Flutter widget — text input, textarea, or
/// dropdown. The [key] is used to collect submitted values.
class UIField {
  final String key;
  final String label;

  /// 'text' | 'textarea' | 'dropdown'
  final String fieldType;
  final String? placeholder;

  /// Options for dropdown fields. Empty for text/textarea.
  final List<String> options;

  const UIField({
    required this.key,
    required this.label,
    required this.fieldType,
    this.placeholder,
    this.options = const [],
  });

  factory UIField.fromJson(Map<String, dynamic> json) => UIField(
        key: json['key'] as String? ?? '',
        label: json['label'] as String? ?? '',
        fieldType: json['type'] as String? ?? 'text',
        placeholder: json['placeholder'] as String?,
        options: (json['options'] as List<dynamic>?)?.cast<String>() ?? [],
      );
}

/// A dynamic UI component produced by the model to gather extra context.
///
/// The gateway strips `<vail_ui>...</vail_ui>` blocks from the stream and
/// delivers them here as structured data. The Flutter client inflates them
/// into native widgets via [DynamicComponentRenderer].
class UIComponent {
  final String type;
  final String? title;
  final String? description;
  final List<UIField> inputFields;
  final List<UIAction> actions;

  const UIComponent({
    required this.type,
    this.title,
    this.description,
    this.inputFields = const [],
    this.actions = const [],
  });

  factory UIComponent.fromJson(Map<String, dynamic> json) {
    final fieldsRaw = json['fields'];
    final inputFields = fieldsRaw is List
        ? fieldsRaw
            .map((f) => UIField.fromJson(f as Map<String, dynamic>))
            .toList()
        : <UIField>[];

    final actionsRaw = json['actions'] as List<dynamic>?;
    return UIComponent(
      type: json['ui_type'] as String? ?? 'unknown',
      title: json['title'] as String?,
      description: json['description'] as String?,
      inputFields: inputFields,
      actions: actionsRaw
              ?.map((a) => UIAction.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'ui_type': type,
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        'fields': inputFields
            .map((f) => {
                  'key': f.key,
                  'label': f.label,
                  'type': f.fieldType,
                  if (f.placeholder != null) 'placeholder': f.placeholder,
                  if (f.options.isNotEmpty) 'options': f.options,
                })
            .toList(),
        'actions': actions.map((a) => a.toJson()).toList(),
      };
}

class UIAction {
  final String label;
  final String payload;
  final bool isPrimary;

  const UIAction({
    required this.label,
    required this.payload,
    this.isPrimary = false,
  });

  factory UIAction.fromJson(Map<String, dynamic> json) => UIAction(
        label: json['label'] as String? ?? 'Confirm',
        payload: json['payload'] as String? ?? '',
        isPrimary: json['is_primary'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'label': label,
        'payload': payload,
        'is_primary': isPrimary,
      };
}
