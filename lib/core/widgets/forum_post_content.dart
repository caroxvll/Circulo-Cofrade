import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/forum_markdown_blocks.dart';
import 'mention_rich_text.dart';

/// Lectura editorial de publicaciones: párrafos, listas, citas y enlaces.
class ForumPostContent extends StatelessWidget {
  const ForumPostContent({
    super.key,
    required this.text,
    this.style,
    this.subtleLinks = false,
    this.premium = false,
  });

  final String text;
  final TextStyle? style;
  final bool subtleLinks;
  final bool premium;

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final blocks = parseForumMarkdownBlocks(text);

    if (blocks.isEmpty) {
      return const SizedBox.shrink();
    }

    if (blocks.length == 1 && blocks.first.kind == ForumMarkdownBlockKind.paragraph) {
      return MentionRichText(
        text: blocks.first.lines.first,
        style: baseStyle,
        subtleLinks: subtleLinks,
      );
    }

    final gap = premium ? 12.0 : 8.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          _ForumMarkdownBlockView(
            block: blocks[i],
            baseStyle: baseStyle,
            subtleLinks: subtleLinks,
            premium: premium,
          ),
        ],
      ],
    );
  }
}

class _ForumMarkdownBlockView extends StatelessWidget {
  const _ForumMarkdownBlockView({
    required this.block,
    required this.baseStyle,
    required this.subtleLinks,
    required this.premium,
  });

  final ForumMarkdownBlock block;
  final TextStyle baseStyle;
  final bool subtleLinks;
  final bool premium;

  @override
  Widget build(BuildContext context) {
    return switch (block.kind) {
      ForumMarkdownBlockKind.paragraph => MentionRichText(
          text: block.lines.first,
          style: baseStyle,
          subtleLinks: subtleLinks,
        ),
      ForumMarkdownBlockKind.bulletList => _BulletList(
          items: block.lines,
          baseStyle: baseStyle,
          subtleLinks: subtleLinks,
          premium: premium,
        ),
      ForumMarkdownBlockKind.orderedList => _OrderedList(
          items: block.lines,
          baseStyle: baseStyle,
          subtleLinks: subtleLinks,
          premium: premium,
        ),
      ForumMarkdownBlockKind.blockquote => _Blockquote(
          lines: block.lines,
          baseStyle: baseStyle,
          subtleLinks: subtleLinks,
          premium: premium,
        ),
    };
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({
    required this.items,
    required this.baseStyle,
    required this.subtleLinks,
    required this.premium,
  });

  final List<String> items;
  final TextStyle baseStyle;
  final bool subtleLinks;
  final bool premium;

  @override
  Widget build(BuildContext context) {
    final markerStyle = baseStyle.copyWith(
      color: premium ? AppColors.burgundy : AppColors.textMuted,
      fontWeight: FontWeight.w700,
      height: 1.45,
    );
    final itemGap = premium ? 6.0 : 4.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(height: itemGap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: premium ? 18 : 14,
                child: Text('•', style: markerStyle),
              ),
              Expanded(
                child: MentionRichText(
                  text: items[i],
                  style: baseStyle,
                  subtleLinks: subtleLinks,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _OrderedList extends StatelessWidget {
  const _OrderedList({
    required this.items,
    required this.baseStyle,
    required this.subtleLinks,
    required this.premium,
  });

  final List<String> items;
  final TextStyle baseStyle;
  final bool subtleLinks;
  final bool premium;

  @override
  Widget build(BuildContext context) {
    final markerStyle = baseStyle.copyWith(
      color: premium ? AppColors.burgundy : AppColors.textMuted,
      fontWeight: FontWeight.w600,
      height: 1.45,
    );
    final itemGap = premium ? 6.0 : 4.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(height: itemGap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: premium ? 24 : 20,
                child: Text('${i + 1}.', style: markerStyle),
              ),
              Expanded(
                child: MentionRichText(
                  text: items[i],
                  style: baseStyle,
                  subtleLinks: subtleLinks,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Blockquote extends StatelessWidget {
  const _Blockquote({
    required this.lines,
    required this.baseStyle,
    required this.subtleLinks,
    required this.premium,
  });

  final List<String> lines;
  final TextStyle baseStyle;
  final bool subtleLinks;
  final bool premium;

  @override
  Widget build(BuildContext context) {
    final quoteStyle = baseStyle.copyWith(
      color: premium ? AppColors.textPrimary : AppColors.textSecondary,
      fontStyle: FontStyle.italic,
      height: 1.5,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(premium ? 14 : 12, premium ? 10 : 8, 12, premium ? 10 : 8),
      decoration: BoxDecoration(
        color: premium
            ? AppColors.gold.withValues(alpha: 0.06)
            : AppColors.backgroundElevated.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(premium ? 10 : 8),
        border: Border(
          left: BorderSide(
            color: AppColors.gold.withValues(alpha: premium ? 0.85 : 0.55),
            width: premium ? 3 : 2,
          ),
        ),
      ),
      child: MentionRichText(
        text: lines.join('\n'),
        style: quoteStyle,
        subtleLinks: subtleLinks,
      ),
    );
  }
}
