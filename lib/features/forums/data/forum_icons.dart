import 'package:flutter/material.dart';

const forumIconByKey = <String, IconData>{
  'church': Icons.church,
  'music_note': Icons.music_note,
  'workspace_premium_outlined': Icons.workspace_premium_outlined,
  'account_balance': Icons.account_balance,
  'filter_vintage_outlined': Icons.filter_vintage_outlined,
  'wb_sunny_outlined': Icons.wb_sunny_outlined,
  'face_3': Icons.face_3,
  'wine_bar_outlined': Icons.wine_bar_outlined,
  'map_outlined': Icons.map_outlined,
};

IconData forumIconFromKey(String? key, {IconData fallback = Icons.church}) {
  if (key == null || key.isEmpty) return fallback;
  return forumIconByKey[key] ?? fallback;
}

String forumIconKey(IconData icon) {
  for (final entry in forumIconByKey.entries) {
    if (entry.value == icon) return entry.key;
  }
  return 'church';
}
