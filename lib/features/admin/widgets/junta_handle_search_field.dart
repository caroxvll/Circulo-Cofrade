import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/cofradeo_avatar.dart';
import '../../../core/widgets/verified_account_badge.dart';
import '../../permissions/data/permissions_repository.dart';
import '../../permissions/permissions_provider.dart';
import '../junta_ui.dart';

class JuntaHandleSearchField extends ConsumerStatefulWidget {
  const JuntaHandleSearchField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.hintText,
    required this.onSelected,
  });

  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final ValueChanged<ProfileHandleSearchHit?> onSelected;

  @override
  ConsumerState<JuntaHandleSearchField> createState() =>
      _JuntaHandleSearchFieldState();
}

class _JuntaHandleSearchFieldState extends ConsumerState<JuntaHandleSearchField> {
  Timer? _debounce;
  String _searchQuery = '';
  ProfileHandleSearchHit? _selected;

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
    final text = widget.controller.text.trim();
    if (_selected != null &&
        text != _selected!.handleLabel &&
        text != _selected!.handle) {
      setState(() => _selected = null);
      widget.onSelected(null);
    }
    _scheduleSearch(text);
  }

  void _scheduleSearch(String text) {
    _debounce?.cancel();
    final query = text.replaceFirst('@', '').trim();
    if (query.length < 2) {
      setState(() => _searchQuery = '');
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      setState(() => _searchQuery = query);
    });
  }

  void _selectProfile(ProfileHandleSearchHit hit) {
    setState(() {
      _selected = hit;
      _searchQuery = '';
    });
    widget.controller.text = hit.handleLabel;
    widget.controller.selection = TextSelection.collapsed(
      offset: widget.controller.text.length,
    );
    widget.onSelected(hit);
  }

  void _clearSelection() {
    setState(() {
      _selected = null;
      _searchQuery = '';
    });
    widget.controller.clear();
    widget.onSelected(null);
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = _searchQuery.length >= 2
        ? ref.watch(profileHandleSearchProvider(_searchQuery))
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          style: JuntaUi.body(color: AppColors.textPrimary),
          textInputAction: TextInputAction.done,
          decoration: JuntaUi.inputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            helperText: 'Escribe al menos 2 caracteres para buscar.',
          ),
        ),
        if (_selected != null) ...[
          const SizedBox(height: 8),
          InputChip(
            avatar: CofradeoAvatar(
              imageUrl: _selected!.avatarUrl,
              size: 24,
              backgroundColor: AppColors.burgundyDark,
            ),
            label: Text(
              '${_selected!.displayName} (${_selected!.handleLabel})',
              style: JuntaUi.body(color: AppColors.textPrimary),
            ),
            deleteIcon: const Icon(Icons.close, size: 16),
            onDeleted: _clearSelection,
            backgroundColor: AppColors.burgundy.withValues(alpha: 0.08),
            side: const BorderSide(color: AppColors.border),
          ),
        ],
        if (_searchQuery.length >= 2) ...[
          const SizedBox(height: 8),
          resultsAsync!.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (_, __) => Text(
              'No se pudo buscar perfiles.',
              style: JuntaUi.caption(color: AppColors.accentRed),
            ),
            data: (results) {
              if (results.isEmpty) {
                return Text(
                  'Sin coincidencias para @$_searchQuery',
                  style: JuntaUi.caption(),
                );
              }

              return Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(JuntaUi.cardRadius),
                child: Container(
                  decoration: JuntaUi.cardDecoration(),
                  child: Column(
                    children: [
                      for (var i = 0; i < results.length; i++) ...[
                        if (i > 0)
                          const Divider(height: 1, color: AppColors.border),
                        _HandleSearchResultTile(
                          hit: results[i],
                          onTap: () => _selectProfile(results[i]),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _HandleSearchResultTile extends StatelessWidget {
  const _HandleSearchResultTile({
    required this.hit,
    required this.onTap,
  });

  final ProfileHandleSearchHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CofradeoAvatar(
              imageUrl: hit.avatarUrl,
              size: 36,
              backgroundColor: AppColors.burgundyDark,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          hit.displayName,
                          style: JuntaUi.cardTitle(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hit.isVerified) ...[
                        const SizedBox(width: 4),
                        const VerifiedAccountIcon(size: 13),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hit.handleLabel,
                    style: JuntaUi.caption(color: AppColors.burgundy)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
