import 'dart:math';

/// A document produced by the Vail model.
/// Stored in-memory during the session; will be persisted in a later phase.
class VailDocument {
  final String id;
  final String title;
  final String content;
  final String prompt;
  final DateTime createdAt;

  VailDocument({
    required this.title,
    required this.content,
    required this.prompt,
    required this.createdAt,
    String? id,
  }) : id = id ?? _generateId();

  /// First ~140 characters of readable content, stripped of markdown syntax.
  /// Used as the subtitle in document list cards.
  String get contentPreview {
    final stripped = content
        .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')   // headings
        .replaceAll(RegExp(r'[*_`~>]'), '')                        // emphasis/code/quote chars
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')       // links → text
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (stripped.length <= 140) return stripped;
    return '${stripped.substring(0, 140)}…';
  }

  int get wordCount {
    if (content.isEmpty) return 0;
    return content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  }

  String get wordCountLabel {
    final n = wordCount;
    if (n < 1000) return '$n words';
    return '${(n / 1000).toStringAsFixed(1)}k words';
  }

  String get readingTimeLabel {
    final minutes = (wordCount / 200).ceil();
    return '${minutes}m read';
  }

  /// Terminal-style document ID, e.g. VT-8829-XQ
  String get terminalId {
    final upper = id.toUpperCase();
    return 'VT-${upper.substring(0, 4)}-${upper.substring(4, 6)}';
  }

  /// Formatted timestamp for the metadata bar, e.g. 2024.05.21_14:02:44
  String get terminalTimestamp {
    final d = createdAt;
    final date =
        '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
    final time =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
    return '${date}_$time';
  }

  static String _generateId() {
    final r = Random.secure();
    final bytes = List<int>.generate(8, (_) => r.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
