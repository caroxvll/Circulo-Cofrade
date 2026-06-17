enum UserRole {
  member,
  editor,
  moderator,
  admin;

  static UserRole fromString(String? raw) {
    return switch (raw) {
      'admin' => UserRole.admin,
      'moderator' => UserRole.moderator,
      'editor' => UserRole.editor,
      _ => UserRole.member,
    };
  }

  bool get isStaff => this == UserRole.admin || this == UserRole.moderator;

  /// Admin y editores (hermandades / colaboradores de confianza).
  bool get canEditCalendar =>
      this == UserRole.admin || this == UserRole.editor;
}
