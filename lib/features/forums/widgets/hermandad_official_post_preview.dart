import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/forum.dart';
import '../utils/official_post_categories.dart';
import 'reply_card.dart';

/// Vista previa de un comunicado oficial antes de publicar.
Future<void> showHermandadOfficialPostPreview(
  BuildContext context, {
  required String content,
  required String officialCategory,
  required String authorHandle,
  String? imageUrl,
  Uint8List? imageBytes,
  bool isFeatured = false,
}) {
  final trimmed = content.trim();
  final hasImage =
      imageBytes != null || (imageUrl?.trim().isNotEmpty ?? false);
  if (trimmed.isEmpty && !hasImage) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Escribe algo o añade una imagen para previsualizar.'),
      ),
    );
    return Future.value();
  }

  final previewReply = ForumReply(
    id: 'preview',
    topicId: 'preview',
    authorHandle: authorHandle,
    timeAgo: 'vista previa',
    content: trimmed,
    commentCount: 0,
    likeCount: 0,
    isOfficial: true,
    officialCategory: officialCategory,
    imageUrl: imageBytes == null ? imageUrl : null,
    isFeatured: isFeatured,
  );

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      final bottom = MediaQuery.viewPaddingOf(context).bottom;
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Vista previa',
                      style: AppTypography.displaySmall(),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    color: AppColors.textMuted,
                  ),
                ],
              ),
              Text(
                isFeatured
                    ? 'Así se verá fijado en ${officialCategoryLabel(officialCategory)}'
                    : 'Así se verá en ${officialCategoryLabel(officialCategory)}',
                style: AppTypography.bodyMedium(color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (imageBytes != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            imageBytes,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      ReplyCard(reply: previewReply),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.burgundy,
                  foregroundColor: AppColors.textOnDark,
                ),
                child: const Text('Volver al editor'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
