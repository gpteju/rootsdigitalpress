// CHANGE-2026-09-07: Created User Data Model.

class UserModel {
  final int id;
  final String username;
  final String email;
  final String fullName;
  final String role;
  final String? lastLoginAt;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    required this.role,
    this.lastLoginAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? json['fullName'] ?? '',
      role: json['role'] ?? 'ADMIN',
      lastLoginAt: json['last_login_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'full_name': fullName,
      'role': role,
      if (lastLoginAt != null) 'last_login_at': lastLoginAt,
    };
  }
}
