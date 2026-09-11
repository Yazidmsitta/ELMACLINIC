enum UserRole { admin, user }

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });
  final String id;
  final String name;
  final String email;
  final UserRole role;
  bool get isAdmin => role == UserRole.admin;
}
