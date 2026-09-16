import '../../../shared/models/forum.dart';
import 'noticias_forum.dart';

/// Ventana en la que el titular puede editar título y mensaje principal.
const topicOwnerEditWindow = Duration(hours: 48);

bool isTopicOwner(ForumTopic topic, String? userId) {
  if (userId == null || topic.authorId == null) return false;
  return topic.authorId!.toLowerCase() == userId.toLowerCase();
}

bool canEditTopicAsOwner(ForumTopic topic, String? userId) {
  if (!isTopicOwner(topic, userId)) return false;
  if (!topic.isPublished || topic.isClosed) return false;
  final created = topic.createdAt;
  if (created == null) return true;
  return DateTime.now().difference(created) < topicOwnerEditWindow;
}

bool canRequestTopicClose(ForumTopic topic, String? userId) {
  if (!isTopicOwner(topic, userId)) return false;
  if (!topic.isPublished || topic.isClosed) return false;
  return topic.closeStatus == TopicCloseStatus.open;
}

bool canFeatureReply({
  required ForumTopic topic,
  required ForumReply reply,
  required String? userId,
  required bool isAdmin,
  required bool isVerified,
  required Set<String> hermandadTopicIds,
}) {
  if (!topic.isPublished || topic.isClosed) return false;
  if (reply.isDeleted) return false;

  if (topic.forumId == 'hermandades' && reply.isOfficial) {
    if (isAdmin) return true;
    if (userId == null) return false;
    return isVerified && hermandadTopicIds.contains(topic.id);
  }

  if (!isTopicOwner(topic, userId)) return false;
  return true;
}

bool canModerateForum({
  required String forumId,
  required bool isAdmin,
  required Set<String> moderatedForumIds,
}) {
  if (isAdmin) return true;
  return moderatedForumIds.contains(forumId);
}

/// Quién puede abrir «Nuevo tema» en un foro.
/// En [noticiasForumId] solo admin / moderadores de ese foro.
bool canCreateTopicInForum({
  required String forumId,
  required bool isAdmin,
  required Set<String> moderatedForumIds,
}) {
  if (forumId == 'hermandades') return false;
  if (isNoticiasForum(forumId)) {
    return canModerateForum(
      forumId: forumId,
      isAdmin: isAdmin,
      moderatedForumIds: moderatedForumIds,
    );
  }
  return true;
}

bool canModerateTopic({
  required ForumTopic topic,
  required bool isAdmin,
  required Set<String> moderatedForumIds,
}) {
  return canModerateForum(
    forumId: topic.forumId,
    isAdmin: isAdmin,
    moderatedForumIds: moderatedForumIds,
  );
}

bool canForumModeratorDeleteReply({
  required ForumReply reply,
  required bool canModerate,
}) {
  return canModerate && !reply.isDeleted;
}
