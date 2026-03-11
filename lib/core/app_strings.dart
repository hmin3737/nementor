/// 내멘토 UI 문구 모음
/// 앱 내 모든 텍스트를 여기서 관리합니다. 문구 변경 시 이 파일만 수정하세요.
abstract final class AppStrings {
  // ── 앱 ──────────────────────────────────────────────────────
  static const String appName = '내멘토';
  static const String appTagline = '수학, 이제 막히면 내멘토';

  // ── 인증 ────────────────────────────────────────────────────
  static const String loginTitle = '내멘토에 오신 걸\n환영합니다';
  static const String loginSubtitle = '학습의 새로운 시작';
  static const String kakaoLogin = '카카오로 계속하기';
  static const String appleLogin = 'Apple로 계속하기';
  static const String emailLogin = '이메일로 로그인';
  static const String emailSignup = '이메일로 가입하기';
  static const String logout = '로그아웃';
  static const String logoutConfirm = '로그아웃 하시겠어요?';

  static const String signupRoleTitle = '어떤 역할로 가입하시나요?';
  static const String signupRoleSubtitle = '역할은 나중에 변경할 수 없어요.\n멘토로도 활동하려면 별도 계정이 필요합니다.';
  static const String studentRole = '학생';
  static const String studentRoleDesc = '질문을 올리고 멘토에게 답변 받기';
  static const String mentorRole = '멘토';
  static const String mentorRoleDesc = '질문에 답변하고 수익 창출하기';

  static const String nicknameTitle = '닉네임을 설정해 주세요';
  static const String nicknameHint = '2~12자, 한글/영문/숫자';
  static const String nicknameCheck = '중복 확인';
  static const String nicknameAvailable = '사용 가능한 닉네임이에요';
  static const String nicknameTaken = '이미 사용 중인 닉네임이에요';

  static const String mentorInfoTitle = '멘토 기본 정보';
  static const String realName = '실명';
  static const String realNameHint = '실명을 입력해 주세요';
  static const String middleSchool = '중학교 (선택)';
  static const String highSchool = '고등학교 (선택)';
  static const String university = '대학교 (선택)';
  static const String department = '학과 (선택)';
  static const String documentUpload = '재학증명서 업로드';
  static const String documentUploadDesc = '재학증명서 또는 졸업증명서를 업로드해 주세요.\n관리자 검토 후 인증 마크가 부여됩니다.';
  static const String documentPending = '서류 검토 중';
  static const String documentVerified = '인증 완료';
  static const String mentorIntroTitle = '멘토 소개';
  static const String introHint = '한줄 소개 (최대 50자)';
  static const String bioHint = '상세 소개를 입력해 주세요';
  static const String subjectSelectTitle = '담당 과목을 선택해 주세요';

  // ── 탭바 ────────────────────────────────────────────────────
  static const String tabFeed = '피드';
  static const String tabBoard = '칼럼';
  static const String tabAsk = '질문하기';
  static const String tabConsulting = '상담관리';
  static const String tabExploreMentor = '멘토 탐색';
  static const String tabNotification = '알림';
  static const String tabMypage = '마이';

  // ── 문제해결 ─────────────────────────────────────────────────
  static const String problemTitle = '문제해결';
  static const String questionFeed = '질문 피드';
  static const String registerQuestion = '질문 등록';
  static const String editQuestion = '질문 수정';

  static const String schoolLevel = '학교급';
  static const String elementary = '초등';
  static const String middle = '중등';
  static const String high = '고등';
  static const String etc = '기타';

  static const String subject = '과목';
  static const String subjectKorean = '국어';
  static const String subjectEnglish = '영어';
  static const String subjectMath = '수학';
  static const String subjectSocial = '사회';
  static const String subjectScience = '과학';
  static const String subjectEtc = '기타';

  static const String questionTitle = '제목 (선택)';
  static const String questionTitleHint = '질문 제목을 입력해 주세요';
  static const String questionBody = '질문 내용';
  static const String questionBodyHint = '질문을 자세히 설명해 주세요.\n수식이 있다면 수식 버튼을 사용하세요.';
  static const String addImage = '이미지 추가';
  static const String imageLimit = '최대 5장, 10MB 이하';

