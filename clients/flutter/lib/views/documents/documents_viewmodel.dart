import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:vail_app/core/config/app_config.dart';
import 'package:vail_app/data/models/api/chat/chat_completion_request.dart';
import 'package:vail_app/data/models/api/chat/chat_message.dart';
import 'package:vail_app/data/models/domain/vail_document.dart';
import 'package:vail_app/data/services/vail_client.dart';

class DocumentsViewModel extends ChangeNotifier {
  final AppConfig _config = GetIt.I<AppConfig>();

  final List<VailDocument> _documents = [];
  List<VailDocument> get documents => List.unmodifiable(_documents);

  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;

  String _streamingContent = '';
  String get streamingContent => _streamingContent;

  String? _generationError;
  String? get generationError => _generationError;

  bool get isEmpty => _documents.isEmpty;

  static const String _systemPrompt =
      'You are a professional document writer. '
      'Produce a well-structured document in Markdown. '
      'Use appropriate headings, sections, bullet points, and formatting. '
      'Output only the document — no conversational commentary, no preamble, '
      'no explanation of what you are writing. Start directly with the content.';

  /// Begins streaming a new document from the model.
  /// Returns the generated [VailDocument] when complete, or null on error.
  ///
  /// Callers should push [DocumentEditorView] immediately after calling this
  /// so the user sees content stream in as it arrives.
  Future<VailDocument?> generateDocument({
    required String prompt,
    required String docType,
  }) async {
    _isGenerating = true;
    _streamingContent = '';
    _generationError = null;
    notifyListeners();

    final fullPrompt = docType == 'Custom'
        ? prompt
        : 'Write a $docType: $prompt';

    final client = VailClient(
      endpoint: _config.endpoint,
      apiKey: _config.apiKey,
      sessionId: '', // documents are standalone — no session history
    );

    final buffer = StringBuffer();
    try {
      await for (final token in client.streamChatCompletion(
        ChatCompletionRequest(
          model: _config.model,
          messages: [
            const ChatMessage(role: 'system', content: _systemPrompt),
            ChatMessage(role: 'user', content: fullPrompt),
          ],
          maxTokens: 8192,
        ),
      )) {
        buffer.write(token.content);
        _streamingContent = buffer.toString();
        notifyListeners();
      }

      // Extract title from first H1 heading, fall back to prompt snippet.
      final title = _extractTitle(buffer.toString()) ??
          (prompt.length > 60 ? '${prompt.substring(0, 57)}…' : prompt);

      final doc = VailDocument(
        title: title,
        content: buffer.toString(),
        prompt: prompt,
        createdAt: DateTime.now(),
      );
      _documents.insert(0, doc);
      _isGenerating = false;
      notifyListeners();
      return doc;
    } on VailClientException catch (e) {
      _generationError = e.message;
      _isGenerating = false;
      notifyListeners();
      return null;
    } catch (_) {
      _generationError = 'Something went wrong. Please try again.';
      _isGenerating = false;
      notifyListeners();
      return null;
    }
  }

  void removeDocument(String id) {
    _documents.removeWhere((d) => d.id == id);
    notifyListeners();
  }

  static String? _extractTitle(String markdown) {
    for (final line in markdown.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('# ')) {
        final title = trimmed.substring(2).trim();
        if (title.isNotEmpty) return title;
      }
    }
    return null;
  }
}
