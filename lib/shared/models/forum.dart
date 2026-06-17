import 'package:flutter/material.dart';

enum TopicStatus { pending, published, rejected }

/// Pilar del foro (categoría raíz fija).
class ForumCategory {
  const ForumCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.sortOrder,
    required this.topicCount,
    required this.messageCount,
    required this.lastMessageAgo,
    this.lastTopicId,
    this.lastTopicTitle,
    this.isEnabled = true,
    this.isActive = false,
    this.lockedLabel,
    this.headerIcon = Icons.church,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  /// Menor número = más arriba en la lista.
  final int sortOrder;
  final int topicCount;
  final int messageCount;
  /// Texto relativo de la última actividad (tema o respuesta).
  final String lastMessageAgo;
  /// Hilo con actividad más reciente en este foro.
  final String? lastTopicId;
  final String? lastTopicTitle;
  /// Si false, el pilar está bloqueado (temporada / admin).
  final bool isEnabled;
  /// Badge «Activo» cuando la comunidad está muy viva.
  final bool isActive;
  /// Mensaje cuando está bloqueado, ej. «Se activará en Cuaresma».
  final String? lockedLabel;
  final IconData headerIcon;

  bool get isLocked => !isEnabled;
}

class ForumTopic {
  const ForumTopic({
    required this.id,
    required this.forumId,
    required this.title,
    required this.excerpt,
    required this.body,
    required this.authorHandle,
    required this.timeAgo,
    required this.commentCount,
    required this.viewCount,
    this.isResolved = false,
    this.avatarIcon = Icons.face_3,
    this.authorId,
    this.authorAvatarUrl,
    this.status = TopicStatus.published,
  });

  final String id;
  final String forumId;
  final String title;
  final String excerpt;
  final String body;
  final String authorHandle;
  final String timeAgo;
  final int commentCount;
  final int viewCount;
  final bool isResolved;
  final IconData avatarIcon;
  final String? authorId;
  final String? authorAvatarUrl;
  final TopicStatus status;

  bool get isPublished => status == TopicStatus.published;
  bool get isPending => status == TopicStatus.pending;
  bool get isRejected => status == TopicStatus.rejected;
}

class ForumReply {
  const ForumReply({
    required this.id,
    required this.topicId,
    required this.authorHandle,
    required this.timeAgo,
    required this.content,
    required this.commentCount,
    required this.likeCount,
    this.avatarIcon = Icons.church,
    this.authorId,
    this.authorAvatarUrl,
    this.parentReplyId,
    this.createdAt,
    this.editedAt,
    this.deletedAt,
  });

  final String id;
  final String topicId;
  final String authorHandle;
  final String timeAgo;
  final String content;
  final int commentCount;
  final int likeCount;
  final IconData avatarIcon;
  final String? authorId;
  final String? authorAvatarUrl;
  final String? parentReplyId;
  final DateTime? createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;
  bool get isEdited => editedAt != null && !isDeleted;

  /// Texto visible en el hilo (el contenido real se conserva en BD).
  String get displayContent =>
      isDeleted ? 'Comentario eliminado por el autor.' : content;

  ForumReply copyWith({
    String? id,
    String? topicId,
    String? authorHandle,
    String? timeAgo,
    String? content,
    int? commentCount,
    int? likeCount,
    IconData? avatarIcon,
    String? authorId,
    String? authorAvatarUrl,
    String? parentReplyId,
    DateTime? createdAt,
    DateTime? editedAt,
    DateTime? deletedAt,
  }) {
    return ForumReply(
      id: id ?? this.id,
      topicId: topicId ?? this.topicId,
      authorHandle: authorHandle ?? this.authorHandle,
      timeAgo: timeAgo ?? this.timeAgo,
      content: content ?? this.content,
      commentCount: commentCount ?? this.commentCount,
      likeCount: likeCount ?? this.likeCount,
      avatarIcon: avatarIcon ?? this.avatarIcon,
      authorId: authorId ?? this.authorId,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      parentReplyId: parentReplyId ?? this.parentReplyId,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
