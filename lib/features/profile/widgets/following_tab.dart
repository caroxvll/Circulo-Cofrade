import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';



import '../../../core/theme/app_colors.dart';

import '../../../core/theme/app_typography.dart';

import '../../../core/widgets/cofradeo_avatar.dart';

import '../../../shared/models/followed_topic.dart';

import '../../../shared/models/user_profile.dart';

import '../../search/follows_provider.dart';



class FollowingTab extends ConsumerWidget {

  const FollowingTab({super.key});



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    final profilesAsync = ref.watch(followedProfilesDetailsProvider);

    final hashtagsAsync = ref.watch(followedHashtagsProvider);

    final topicsAsync = ref.watch(followedTopicsDetailsProvider);



    return profilesAsync.when(

      loading: () => const Center(child: CircularProgressIndicator()),

      error: (_, __) => const Center(child: Text('Error al cargar seguimientos')),

      data: (profiles) {

        final hashtags = hashtagsAsync.asData?.value ?? {};

        final topics = topicsAsync.asData?.value ?? [];



        if (profiles.isEmpty && hashtags.isEmpty && topics.isEmpty) {

          return ListView(

            padding: const EdgeInsets.all(24),

            children: [

              Icon(

                Icons.person_add_outlined,

                size: 40,

                color: AppColors.textMuted.withValues(alpha: 0.5),

              ),

              const SizedBox(height: 12),

              Text(

                'Aún no sigues a nadie',

                style: AppTypography.displaySmall(color: AppColors.textMuted),

                textAlign: TextAlign.center,

              ),

              const SizedBox(height: 6),

              Text(

                'Sigue hashtags en Buscar, cuentas en los foros o hilos concretos.',

                style: AppTypography.bodyMedium(),

                textAlign: TextAlign.center,

              ),

            ],

          );

        }



        return ListView(

          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),

          children: [

            if (topics.isNotEmpty) ...[

              Text('Hilos', style: AppTypography.displaySmall()),

              const SizedBox(height: 12),

              for (final topic in topics) _TopicFollowTile(topic: topic),

              const SizedBox(height: 24),

            ],

            if (hashtags.isNotEmpty) ...[

              Text('Hashtags', style: AppTypography.displaySmall()),

              const SizedBox(height: 12),

              for (final tag in hashtags.toList()..sort())

                _HashtagFollowTile(hashtag: tag),

              const SizedBox(height: 24),

            ],

            if (profiles.isNotEmpty) ...[

              Text('Cuentas', style: AppTypography.displaySmall()),

              const SizedBox(height: 12),

              for (final profile in profiles)

                _ProfileFollowTile(profile: profile),

            ],

          ],

        );

      },

    );

  }

}



class _TopicFollowTile extends ConsumerWidget {

  const _TopicFollowTile({required this.topic});



  final FollowedTopic topic;



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    return Padding(

      padding: const EdgeInsets.only(bottom: 10),

      child: Material(

        color: AppColors.surface,

        borderRadius: BorderRadius.circular(12),

        child: InkWell(

          onTap: () => context.push(

            '/foros/${topic.forumId}/tema/${topic.topicId}',

          ),

          borderRadius: BorderRadius.circular(12),

          child: Container(

            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),

            decoration: BoxDecoration(

              borderRadius: BorderRadius.circular(12),

              border: Border.all(color: AppColors.border),

            ),

            child: Row(

              children: [

                const CofradeoAvatar(

                  icon: Icons.forum_outlined,

                  size: 40,

                  backgroundColor: AppColors.burgundyDark,

                ),

                const SizedBox(width: 12),

                Expanded(

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Text(

                        topic.title,

                        style: AppTypography.titleLarge().copyWith(fontSize: 15),

                        maxLines: 2,

                        overflow: TextOverflow.ellipsis,

                      ),

                      if (topic.preview.isNotEmpty)

                        Text(

                          topic.preview,

                          style: AppTypography.labelSmall(),

                          maxLines: 1,

                          overflow: TextOverflow.ellipsis,

                        ),

                    ],

                  ),

                ),

                TextButton(

                  onPressed: () async {

                    await ref.read(topicFollowControllerProvider).toggle(

                          topicId: topic.topicId,

                          currentlyFollowing: true,

                        );

                  },

                  child: Text(

                    'Dejar de seguir',

                    style: AppTypography.labelSmall(color: AppColors.burgundy),

                  ),

                ),

              ],

            ),

          ),

        ),

      ),

    );

  }

}



class _HashtagFollowTile extends ConsumerWidget {

  const _HashtagFollowTile({required this.hashtag});



  final String hashtag;



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    return Padding(

      padding: const EdgeInsets.only(bottom: 10),

      child: Container(

        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),

        decoration: BoxDecoration(

          color: AppColors.surface,

          borderRadius: BorderRadius.circular(12),

          border: Border.all(color: AppColors.border),

        ),

        child: Row(

          children: [

            const CofradeoAvatar(

              icon: Icons.tag,

              size: 40,

              backgroundColor: AppColors.burgundyDark,

            ),

            const SizedBox(width: 12),

            Expanded(

              child: Text(

                hashtag,

                style: AppTypography.titleLarge().copyWith(fontSize: 15),

              ),

            ),

            TextButton(

              onPressed: () async {

                await ref.read(hashtagFollowControllerProvider).toggle(

                      hashtag: hashtag,

                      currentlyFollowing: true,

                    );

              },

              child: Text(

                'Dejar de seguir',

                style: AppTypography.labelSmall(color: AppColors.burgundy),

              ),

            ),

          ],

        ),

      ),

    );

  }

}



class _ProfileFollowTile extends ConsumerWidget {

  const _ProfileFollowTile({required this.profile});



  final UserProfile profile;



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    return Padding(

      padding: const EdgeInsets.only(bottom: 10),

      child: Material(

        color: AppColors.surface,

        borderRadius: BorderRadius.circular(12),

        child: InkWell(

          onTap: () => context.push('/perfil/usuario/${profile.id}'),

          borderRadius: BorderRadius.circular(12),

          child: Container(

            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),

            decoration: BoxDecoration(

              borderRadius: BorderRadius.circular(12),

              border: Border.all(color: AppColors.border),

            ),

            child: Row(

              children: [

                CofradeoAvatar(

                  imageUrl: profile.avatarUrl,

                  icon: profile.avatarIcon,

                  size: 40,

                  backgroundColor: AppColors.burgundyDark,

                ),

                const SizedBox(width: 12),

                Expanded(

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Text(

                        profile.displayName,

                        style: AppTypography.titleLarge().copyWith(fontSize: 15),

                      ),

                      Text(

                        profile.handle,

                        style: AppTypography.labelSmall(),

                      ),

                    ],

                  ),

                ),

                TextButton(

                  onPressed: () async {

                    await ref.read(profileFollowControllerProvider).toggle(

                          profileId: profile.id,

                          currentlyFollowing: true,

                        );

                  },

                  child: Text(

                    'Dejar de seguir',

                    style: AppTypography.labelSmall(color: AppColors.burgundy),

                  ),

                ),

              ],

            ),

          ),

        ),

      ),

    );

  }

}

