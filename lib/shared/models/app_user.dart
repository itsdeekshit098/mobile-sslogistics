class AppUser {
  final String id;
  final String email;
  final String displayName;
  final String role; // 'admin' | 'staff' | 'driver' | 'superadmin'

  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
  });

  /// Admin-equivalent: 'admin' or 'superadmin'. Superadmin is admin-equivalent
  /// everywhere except the superadmin-exclusive settings/sessions pages —
  /// mirrors the web's `isAdmin(role)` in src/lib/routePermissions.ts.
  bool get isAdmin => role == 'admin' || role == 'superadmin';
  bool get isStaff => role == 'staff';
  bool get isDriver => role == 'driver';
  bool get isSuperAdmin => role == 'superadmin';

  /// Only admins can edit / delete diesel records
  bool get canEdit => isAdmin;
  bool get canDelete => isAdmin;

  /// All roles can create diesel records
  bool get canCreate => true;

  /// First letter of display name (falls back to email) for avatar initials
  String get initials {
    final label = displayName.isNotEmpty ? displayName : email;
    return label.isNotEmpty ? label[0].toUpperCase() : '?';
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final email = json['email'] as String? ?? '';
    return AppUser(
      id: json['id'] as String? ?? '',
      email: email,
      displayName: json['displayName'] as String? ?? email,
      role: json['role'] as String? ?? 'driver',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'role': role,
      };
}
