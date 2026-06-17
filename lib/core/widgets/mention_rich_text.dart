import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/hashtag_text.dart';
import '../utils/mention_text.dart';
import '../../features/profile/profile_provider.dart';

enum _SocialSpanKind { text, mention, hashtag }

class _SocialSpanMatch {
  _SocialSpanMatch({
    required this.start,
    required this.end,
    required this.kind,
    required this.value,
  });

  final int start;
  final int end;
  final _SocialSpanKind kind;
  final String value;
}

/// Texto con @handles y #hashtags clicables.
class MentionRichText extends ConsumerStatefulWidget {
  const MentionRichText({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  ConsumerState<MentionRichText> createState() => _MentionRichTextState();
}

class _MentionRichTextState extends ConsumerState<MentionRichText> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  Future<void> _openMentionProfile(String handle) async {
    final profileId =
        await ref.read(profileRepositoryProvider).findProfileIdByHandle(handle);
    if (profileId != null && mounted) {
      context.push('/perfil/usuario/$profileId');
    }
  }

  void _openHashtagSearch(String hashtag) {
    final tag = hashtag.startsWith('#') ? hashtag : '#$hashtag';
    context.go('/buscar?q=${Uri.encodeComponent(tag)}');
  }

  List<_SocialSpanMatch> _collectMatches(String text) {
    final matches = <_SocialSpanMatch>[];

    for (final match in mentionInTextPattern.allMatches(text)) {
      matches.add(
        _SocialSpanMatch(
          start: match.start,
          end: match.end,
          kind: _SocialSpanKind.mention,
          value: match.group(0)!,
        ),
      );
    }

    for (final match in hashtagInTextPattern.allMatches(text)) {
      final start = match.start;
      if (matches.any((m) => start >= m.start && start < m.end)) continue;
      matches.add(
        _SocialSpanMatch(
          start: start,
          end: match.end,
          kind: _SocialSpanKind.hashtag,
          value: '#${match.group(1)!}',
        ),
      );
    }

    matches.sort((a, b) => a.start.compareTo(b.start));
    return matches;
  }

  @override
  Widget build(BuildContext context) {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final baseStyle = widget.style ?? AppTypography.bodyLarge();
    final linkStyle = baseStyle.copyWith(
      color: AppColors.burgundy,
      fontWeight: FontWeight.w600,
    );

    final matches = _collectMatches(widget.text);
    if (matches.isEmpty) {
      return Text(
        widget.text,
        style: baseStyle,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      );
    }

    final spans = <InlineSpan>[];
    var lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: widget.text.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }

      final recognizer = TapGestureRecognizer()
        ..onTap = () {
          switch (match.kind) {
            case _SocialSpanKind.mention:
              _openMentionProfile(match.value);
            case _SocialSpanKind.hashtag:
              _openHashtagSearch(match.value);
            case _SocialSpanKind.text:
              break;
          }
        };
      _recognizers.add(recognizer);

      spans.add(TextSpan(
        text: match.value,
        style: linkStyle,
        recognizer: recognizer,
      ));

      lastEnd = match.end;
    }

    if (lastEnd < widget.text.length) {
      spans.add(TextSpan(
        text: widget.text.substring(lastEnd),
        style: baseStyle,
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
