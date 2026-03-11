import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/question_model.dart';
import '../../../shared/services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';

final _client = SupabaseService.client;

// ── 학생 피드 (내 질문 목록) ─────────────────────────────────────
final myQuestionsProvider =
    FutureProvider.autoDispose<List<QuestionModel>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];
  final data = await _client
      .from(SupabaseService.questionsTable)
      .select()
      .eq('student_id', user.id)
      .order('created_at', ascending: false);
  return (data as List).map((e) => QuestionModel.fromJson(e)).toList();
});

// ── 멘토 피드 (오픈된 질문 목록, 필터 통과한 것) ────────────────
final mentorFeedProvider =
    FutureProvider.autoDispose<List<QuestionModel>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];

  final data = await _client
      .from(SupabaseService.questionsTable)
      .select('*, question_filters(*)')
      .eq('status', 'open')
      .order('created_at', ascending: false)
      .limit(50);

  final questions =
      (data as List).map((e) => QuestionModel.fromJson(e)).toList();

  // 필터가 없는 질문만 있으면 바로 반환
  if (!questions.any((q) => q.filter != null && q.filter!.isFiltered)) {
    return questions;
  }

  // 멘토의 인증 목록 조회
  final certsData = await _client
      .from(SupabaseService.mentorCertificationsTable)
      .select()
      .eq('mentor_id', user.id);
  final myCerts = (certsData as List).cast<Map<String, dynamic>>();

  // 멘토의 대학교 조회
  final profileData = await _client
      .from(SupabaseService.mentorProfilesTable)
      .select('university')
      .eq('user_id', user.id)
      .maybeSingle();
  final myUniversity = profileData?['university'] as String?;

  return questions.where((q) {
    final filter = q.filter;
    if (filter == null || !filter.isFiltered) return true;

    if (filter.filterType == MentorFilterType.specific) {
      return filter.allowedMentorIds.contains(user.id);
    }

    if (filter.filterType == MentorFilterType.condition) {
      // 대학교 조건 체크
      if (filter.requireUniversity != null &&
          filter.requireUniversity!.isNotEmpty) {
        if (myUniversity == null ||
            !myUniversity
                .toLowerCase()
                .contains(filter.requireUniversity!.toLowerCase())) {
          return false;
        }
      }
      // 인증 조건 체크
      for (final condition in filter.certConditions) {
        final matching =
            myCerts.where((c) => c['subject'] == condition.subject).toList();
        if (matching.isEmpty) return false;
        if (condition.minLevel == CertFilterLevel.masterOnly) {
          if (!matching.any((c) => c['level'] == 'master')) return false;
        }
        // proOrAbove: pro 또는 master 모두 허용
      }
      return true;
    }

    return true;
  }).toList();
});

// ── 오픈 피드 (학생 화면) ─────────────────────────────────────────
final studentFeedProvider =
    FutureProvider.autoDispose<List<QuestionModel>>((ref) async {
  final data = await _client
      .from(SupabaseService.questionsTable)
      .select()
      .eq('status', 'open')
      .order('created_at', ascending: false)
      .limit(50);
  return (data as List).map((e) => QuestionModel.fromJson(e)).toList();
});

// ── 질문의 채팅방 ID 조회 ─────────────────────────────────────────
final chatRoomIdProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, questionId) async {
  final data = await _client
      .from(SupabaseService.chatRoomsTable)
      .select('id')
      .eq('question_id', questionId)
      .maybeSingle();
  return data?['id'] as String?;
});

// ── 질문 상세 ─────────────────────────────────────────────────────
final questionDetailProvider =
    FutureProvider.autoDispose.family<QuestionModel?, String>((ref, id) async {
  final data = await _client
      .from(SupabaseService.questionsTable)
      .select()
      .eq('id', id)
      .maybeSingle();
  if (data == null) return null;
  return QuestionModel.fromJson(data);
});

// ── 과목별 추천 가격 ─────────────────────────────────────────────
final defaultPriceProvider =
    FutureProvider.autoDispose.family<int, String>((ref, subject) async {
  final data = await _client
      .from('subject_default_prices')
      .select('price')
      .eq('subject', subject)
      .maybeSingle();
  return (data?['price'] as int?) ?? 3000;
});

// ── 질문 등록 상태 ────────────────────────────────────────────────
class QuestionRegisterState {
  const QuestionRegisterState({
    this.schoolLevel,
    this.subject,
    this.title,
    this.body = '',
    this.imageUrls = const [],
    this.price = 3000,
    this.filterType = MentorFilterType.all,
    this.allowedMentorIds = const [],
    this.allowedMentorNames = const [],
    this.certConditions = const [],
    this.requireUniversity,
  });

  final SchoolLevel? schoolLevel;
  final QuestionSubject? subject;
  final String? title;
  final String body;
  final List<String> imageUrls;
  final int price;
  final MentorFilterType filterType;
  final List<String> allowedMentorIds;
  final List<String> allowedMentorNames; // 표시용 닉네임 (IDs와 1:1 대응)
  final List<CertCondition> certConditions;
  final String? requireUniversity;

