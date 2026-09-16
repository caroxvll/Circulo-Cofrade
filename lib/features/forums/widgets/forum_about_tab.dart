import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cofradeo_bottom_nav.dart';
import '../../../shared/models/forum.dart';
import '../../admin/admin_provider.dart';
import '../data/forum_about_moderator.dart';
import '../data/mock_forums.dart';
import '../forum_topics_typography.dart';
import '../forums_provider.dart';
import '../utils/forum_activity_badge.dart';
import 'forum_pillar_icon_mark.dart';

class ForumAboutTab extends ConsumerWidget {
  const ForumAboutTab({super.key, required this.forum});

  final ForumCategory forum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final moderatorsAsync = forum.isHermandadesChannel
        ? null
        : ref.watch(forumAboutModeratorsProvider(forum.id));
    final activity = forumActivityLevel(forum);
    final createdLabel = _createdLabel(forum.createdAt);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        cofradeoBottomScrollPadding(context) + 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isAdmin)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _openEditSheet(context, ref),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: Text(
                  'Editar contenido',
                  style: ForumTopicsTypography.style(
                    color: AppColors.burgundy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          _AboutHeroHeader(forum: forum, activity: activity),
          const SizedBox(height: 16),
          _AboutStatsCard(
            forum: forum,
            createdLabel: createdLabel,
            topicCount: forum.topicCount,
            messageCount: forum.messageCount,
          ),
          const SizedBox(height: 20),
          _AboutSection(
            icon: Icons.menu_book_outlined,
            title: 'Descripción',
            child: Text(
              forum.aboutBodyDisplay,
              style: ForumTopicsTypography.style(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _AboutSection(
            icon: Icons.shield_outlined,
            title: forum.isHermandadesChannel
                ? 'Normas del apartado'
                : 'Normas del foro',
            child: Column(
              children: [
                for (var i = 0; i < forum.forumRulesList.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i < forum.forumRulesList.length - 1 ? 10 : 0,
                    ),
                    child: _AboutRuleRow(
                      icon: (forum.isHermandadesChannel
                              ? _hermandadesRuleIcons
                              : _ruleIcons)[
                          i %
                              (forum.isHermandadesChannel
                                      ? _hermandadesRuleIcons
                                      : _ruleIcons)
                                  .length],
                      text: forum.forumRulesList[i],
                    ),
                  ),
              ],
            ),
          ),
          if (forum.isHermandadesChannel) ...[
            const SizedBox(height: 18),
            _AboutSection(
              icon: Icons.verified_outlined,
              title: 'Publicación oficial',
              child: Text(
                'Las publicaciones las gestionan las cuentas verificadas de '
                'cada hermandad. Los usuarios pueden leer y seguir la '
                'actualidad, pero no pueden escribir ni debatir en este '
                'apartado.',
                style: ForumTopicsTypography.style(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                  height: 1.45,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 18),
            _AboutSection(
              icon: Icons.groups_outlined,
              title: 'Moderadores',
              child: moderatorsAsync!.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (_, _) => Text(
                'No se pudieron cargar los moderadores.',
                style: ForumTopicsTypography.style(
                  color: AppColors.textMuted,
                ),
              ),
              data: (moderators) {
                if (moderators.isEmpty) {
                  return Text(
                    'Sin moderadores asignados. La Junta puede designarlos '
                    'desde el panel de administración.',
                    style: ForumTopicsTypography.style(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                  );
                }
                return Wrap(
                  spacing: 12,
                  runSpacing: 16,
                  alignment: WrapAlignment.start,
                  children: [
                    for (final mod in moderators)
                      _AboutModeratorChip(moderator: mod),
                  ],
                );
              },
            ),
          ),
          ],
        ],
      ),
    );
  }

  String _createdLabel(DateTime? createdAt) {
    if (createdAt == null) return '—';
    return DateFormat('MMMM yyyy', 'es').format(createdAt);
  }

  Future<void> _openEditSheet(BuildContext context, WidgetRef ref) async {
    final taglineController =
        TextEditingController(text: forum.aboutTagline ?? '');
    final bodyController = TextEditingController(text: forum.aboutBody ?? '');
    final rulesController = TextEditingController(
      text: forum.forumRules ??
          (forum.isHermandadesChannel
              ? ForumCategory.defaultHermandadesRules.join('\n')
              : ForumCategory.defaultForumRules.join('\n')),
    );

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  forum.isHermandadesChannel
                      ? 'Editar «Acerca del apartado»'
                      : 'Editar «Acerca del foro»',
                  style: AppTypography.displaySmall().copyWith(fontSize: 20),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  forum.name,
                  style: ForumTopicsTypography.style(
                    color: AppColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: taglineController,
                  decoration: const InputDecoration(
                    labelText: 'Frase breve',
                    hintText: 'El lugar de encuentro para todos los cofrades.',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    hintText: 'Texto de presentación del foro…',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 3,
                  maxLines: 6,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rulesController,
                  decoration: const InputDecoration(
                    labelText: 'Normas (una por línea)',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 5,
                  maxLines: 10,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.burgundy,
                    foregroundColor: AppColors.textOnDark,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Guardar'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (saved != true || !context.mounted) {
      taglineController.dispose();
      bodyController.dispose();
      rulesController.dispose();
      return;
    }

    try {
      await ref.read(adminRepositoryProvider).updatePillar(
            pillarId: forum.id,
            aboutTagline: taglineController.text,
            aboutBody: bodyController.text,
            forumRules: rulesController.text,
          );
      ref.invalidate(forumPillarProvider(forum.id));
      invalidateForumPillarData(ref);
      ref.invalidate(adminPillarsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contenido del foro actualizado')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo guardar. ¿Ejecutaste forum_pillar_about.sql?',
            ),
          ),
        );
      }
    } finally {
      taglineController.dispose();
      bodyController.dispose();
      rulesController.dispose();
    }
  }

  static const _ruleIcons = [
    Icons.people_outline,
    Icons.notifications_none_outlined,
    Icons.mail_outline,
    Icons.edit_outlined,
    Icons.person_outline,
  ];

  static const _hermandadesRuleIcons = [
    Icons.verified_outlined,
    Icons.speaker_notes_off_outlined,
    Icons.article_outlined,
    Icons.account_balance_outlined,
    Icons.contact_mail_outlined,
  ];
}

