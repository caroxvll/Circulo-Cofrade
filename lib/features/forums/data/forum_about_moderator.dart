/// Moderador visible en la ficha «Acerca del foro».
class ForumAboutModerator {
  const ForumAboutModerator({
    required this.handle,
    required this.isAdmin,
    this.avatarUrl,
  });

  final String handle;
  final bool isAdmin;
  final String? avatarUrl;

  String get roleLabel => isAdmin ? 'Administrador' : 'Moderador';
}
