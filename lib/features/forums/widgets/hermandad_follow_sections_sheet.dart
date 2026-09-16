import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../utils/official_post_categories.dart';

/// Todas las secciones oficiales (avisos sin filtrar).
const allHermandadNotifyCategories = ['noticia', 'culto', 'acto', 'patrimonio'];

/// Normaliza categorías guardadas; `null` = todas; `[]` = ninguna.
List<String>? normalizeHermandadNotifyCategories(List<String>? raw) {
  if (raw == null) return null;
  if (raw.isEmpty) return const [];
  final set = raw.toSet();
  if (set.length >= allHermandadNotifyCategories.length &&
      allHermandadNotifyCategories.every(set.contains)) {
    return null;
  }
  return allHermandadNotifyCategories.where(set.contains).toList();
}

String hermandadNotifyCategoriesLabel(List<String>? categories) {
  if (categories != null && categories.isEmpty) return 'Sin avisos';
  final normalized = normalizeHermandadNotifyCategories(categories);
  if (normalized == null) return 'Todas las secciones';
  if (normalized.isEmpty) return 'Sin avisos';
  return normalized.map(officialCategoryLabel).join(', ');
}

/// Resultado del sheet de avisos por sección.
class HermandadFollowSheetOutcome {
  const HermandadFollowSheetOutcome({
    this.categories,
    this.unfollow = false,
  });

  /// `null` = todas las secciones; `[]` = ninguna.
  final List<String>? categories;
  final bool unfollow;
}

/// Elige qué secciones del tablón quieren avisos al seguir la hermandad.
Future<HermandadFollowSheetOutcome?> showHermandadFollowSectionsSheet(
  BuildContext context, {
  List<String>? initialCategories,
  bool following = false,
}) {
  return showModalBottomSheet<HermandadFollowSheetOutcome>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _HermandadFollowSectionsSheet(
      initialCategories: initialCategories,
      following: following,
    ),
  );
}

class _HermandadFollowSectionsSheet extends StatefulWidget {
  const _HermandadFollowSectionsSheet({
    required this.initialCategories,
    required this.following,
  });

  final List<String>? initialCategories;
  final bool following;

  @override
  State<_HermandadFollowSectionsSheet> createState() =>
      _HermandadFollowSectionsSheetState();
}

class _HermandadFollowSectionsSheetState
    extends State<_HermandadFollowSectionsSheet> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    final initial = normalizeHermandadNotifyCategories(widget.initialCategories);
    _selected = initial == null
        ? allHermandadNotifyCategories.toSet()
        : initial.toSet();
  }

  void _toggleAll(bool all) {
    setState(() {
      _selected = all ? allHermandadNotifyCategories.toSet() : {};
    });
  }

  List<String>? _resultCategories() {
    if (_selected.isEmpty) return [];
    if (_selected.length >= allHermandadNotifyCategories.length) return null;
    return allHermandadNotifyCategories.where(_selected.contains).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final allSelected = _selected.length >= allHermandadNotifyCategories.length;

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
                    'Avisos del tablón',
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
              'Elige de qué secciones quieres recibir notificaciones.',
              style: AppTypography.bodyMedium(color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Todas las secciones'),
              value: allSelected,
              activeThumbColor: AppColors.burgundy,
              onChanged: (value) => _toggleAll(value),
            ),
            for (final category in officialPostCategories)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(category.label),
                secondary: Icon(category.icon, color: AppColors.burgundy),
                value: _selected.contains(category.value),
                activeColor: AppColors.burgundy,
                onChanged: allSelected
                    ? null
                    : (checked) {
                        setState(() {
                          if (checked == true) {
                            _selected.add(category.value);
                          } else {
                            _selected.remove(category.value);
                          }
                        });
                      },
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                HermandadFollowSheetOutcome(categories: _resultCategories()),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.burgundy,
                foregroundColor: AppColors.textOnDark,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(widget.following ? 'Guardar avisos' : 'Seguir hermandad'),
            ),
            if (widget.following) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(
                  context,
                  const HermandadFollowSheetOutcome(unfollow: true),
                ),
                style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
                child: const Text('Dejar de seguir'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
