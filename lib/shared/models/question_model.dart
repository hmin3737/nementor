import 'package:equatable/equatable.dart';

enum QuestionStatus { open, accepted, closed, cancelled }

enum SchoolLevel { elementary, middle, high, etc }

enum QuestionSubject { math, korean, english, science, social, etc }

enum MentorFilterType { all, specific, condition }

class QuestionModel extends Equatable {
  const QuestionModel({
    required this.id,
    required this.studentId,
    this.studentNickname,
    this.title,
    required this.body,
    this.imageUrls = const [],
    this.schoolLevel,
    this.subject,
    required this.price,
    required this.status,
    this.mentorId,
    this.mentorNickname,
    this.acceptedAt,
    this.closeRequestedAt,
    this.closeConfirmedAt,
    required this.createdAt,
    required this.updatedAt,
    this.filter,
  });

  final String id;
  final String studentId;
  final String? studentNickname;
  final String? title;
  final String body;
  final List<String> imageUrls;
  final SchoolLevel? schoolLevel;
  final QuestionSubject? subject;
  final int price;
  final QuestionStatus status;
  final String? mentorId;
  final String? mentorNickname;
  final DateTime? acceptedAt;
  final DateTime? closeRequestedAt;
  final DateTime? closeConfirmedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final QuestionFilter? filter;

  factory QuestionModel.fromJson(Map<String, dynamic> json) => QuestionModel(
        id: json['id'] as String,
        studentId: json['student_id'] as String,
        studentNickname: json['student_nickname'] as String?,
        title: json['title'] as String?,
        body: json['body'] as String,
        imageUrls: (json['image_urls'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        schoolLevel: json['school_level'] != null
            ? SchoolLevel.values.firstWhere(
                (l) => l.name == json['school_level'],
                orElse: () => SchoolLevel.etc,
              )
            : null,
        subject: json['subject'] != null
            ? QuestionSubject.values.firstWhere(
                (s) => s.name == json['subject'],
                orElse: () => QuestionSubject.etc,
              )
            : null,
        price: json['price'] as int,
        status: QuestionStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => QuestionStatus.open,
        ),
        mentorId: json['mentor_id'] as String?,
        mentorNickname: json['mentor_nickname'] as String?,
        acceptedAt: json['accepted_at'] != null
            ? DateTime.parse(json['accepted_at'] as String)
            : null,
        closeRequestedAt: json['close_requested_at'] != null
            ? DateTime.parse(json['close_requested_at'] as String)
            : null,
        closeConfirmedAt: json['close_confirmed_at'] != null
            ? DateTime.parse(json['close_confirmed_at'] as String)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  bool get isOpen => status == QuestionStatus.open;
  bool get isAccepted => status == QuestionStatus.accepted;
  bool get isClosed => status == QuestionStatus.closed;
  bool get isCancelled => status == QuestionStatus.cancelled;

  bool get hasCloseRequest => closeRequestedAt != null;

  DateTime? get autoCloseAt =>
      closeRequestedAt?.add(const Duration(hours: 24));

  @override
  List<Object?> get props => [id, studentId, price, status, createdAt];
}

class QuestionFilter extends Equatable {
  const QuestionFilter({
    required this.filterType,
    this.allowedMentorIds = const [],
    this.certConditions = const [],
    this.requireUniversity,
  });

  final MentorFilterType filterType;
  final List<String> allowedMentorIds;
  final List<CertCondition> certConditions;
  final String? requireUniversity;

  factory QuestionFilter.fromJson(Map<String, dynamic> json) => QuestionFilter(
        filterType: MentorFilterType.values.firstWhere(
          (t) => t.name == json['filter_type'],
          orElse: () => MentorFilterType.all,
        ),
        allowedMentorIds: (json['allowed_mentor_ids'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        certConditions:
            (json['require_cert_conditions'] as List<dynamic>?)?.map((e) {
                  final map = e as Map<String, dynamic>;
                  return CertCondition(
                    subject: map['subject'] as String,
                    minLevel: map['min_level'] == 'master'
                        ? CertFilterLevel.masterOnly
                        : CertFilterLevel.proOrAbove,
                  );
                }).toList() ??
                [],
        requireUniversity: json['require_university'] as String?,
      );

  bool get isFiltered => filterType != MentorFilterType.all;

  @override
  List<Object?> get props =>
      [filterType, allowedMentorIds, certConditions, requireUniversity];
}

enum CertFilterLevel { proOrAbove, masterOnly }

class CertCondition extends Equatable {
  const CertCondition({required this.subject, required this.minLevel});

  final String subject;
  final CertFilterLevel minLevel;

  String get label {
    final levelLabel =
        minLevel == CertFilterLevel.masterOnly ? '마스터만' : '프로 이상';
    return '$subject · $levelLabel';
  }

  @override
  List<Object?> get props => [subject, minLevel];
}
