import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'user_model.dart';

class BoardPost extends Equatable {
  const BoardPost({
    required this.id,
    required this.mentorId,
    required this.mentorNickname,
    this.mentorUniversity,
    this.mentorCertifications = const [],
    required this.title,
    required this.body,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.createdAt,
    required this.updatedAt,
    this.isLiked = false,
  });

  final String id;
  final String mentorId;
  final String mentorNickname;
  final String? mentorUniversity;
  final List<MentorCertification> mentorCertifications;
  final String title;
  final String body;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isLiked;

  factory BoardPost.fromJson(Map<String, dynamic> json) => BoardPost(
        id: json['id'] as String,
        mentorId: json['mentor_id'] as String,
        mentorNickname: json['mentor_nickname'] as String? ?? '',
        mentorUniversity: json['mentor_university'] as String?,
        mentorCertifications:
            ((json['users'] as Map<String, dynamic>?)?['mentor_certifications']
                        as List<dynamic>?)
                    ?.map((e) => MentorCertification.fromJson(
                        e as Map<String, dynamic>))
                    .toList() ??
                [],
        title: json['title'] as String,
        body: json['body'] as String,
        viewCount: json['view_count'] as int? ?? 0,
        likeCount: json['like_count'] as int? ?? 0,
        commentCount: json['comment_count'] as int? ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        isLiked: json['is_liked'] as bool? ?? false,
      );

  String get bodyPreview {
    try {
      final ops = jsonDecode(body) as List;
      final plain = ops
          .where((op) => op['insert'] is String)
          .map((op) => op['insert'] as String)
          .join()
          .replaceAll('\n', ' ')
          .trim();
      return plain.length > 100 ? '${plain.substring(0, 100)}...' : plain;
    } catch (_) {
      final plain = body.replaceAll(RegExp(r'\$.*?\$'), '[수식]').trim();
      return plain.length > 100 ? '${plain.substring(0, 100)}...' : plain;
    }
  }

  @override
  List<Object?> get props => [id, mentorId, title, createdAt];
}

class BoardComment extends Equatable {
  const BoardComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userNickname,
    required this.userRole,
    this.parentId,
    required this.body,
    required this.createdAt,
    this.replies = const [],
  });

  final String id;
  final String postId;
  final String userId;
  final String userNickname;
  final UserRole userRole;
  final String? parentId;
  final String body;
  final DateTime createdAt;
  final List<BoardComment> replies;

  bool get isReply => parentId != null;

  factory BoardComment.fromJson(Map<String, dynamic> json) => BoardComment(
        id: json['id'] as String,
        postId: json['post_id'] as String,
        userId: json['user_id'] as String,
        userNickname: json['user_nickname'] as String? ?? '',
        userRole: UserRole.values.firstWhere(
          (r) => r.name == (json['user_role'] as String? ?? 'student'),
          orElse: () => UserRole.student,
        ),
        parentId: json['parent_id'] as String?,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        replies: (json['replies'] as List<dynamic>?)
                ?.map((e) =>
                    BoardComment.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  @override
  List<Object?> get props => [id, postId, userId, createdAt];
}
