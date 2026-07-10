/// Data models for GET/PUT/DELETE/PATCH /api/admin/sessions.
class UserSession {
  final String id;
  final String? device;
  final String? ip;
  final DateTime createdAt;
  final DateTime? lastActiveAt;

  const UserSession({
    required this.id,
    this.device,
    this.ip,
    required this.createdAt,
    this.lastActiveAt,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) => UserSession(
        id: json['id'] as String? ?? '',
        device: json['device'] as String?,
        ip: json['ip'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        lastActiveAt: DateTime.tryParse(json['lastActiveAt'] as String? ?? ''),
      );
}

class SessionUser {
  final String id;
  final String email;
  final String? displayName;
  final String role;
  final DateTime? lastSignInAt;
  final DateTime createdAt;
  final bool isBanned;
  final DateTime? bannedUntil;
  final List<UserSession> sessions;

  const SessionUser({
    required this.id,
    required this.email,
    this.displayName,
    required this.role,
    this.lastSignInAt,
    required this.createdAt,
    required this.isBanned,
    this.bannedUntil,
    required this.sessions,
  });

  String get label => (displayName?.isNotEmpty ?? false) ? displayName! : email;

  String get initials {
    final l = label;
    return l.isNotEmpty ? l[0].toUpperCase() : '?';
  }

  factory SessionUser.fromJson(Map<String, dynamic> json) {
    final rawSessions = json['sessions'] as List? ?? const [];
    return SessionUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String?,
      role: json['role'] as String? ?? '',
      lastSignInAt: DateTime.tryParse(json['lastSignInAt'] as String? ?? ''),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      isBanned: json['isBanned'] as bool? ?? false,
      bannedUntil: DateTime.tryParse(json['bannedUntil'] as String? ?? ''),
      sessions: rawSessions.map((e) => UserSession.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class SessionsPage {
  final List<SessionUser> users;
  final int total;
  final int page;
  final int perPage;

  const SessionsPage({
    required this.users,
    required this.total,
    required this.page,
    required this.perPage,
  });
}
