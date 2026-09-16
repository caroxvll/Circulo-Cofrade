enum UserRole {
  member,
  admin;

  static UserRole fromString(String? raw) {
    return switch (raw) {
      'admin' => UserRole.admin,
      _ => UserRole.member,
    };
  }

  bool get isAdmin => this == UserRole.admin;
}
