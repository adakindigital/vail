import 'dart:typed_data';
import 'package:vail_app/data/models/api/chat/ui_component.dart';

/// UI-layer representation of a single message in the chat view.
class ConversationMessage {
  final String role;
  final String content;
  final bool isStreaming;
  final DateTime timestamp;

  /// Raw bytes of an attached image, if any.
  final Uint8List? imageBytes;

  /// The model tier that produced this message. Only set on assistant messages.
  final String? model;

  /// Dynamic UI components to render inside the message bubble.
  final List<UIComponent> uiComponents;

  /// True once the user has submitted the form attached to this assistant
  /// message. Drives DynamicComponentRenderer into its submitted state.
  /// Persisted here (not in widget state) so it survives ListView rebuilds.
  final bool formSubmitted;

  /// When set on a user message, it renders as a form-context summary card
  /// instead of a plain text bubble. Keys are field labels, values are what
  /// the user entered. Null means normal text bubble.
  ///
  /// Pass an empty map for a "skipped" card with no field rows.
  final Map<String, String>? formContext;

  const ConversationMessage({
    required this.role,
    required this.content,
    this.isStreaming = false,
    required this.timestamp,
    this.imageBytes,
    this.model,
    this.uiComponents = const [],
    this.formSubmitted = false,
    this.formContext,
  });

  bool get isFromUser => role == 'user';
  bool get isFromAssistant => role == 'assistant';

  ConversationMessage copyWith({
    String? content,
    bool? isStreaming,
    String? model,
    List<UIComponent>? uiComponents,
    bool? formSubmitted,
    Map<String, String>? formContext,
  }) =>
      ConversationMessage(
        role: role,
        content: content ?? this.content,
        isStreaming: isStreaming ?? this.isStreaming,
        timestamp: timestamp,
        imageBytes: imageBytes,
        model: model ?? this.model,
        uiComponents: uiComponents ?? this.uiComponents,
        formSubmitted: formSubmitted ?? this.formSubmitted,
        formContext: formContext ?? this.formContext,
      );
}
