import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/forum_text_format.dart';
import '../utils/hashtag_text.dart';
import '../utils/mention_text.dart';
import '../../features/profile/profile_provider.dart';

enum _SocialSpanKind { mention, hashtag, url, markdownLink }

class _SocialSpanMatch {
  _SocialSpanMatch({
    required this.start,
    required this.end,
    required this.kind,
    required this.display,
    this.url,
  });

  final int start;
  final int end;
  final _SocialSpanKind kind;
  final String display;
  final String? url;
}

/// Texto enriquecido: @menciones, #hashtags, **negrita**, URLs y [enlaces](url).
class MentionRichText extends ConsumerStatefulWidget {
  const MentionRichText({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
    this.subtleLinks = false,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool subtleLinks;

  @override
  ConsumerState<MentionRichText> createState() => _MentionRichTextState();
}

class _MentionRichTextState extends ConsumerState<MentionRichText> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void didUpdateWidget(MentionRichText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _disposeRecognizers();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
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

  Future<void> _openUrl(String raw) async {
    final uri = Uri.tryParse(normalizeUrlForLaunch(raw));
    if (uri == null || !mounted) return;
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el enlace.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el enlace.')),
        );
      }
    }
  }

  List<_SocialSpanMatch> _collectSpecialMatches(String text) {
    final matches = <_SocialSpanMatch>[];

    void addIfFree(_SocialSpanMatch candidate) {
      final overlaps = matches.any(
        (m) =>
            candidate.start < m.end &&
            candidate.end > m.start,
      );
      if (!overlaps) matches.add(candidate);
    }

    for (final match in markdownLinkPattern.allMatches(text)) {
      addIfFree(
        _SocialSpanMatch(
          start: match.start,
          end: match.end,
          kind: _SocialSpanKind.markdownLink,
          display: match.group(1)!,
          url: match.group(2)!,
        ),
      );
    }

    for (final match in mentionInTextPattern.allMatches(text)) {
      addIfFree(
        _SocialSpanMatch(
          start: match.start,
          end: match.end,
          kind: _SocialSpanKind.mention,
          display: match.group(0)!,
        ),
      );
    }

    for (final match in hashtagInTextPattern.allMatches(text)) {
      addIfFree(
        _SocialSpanMatch(
          start: match.start,
          end: match.end,
          kind: _SocialSpanKind.hashtag,
          display: '#${match.group(1)!}',
        ),
      );
    }

    for (final match in urlInTextPattern.allMatches(text)) {
      addIfFree(
        _SocialSpanMatch(
          start: match.start,
          end: match.end,
          kind: _SocialSpanKind.url,
          display: match.group(0)!,
          url: match.group(0)!,
        ),
      );
    }

    matches.sort((a, b) => a.start.compareTo(b.start));
    return matches;
  }

  TextStyle _baseStyle() => widget.style ?? AppTypography.bodyLarge();

  TextStyle _socialStyle(TextStyle base) => base.copyWith(
        color: widget.subtleLinks
            ? AppColors.burgundy.withValues(alpha: 0.82)
            : AppColors.burgundy,
        fontWeight: widget.subtleLinks ? FontWeight.w500 : FontWeight.w600,
        fontSize: base.fontSize,
        height: base.height,
      );

  TextStyle _urlStyle(TextStyle base) => base.copyWith(
        color: AppColors.burgundy,
        fontWeight: FontWeight.w500,
        fontSize: base.fontSize,
        height: base.height,
        decoration: TextDecoration.underline,
        decorationColor: AppColors.burgundy.withValues(alpha: 0.45),
      );

  TextStyle _boldStyle(TextStyle base) => base.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: base.fontSize,
        height: base.height,
      );

  TextStyle _italicStyle(TextStyle base) => base.copyWith(
        fontStyle: FontStyle.italic,
        fontSize: base.fontSize,
        height: base.height,
      );

  List<InlineSpan> _styledPlainSpans(String plain, TextStyle base) {
    if (plain.isEmpty) return [];

    final spans = <InlineSpan>[];
    final stylePattern = RegExp(r'\*\*(.+?)\*\*|_(.+?)_');
    var last = 0;

    for (final match in stylePattern.allMatches(plain)) {
      if (match.start > last) {
        spans.add(TextSpan(
          text: plain.substring(last, match.start),
          style: base,
        ));
      }
      if (match.group(1) != null) {
        spans.add(TextSpan(
          text: match.group(1)!,
          style: _boldStyle(base),
        ));
      } else if (match.group(2) != null) {
        spans.add(TextSpan(
          text: match.group(2)!,
          style: _italicStyle(base),
        ));
      }
      last = match.end;
    }

    if (last < plain.length) {
      spans.add(TextSpan(text: plain.substring(last), style: base));
    }

    return spans;
  }

  List<InlineSpan> _plainSpans(String plain, TextStyle base) =>
      _styledPlainSpans(plain, base);

  TapGestureRecognizer _tapRecognizer(VoidCallback onTap) {
    final recognizer = TapGestureRecognizer()..onTap = onTap;
    _recognizers.add(recognizer);
    return recognizer;
  }

  InlineSpan _specialSpan(_SocialSpanMatch match, TextStyle base) {
    final social = _socialStyle(base);
    switch (match.kind) {
      case _SocialSpanKind.mention:
        return TextSpan(
          text: match.display,
          style: social,
          recognizer: _tapRecognizer(
            () => _openMentionProfile(match.display),
          ),
        );
      case _SocialSpanKind.hashtag:
        return TextSpan(
          text: match.display,
          style: social,
          recognizer: _tapRecognizer(
            () => _openHashtagSearch(match.display),
          ),
        );
      case _SocialSpanKind.url:
      case _SocialSpanKind.markdownLink:
        final url = match.url ?? match.display;
        return WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openUrl(url),
            child: Text(
              match.display,
              style: _urlStyle(base),
            ),
          ),
        );
    }
  }

  List<InlineSpan> _buildSpans(String text) {
    final base = _baseStyle();
    final special = _collectSpecialMatches(text);
    if (special.isEmpty) return _plainSpans(text, base);

    final spans = <InlineSpan>[];
    var lastEnd = 0;

    for (final match in special) {
      if (match.start > lastEnd) {
        spans.addAll(
          _plainSpans(text.substring(lastEnd, match.start), base),
        );
      }
      spans.add(_specialSpan(match, base));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.addAll(_plainSpans(text.substring(lastEnd), base));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final normalized = widget.text.replaceAll(r'\n', '\n');
    final spans = _buildSpans(normalized);

    if (spans.isEmpty) {
      return Text(
        normalized,
        style: _baseStyle(),
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      );
    }

    return Text.rich(
      TextSpan(children: spans, style: _baseStyle()),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
