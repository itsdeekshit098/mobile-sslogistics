/// Data model for a notification returned by GET /api/notifications.
class NotificationItem {
  final int id;
  final String type;
  final String title;
  final String body;
  final String? linkPath;
  final Map<String, dynamic> metadata;
  final String? readAt;
  final String createdAt;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.linkPath,
    this.metadata = const {},
    this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as int,
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      linkPath: json['link_path'] as String?,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
      readAt: json['read_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  NotificationItem copyWith({String? readAt}) {
    return NotificationItem(
      id: id,
      type: type,
      title: title,
      body: body,
      linkPath: linkPath,
      metadata: metadata,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }
}

/// Paginated list result
class NotificationListData {
  final List<NotificationItem> items;
  final int total;
  final int unreadCount;

  const NotificationListData({
    required this.items,
    required this.total,
    required this.unreadCount,
  });
}
