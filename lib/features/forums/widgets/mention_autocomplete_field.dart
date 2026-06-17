import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/hashtag_text.dart';
import '../../../core/utils/mention_text.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../../../shared/models/mention_candidate.dart';
import '../../profile/profile_provider.dart';
import '../../search/data/mock_search.dart';
import '../../search/search_provider.dart';

class MentionAutocompleteField extends ConsumerStatefulWidget {
  const MentionAutocompleteField({
    super.key,
    required this.controller,
    this.focusNode,
    this.maxLines = 4,
    this.minLines = 3,
    this.hintText,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final int maxLines;
  final int minLines;
  final String? hintText;
  final VoidCallback? onSubmitted;

  @override
  ConsumerState<MentionAutocompleteField> createState() =>
      _MentionAutocompleteFieldState();
}

enum _AutocompleteMode { none, mention, hashtag }

class _MentionAutocompleteFieldState
    extends ConsumerState<MentionAutocompleteField> {
  _AutocompleteMode _mode = _AutocompleteMode.none;
  ActiveMention? _activeMention;
  ActiveHashtag? _activeHashtag;
  List<MentionCandidate> _mentionSuggestions = [];
  List<String> _hashtagSuggestions = [];
  var _loading = false;
  Timer? _debounce;
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final text = widget.controller.text;
    final cursor = widget.controller.selection.baseOffset;
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
      final repo = ref.read(profileRepositoryProvider);
      final results = await repo.searchMentionCandidates(query);
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
        tags = await ref.read(trendsRepositoryProvider).fetchTrends().then(
              (trends) => trends.map((t) => t.hashtag).toList(),
            );
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
        _hashtagSuggestions =
            filterHashtagSuggestions(query, mockSearchTrends.map((t) => t.hashtag).toList());
        _loading = false;
      });
    }
  }

  void _selectMention(MentionCandidate candidate) {
    final mention = _activeMention;
    if (mention == null) return;

    final cursor = widget.controller.selection.baseOffset;
    final newText = applyMentionSelection(
      text: widget.controller.text,
      cursorOffset: cursor,
      mentionStartIndex: mention.startIndex,
      handle: candidate.handle,
    );
    final newCursor = cursorAfterMention(mention.startIndex, candidate.handle);

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
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

    final cursor = widget.controller.selection.baseOffset;
    final newText = applyHashtagSelection(
      text: widget.controller.text,
      cursorOffset: cursor,
      hashtagStartIndex: active.startIndex,
      hashtag: hashtag,
    );
    final newCursor = cursorAfterHashtag(active.startIndex, hashtag);

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );

    setState(() {
      _mode = _AutocompleteMode.none;
      _activeHashtag = null;
      _hashtagSuggestions = [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          autofocus: widget.focusNode == null,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: widget.hintText,
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
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
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final tag = suggestions[index];
        return ListTile(
          dense: true,
          leading: const Icon(Icons.tag, color: AppColors.burgundy, size: 20),
          title: Text(tag, style: AppTypography.titleLarge().copyWith(fontSize: 15)),
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
      separatorBuilder: (_, __) => const Divider(height: 1),
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
