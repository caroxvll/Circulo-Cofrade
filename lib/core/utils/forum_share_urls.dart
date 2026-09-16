import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/app_branding.dart';
import 'forum_topic_query.dart';
import '../../features/forums/utils/official_post_categories.dart';

/// Enlace absoluto a un tema (o comentario) del foro.
String buildForumTopicShareUrl({
  required String forumId,
  required String topicId,
  String? section,
  String? replyId,
}) {
  final query = buildForumTopicQuery(section: section, replyId: replyId);
  final path = '/foros/$forumId/tema/$topicId$query';
  if (kIsWeb) {
    return '${Uri.base.origin}$path';
  }
  return '${AppBranding.webOrigin}$path';
}

/// Alias del tablón de hermandad (misma URL que [buildForumTopicShareUrl]).
String buildHermandadBoardShareUrl({
  required String forumId,
  required String topicId,
  String? section,
  String? replyId,
}) =>
    buildForumTopicShareUrl(
      forumId: forumId,
      topicId: topicId,
      section: section,
      replyId: replyId,
    );

Rect? _shareOrigin(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

String _topicShareMessage({
  required String url,
  String? title,
  String? section,
}) {
  final brand = AppBranding.name;
  final sectionLabel =
      section != null ? officialCategoryLabel(section) : null;
  final trimmed = title?.trim();
  return switch ((trimmed, sectionLabel)) {
    (final text?, final sec?) when text.isNotEmpty =>
      '$text · $sec · $brand\n$url',
    (final text?, _) when text.isNotEmpty => '$text · $brand\n$url',
    (_, final sec?) => 'Comunicado oficial · $sec · $brand\n$url',
    _ => 'Tema en $brand\n$url',
  };
}

String _replyShareMessage({
  required String url,
  String? excerpt,
  String? authorHandle,
  String? section,
}) {
  final brand = AppBranding.name;
  final sectionLabel =
      section != null ? officialCategoryLabel(section) : null;
  final handle = authorHandle?.trim();
  final body = excerpt?.trim();
  final who = (handle != null && handle.isNotEmpty) ? '@$handle' : null;

  if (sectionLabel != null) {
    if (body != null && body.isNotEmpty) {
      return '$body · $sectionLabel · $brand\n$url';
    }
    return 'Comunicado oficial · $sectionLabel · $brand\n$url';
  }
  if (body != null && body.isNotEmpty) {
    if (who != null) return '$who: $body · $brand\n$url';
    return '$body · $brand\n$url';
  }
  if (who != null) return 'Comentario de $who · $brand\n$url';
  return 'Comentario en $brand\n$url';
}

/// Comparte enlace a un tema del foro.
Future<void> shareForumTopicLink(
  BuildContext context, {
  required String forumId,
  required String topicId,
  String? section,
  String? replyId,
  String? label,
}) {
  final url = buildForumTopicShareUrl(
    forumId: forumId,
    topicId: topicId,
    section: section,
    replyId: replyId,
  );
  return SharePlus.instance.share(
    ShareParams(
      text: _topicShareMessage(url: url, title: label, section: section),
      sharePositionOrigin: _shareOrigin(context),
    ),
  );
}

/// Comparte enlace a un comentario concreto (`?reply=`).
Future<void> shareForumReplyLink(
  BuildContext context, {
  required String forumId,
  required String topicId,
  required String replyId,
  String? section,
  String? excerpt,
  String? authorHandle,
}) {
  final url = buildForumTopicShareUrl(
    forumId: forumId,
    topicId: topicId,
    section: section,
    replyId: replyId,
  );
  return SharePlus.instance.share(
    ShareParams(
      text: _replyShareMessage(
        url: url,
        excerpt: excerpt,
        authorHandle: authorHandle,
        section: section,
      ),
      sharePositionOrigin: _shareOrigin(context),
    ),
  );
}
