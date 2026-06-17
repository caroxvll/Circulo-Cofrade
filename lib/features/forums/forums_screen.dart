import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_branding.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/calendar_quick_access_button.dart';
import '../notifications/widgets/notifications_bell_button.dart';
import 'data/mock_forums.dart';
import 'forums_provider.dart';
import 'widgets/forum_category_card.dart';

class ForumsScreen extends ConsumerWidget {
  const ForumsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pillarsAsync = ref.watch(forumPillarsProvider);
    final pillars =
        pillarsAsync.asData?.value ?? visibleForumCategories;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          actions: [
            const CalendarQuickAccessButton(),
            const NotificationsBellButton(),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1A0A0A),
                        Color(0xFF3D1515),
                        Color(0xFF0D0D0D),
                      ],
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.2),
                        Colors.black.withValues(alpha: 0.75),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const AppLogo(size: 44),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppBranding.nameUpper,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.gold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  Text(
                                    AppBranding.tagline,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.goldLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          'Foros',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: AppColors.goldPale,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppBranding.forumsPitch,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          sliver: SliverList.separated(
            itemCount: pillars.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final forum = pillars[index];
              return ForumCategoryCard(
                forum: forum,
                onTap: () => context.push('/foros/${forum.id}'),
              );
            },
          ),
        ),
      ],
    );
  }
}
