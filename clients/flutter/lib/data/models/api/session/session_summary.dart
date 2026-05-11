/// A session record as returned by GET /v1/sessions.
class SessionSummary {
  final String id;
  final String? title;
  final int messageCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SessionSummary({
    required this.id,
    required this.title,
    required this.messageCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SessionSummary.fromJson(Map<String, dynamic> json) => SessionSummary(
        id: json['id'] as String,
        title: json['title'] as String?,
        messageCount: json['message_count'] as int,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  String get displayTitle => (title != null && title!.isNotEmpty)
      ? title!
      : 'New conversation';
}
