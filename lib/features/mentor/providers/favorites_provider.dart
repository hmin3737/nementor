import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_colors.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';

/// 특정 멘토의 즐겨찾기 여부 (학생 전용)
final isFavoriteProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, mentorId) async {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null || user.role != UserRole.student) return false;
  final row = await SupabaseService.client
      .from(SupabaseService.mentorFavoritesTable)
      .select('id')
      .eq('student_id', user.id)
      .eq('mentor_id', mentorId)
      .maybeSingle();
  return row != null;
});

/// 즐겨찾기 토글
Future<void> toggleFavorite(WidgetRef ref, String mentorId) async {
  final user = ref.read(currentUserProvider).valueOrNull;
  if (user == null || user.role != UserRole.student) return;
  final isFav = ref.read(isFavoriteProvider(mentorId)).valueOrNull ?? false;
  if (isFav) {
    await SupabaseService.client
        .from(SupabaseService.mentorFavoritesTable)
        .delete()
        .eq('student_id', user.id)
        .eq('mentor_id', mentorId);
  } else {
    await SupabaseService.client
        .from(SupabaseService.mentorFavoritesTable)
        .insert({'student_id': user.id, 'mentor_id': mentorId});
  }
  ref.invalidate(isFavoriteProvider(mentorId));
}

/// 관심 멘토 목록 (전체 프로필 포함)
final favoriteMentorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null || user.role != UserRole.student) return [];

  final favorites = await SupabaseService.client
      .from(SupabaseService.mentorFavoritesTable)
      .select('mentor_id')
      .eq('student_id', user.id);

  final favList = (favorites as List);
  if (favList.isEmpty) return [];

  final mentorIds =
      favList.map((f) => f['mentor_id'] as String).toList();

  final profiles = await SupabaseService.client
      .from(SupabaseService.mentorProfilesTable)
      .select('*, users!inner(nickname, mentor_certifications(*))')
      .inFilter('user_id', mentorIds);

  return (profiles as List).cast<Map<String, dynamic>>();
});

/// 관심 멘토 하트 버튼 위젯 (학생이 아니면 렌더링 안 함)
class MentorFavoriteButton extends ConsumerWidget {
  const MentorFavoriteButton({super.key, required this.mentorId});
  final String mentorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user?.role != UserRole.student) return const SizedBox.shrink();

    final isFavAsync = ref.watch(isFavoriteProvider(mentorId));
    final isFav = isFavAsync.valueOrNull ?? false;

    return IconButton(
      icon: Icon(
        isFav ? Icons.favorite : Icons.favorite_border,
        color: isFav ? AppColors.error : AppColors.textSub,
      ),
      onPressed: () => toggleFavorite(ref, mentorId),
    );
  }
}
