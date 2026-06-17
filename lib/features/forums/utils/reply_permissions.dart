import '../../../shared/models/forum.dart';

/// Ventana en la que el autor puede editar su respuesta.
const replyEditWindow = Duration(minutes: 30);

bool replyHasChildReplies(ForumReply reply, Iterable<ForumReply> allReplies) {
  final id = reply.id.toLowerCase();
  return allReplies.any(
    (r) => (r.parentReplyId?.toLowerCase() ?? '') == id && !r.isDeleted,
  );
}

bool canAuthorEditReply(
  ForumReply reply,
  String? userId, {
  required bool hasChildReplies,
}) {
  if (userId == null || reply.authorId != userId) return false;
  if (reply.isDeleted) return false;
  if (hasChildReplies) return false;
  final created = reply.createdAt;
  if (created == null) return false;
  return DateTime.now().difference(created) < replyEditWindow;
}

bool canAuthorDeleteReply(ForumReply reply, String? userId) {
  if (userId == null || reply.authorId != userId) return false;
  return !reply.isDeleted;
}

bool canStaffDeleteReply(ForumReply reply, bool isStaff) {
  return isStaff && !reply.isDeleted;
}

Duration? replyEditTimeRemaining(ForumReply reply) {
  final created = reply.createdAt;
  if (created == null) return null;
  final remaining = replyEditWindow - DateTime.now().difference(created);
  if (remaining.isNegative) return Duration.zero;
  return remaining;
}

String replyEditWindowLabel(ForumReply reply) {
  final remaining = replyEditTimeRemaining(reply);
  if (remaining == null || remaining <= Duration.zero) {
    return 'Ya no se puede editar';
  }
  final minutes = remaining.inMinutes;
  if (minutes >= 1) return 'Editable $minutes min más';
  return 'Editable ${remaining.inSeconds} s más';
}
