import 'package:equatable/equatable.dart';

enum UserRole { student, mentor, admin }

enum CertLevel { pro, master }

class UserModel extends Equatable {
  const UserModel({
    required this.id,
    required this.email,
    required this.nickname,
    required this.role,
    required this.cashBalance,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String nickname;
  final UserRole role;
  final int cashBalance;
  final DateTime createdAt;

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        email: json['email'] as String,
        nickname: json['nickname'] as String,
        role: UserRole.values.firstWhere(
          (r) => r.name == json['role'],
          orElse: () => UserRole.student,
        ),
        cashBalance: json['cash_balance'] as int? ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'nickname': nickname,
        'role': role.name,
        'cash_balance': cashBalance,
        'created_at': createdAt.toIso8601String(),
      };

  UserModel copyWith({
    String? id,
    String? email,
    String? nickname,
    UserRole? role,
    int? cashBalance,
    DateTime? createdAt,
  }) =>
      UserModel(
        id: id ?? this.id,
        email: email ?? this.email,
        nickname: nickname ?? this.nickname,
        role: role ?? this.role,
        cashBalance: cashBalance ?? this.cashBalance,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  List<Object?> get props => [id, email, nickname, role, cashBalance, createdAt];
}

class MentorProfile extends Equatable {
  const MentorProfile({
    required this.userId,
    this.realName,
    this.middleSchool,
    this.highSchool,
    this.university,
    this.department,
    required this.verified,
    this.hourlyRateMin,
    this.hourlyRateMax,
    this.intro,
    this.bio,
    this.subjects = const [],
    required this.rating,
    required this.reviewCount,
    this.certifications = const [],
  });

  final String userId;
  final String? realName;
  final String? middleSchool;
  final String? highSchool;
  final String? university;
  final String? department;
  final bool verified;
  final int? hourlyRateMin;
  final int? hourlyRateMax;
  final String? intro;
  final String? bio;
  final List<String> subjects;
  final double rating;
  final int reviewCount;
  final List<MentorCertification> certifications;

  factory MentorProfile.fromJson(Map<String, dynamic> json) => MentorProfile(
        userId: json['user_id'] as String,
        realName: json['real_name'] as String?,
        middleSchool: json['middle_school'] as String?,
        highSchool: json['high_school'] as String?,
        university: json['university'] as String?,
        department: json['department'] as String?,
        verified: json['verified'] as bool? ?? false,
        hourlyRateMin: json['hourly_rate_min'] as int?,
        hourlyRateMax: json['hourly_rate_max'] as int?,
        intro: json['intro'] as String?,
        bio: json['bio'] as String?,
        subjects: (json['subjects'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
        reviewCount: json['review_count'] as int? ?? 0,
        certifications: (json['mentor_certifications'] as List<dynamic>?)
                ?.map((e) =>
                    MentorCertification.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  String get hourlyRateDisplay {
    if (hourlyRateMin == null && hourlyRateMax == null) return '';
    if (hourlyRateMin == hourlyRateMax || hourlyRateMax == null) {
      return '₩${_format(hourlyRateMin ?? 0)}/h';
    }
    return '₩${_format(hourlyRateMin ?? 0)} ~ ₩${_format(hourlyRateMax ?? 0)}';
  }

  String _format(int v) {
    return v.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  @override
  List<Object?> get props => [
        userId,
        realName,
        university,
        department,
        verified,
        rating,
        reviewCount,
        certifications,
      ];
}

class MentorCertification extends Equatable {
  const MentorCertification({
    required this.id,
    required this.mentorId,
    required this.subject,
    required this.level,
    required this.grantedAt,
  });

  final String id;
  final String mentorId;
  final String subject;
  final CertLevel level;
  final DateTime grantedAt;

  factory MentorCertification.fromJson(Map<String, dynamic> json) =>
      MentorCertification(
        id: json['id'] as String,
        mentorId: json['mentor_id'] as String,
        subject: json['subject'] as String,
        level: CertLevel.values.firstWhere(
          (l) => l.name == json['level'],
          orElse: () => CertLevel.pro,
        ),
        grantedAt: DateTime.parse(json['granted_at'] as String),
      );

  @override
  List<Object?> get props => [id, mentorId, subject, level];
}
