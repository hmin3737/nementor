import 'package:flutter/material.dart';

/// 내멘토 스페이싱 시스템 — 4pt 기반
/// 여백/간격 변경 시 이 파일만 수정하세요.
abstract final class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double base = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double x2l = 32.0;
  static const double x3l = 48.0;
  static const double x4l = 64.0;

  // ── 화면 레이아웃 ─────────────────────────────────────────────
  static const double screenHorizontal = base; // 화면 좌우 여백
  static const double cardPadding = base; // 카드 내부 패딩
  static const double cardPaddingV = md; // 카드 상하 패딩
  static const double sectionGap = x2l; // 섹션 간격
  static const double itemGap = md; // 목록 아이템 간격

  // ── 컴포넌트 ─────────────────────────────────────────────────
  static const double cardRadius = 16.0; // 카드 corner radius
  static const double buttonRadius = 14.0; // 버튼 corner radius
  static const double inputRadius = 12.0; // 입력창 corner radius
  static const double chipRadius = 100.0; // 칩 corner radius (pill)
  static const double badgeRadius = 6.0; // 배지 corner radius
  static const double bottomSheetRadius = 24.0; // 바텀시트 corner radius
  static const double dialogRadius = 20.0; // 다이얼로그 corner radius

  // ── 버튼 ────────────────────────────────────────────────────
  static const double buttonHeight = 54.0; // Primary 버튼 높이
  static const double buttonHeightSm = 44.0; // 작은 버튼 높이
  static const double buttonHeightXs = 36.0; // 아주 작은 버튼

  // ── 아이콘/아바타 ────────────────────────────────────────────
  static const double avatarSm = 36.0;
  static const double avatarMd = 48.0;
  static const double avatarLg = 64.0;
  static const double iconSm = 16.0;
  static const double iconMd = 20.0;
  static const double iconLg = 24.0;

  // ── 탭바 ────────────────────────────────────────────────────
  static const double tabBarHeight = 60.0;
  static const double tabBarIconSize = 24.0;

  // ── 그림자 ──────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF000000).withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: const Color(0xFF000000).withValues(alpha: 0.10),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ];

  // ── EdgeInsets 헬퍼 ──────────────────────────────────────────
  static const EdgeInsets screenPadding =
      EdgeInsets.symmetric(horizontal: screenHorizontal);

  static const EdgeInsets cardInsets =
      EdgeInsets.symmetric(horizontal: cardPadding, vertical: cardPaddingV);

  static const EdgeInsets sectionInsets =
      EdgeInsets.symmetric(horizontal: screenHorizontal, vertical: x2l);
}
