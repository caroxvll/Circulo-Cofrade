import '../../features/forums/utils/official_post_categories.dart';

/// Query string para rutas `/foros/:id/tema/:id` (`?seccion=cultos&reply=…`).
String buildForumTopicQuery({
  String? section,
  String? replyId,
  bool approved = false,
}) {
  final params = <String, String>{};
  if (approved) params['aprobado'] = '1';
  if (section != null && section.isNotEmpty) {
    params[hermandadSectionQueryKey] = hermandadSectionQueryValue(section);
  }
  if (replyId != null && replyId.isNotEmpty) {
    params['reply'] = replyId;
  }
  if (params.isEmpty) return '';
  return '?${params.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
}
