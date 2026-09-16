import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/forum_quill_markdown.dart';
import '../../../core/utils/hashtag_text.dart';
import '../../../core/utils/mention_text.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../../../shared/models/mention_candidate.dart';
import '../../profile/profile_provider.dart';
import '../../search/data/mock_search.dart';
import '../../search/search_provider.dart';
import '../forum_topics_typography.dart';
import 'forum_quill_editor_shared.dart';

export 'forum_quill_editor_shared.dart' show ForumComposeToolbar;

enum _AutocompleteMode { none, mention, hashtag }

/// Editor WYSIWYG con negrita/cursiva activables y @menciones.
class ForumComposeField extends ConsumerStatefulWidget {
  const ForumComposeField({
    super.key,
    required this.controller,
    this.focusNode,
    this.maxLines = 6,
    this.minLines = 4,
    this.hintText,
    this.onSubmitted,
    this.toolbar = ForumComposeToolbar.standard,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final int maxLines;
  final int minLines;
  final String? hintText;
  final VoidCallback? onSubmitted;
  final ForumComposeToolbar toolbar;

  @override
  ConsumerState<ForumComposeField> createState() => ForumComposeFieldState();
}

class ForumComposeFieldState extends ConsumerState<ForumComposeField> {
  late final QuillController _quill;
  late final FocusNode _editorFocus;
  var _syncing = false;

  _AutocompleteMode _mode = _AutocompleteMode.none;
  ActiveMention? _activeMention;
  ActiveHashtag? _activeHashtag;
  List<MentionCandidate> _mentionSuggestions = [];
  List<String> _hashtagSuggestions = [];
  var _loading = false;
  Timer? _debounce;
  int _searchGeneration = 0;

  String get markdown => forumDocumentToMarkdown(_quill.document);

  @override
  void initState() {
    super.initState();
    _editorFocus = widget.focusNode ?? FocusNode();
    _quill = QuillController(
      document: forumMarkdownToDocument(widget.controller.text),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _quill.addListener(_onQuillChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _quill.removeListener(_onQuillChanged);
    _quill.dispose();
    if (widget.focusNode == null) {
      _editorFocus.dispose();
    }
    super.dispose();
  }

  void _onQuillChanged() {
    if (!_syncing) {
      _syncing = true;
      final md = markdown;
      if (widget.controller.text != md) {
        widget.controller.value = widget.controller.value.copyWith(
          text: md,
          selection: TextSelection.collapsed(offset: md.length),
        );
      }
      _syncing = false;
    }
    _updateAutocomplete();
  }

  void _updateAutocomplete() {
    final text = _quill.document.toPlainText();
    final cursor = _quill.selection.baseOffset;
    final mention = parseActiveMention(text, cursor);
    final hashtag = parseActiveHashtag(text, cursor);

    _AutocompleteMode nextMode = _AutocompleteMode.none;
    if (mention != null &&
        (hashtag == null || mention.startIndex >= hashtag.startIndex)) {
      nextMode = _AutocompleteMode.mention;
    } else if (hashtag != null) {
      nextMode = _AutocompleteMode.hashtag;
    }

    if (nextMode == _AutocompleteMode.none) {
      if (_mode != _AutocompleteMode.none) {
        setState(() {
          _mode = _AutocompleteMode.none;
          _activeMention = null;
          _activeHashtag = null;
          _mentionSuggestions = [];
          _hashtagSuggestions = [];
          _loading = false;
        });
      }
      return;
    }

    if (nextMode == _AutocompleteMode.mention) {
      if (_mode == _AutocompleteMode.mention &&
          mention!.query == _activeMention?.query &&
          mention.startIndex == _activeMention?.startIndex) {
        return;
      }
      setState(() {
        _mode = _AutocompleteMode.mention;
        _activeMention = mention;
        _activeHashtag = null;
        _hashtagSuggestions = [];
      });
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), () {
        _runMentionSearch(mention!.query);
      });
      return;
    }

    if (_mode == _AutocompleteMode.hashtag &&
        hashtag!.query == _activeHashtag?.query &&
        hashtag.startIndex == _activeHashtag?.startIndex) {
      return;
    }
    setState(() {
      _mode = _AutocompleteMode.hashtag;
      _activeHashtag = hashtag;
      _activeMention = null;
      _mentionSuggestions = [];
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      _runHashtagSearch(hashtag!.query);
    });
  }

  Future<void> _runMentionSearch(String query) async {
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _mentionSuggestions = [];
          _loading = false;
        });
      }
      return;
    }

    final generation = ++_searchGeneration;
    setState(() => _loading = true);

    try {
      final results =
          await ref.read(profileRepositoryProvider).searchMentionCandidates(query);
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _mentionSuggestions = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _mentionSuggestions = [];
        _loading = false;
      });
    }
  }

  Future<void> _runHashtagSearch(String query) async {
    final generation = ++_searchGeneration;
    setState(() => _loading = true);

    try {
      List<String> tags;
      final trendsAsync = ref.read(searchTrendsProvider);
      if (trendsAsync.hasValue && trendsAsync.value!.isNotEmpty) {
        tags = trendsAsync.value!.map((t) => t.hashtag).toList();
      } else {
        tags = await ref
            .read(trendsRepositoryProvider)
            .fetchTrends()
            .then((trends) => trends.map((t) => t.hashtag).toList());
      }
      if (tags.isEmpty) {
        tags = mockSearchTrends.map((t) => t.hashtag).toList();
      }
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _hashtagSuggestions = filterHashtagSuggestions(query, tags);
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _hashtagSuggestions = filterHashtagSuggestions(
          query,
          mockSearchTrends.map((t) => t.hashtag).toList(),
        );
        _loading = false;
      });
    }
  }

  void _selectMention(MentionCandidate candidate) {
    final mention = _activeMention;
    if (mention == null) return;

    final cursor = _quill.selection.baseOffset;
    final replaceLength = cursor - mention.startIndex;
    final handle = candidate.handle.startsWith('@')
        ? candidate.handle.substring(1)
        : candidate.handle;
    final insert = '@$handle ';

    _quill.replaceText(
      mention.startIndex,
      replaceLength,
      insert,
      TextSelection.collapsed(offset: mention.startIndex + insert.length),
    );

    setState(() {
      _mode = _AutocompleteMode.none;
      _activeMention = null;
      _mentionSuggestions = [];
      _loading = false;
    });
  }

  void _selectHashtag(String hashtag) {
    final active = _activeHashtag;
    if (active == null) return;

    final cursor = _quill.selection.baseOffset;
    final replaceLength = cursor - active.startIndex;
    final tag = hashtag.startsWith('#') ? hashtag.substring(1) : hashtag;
    final insert = '#$tag ';

    _quill.replaceText(
      active.startIndex,
      replaceLength,
      insert,
      TextSelection.collapsed(offset: active.startIndex + insert.length),
    );

    setState(() {
      _mode = _AutocompleteMode.none;
      _activeHashtag = null;
      _hashtagSuggestions = [];
      _loading = false;
    });
  }

  String _hintText() {
    return widget.toolbar == ForumComposeToolbar.editorial
        ? 'Negrita, enlaces, listas y citas se ven al escribir.'
        : 'Activa negrita o cursiva y escribe · @menciones y #hashtags también.';
  }

  double _editorHeight(BuildContext context) {
    const lineHeight = 24.0;
    const chrome = 24.0;
    final minH = widget.minLines * lineHeight + chrome;
    final preferred = widget.maxLines * lineHeight + chrome;
    final screenCap = MediaQuery.sizeOf(context).height * 0.34;
    return preferred.clamp(minH, screenCap);
  }

  @override
  Widget build(BuildContext context) {
    final editorHeight = _editorHeight(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_mode == _AutocompleteMode.mention)
          _MentionSuggestionsPanel(
            query: _activeMention?.query ?? '',
            loading: _loading,
            suggestions: _mentionSuggestions,
            onSelect: _selectMention,
          ),
        if (_mode == _AutocompleteMode.hashtag)
          _HashtagSuggestionsPanel(
            query: _activeHashtag?.query ?? '',
            loading: _loading,
            suggestions: _hashtagSuggestions,
            onSelect: _selectHashtag,
          ),
        forumQuillToolbar(controller: _quill, toolbar: widget.toolbar),
        const SizedBox(height: 8),
        SizedBox(
          height: editorHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: QuillEditor.basic(
                controller: _quill,
                focusNode: _editorFocus,
                config: forumQuillEditorConfig(
                  hintText: widget.hintText,
                  expands: true,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _hintText(),
          style: ForumTopicsTypography.style(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _HashtagSuggestionsPanel extends StatelessWidget {
  const _HashtagSuggestionsPanel({
    required this.query,
    required this.loading,
    required this.suggestions,
    required this.onSelect,
  });

  final String query;
  final bool loading;
  final List<String> suggestions;
  final void Function(String hashtag) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (suggestions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          query.isEmpty
              ? 'Escribe # para ver tendencias'
              : 'Sin hashtags que coincidan',
          style: AppTypography.bodyMedium(color: AppColors.textMuted),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: suggestions.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final tag = suggestions[index];
        return ListTile(
          dense: true,
          leading: const Icon(Icons.tag, color: AppColors.burgundy, size: 20),
          title: Text(
            tag,
            style: AppTypography.titleLarge().copyWith(fontSize: 15),
          ),
          onTap: () => onSelect(tag),
        );
      },
    );
  }
}

class _MentionSuggestionsPanel extends StatelessWidget {
  const _MentionSuggestionsPanel({
    required this.query,
    required this.loading,
    required this.suggestions,
    required this.onSelect,
  });

  final String query;
  final bool loading;
  final List<MentionCandidate> suggestions;
  final void Function(MentionCandidate candidate) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (query.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          'Escribe el @usuario para buscar',
          style: AppTypography.bodyMedium(color: AppColors.textMuted),
        ),
      );
    }

    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (suggestions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          'Ningún usuario con @$query',
          style: AppTypography.bodyMedium(color: AppColors.textMuted),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: suggestions.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final candidate = suggestions[index];
        final handle = candidate.handle.startsWith('@')
            ? candidate.handle
            : '@${candidate.handle}';
        return ListTile(
          dense: true,
          leading: CofradeoAvatar(
            imageUrl: candidate.avatarUrl,
            size: 36,
            backgroundColor: AppColors.backgroundElevated,
          ),
          title: Text(
            candidate.displayName,
            style: AppTypography.titleLarge().copyWith(fontSize: 15),
          ),
          subtitle: Text(handle, style: AppTypography.labelSmall()),
          onTap: () => onSelect(candidate),
        );
      },
    );
  }
}
