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

  // filter_type='all' 또는 자신에게 허용된 질문
  final data = await _client
      .from(SupabaseService.questionsTable)
      .select('*, question_filters(*)')
      .eq('status', 'open')
      .order('created_at', ascending: false)
      .limit(50);

  return (data as List).map((e) => QuestionModel.fromJson(e)).toList();
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

  void addCertCondition(CertCondition c) =>
      state = state.copyWith(certConditions: [...state.certConditions, c]);

  void removeCertCondition(int idx) {
    final list = [...state.certConditions]..removeAt(idx);
    state = state.copyWith(certConditions: list);
  }

  void setRequireUniversity(String? v) =>
      state = state.copyWith(requireUniversity: v);

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

      // 3. 캐시 차감 (Edge Function 호출)
      await SupabaseService.client.functions.invoke(
        'deduct-cash',
        body: {'question_id': qId, 'amount': form.price},
      );

      state = const AsyncData(null);
      return qId;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  Future<void> preempt(String questionId, String mentorId) async {
    state = const AsyncLoading();
    try {
      await _client.rpc('preempt_question', params: {
        'p_question_id': questionId,
        'p_mentor_id': mentorId,
      });
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
