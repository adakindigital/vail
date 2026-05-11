import 'package:vail_app/data/models/api/chat/ui_component.dart';

/// A single chunk of a chat completion stream.
class ChatCompletionChunk {
  final String content;
  final String? model;
  
  /// Gateway-parsed dynamic UI components.
  /// Usually only present on the final chunk of a turn.
  final List<UIComponent> uiComponents;

  const ChatCompletionChunk({
    required this.content,
    this.model,
    this.uiComponents = const [],
  });

  factory ChatCompletionChunk.fromJson(Map<String, dynamic> json) {
    final choices = json["choices"] as List<dynamic>?;
    String content = "";
    if (choices != null && choices.isNotEmpty) {
      final delta = choices[0]["delta"] as Map<String, dynamic>?;
      content = delta?["content"] as String? ?? "";
    }

    final uiRaw = json["ui_components"] as List<dynamic>?;
    return ChatCompletionChunk(
      content: content,
      model: json["model"] as String?,
      uiComponents: uiRaw?.map((u) => UIComponent.fromJson(u as Map<String, dynamic>)).toList() ?? [],
    );
  }
}
