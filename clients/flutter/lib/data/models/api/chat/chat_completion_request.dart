import 'package:vail_app/data/models/api/chat/chat_message.dart';

/// Request body for POST /v1/chat/completions.
class ChatCompletionRequest {
  final String model;
  final List<ChatMessage> messages;
  final bool stream;

  /// Explicit token cap sent to the backend.
  /// Prevents mlx_lm from silently truncating at its own default (often 512–1024).
  final int maxTokens;

  const ChatCompletionRequest({
    required this.model,
    required this.messages,
    this.stream = true,
    this.maxTokens = 8192,
  });

  Map<String, dynamic> toJson() => {
        'model': model,
        'messages': messages.map((m) => m.toJson()).toList(),
        'stream': stream,
        'max_tokens': maxTokens,
      };
}