  static const String priceTitle = '가격 설정';
  static const String priceUnit = '₩';
  static const String avgAnswerTime = '이 가격대 평균 답변 시간';
  static const String aboutMin = '약 {0}분';

  static const String mentorFilter = '멘토 필터';
  static const String filterAll = '모든 멘토';
  static const String filterSpecific = '특정 멘토 선택';
  static const String filterCondition = '조건 필터';
  static const String addCertCondition = '+ 인증 조건 추가';
  static const String proOrAbove = '프로 이상';
  static const String masterOnly = '마스터만';
  static const String universityFilter = '특정 대학교 재학';

  static const String questionConfirmTitle = '질문 등록 확인';
  static const String willDeduct = '차감될 캐시';
  static const String currentBalance = '현재 잔액';
  static const String afterBalance = '등록 후 잔액';
  static const String registerNow = '등록하기';
  static const String notEnoughCash = '캐시가 부족해요';
  static const String chargeCash = '캐시 충전하기';

  static const String preempt = '선점하기';
  static const String preemptConfirm = '이 질문을 선점하시겠어요?';
  static const String preemptConfirmDesc = '선점 후에는 바로 채팅방이 열립니다.\n학생이 질문한 가격: {0}';
  static const String alreadyPreempted = '다른 멘토가 먼저 선점했어요';
  static const String preemptSuccess = '선점했어요! 채팅방이 열립니다.';

  static const String chatRoom = '채팅';
  static const String declareEnd = '종료 선언';
  static const String declareEndConfirm = '답변을 종료하시겠어요?';
  static const String declareEndDesc = '종료하면 즉시 답변이 마감됩니다.\n이의가 있으면 분쟁 신청이 가능합니다.';
  static const String endDeclared = '답변이 종료되었습니다.';
  static const String endConfirmed = '답변이 종료되었습니다.';
  static const String raiseDispute = '이의 신청';
  static const String inputMessage = '메시지를 입력하세요';
  static const String addMath = '수식';

  // ── 평가 ────────────────────────────────────────────────────
  static const String reviewTitle = '답변은 어떠셨나요?';
  static const String reviewHint = '후기를 남겨주세요 (선택)';
  static const String submitReview = '후기 등록';
  static const String skipReview = '건너뛰기';

  // ── 멘토 탐색 ─────────────────────────────────────────────────
  static const String exploreMentor = '멘토 탐색';
  static const String mentorProfile = '멘토 프로필';
  static const String hourlyRate = '시급';
  static const String hourlyRateRange = '시급 {0}~{1}';
  static const String rating = '평점';
  static const String reviewCount = '리뷰 {0}개';
  static const String recentColumns = '최근 칼럼';
  static const String recentReviews = '최근 리뷰';
  static const String requestConsulting = '상담 신청';

  // ── 내멘토 인증 ───────────────────────────────────────────────
  static const String certTitle = '내멘토 인증';
  static const String certPro = 'PRO';
  static const String certMaster = 'MASTER';
  static const String certProLabel = '프로';
  static const String certMasterLabel = '마스터';
  static const String certDescription = '내멘토가 검증한 전문 멘토입니다.';
  static const String noCert = '인증 없음';
  static const String unverifiedMentor = '미인증';

  // ── 게시판 ──────────────────────────────────────────────────
  static const String boardTitle = '학습 칼럼';
  static const String writeColumn = '칼럼 작성';
  static const String editColumn = '칼럼 수정';
  static const String deleteColumn = '삭제';
  static const String deleteColumnConfirm = '칼럼을 삭제하시겠어요?';
  static const String viewCount = '조회 {0}';
  static const String likeCount = '좋아요 {0}';
  static const String commentCount = '댓글 {0}';
  static const String writeComment = '댓글 작성';
  static const String commentHint = '댓글을 입력하세요';
  static const String writeReply = '답글 달기';
  static const String replyHint = '답글을 입력하세요';
  static const String submit = '등록';