class _AboutHeroHeader extends StatelessWidget {
  const _AboutHeroHeader({
    required this.forum,
    required this.activity,
  });

  final ForumCategory forum;
  final ForumActivityLevel activity;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ForumPillarIconMark(forum: forum, size: 64),
        const SizedBox(height: 12),
        Text(
          forum.isHermandadesChannel
              ? 'INFORMACIÓN DEL APARTADO'
              : 'INFORMACIÓN DEL FORO',
          style: AppTypography.screenTitle(color: AppColors.goldDark)
              .copyWith(fontSize: 22, letterSpacing: 0.6),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          forum.name.toUpperCase(),
          style: AppTypography.displaySmall(
            color: AppColors.textPrimary,
          ).copyWith(fontSize: 18, letterSpacing: 0.4),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        _AboutActivityBadge(level: activity),
        const SizedBox(height: 8),
        Text(
          forum.aboutTaglineDisplay,
          style: ForumTopicsTypography.style(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w400,
            height: 1.35,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _AboutActivityBadge extends StatelessWidget {
  const _AboutActivityBadge({required this.level});

  final ForumActivityLevel level;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, dot) = switch (level) {
      ForumActivityLevel.veryActive => (
        AppColors.gold.withValues(alpha: 0.18),
        AppColors.goldDark,
        AppColors.gold,
      ),
      ForumActivityLevel.active => (
        const Color(0xFFE8F5E9),
        const Color(0xFF2E7D32),
        const Color(0xFF6BCB77),
      ),
      ForumActivityLevel.low => (
        AppColors.backgroundElevated,
        AppColors.textMuted,
        AppColors.textMuted,
      ),
      ForumActivityLevel.upcoming => (
        AppColors.backgroundElevated,
        AppColors.textMuted,
        null,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            forumActivityLabel(level),
            style: ForumTopicsTypography.style(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutStatsCard extends StatelessWidget {
  const _AboutStatsCard({
    required this.forum,
    required this.createdLabel,
    required this.topicCount,
    required this.messageCount,
  });

  final ForumCategory forum;
  final String createdLabel;
  final int topicCount;
  final int messageCount;

  @override
  Widget build(BuildContext context) {
    final isHermandades = forum.isHermandadesChannel;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _AboutStatColumn(
                icon: Icons.calendar_month_outlined,
                label: 'Creado el',
                value: createdLabel,
              ),
            ),
            const VerticalDivider(width: 1, color: AppColors.border),
            Expanded(
              child: _AboutStatColumn(
                icon: isHermandades
                    ? Icons.newspaper_outlined
                    : Icons.folder_outlined,
                label: isHermandades ? 'Publicaciones' : 'Temas',
                value: formatCount(topicCount),
              ),
            ),
            const VerticalDivider(width: 1, color: AppColors.border),
            Expanded(
              child: _AboutStatColumn(
                icon: isHermandades
                    ? Icons.visibility_outlined
                    : Icons.chat_bubble_outline,
                label: isHermandades ? 'Acceso' : 'Respuestas',
                value: isHermandades
                    ? 'Solo lectura'
                    : formatCount(messageCount),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutStatColumn extends StatelessWidget {
  const _AboutStatColumn({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: AppColors.burgundy),
          const SizedBox(height: 6),
          Text(
            label,
            style: ForumTopicsTypography.style(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: ForumTopicsTypography.style(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppColors.burgundy),
            const SizedBox(width: 8),
            Text(
              title.toUpperCase(),
              style: AppTypography.displaySmall(color: AppColors.burgundy)
                  .copyWith(fontSize: 15, letterSpacing: 0.5),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
        const SizedBox(height: 4),
        const Divider(height: 24, color: AppColors.border),
      ],
    );
  }
}

class _AboutRuleRow extends StatelessWidget {
  const _AboutRuleRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.goldDark),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: ForumTopicsTypography.style(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _AboutModeratorChip extends StatelessWidget {
  const _AboutModeratorChip({required this.moderator});

  final ForumAboutModerator moderator;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120, maxWidth: 156),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.45),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.goldDark.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.backgroundElevated,
              backgroundImage: moderator.avatarUrl != null &&
                      moderator.avatarUrl!.trim().isNotEmpty
                  ? NetworkImage(moderator.avatarUrl!)
                  : null,
              child: moderator.avatarUrl == null ||
                      moderator.avatarUrl!.trim().isEmpty
                  ? Icon(Icons.person, color: AppColors.goldDark, size: 28)
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '@${moderator.handle}',
            style: ForumTopicsTypography.style(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          _ModeratorRoleBadge(
            label: moderator.roleLabel,
            isAdmin: moderator.isAdmin,
          ),
        ],
      ),
    );
  }
}

class _ModeratorRoleBadge extends StatelessWidget {
  const _ModeratorRoleBadge({required this.label, required this.isAdmin});

  final String label;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final bg = isAdmin
        ? AppColors.gold.withValues(alpha: 0.32)
        : const Color(0xFFF3EBD8);
    final fg = isAdmin ? const Color(0xFF7A5A12) : AppColors.goldDark;
    final border = isAdmin
        ? AppColors.gold.withValues(alpha: 0.65)
        : AppColors.goldLight.withValues(alpha: 0.9);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: AppColors.goldDark.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAdmin ? Icons.shield : Icons.shield_outlined,
            size: 11,
            color: fg,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: ForumTopicsTypography.style(
              color: fg,
              fontWeight: FontWeight.w700,
            ).copyWith(letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }
}