  QuestionRegisterState copyWith({
    SchoolLevel? schoolLevel,
    QuestionSubject? subject,
    String? title,
    String? body,
    List<String>? imageUrls,
    int? price,
    MentorFilterType? filterType,
    List<String>? allowedMentorIds,
    List<String>? allowedMentorNames,
    List<CertCondition>? certConditions,
    String? requireUniversity,
    bool clearSchoolLevel = false,
    bool clearSubject = false,
  }) =>
      QuestionRegisterState(
        schoolLevel: clearSchoolLevel ? null : schoolLevel ?? this.schoolLevel,
        subject: clearSubject ? null : subject ?? this.subject,
        title: title ?? this.title,
        body: body ?? this.body,
        imageUrls: imageUrls ?? this.imageUrls,
        price: price ?? this.price,
        filterType: filterType ?? this.filterType,
        allowedMentorIds: allowedMentorIds ?? this.allowedMentorIds,
        allowedMentorNames: allowedMentorNames ?? this.allowedMentorNames,
        certConditions: certConditions ?? this.certConditions,
        requireUniversity: requireUniversity ?? this.requireUniversity,
      );
}

class QuestionRegisterNotifier extends Notifier<QuestionRegisterState> {
  @override
  QuestionRegisterState build() => const QuestionRegisterState();

  void setSchoolLevel(SchoolLevel? v) =>
      state = state.copyWith(schoolLevel: v, clearSchoolLevel: v == null);

  void setSubject(QuestionSubject? v) =>
      state = state.copyWith(subject: v, clearSubject: v == null);

  void setTitle(String v) => state = state.copyWith(title: v);

  void setBody(String v) => state = state.copyWith(body: v);

  void setPrice(int v) => state = state.copyWith(price: v.clamp(0, 9999999));

  void adjustPrice(int delta) => setPrice(state.price + delta);

  void setFilterType(MentorFilterType t) =>
      state = state.copyWith(filterType: t);

  void setAllowedMentors(List<String> ids, List<String> names) =>
      state = state.copyWith(
          allowedMentorIds: ids, allowedMentorNames: names);

  void addCertCondition(CertCondition c) =>
      state = state.copyWith(certConditions: [...state.certConditions, c]);

  void removeCertCondition(int idx) {
    final list = [...state.certConditions]..removeAt(idx);
    state = state.copyWith(certConditions: list);
  }

  void setRequireUniversity(String? v) =>
      state = state.copyWith(requireUniversity: v);

  void addImageUrls(List<String> urls) =>
      state = state.copyWith(imageUrls: [...state.imageUrls, ...urls]);

  void removeImageUrl(int index) {
    final list = [...state.imageUrls]..removeAt(index);
    state = state.copyWith(imageUrls: list);
  }

  void reset() => state = const QuestionRegisterState();
}

final questionRegisterProvider =
    NotifierProvider<QuestionRegisterNotifier, QuestionRegisterState>(
  QuestionRegisterNotifier.new,
);

// ── 질문 등록 액션 ────────────────────────────────────────────────
final questionSubmitProvider =
    AsyncNotifierProvider<QuestionSubmitNotifier, void>(
  QuestionSubmitNotifier.new,
);

class QuestionSubmitNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String?> submit(QuestionRegisterState form, String studentId) async {
    state = const AsyncLoading();
    try {
      // 1. 질문 등록
      final row = await _client.from(SupabaseService.questionsTable).insert({
        'student_id': studentId,
        'title': form.title?.isEmpty == true ? null : form.title,
        'body': form.body,
        'image_urls': form.imageUrls,
        'school_level': form.schoolLevel?.name,
        'subject': form.subject?.name,
        'price': form.price,
        'status': 'open',
      }).select().single();

      final qId = row['id'] as String;

      // 2. 필터 등록
      if (form.filterType != MentorFilterType.all) {
        await _client.from('question_filters').insert({
          'question_id': qId,
          'filter_type': form.filterType.name,
          'allowed_mentor_ids':
              form.filterType == MentorFilterType.specific
                  ? form.allowedMentorIds
                  : null,
          'require_cert_conditions':
              form.filterType == MentorFilterType.condition
                  ? form.certConditions
                      .map((c) => {
                            'subject': c.subject,
                            'min_level': c.minLevel == CertFilterLevel.masterOnly
                                ? 'master'
                                : 'pro',
                          })
                      .toList()
                  : null,
          'require_university': form.requireUniversity,
        });
      }

      // 3. 캐시 차감 (RPC 호출)
      await _client.rpc('deduct_cash_for_question', params: {
        'p_question_id': qId,
        'p_amount': form.price,
      });

      state = const AsyncData(null);
      return qId;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  Future<bool> cancel(String questionId) async {
    state = const AsyncLoading();
    try {
      await _client.rpc('cancel_question', params: {'p_question_id': questionId});
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> giveUp(String questionId, String mentorId) async {
    state = const AsyncLoading();
    try {
      await _client.rpc('give_up_question', params: {
        'p_question_id': questionId,
        'p_mentor_id': mentorId,
      });
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<String?> preempt(String questionId, String mentorId) async {
    state = const AsyncLoading();
    try {
      final roomId = await _client.rpc('preempt_question', params: {
        'p_question_id': questionId,
        'p_mentor_id': mentorId,
      }) as String?;
      state = const AsyncData(null);
      return roomId;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }
}
