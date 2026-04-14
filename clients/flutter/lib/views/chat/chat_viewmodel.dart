import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:vail_app/core/config/app_config.dart';
import 'package:vail_app/data/models/api/chat/chat_completion_request.dart';
import 'package:vail_app/data/models/api/chat/chat_message.dart';
import 'package:vail_app/data/models/domain/conversation_message.dart';
import 'package:vail_app/data/services/vail_client.dart';

enum ChatState { idle, sending, error }

class ChatViewModel extends ChangeNotifier {
  final AppConfig _config = GetIt.I<AppConfig>();

  ChatState _state = ChatState.idle;
  ChatState get state => _state;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  late String _activeModel = _config.model;
  String get activeModel => _activeModel;

  final List<ConversationMessage> _messages = [];
  List<ConversationMessage> get messages => List.unmodifiable(_messages);

  /// Increments on every notifyListeners() call — lets Selectors rebuild
  /// even when only message content changes (not just list length).
  int _changeCount = 0;
  int get changeCount => _changeCount;

  String _sessionId = _generateSessionId();
  String get sessionId => _sessionId;

  /// Tracks which message indices have had their insight card dismissed.
  /// Cleared on new session / session load.
  final Set<int> _dismissedInsightIndices = {};

  bool isInsightCardDismissed(int index) =>
      _dismissedInsightIndices.contains(index);

  void dismissInsightCard(int index) {
    _dismissedInsightIndices.add(index);
    notifyListeners();
  }

  late VailClient _client = _buildClient();

  VailClient _buildClient() => VailClient(
        endpoint: _config.endpoint,
        apiKey: _config.apiKey,
        sessionId: _sessionId,
      );

  bool get isSending => _state == ChatState.sending;

  @override
  void notifyListeners() {
    _changeCount++;
    super.notifyListeners();
  }

  Future<void> sendMessage(String userInput, {Uint8List? imageBytes}) async {
    if (userInput.trim().isEmpty || isSending) return;

    _messages.add(ConversationMessage(
      role: 'user',
      content: userInput.trim(),
      timestamp: DateTime.now(),
      imageBytes: imageBytes,
    ));

    // Placeholder for the streaming assistant response — stamp the model so
    // the insight card reflects what actually produced this message.
    _messages.add(ConversationMessage(
      role: 'assistant',
      content: '',
      isStreaming: true,
      timestamp: DateTime.now(),
      model: _activeModel,
    ));

    _state = ChatState.sending;
    _errorMessage = '';
    notifyListeners();

    // Send only the current message — the gateway injects conversation
    // history server-side via the X-Session-Id header.
    final request = ChatCompletionRequest(
      model: _activeModel,
      messages: [
        ChatMessage(
          role: 'user',
          content: userInput.trim(),
          imageBytes: imageBytes,
        ),
      ],
    );

    final buffer = StringBuffer();
    try {
      await for (final token in _client.streamChatCompletion(request)) {
        buffer.write(token);
        _updateStreamingMessage(buffer.toString());
      }
      _finaliseStreamingMessage(buffer.toString());
      _state = ChatState.idle;
    } on VailClientException catch (e) {
      _removeStreamingMessage();
      _errorMessage = e.message;
      _state = ChatState.error;
    } catch (e) {
      _removeStreamingMessage();
      _errorMessage = 'Something went wrong. Please try again.';
      _state = ChatState.error;
    }

    notifyListeners();
  }

  void setModel(String model) {
    _activeModel = model;
    notifyListeners();
  }

  /// Clears the current conversation and starts a fresh session.
  /// Re-reads model from config so Settings changes take effect immediately.
  void startNewSession() {
    _messages.clear();
    _dismissedInsightIndices.clear();
    _sessionId = _generateSessionId();
    _activeModel = _config.model;
    _client = _buildClient();
    _state = ChatState.idle;
    _errorMessage = '';
    notifyListeners();
  }

  /// Replaces the current conversation with messages from a saved session.
  /// The session ID is set so subsequent messages continue in that thread.
  void loadSession(String sessionId, List<ConversationMessage> messages) {
    _messages
      ..clear()
      ..addAll(messages);
    _dismissedInsightIndices.clear();
    _sessionId = sessionId;
    _client = _buildClient();
    _state = ChatState.idle;
    _errorMessage = '';
    notifyListeners();
  }

  void dismissError() {
    _errorMessage = '';
    _state = ChatState.idle;
    notifyListeners();
  }

  void _updateStreamingMessage(String content) {
    final streamingIndex = _messages.lastIndexWhere((m) => m.isStreaming);
    if (streamingIndex == -1) return;
    _messages[streamingIndex] = _messages[streamingIndex].copyWith(content: content);
    notifyListeners();
  }

  void _finaliseStreamingMessage(String content) {
    final streamingIndex = _messages.lastIndexWhere((m) => m.isStreaming);
    if (streamingIndex == -1) return;
    _messages[streamingIndex] = _messages[streamingIndex].copyWith(
      content: content,
      isStreaming: false,
    );
  }

  void _removeStreamingMessage() {
    _messages.removeWhere((m) => m.isStreaming);
  }

  /// Returns true if the user's message looks like a request to write a document.
  /// Used by the UI to offer the Doc Writer before sending to the model.
  static bool detectsDocIntent(String text) {
    final lower = text.toLowerCase();
    const writeVerbs = {
      'write', 'draft', 'compose', 'create', 'generate', 'prepare', 'make', 'help me with',
    };
    const docNouns = {
      'email', 'letter', 'document', 'report', 'essay', 'proposal',
      'memo', 'cover letter', 'cv', 'resume', 'article', 'blog post',
      'press release', 'contract', 'agreement', 'notice', 'summary',
      'brief', 'plan', 'outline', 'doc', 'write-up',
    };
    final hasVerb = writeVerbs.any((v) => lower.contains(v));
    final hasNoun = docNouns.any((n) => lower.contains(n));
    return hasVerb && hasNoun;
  }

  static String _generateSessionId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
