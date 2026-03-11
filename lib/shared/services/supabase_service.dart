import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase 클라이언트 접근 싱글톤
/// 환경 변수 또는 --dart-define으로 주입
class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://jqhhcgqzidvgfznxphkm.supabase.co', // TODO: 실제 URL로 교체
      ),
      anonKey: const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpxaGhjZ3F6aWR2Z2Z6bnhwaGttIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMwNjg5MDIsImV4cCI6MjA4ODY0NDkwMn0.TFwtj4TEhwRLahZi101vD7GCt2jAFiHvWt1SHpfD6TA', // TODO: 실제 anon key로 교체
      ),
    );
  }

  // ── 테이블 이름 상수 ─────────────────────────────────────────
  static const String usersTable = 'users';
  static const String mentorProfilesTable = 'mentor_profiles';
  static const String mentorCertificationsTable = 'mentor_certifications';
  static const String mentorDocumentsTable = 'mentor_documents';
  static const String questionsTable = 'questions';
  static const String questionFiltersTable = 'question_filters';
  static const String chatRoomsTable = 'chat_rooms';
  static const String chatMessagesTable = 'chat_messages';
  static const String cashLedgerTable = 'cash_ledger';
  static const String cashHoldsTable = 'cash_holds';
  static const String disputesTable = 'disputes';
  static const String reviewsTable = 'reviews';
  static const String boardPostsTable = 'board_posts';
  static const String boardCommentsTable = 'board_comments';
  static const String boardLikesTable = 'board_likes';
  static const String subjectDefaultPricesTable = 'subject_default_prices';
  static const String notificationsTable = 'notifications';
  static const String mentorConsultationRatesTable =
      'mentor_consultation_rates';
  static const String certRequestsTable = 'cert_requests';
  static const String mentorFavoritesTable = 'mentor_favorites';

  // ── Storage 버킷 이름 ────────────────────────────────────────
  static const String questionImagesBucket = 'question-images';
  static const String mentorDocumentsBucket = 'mentor-documents';
  static const String avatarsBucket = 'avatars';
  static const String boardImagesBucket = 'board-images';
  static const String disputeEvidenceBucket = 'dispute-evidence';
}
