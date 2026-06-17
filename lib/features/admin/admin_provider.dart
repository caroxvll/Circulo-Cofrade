import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/forum.dart';
import '../../shared/models/user_role.dart';
import '../auth/auth_provider.dart';
import '../profile/profile_provider.dart';
import 'data/admin_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return createAdminRepository();
});

final isStaffProvider = Provider<bool>((ref) {
  final profile = ref.watch(currentUserProfileProvider).asData?.value;
  return profile?.role.isStaff ?? false;
});

final isAdminProvider = Provider<bool>((ref) {
  final profile = ref.watch(currentUserProfileProvider).asData?.value;
  return profile?.role == UserRole.admin;
});

final pendingTopicsProvider = FutureProvider<List<ForumTopic>>((ref) async {
  if (!ref.watch(isStaffProvider)) return [];
  return ref.watch(adminRepositoryProvider).fetchPendingTopics();
});

final pendingReportsProvider =
    FutureProvider<List<ModerationReport>>((ref) async {
  if (!ref.watch(isStaffProvider)) return [];
  return ref.watch(adminRepositoryProvider).fetchPendingReports();
});

final pendingReportGroupsProvider =
    FutureProvider<List<ModerationReportGroup>>((ref) async {
  final reports = await ref.watch(pendingReportsProvider.future);
  return groupModerationReports(reports);
});

final adminPillarsProvider = FutureProvider<List<ForumCategory>>((ref) async {
  if (!ref.watch(isAdminProvider)) return [];
  return ref.watch(adminRepositoryProvider).fetchPillars();
});
