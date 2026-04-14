import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vail_app/data/models/api/chat/chat_completion_request.dart';
import 'package:vail_app/data/models/api/session/session_summary.dart';
import 'package:vail_app/data/models/domain/conversation_message.dart';

/// HTTP client for the Vail gateway API.
///
/// Wraps all gateway endpoints. Handles auth headers, SSE streaming,
/// and surfaces typed errors. All other services go through this — nothing
/// else in the app calls http directly.
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

  /// Streams a chat completion response token by token.
  /// Yields each text token as it arrives from the gateway SSE stream.
  /// Throws [VailClientException] on connection errors or non-200 responses.
  Stream<String> streamChatCompletion(ChatCompletionRequest request) async* {
    final uri = Uri.parse('$endpoint/v1/chat/completions');
    final body = jsonEncode(request.toJson());

    final httpRequest = http.Request('POST', uri);
    httpRequest.headers.addAll(_headers);
    httpRequest.body = body;

    // Keep a strong reference to the client for the entire duration of the
    // stream. An anonymous http.Client() with no stored reference can be
    // garbage-collected mid-stream, which closes the socket and silently
    // truncates long responses (especially noticeable on macOS).
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
        throw VailClientException(
          'Gateway returned ${response.statusCode}: $errorBody',
        );
      }

      final stream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in stream) {
        if (!line.startsWith('data: ')) continue;

        final payload = line.substring(6);
        if (payload == '[DONE]') break;

        try {
          final chunk = jsonDecode(payload) as Map<String, dynamic>;

          // Gateway forwards backend errors as SSE error events.
          if (chunk.containsKey('error')) {
            final errorMap = chunk['error'];
            final message = errorMap is Map
                ? (errorMap['message'] as String? ?? 'Backend error')
                : 'Backend error';
            throw VailClientException(message);
          }

          final choices = chunk['choices'] as List<dynamic>?;
          if (choices == null || choices.isEmpty) continue;

          final delta = (choices[0] as Map<String, dynamic>)['delta']
              as Map<String, dynamic>?;
          final token = delta?['content'] as String?;
          if (token != null && token.isNotEmpty) yield token;
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

  /// Returns all sessions, newest first.
  Future<List<SessionSummary>> listSessions() async {
    final uri = Uri.parse('$endpoint/v1/sessions');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode != 200) {
      throw VailClientException('Failed to load sessions: ${response.statusCode}');
    }

    // Gateway returns {"sessions": [...], "count": N}
    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> items = body['sessions'] as List<dynamic>;
    return items
        .map((item) => SessionSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Deletes a session and all its messages.
  Future<void> deleteSession(String sessionId) async {
    final uri = Uri.parse('$endpoint/v1/sessions/$sessionId');
    final response = await http.delete(uri, headers: _headers);

    if (response.statusCode != 200) {
      throw VailClientException('Failed to delete session: ${response.statusCode}');
    }
  }

  /// Returns the ordered messages for a saved session.
  /// Used to restore conversation history when the user taps a session tile.
  Future<List<ConversationMessage>> getSessionMessages(String id) async {
    final uri = Uri.parse('$endpoint/v1/sessions/$id');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode != 200) {
      throw VailClientException('Failed to load session: ${response.statusCode}');
    }

    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> msgs = body['messages'] as List<dynamic>;
    final now = DateTime.now();
    return msgs.map((m) {
      final map = m as Map<String, dynamic>;
      return ConversationMessage(
        role: map['role'] as String,
        content: map['content'] as String,
        timestamp: now,
      );
    }).toList();
  }

  /// Returns gateway health. Used to verify connectivity on settings screen.
  Future<bool> checkHealth() async {
    try {
      final uri = Uri.parse('$endpoint/health');
      final response = await http.get(uri).timeout(const Duration(seconds: 5),);
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
