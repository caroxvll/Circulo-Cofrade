import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/auth_provider.dart';
import '../../forums/widgets/forums_beige_background.dart';
import '../../search/follows_provider.dart';
import '../profile_design.dart';
import '../profile_provider.dart';
import 'profile_people_list.dart';
import 'profile_people_mode.dart';
import '../../../core/widgets/cofradeo_skeleton.dart';

/// Pantalla de personas: Seguidores / Siguiendo + búsqueda.
/// [forUserId] null = listas propias; si hay id = cotilleo de otro perfil.
class FollowersScreen extends ConsumerStatefulWidget {
  const FollowersScreen({
    super.key,
    this.initialMode = ProfilePeopleMode.seguidores,
    this.forUserId,
  });

  final ProfilePeopleMode initialMode;
  final String? forUserId;

  @override
  ConsumerState<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends ConsumerState<FollowersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profilePeopleModeProvider.notifier).setMode(widget.initialMode);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(profilePeopleModeProvider);
    final title = mode == ProfilePeopleMode.seguidores
        ? 'Seguidores'
        : 'Siguiendo';
    final forUserId = widget.forUserId;
    final currentUser = ref.watch(currentUserProvider);
    final followed = ref.watch(followedProfilesProvider).asData?.value ?? {};

    Widget body = ProfilePeopleList(forUserId: forUserId);

    if (forUserId != null && currentUser?.id != forUserId) {
      final profileAsync = ref.watch(userProfileProvider(forUserId));
      body = profileAsync.when(
        skipLoadingOnReload: true,
        loading: () => const PeopleListSkeleton(),
        error: (_, _) => body,
        data: (profile) {
          if (profile == null) return body;
          final canView =
              !profile.isPrivate || followed.contains(forUserId);
          if (canView) return body;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(ProfileDesign.screenPadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 36,
                    color: AppColors.burgundy,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Esta cuenta es privada',
                    style: AppTypography.titleLarge().copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Solo sus seguidores pueden ver esta lista.',
                    style: AppTypography.bodyMedium(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        image: forumsBeigeDecorationImage(context),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(title),
          backgroundColor: Colors.transparent,
        ),
        body: body,
      ),
    );
  }
}
