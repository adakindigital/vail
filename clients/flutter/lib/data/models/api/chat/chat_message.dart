import 'dart:convert';
import 'dart:typed_data';
import 'package:vail_app/data/models/api/chat/ui_component.dart';

/// A single message in the format the gateway API expects and returns.
class ChatMessage {
  final String role;
  final String content;
  final String? model;
  final Uint8List? imageBytes;
  
  /// Dynamic UI components attached to the message.
  final List<UIComponent> uiComponents;

  const ChatMessage({
    required this.role,
    required this.content,
    this.model,
    this.imageBytes,
    this.uiComponents = const [],
  });

  Map<String, dynamic> toJson() {
    if (imageBytes != null) {
      final b64 = base64Encode(imageBytes!);
      return {
        'role': role,
        'content': [
          if (content.isNotEmpty) {'type': 'text', 'text': content},
          {
            'type': 'image_url',
            'image_url': {'url': 'data:image/jpeg;base64,$b64'},
          },
        ],
        if (model != null) 'model': model,
        if (uiComponents.isNotEmpty) 'ui_components': uiComponents.map((u) => u.toJson()).toList(),
      };
    }
    return {
      'role': role,
      'content': content,
      if (model != null) 'model': model,
      if (uiComponents.isNotEmpty) 'ui_components': uiComponents.map((u) => u.toJson()).toList(),
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final uiRaw = json['ui_components'] as List<dynamic>?;
    return ChatMessage(
      role: json['role'] as String,
      content: json['content'] as String,
      model: json['model'] as String?,
      uiComponents: uiRaw?.map((u) => UIComponent.fromJson(u as Map<String, dynamic>)).toList() ?? [],
    );
  }
}
