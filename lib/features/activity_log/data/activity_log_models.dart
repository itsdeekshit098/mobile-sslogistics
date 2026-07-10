/// Data models for GET /api/activity-log.
class ActivityLogEntry {
  final int id;
  final String action;
  final String? userId;
  final String? userEmail;
  final String? userDisplayName;
  final String tableName;
  final int? recordId;
  final Map<String, dynamic> details;
  final DateTime createdAt;

  const ActivityLogEntry({
    required this.id,
    required this.action,
    this.userId,
    this.userEmail,
    this.userDisplayName,
    required this.tableName,
    this.recordId,
    required this.details,
    required this.createdAt,
  });

  /// Who performed the action, falling back through display name → email →
  /// "System" for actions with no associated user.
  String get actorLabel => userDisplayName ?? userEmail ?? 'System';

  factory ActivityLogEntry.fromJson(Map<String, dynamic> json) {
    final rawDetails = json['details'];
    return ActivityLogEntry(
      id: json['id'] as int,
      action: json['action'] as String? ?? '',
      userId: json['user_id'] as String?,
      userEmail: json['user_email'] as String?,
      userDisplayName: json['user_display_name'] as String?,
      tableName: json['table_name'] as String? ?? '',
      recordId: json['record_id'] as int?,
      details: rawDetails is Map<String, dynamic> ? rawDetails : const {},
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// One page of activity log entries.
class ActivityLogPage {
  final List<ActivityLogEntry> entries;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  const ActivityLogPage({
    required this.entries,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });
}
