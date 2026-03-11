import 'package:flutter/material.dart';

/// 내멘토 색상 시스템
/// 색상 변경 시 이 파일만 수정하면 앱 전체에 반영됩니다.
abstract final class AppColors {
  // ── 브랜드 기본 ──────────────────────────────────────────────
  static const Color primary = Color(0xFF160534); // 딥 퍼플 블랙
  static const Color accent = Color(0xFF8000FF); // 브랜드 퍼플 (문제해결 CTA)
  static const Color consultAccent = Color(0xFF00B4D8); // 스카이 블루 (학습상담 CTA)
  static const Color surface = Color(0xFFF7F5FF); // 연보라 배경
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFEDE8FA); // 보라빛 테두리

  // ── 내멘토 인증 ───────────────────────────────────────────────
  static const Color proCertColor = Color(0xFF8000FF); // 프로 인증 — 브랜드 퍼플
  static const Color masterCertColor = Color(0xFF10B981); // 마스터 인증 — 에메랄드

  // ── 시멘틱 ──────────────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // ── 텍스트 ──────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0D0120); // 퍼플 틴트 블랙
  static const Color textSub = Color(0xFF6B6380); // 퍼플 틴트 회색
  static const Color textDisabled = Color(0xFFC4BBD4); // 연보라 비활성
  static const Color textOnAccent = Color(0xFFFFFFFF);

  // ── 다크모드 ─────────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF06010F);
  static const Color darkSurface = Color(0xFF160534);
  static const Color darkCard = Color(0xFF1E0A42);
  static const Color darkBorder = Color(0xFF2D1A52);

  // ── 기타 ────────────────────────────────────────────────────
  static const Color mathBlock = Color(0xFFF3EEFF); // 연보라 수식 블록 배경
  static const Color studentBubble = accent; // 학생 말풍선
  static const Color mentorBubble = card; // 멘토 말풍선
  static const Color divider = Color(0xFFEDE8FA);
  static const Color shimmerBase = Color(0xFFE8E0F5);
  static const Color shimmerHighlight = Color(0xFFF5F0FF);

  // ── 그라디언트 ───────────────────────────────────────────────
  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF9B30FF), Color(0xFF5A00C0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient consultGradient = LinearGradient(
    colors: [Color(0xFF00B4D8), Color(0xFF0090AD)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── ThemeData 헬퍼 ───────────────────────────────────────────
  static ColorScheme get lightColorScheme => const ColorScheme.light(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: error,
        onPrimary: textOnAccent,
        onSecondary: textOnAccent,
        onSurface: textPrimary,
        onError: textOnAccent,
        outline: border,
      );

  static ColorScheme get darkColorScheme => const ColorScheme.dark(
        primary: accent,
        secondary: consultAccent,
        surface: darkSurface,
        error: error,
        onPrimary: textOnAccent,
        onSecondary: textOnAccent,
        onSurface: Color(0xFFE8E0F5),
        onError: textOnAccent,
        outline: darkBorder,
      );
}