  // ── 캐시/결제 ─────────────────────────────────────────────────
  static const String cashTitle = '캐시';
  static const String myBalance = '내 캐시';
  static const String chargeTitle = '캐시 충전';
  static const String chargeHistory = '충전 내역';
  static const String useHistory = '사용 내역';
  static const String cashUnit = '캐시';
  static const String iapCharge = '캐시 충전';
  static const String questionHold = '질문 등록';
  static const String questionRefund = '질문 취소 환불';
  static const String mentorEarn = '답변 수익';
  static const String platformFee = '플랫폼 수수료';
  static const String adminAdjust = '관리자 조정';

  // ── 분쟁조정센터 ─────────────────────────────────────────────
  static const String disputeTitle = '분쟁조정센터';
  static const String disputeApply = '분쟁 신청';
  static const String disputeReason = '분쟁 사유';
  static const String disputeReasonHint = '분쟁 사유를 자세히 설명해 주세요';
  static const String disputeAttach = '증거 첨부 (선택)';
  static const String disputePending = '접수됨';
  static const String disputeReviewing = '검토 중';
  static const String disputeResolved = '처리 완료';
  static const String disputeResult = '처리 결과';

  // ── 마이페이지 ───────────────────────────────────────────────
  static const String mypageTitle = '마이페이지';
  static const String myQuestions = '내 질문 내역';
  static const String myAnswers = '내 답변 내역';
  static const String myConsulting = '내 상담 내역';
  static const String myEarnings = '수익 내역';
  static const String myDisputes = '분쟁 내역';
  static const String settings = '설정';
  static const String editProfile = '프로필 수정';
  static const String notificationSettings = '알림 설정';

  // ── 관리자 ──────────────────────────────────────────────────
  static const String adminTitle = '관리자';
  static const String documentReview = '서류 심사';
  static const String grantCert = '인증 부여';
  static const String disputeManage = '분쟁 처리';
  static const String priceManage = '추천 가격 설정';
  static const String userManage = '사용자 관리';
  static const String approve = '승인';
  static const String reject = '반려';
  static const String grantPro = '프로 인증 부여';
  static const String grantMaster = '마스터 인증 부여';
  static const String revokeCert = '인증 취소';

  // ── 공통 ────────────────────────────────────────────────────
  static const String confirm = '확인';
  static const String cancel = '취소';
  static const String save = '저장';
  static const String edit = '수정';
  static const String delete = '삭제';
  static const String close = '닫기';
  static const String next = '다음';
  static const String back = '이전';
  static const String complete = '완료';
  static const String loading = '불러오는 중...';
  static const String noData = '데이터가 없어요';
  static const String retry = '다시 시도';
  static const String networkError = '네트워크 연결을 확인해 주세요';
  static const String serverError = '잠시 후 다시 시도해 주세요';
  static const String unknownError = '오류가 발생했어요';
  static const String copyDone = '복사했어요';
  static const String shareDone = '공유했어요';
  static const String today = '오늘';
  static const String yesterday = '어제';

  // ── 과목 목록 ─────────────────────────────────────────────────
  static const List<String> certSubjects = [
    '초중등국어',
    '초중등영어',
    '초중등수학',
    '초중등과학',
    '초중등사회',
    '고등국어',
    '고등수학(미적분)',
    '고등수학(확률과통계)',
    '고등수학(기하)',
    '고등영어',
    '생활과윤리',
    '윤리와사상',
    '한국지리',
    '세계지리',
    '동아시아사',
    '세계사',
    '정치와법',
    '사회문화',
    '경제',
    '물리학I',
    '물리학II',
    '화학I',
    '화학II',
    '생명과학I',
    '생명과학II',
    '지구과학I',
    '지구과학II',
  ];

  /// PRO/MASTER 인증이 부여되는 과목 (초중등 5과목 제외) — 질문 필터 드롭다운에 사용
  static const List<String> certSubjectsForFilter = [
    '고등국어',
    '고등수학(미적분)',
    '고등수학(확률과통계)',
    '고등수학(기하)',
    '고등영어',
    '생활과윤리',
    '윤리와사상',
    '한국지리',
    '세계지리',
    '동아시아사',
    '세계사',
    '정치와법',
    '사회문화',
    '경제',
    '물리학I',
    '물리학II',
    '화학I',
    '화학II',
    '생명과학I',
    '생명과학II',
    '지구과학I',
    '지구과학II',
  ];
}
