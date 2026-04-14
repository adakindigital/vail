import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:vail_app/core/config/app_config.dart';
import 'package:vail_app/data/models/api/session/session_summary.dart';
import 'package:vail_app/data/services/vail_client.dart';

enum SessionsState { idle, loading, loaded, error }

class SessionsViewModel extends ChangeNotifier {
  final AppConfig _config = GetIt.I<AppConfig>();

  SessionsState _state = SessionsState.idle;
  SessionsState get state => _state;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  List<SessionSummary> _sessions = [];

  /// Sessions sorted newest first (by updatedAt descending).
  List<SessionSummary> get sessions => List.unmodifiable(_sessions);

  bool get isEmpty => _state == SessionsState.loaded && _sessions.isEmpty;

  Future<void> load() async {
    if (_state == SessionsState.loading) return;

    _state = SessionsState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      final client = VailClient(
        endpoint: _config.endpoint,
        apiKey: _config.apiKey,
        sessionId: '',
      );
      final raw = await client.listSessions();
      _sessions = _sortedNewestFirst(raw);
      _state = SessionsState.loaded;
    } on VailClientException catch (e) {
      _errorMessage = e.message;
      _state = SessionsState.error;
    } catch (_) {
      _errorMessage = 'Could not load sessions.';
      _state = SessionsState.error;
    }

    notifyListeners();
  }

  /// Refreshes the sessions list in the background without touching [state].
  /// Used after a chat turn completes so the new/updated session surfaces at
  /// the top of both the sidebar and history tab without showing a spinner.
  Future<void> silentRefresh() async {
    try {
      final client = VailClient(
        endpoint: _config.endpoint,
        apiKey: _config.apiKey,
        sessionId: '',
      );
      final raw = await client.listSessions();
      _sessions = _sortedNewestFirst(raw);
      notifyListeners();
    } catch (_) {
      // Non-fatal — current list stays intact
    }
  }

  Future<void> deleteSession(String sessionId) async {
    try {
      final client = VailClient(
        endpoint: _config.endpoint,
        apiKey: _config.apiKey,
        sessionId: '',
      );
      await client.deleteSession(sessionId);
      _sessions = _sessions.where((s) => s.id != sessionId).toList();
      notifyListeners();
    } catch (_) {
      // Non-fatal — list remains intact if delete fails
    }
  }

  static List<SessionSummary> _sortedNewestFirst(List<SessionSummary> sessions) {
    final sorted = List<SessionSummary>.from(sessions);
    sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted;
  }
}
