import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/board_model.dart';
import '../../../shared/services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';

// ── 칼럼 목록 ───────────────────────────────────────────────
final boardListProvider = FutureProvider.autoDispose<List<BoardPost>>((ref) async {
  final rows = await SupabaseService.client
      .from(SupabaseService.boardPostsTable)
      .select('*, mentor_certifications:mentor_certifications(subject, level)')
      .order('created_at', ascending: false)
      .limit(50);
  return rows.map((e) => BoardPost.fromJson(e)).toList();
});

// ── 칼럼 상세 ───────────────────────────────────────────────
final boardDetailProvider =
    FutureProvider.autoDispose.family<BoardPost?, String>((ref, postId) async {
  final data = await SupabaseService.client
      .from(SupabaseService.boardPostsTable)
      .select('*, mentor_certifications:mentor_certifications(subject, level)')
      .eq('id', postId)
      .maybeSingle();
  if (data == null) return null;
  return BoardPost.fromJson(data);
});

// ── 댓글 목록 ───────────────────────────────────────────────
final boardCommentsProvider =
    FutureProvider.autoDispose.family<List<BoardComment>, String>((ref, postId) async {
  final rows = await SupabaseService.client
      .from(SupabaseService.boardCommentsTable)
      .select()
      .eq('post_id', postId)
      .isFilter('parent_id', null)
      .order('created_at');
  final comments =
      rows.map((e) => BoardComment.fromJson(e)).toList();

  // 대댓글 fetch
  final replyRows = await SupabaseService.client
      .from(SupabaseService.boardCommentsTable)
      .select()
      .eq('post_id', postId)
      .not('parent_id', 'is', null)
      .order('created_at');
  final replies =
      replyRows.map((e) => BoardComment.fromJson(e)).toList();

  return comments.map((c) {
    final children = replies.where((r) => r.parentId == c.id).toList();
    return BoardComment(
      id: c.id,
      postId: c.postId,
      userId: c.userId,
      userNickname: c.userNickname,
      userRole: c.userRole,
      parentId: c.parentId,
      body: c.body,
      createdAt: c.createdAt,
      replies: children,
    );
  }).toList();
});

// ── 좋아요 상태 ─────────────────────────────────────────────
final boardLikedProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, postId) async {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return false;
  final row = await SupabaseService.client
      .from(SupabaseService.boardLikesTable)
      .select('id')
      .eq('post_id', postId)
      .eq('user_id', user.id)
      .maybeSingle();
  return row != null;
});

// ── 칼럼 쓰기 상태 ──────────────────────────────────────────
class BoardWriteState {
  const BoardWriteState({this.isLoading = false, this.error});
  final bool isLoading;
  final String? error;
}

class BoardWriteNotifier extends Notifier<BoardWriteState> {
  @override
  BoardWriteState build() => const BoardWriteState();

  Future<String?> submit({
    required String title,
    required String body,
    String? editPostId,
  }) async {
    state = const BoardWriteState(isLoading: true);
    try {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user == null) throw Exception('로그인이 필요해요');

      if (editPostId != null) {
        await SupabaseService.client
            .from(SupabaseService.boardPostsTable)
            .update({'title': title, 'body': body})
            .eq('id', editPostId);
        state = const BoardWriteState();
        return editPostId;
      } else {
        final row = await SupabaseService.client
            .from(SupabaseService.boardPostsTable)
            .insert({
              'mentor_id': user.id,
              'mentor_nickname': user.nickname,
              'title': title,
              'body': body,
            })
            .select('id')
            .single();
        state = const BoardWriteState();
        return row['id'] as String;
      }
    } catch (e) {
      state = BoardWriteState(error: e.toString());
      return null;
    }
  }

  Future<void> delete(String postId) async {
    state = const BoardWriteState(isLoading: true);
    try {
      await SupabaseService.client
          .from(SupabaseService.boardPostsTable)
          .delete()
          .eq('id', postId);
      state = const BoardWriteState();
    } catch (e) {
      state = BoardWriteState(error: e.toString());
    }
  }

  Future<void> toggleLike(String postId) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    final liked = await SupabaseService.client
        .from(SupabaseService.boardLikesTable)
        .select('id')
        .eq('post_id', postId)
        .eq('user_id', user.id)
        .maybeSingle();
    if (liked != null) {
      await SupabaseService.client
          .from(SupabaseService.boardLikesTable)
          .delete()
          .eq('post_id', postId)
          .eq('user_id', user.id);
    } else {
      await SupabaseService.client
          .from(SupabaseService.boardLikesTable)
          .insert({'post_id': postId, 'user_id': user.id});
    }
  }

  Future<void> addComment({
    required String postId,
    required String body,
    String? parentId,
  }) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    await SupabaseService.client
        .from(SupabaseService.boardCommentsTable)
        .insert({
      'post_id': postId,
      'user_id': user.id,
      'user_nickname': user.nickname,
      'user_role': user.role.name,
      'body': body,
      if (parentId != null) 'parent_id': parentId,
    });
  }
}

final boardWriteProvider =
    NotifierProvider<BoardWriteNotifier, BoardWriteState>(BoardWriteNotifier.new);
