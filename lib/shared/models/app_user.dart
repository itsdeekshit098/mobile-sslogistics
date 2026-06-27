class AppUser {
  final String id;
  final String email;
  final String role; // 'admin' | 'staff' | 'driver'

  const AppUser({
    required this.id,
    required this.email,
    required this.role,
  });

  bool get isAdmin => role == 'admin';
  bool get isStaff => role == 'staff';
  bool get isDriver => role == 'driver';

  /// Only admins can edit / delete diesel records
  bool get canEdit => isAdmin;
  bool get canDelete => isAdmin;

  /// All roles can create diesel records
  bool get canCreate => true;

  /// First letter of email for avatar initials
  String get initials => email.isNotEmpty ? email[0].toUpperCase() : '?';

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'driver',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'role': role,
      };
}
