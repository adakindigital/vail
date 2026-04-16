import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vail_app/data/models/api/chat/chat_completion_request.dart';
import 'package:vail_app/data/models/api/chat/chat_completion_chunk.dart';
import 'package:vail_app/data/models/api/chat/ui_component.dart';
import 'package:vail_app/data/models/api/session/session_summary.dart';
import 'package:vail_app/data/models/domain/conversation_message.dart';

/// HTTP client for the Vail gateway API.
class VailClient {
  final String endpoint;
  final String apiKey;
  final String sessionId;

  VailClient({
    required this.endpoint,
    required this.apiKey,
    required this.sessionId,
  });

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
        if (sessionId.isNotEmpty) 'X-Session-Id': sessionId,
      };

  Stream<ChatCompletionChunk> streamChatCompletion(ChatCompletionRequest request) async* {
    final uri = Uri.parse('$endpoint/v1/chat/completions');
    final body = jsonEncode(request.toJson());

    final httpRequest = http.Request('POST', uri);
    httpRequest.headers.addAll(_headers);
    httpRequest.body = body;

    final client = http.Client();
    try {
      final http.StreamedResponse response;
      try {
        response = await client.send(httpRequest);
      } catch (e) {
        throw const VailClientException('Cannot reach Vail gateway — is it running?');
      }

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        throw VailClientException('Gateway returned ${response.statusCode}: $errorBody');
      }

      final stream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in stream) {
        if (!line.startsWith('data: ')) continue;

        final payload = line.substring(6);
        if (payload == '[DONE]') break;

        try {
          final chunkMap = jsonDecode(payload) as Map<String, dynamic>;
          
          if (chunkMap.containsKey('error')) {
            final errorMap = chunkMap['error'];
            final message = errorMap is Map ? (errorMap['message'] as String? ?? 'Backend error') : 'Backend error';
            throw VailClientException(message);
          }

          yield ChatCompletionChunk.fromJson(chunkMap);
        } on VailClientException {
          rethrow;
        } catch (_) {
          continue;
        }
      }
    } finally {
      client.close();
    }
  }

  Future<List<SessionSummary>> listSessions() async {
    final uri = Uri.parse('$endpoint/v1/sessions');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) throw const VailClientException('Failed to load sessions');
    final Map<String, dynamic> body = jsonDecode(response.body);
    final List<dynamic> items = body['sessions'];
    return items.map((item) => SessionSummary.fromJson(item)).toList();
  }

  Future<void> deleteSession(String sessionId) async {
    final uri = Uri.parse('$endpoint/v1/sessions/$sessionId');
    final response = await http.delete(uri, headers: _headers);
    if (response.statusCode != 200) throw const VailClientException('Failed to delete session');
  }

  Future<List<ConversationMessage>> getSessionMessages(String id) async {
    final uri = Uri.parse('$endpoint/v1/sessions/$id');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) throw const VailClientException('Failed to load session');
    final Map<String, dynamic> body = jsonDecode(response.body);
    final List<dynamic> msgs = body['messages'];
    final now = DateTime.now();
    return msgs.map((m) {
      final map = m as Map<String, dynamic>;
      final uiRaw = map['ui_components'] as List<dynamic>?;
      return ConversationMessage(
        role: map['role'] as String,
        content: map['content'] as String,
        timestamp: now,
        model: map['model'] as String?,
        uiComponents: uiRaw?.map((u) => UIComponent.fromJson(u)).toList() ?? [],
      );
    }).toList();
  }

  Future<bool> checkHealth() async {
    try {
      final uri = Uri.parse('$endpoint/health');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

class VailClientException implements Exception {
  final String message;
  const VailClientException(this.message);
  @override
  String toString() => message;
}
