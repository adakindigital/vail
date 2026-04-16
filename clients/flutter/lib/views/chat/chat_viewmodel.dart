import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:vail_app/core/config/app_config.dart';
import 'package:vail_app/data/models/api/chat/chat_completion_request.dart';
import 'package:vail_app/data/models/api/chat/chat_message.dart';
import 'package:vail_app/data/models/api/chat/ui_component.dart';
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
  bool get isPro => _config.isPro;
  final List<ConversationMessage> _messages = [];
  List<ConversationMessage> get messages => List.unmodifiable(_messages);
  int _changeCount = 0;
  int get changeCount => _changeCount;
  String _sessionId = _generateSessionId();
  String get sessionId => _sessionId;
  final Set<int> _dismissedInsightIndices = {};

  bool isInsightCardDismissed(int index) => _dismissedInsightIndices.contains(index);
  void dismissInsightCard(int index) {
    _dismissedInsightIndices.add(index);
    notifyListeners();
  }

  late VailClient _client = _buildClient();
  VailClient _buildClient() => VailClient(endpoint: _config.endpoint, apiKey: _config.apiKey, sessionId: _sessionId);
  bool get isSending => _state == ChatState.sending;

  @override
  void notifyListeners() {
    _changeCount++;
    super.notifyListeners();
  }

  /// Marks the last assistant message that has UI components as submitted.
  /// Called after the user taps an action button, so the form collapses to the
  /// submitted banner and survives ListView rebuilds.
  void markFormSubmitted() {
    final idx = _messages.lastIndexWhere((m) => m.isFromAssistant && m.uiComponents.isNotEmpty);
    if (idx == -1) return;
    _messages[idx] = _messages[idx].copyWith(formSubmitted: true);
    notifyListeners();
  }

  Future<void> sendMessage(String userInput, {Uint8List? imageBytes, Map<String, String>? formContext}) async {
    if (userInput.trim().isEmpty || isSending) return;
    _messages.add(ConversationMessage(role: 'user', content: userInput.trim(), timestamp: DateTime.now(), imageBytes: imageBytes, formContext: formContext));
    _messages.add(ConversationMessage(role: 'assistant', content: '', isStreaming: true, timestamp: DateTime.now(), model: _activeModel));
    _state = ChatState.sending;
    _errorMessage = '';
    notifyListeners();

    final request = ChatCompletionRequest(model: _activeModel, messages: [ChatMessage(role: 'user', content: userInput.trim(), imageBytes: imageBytes)]);
    final buffer = StringBuffer();
    String? finalModel;
    final List<UIComponent> uiComponents = [];
    try {
      await for (final chunk in _client.streamChatCompletion(request)) {
        buffer.write(chunk.content);
        if (chunk.model != null) finalModel = chunk.model;
        if (chunk.uiComponents.isNotEmpty) uiComponents.addAll(chunk.uiComponents);
        _updateStreamingMessage(buffer.toString(), model: finalModel, uiComponents: List.from(uiComponents));
      }
      _finaliseStreamingMessage(buffer.toString(), model: finalModel, uiComponents: List.from(uiComponents));
      _state = ChatState.idle;
    } catch (e) {
      _removeStreamingMessage();
      _errorMessage = e is VailClientException ? e.message : 'Something went wrong.';
      _state = ChatState.error;
    }
    notifyListeners();
  }

  void setModel(String model) {
    _activeModel = model;
    notifyListeners();
  }

  // TODO(prod): remove — dev-only bypass. Pro status must come from server-side
  //             entitlement check after PayFast confirmation, not client config.
  void refreshPlan() => notifyListeners();

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

  void loadSession(String sessionId, List<ConversationMessage> messages) {
    _messages..clear()..addAll(messages);
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

  void _updateStreamingMessage(String content, {String? model, List<UIComponent>? uiComponents}) {
    final streamingIndex = _messages.lastIndexWhere((m) => m.isStreaming);
    if (streamingIndex == -1) return;
    _messages[streamingIndex] = _messages[streamingIndex].copyWith(content: content, model: model, uiComponents: uiComponents);
    notifyListeners();
  }

  void _finaliseStreamingMessage(String content, {String? model, List<UIComponent>? uiComponents}) {
    final streamingIndex = _messages.lastIndexWhere((m) => m.isStreaming);
    if (streamingIndex == -1) return;
    _messages[streamingIndex] = _messages[streamingIndex].copyWith(content: content, isStreaming: false, model: model, uiComponents: uiComponents);
  }

  void _removeStreamingMessage() => _messages.removeWhere((m) => m.isStreaming);

  /// Returns true if the user's message looks like a request to write a document.
  static bool detectsDocIntent(String text) {
    final lower = text.toLowerCase();
    const writeVerbs = {'write', 'draft', 'compose', 'create', 'generate', 'prepare', 'make', 'help me with'};
    const docNouns = {'email', 'letter', 'document', 'report', 'essay', 'proposal', 'memo', 'cover letter', 'cv', 'resume', 'article', 'blog post', 'press release', 'contract', 'agreement', 'notice', 'summary', 'brief', 'plan', 'outline', 'doc', 'write-up'};
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
